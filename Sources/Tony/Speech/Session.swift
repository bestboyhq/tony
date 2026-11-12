import FluidAudio
import Foundation
import OSLog

/// One dictation: takes 16 kHz samples as they arrive, tracks speech with voice activity detection,
/// and turns them into text.
///
/// Dictation transcribes in the background while the user still speaks: the first pause after ten seconds
/// of talk closes a segment, so key up only transcribes what came after the last one, and Parakeet never sees
/// the several minutes of audio where it degrades. Cutting inside a pause means no word is cut. And at each
/// breath, the rest is drafted: when the user lets go without saying more, the draft is the text.
actor Session {
    static let speechThreshold: Float = 0.6
    static let window = VadManager.chunkSize  // 256 ms at 16 kHz
    /// A background segment closes at the first pause after this much of it (in VAD windows): ~10 s, so it
    /// fits the model's one 15 s window. At 5 s and a breath, FLEURS dictations of three sentences came out
    /// with 16% more word errors in English than with 30 s.
    static let segmentAfter = 40
    /// Past this (~2 min) with no pause, cut at the quietest window anyway.
    static let forceAfter = 470
    /// Parakeet hears this much (in VAD windows, ~2 s) on each side of a cut, and writes only the words that
    /// start on its side. Heard alone, a segment ends in a period and the next starts with a capital, so a
    /// thinking pause mid-sentence came out "like fire. And forget".
    static let context = 8

    private let asr: AsrManager
    private let vad: VadManager
    private let languages: Set<Language>
    private let words: Words?
    private var samples: [Float] = []
    private var vadState: VadStreamState
    /// Speech probability per VAD window.
    private var probabilities: [Float] = []
    /// Windows already handed to the model.
    private var committed = 0
    private var texts: [(text: String, next: String?)] = []
    private var background: Task<Void, Never>?
    /// The windows since the last cut, transcribed at the user's last breath.
    private var draft: (windows: Range<Int>, text: Task<String, Never>)?
    private let log = Logger(subsystem: "com.bestboyhq.tony", category: "speech")

    init(asr: AsrManager, vad: VadManager, languages: Set<Language>, words: Words?) {
        self.asr = asr
        self.vad = vad
        self.languages = languages
        self.words = words
        vadState = VadStreamState.initial()
    }

    func append(_ chunk: [Float]) async {
        samples += chunk
        while samples.count - probabilities.count * Self.window >= Self.window {
            let start = probabilities.count * Self.window
            await classify(Array(samples[start..<start + Self.window]))
        }
        let previous = background
        if let cut = Segments.cut(probabilities, from: committed, after: Self.segmentAfter, force: Self.forceAfter, context: Self.context) {
            let range = committed..<cut
            committed = cut
            background = Task {
                await previous?.value
                texts.append(await transcribe(range, cut: true))
            }
        } else if let last = probabilities.indices.last, last > committed, draft?.windows != committed..<probabilities.count,
                  probabilities[last] < Self.speechThreshold, probabilities[last - 1] >= Self.speechThreshold {
            // A breath: what key up would transcribe, should the user say nothing more.
            let windows = committed..<probabilities.count
            draft = (windows, Task {
                await previous?.value
                return await transcribe(windows).text
            })
        }
    }

    /// The whole dictation as text, empty when nobody spoke.
    func finish() async -> String {
        let tail = samples.count - probabilities.count * Self.window
        if tail > 0 {
            let start = probabilities.count * Self.window
            await classify(Array(samples[start...]) + [Float](repeating: 0, count: Self.window - tail))
        }
        await background?.value
        // Nothing said since the draft: its speech, padded and trimmed, is what is left.
        if let draft, draft.windows.lowerBound == committed, !probabilities[draft.windows.upperBound...].contains(where: { $0 >= Self.speechThreshold }) {
            texts.append((await draft.text.value, nil))
        } else {
            texts.append(await transcribe(committed..<probabilities.count))
        }
        return Segments.join(texts)
    }

    private func classify(_ window: [Float]) async {
        do {
            let result = try await vad.processStreamingChunk(window, state: vadState)
            vadState = result.state
            probabilities.append(result.probability)
        } catch {
            log.error("VAD failed: \(error.localizedDescription, privacy: .public)")
            probabilities.append(1)  // unsure: let the model hear it
        }
    }

    /// Transcribes the speech in `windows`, trimmed of silence at both ends; nothing when there is none.
    /// Speech models invent text ("Thank you.") from silence and noise. Parakeet also hears the `context`
    /// before a cut, and after it when the windows end at one, and writes only the words that start in the windows;
    /// `next` is the word it heard after the cut.
    ///
    /// Parakeet hears one language per clip: when the user switches language mid-dictation, it garbles one
    /// language or drops it. Then each language's run is transcribed on its own, if that makes Parakeet sure.
    private func transcribe(_ windows: Range<Int>, cut: Bool = false) async -> (text: String, next: String?) {
        guard let speech = Segments.speech(probabilities, in: windows, threshold: Self.speechThreshold) else { return ("", nil) }
        let start = speech.lowerBound * Self.window
        let end = min(speech.upperBound * Self.window, samples.count)
        // Within the model's one window: past it, FluidAudio cuts the clip again, in speech. The words after a cut
        // come first: with a second of them or less, the segment still ended in a period ("how. Much").
        let room = max(0, ASRConstants.maxModelSamples - (end - start))
        let after = cut ? min(Self.context * Self.window, room, samples.count - end) : 0
        let before = windows.lowerBound > 0 ? min(Self.context * Self.window, room - after, start) : 0
        let clip = start - before..<end + after
        guard let whole = await recognize(clip, keeping: windows.lowerBound * Self.window..<windows.upperBound * Self.window) else { return ("", nil) }
        let offset = Double(start - clip.lowerBound) / 16000
        let tokens = whole.tokens.map { TokenTiming(token: $0.token, tokenId: $0.tokenId, startTime: $0.startTime - offset, endTime: $0.endTime - offset, confidence: $0.confidence) }
        guard let runs = Segments.languages(Array(probabilities[speech]), tokens: tokens, threshold: Self.speechThreshold, window: Self.window) else { return (whole.text, whole.next) }
        // The unsure runs first: unless one of them comes out sure, the whole stands.
        let order = runs.indices.filter { runs[$0].unsure } + runs.indices.filter { !runs[$0].unsure }
        var texts = [String](repeating: "", count: runs.count)
        var rescued = false
        for i in order {
            if !runs[i].unsure, !rescued { break }
            let run = runs[i].samples
            guard let part = await recognize(start + run.lowerBound..<min(start + run.upperBound, end)) else { return (whole.text, whole.next) }
            texts[i] = part.text
            rescued = rescued || runs[i].unsure && Segments.sure(part.tokens)
        }
        log.info("split into \(runs.count) runs for a language switch: \(rescued ? "rescued" : "kept the whole", privacy: .public)")
        return (rescued ? texts.filter { !$0.isEmpty }.joined(separator: " ") : whole.text, whole.next)
    }

    /// Parakeet's text for `clip` of the samples, with the user's words, and the tokens it heard, timed from the
    /// clip's start; with `keep`, only the words that start in those samples, and the word it heard after them.
    /// Nil when it fails.
    private func recognize(_ clip: Range<Int>, keeping keep: Range<Int>? = nil) async -> (text: String, tokens: [TokenTiming], next: String?)? {
        var audio = Array(samples[clip])
        if audio.count < 16000 { audio += [Float](repeating: 0, count: 16000 - audio.count) }  // the model wants at least 0.3 s
        do {
            let started = Date()
            async let heard = try? words?.listen(audio)
            var decoder = TdtDecoderState.make(decoderLayers: await asr.decoderLayerCount)
            var result = try await asr.transcribe(audio, decoderState: &decoder, languages: languages)
            var next: String?
            if let keep {
                let from = Double(keep.lowerBound - clip.lowerBound) / 16000, to = Double(keep.upperBound - clip.lowerBound) / 16000
                next = Segments.words(of: result, startingIn: to..<Double.infinity).text.split(separator: " ").first.map(String.init)
                result = Segments.words(of: result, startingIn: from..<to)
            }
            guard let words, let heard = await heard else {
                log.info("transcribed \(Double(audio.count) / 16000, format: .fixed(precision: 1)) s in \(result.processingTime * 1000, format: .fixed(precision: 0)) ms")
                return (Cleanup.dropUnknown(result.text), result.tokenTimings ?? [], next)
            }
            let text = words.apply(to: result, heard: heard)
            log.info("transcribed \(Double(audio.count) / 16000, format: .fixed(precision: 1)) s with the user's words in \(Date().timeIntervalSince(started) * 1000, format: .fixed(precision: 0)) ms")
            return (Cleanup.dropUnknown(text), result.tokenTimings ?? [], next)
        } catch {
            log.error("transcription failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

/// Where speech is, and where to cut, in per-window speech probabilities.
nonisolated enum Segments {
    /// Windows with speech in `range`, padded by one window each side; nil when nobody spoke.
    static func speech(_ probabilities: [Float], in range: Range<Int>, threshold: Float) -> Range<Int>? {
        let range = range.clamped(to: 0..<probabilities.count)
        guard let first = range.first(where: { probabilities[$0] >= threshold }),
              let last = range.last(where: { probabilities[$0] >= threshold }) else { return nil }
        return max(range.lowerBound, first - 1)..<min(range.upperBound, last + 2)
    }

    /// Where to close a background segment that starts at window `start`, if it is time: at the start of the
    /// first pause past its first `after` windows, or at the quietest window once `force` windows wait without
    /// one; either with `context` windows heard after it. A pause is two quiet windows, half a second (Silero
    /// reads about 0.2 between sentences): one quiet window is a breath, often mid-sentence, and cutting there
    /// cost words on both sides. The word after a pause starts at its end, and Parakeet times it up to 100 ms
    /// early: cut in the middle, the word came out on both sides of the cut, or on neither.
    static func cut(_ probabilities: [Float], from start: Int, after: Int, force: Int, context: Int = 1, quiet: Float = 0.4) -> Int? {
        if let pause = probabilities.indices.dropFirst(start + after).dropLast(context).first(where: { probabilities[$0] < quiet && probabilities[$0 + 1] < quiet }) { return pause }
        guard probabilities.count - start >= force else { return nil }
        return ((probabilities.count - after)...(probabilities.count - context)).min { probabilities[$0] < probabilities[$1] }
    }

    /// `result` with only the words whose first token starts in `seconds`, each with its punctuation.
    static func words(of result: ASRResult, startingIn seconds: Range<Double>) -> ASRResult {
        guard let timings = result.tokenTimings else { return result }
        var kept = false
        let tokens = timings.enumerated().filter { i, timing in
            if i == 0 || timing.token.hasPrefix(" ") { kept = seconds.contains(timing.startTime) }
            return kept
        }.map(\.element)
        guard tokens.count < timings.count else { return result }
        return ASRResult(text: tokens.map(\.token).joined().trimmingCharacters(in: .whitespaces), confidence: result.confidence,
                         duration: result.duration, processingTime: result.processingTime, tokenTimings: tokens)
    }

    /// The segments' texts as one. Parakeet often starts a sentence at a cut, even when it hears two seconds before
    /// it ("wyślij mi Proszę"), so the word after a cut takes its case from the segment before it, which heard it
    /// mid-clip, where both heard the same word.
    static func join(_ parts: [(text: String, next: String?)]) -> String {
        var texts: [String] = [], next: String?
        for part in parts {
            var text = part.text
            if let next, let word = text.split(separator: " ").first, next.first?.isLetter == true, word.first?.isLetter == true,
               word.filter(\.isLetter).lowercased() == next.filter(\.isLetter).lowercased() {
                text = String(next.prefix(1) + text.dropFirst())
            }
            if !text.isEmpty { texts.append(text) }
            next = part.next
        }
        return texts.joined(separator: " ")
    }

    /// Where Parakeet lost the language in a clip, as runs of sure and unsure parts in samples; nil when
    /// there is nothing to split. Cuts the clip in the middle of each pause and around each second without a
    /// word, and judges each part with a second of speech by Parakeet's confidence in its words: a language it
    /// is not hearing comes out unsure (about 0.6, against 0.95 and up) or as no words at all.
    static func languages(_ probabilities: [Float], tokens: [TokenTiming], threshold: Float, window: Int, quiet: Float = 0.4) -> [(samples: Range<Int>, unsure: Bool)]? {
        // ponytail: a switch with no pause that Parakeet garbles but keeps ("we should przenieść się na piontek")
        // stays whole; cutting at dips in confidence between words would catch it.
        let rate = 16000.0
        let end = probabilities.count * window
        var cuts = [0, end]
        var i = 0
        while i < probabilities.count {
            var j = i
            while j < probabilities.count, probabilities[j] < quiet { j += 1 }
            if j > i { cuts.append((i + j) * window / 2) }
            i = j + 1
        }
        let words = tokens.filter { $0.token.contains(where: \.isLetter) }
        let spans: [(start: Double, end: Double)] = [(0, 0)] + words.map { ($0.startTime, $0.endTime) } + [(Double(end) / rate, 0)]
        for (last, next) in zip(spans, spans.dropFirst()) where next.start - last.end >= 1 {
            cuts += [Int(last.end * rate), Int(next.start * rate)]
        }
        let bounds = Set(cuts.filter { $0 <= end }).sorted()
        var runs: [(samples: Range<Int>, unsure: Bool?)] = []
        for (a, b) in zip(bounds, bounds.dropFirst()) {
            let spoken = probabilities.indices.filter { (a..<b).contains($0 * window + window / 2) && probabilities[$0] >= threshold }.count
            // Less than a second of speech is too little to judge: it goes with its neighbor.
            let unsure: Bool? = spoken * window < Int(rate) ? nil : !sure(words.filter { (a..<b).contains(Int($0.startTime * rate)) })
            if let last = runs.last, unsure == nil || last.unsure == nil || unsure == last.unsure {
                runs[runs.count - 1] = (last.samples.lowerBound..<b, last.unsure ?? unsure)
            } else {
                runs.append((a..<b, unsure))
            }
        }
        return runs.count > 1 ? runs.map { ($0.samples, $0.unsure ?? false) } : nil
    }

    /// Whether Parakeet is sure of the words in `tokens`; not without words.
    static func sure(_ tokens: [TokenTiming]) -> Bool {
        let words = tokens.filter { $0.token.contains(where: \.isLetter) }
        return !words.isEmpty && words.map(\.confidence).reduce(0, +) / Float(words.count) >= 0.8
    }
}
