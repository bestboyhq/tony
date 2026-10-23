import FluidAudio
import Foundation
import OSLog

/// One dictation: takes 16 kHz samples as they arrive, tracks speech with voice activity detection,
/// and turns them into text.
///
/// Dictation transcribes in the background while the user still speaks: the first pause after five seconds
/// of talk closes a segment, so key up only transcribes what came after the last one, and Parakeet never sees
/// the several minutes of audio where it degrades. Cutting inside a pause means no word is cut.
actor Session {
    static let speechThreshold: Float = 0.6
    static let window = VadManager.chunkSize  // 256 ms at 16 kHz
    /// A background segment closes at the first pause after this much of it (in VAD windows): ~5 s. On
    /// LibriSpeech and FLEURS fed in real time, key up took 62 ms (median) against 158 ms with segments only
    /// past 30 s, with fewer word errors; at 3 s, punctuation slipped where sentences were split.
    static let segmentAfter = 20
    /// Past this (~2 min) with no pause, cut at the quietest window anyway.
    static let forceAfter = 470

    private let asr: AsrManager
    private let vad: VadManager
    private let language: Language?
    private let words: Words?
    private var samples: [Float] = []
    private var vadState: VadStreamState
    /// Speech probability per VAD window.
    private var probabilities: [Float] = []
    /// Windows already handed to the model.
    private var committed = 0
    private var texts: [String] = []
    private var background: Task<Void, Never>?
    private let log = Logger(subsystem: "com.bestboyhq.tony", category: "speech")

    init(asr: AsrManager, vad: VadManager, language: Language?, words: Words?) {
        self.asr = asr
        self.vad = vad
        self.language = language
        self.words = words
        vadState = VadStreamState.initial()
    }

    func append(_ chunk: [Float]) async {
        samples += chunk
        while samples.count - probabilities.count * Self.window >= Self.window {
            let start = probabilities.count * Self.window
            await classify(Array(samples[start..<start + Self.window]))
        }
        if let cut = Segments.cut(probabilities, from: committed, after: Self.segmentAfter, force: Self.forceAfter) {
            let range = committed..<cut
            committed = cut
            let previous = background
            background = Task {
                await previous?.value
                texts.append(await transcribe(range))
            }
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
        texts.append(await transcribe(committed..<probabilities.count))
        return texts.filter { !$0.isEmpty }.joined(separator: " ")
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
    /// Speech models invent text ("Thank you.") from silence and noise.
    ///
    /// Parakeet hears one language per clip: when the user switches language mid-dictation, it garbles one
    /// language or drops it. Then each language's run is transcribed on its own, if that makes Parakeet sure.
    private func transcribe(_ windows: Range<Int>) async -> String {
        guard let speech = Segments.speech(probabilities, in: windows, threshold: Self.speechThreshold) else { return "" }
        let start = speech.lowerBound * Self.window
        let end = min(speech.upperBound * Self.window, samples.count)
        guard let whole = await recognize(start..<end) else { return "" }
        guard let runs = Segments.languages(Array(probabilities[speech]), tokens: whole.tokens, threshold: Self.speechThreshold, window: Self.window) else { return whole.text }
        // The unsure runs first: unless one of them comes out sure, the whole stands.
        let order = runs.indices.filter { runs[$0].unsure } + runs.indices.filter { !runs[$0].unsure }
        var texts = [String](repeating: "", count: runs.count)
        var rescued = false
        for i in order {
            if !runs[i].unsure, !rescued { break }
            let run = runs[i].samples
            guard let part = await recognize(start + run.lowerBound..<min(start + run.upperBound, end)) else { return whole.text }
            texts[i] = part.text
            rescued = rescued || runs[i].unsure && Segments.sure(part.tokens)
        }
        log.info("split into \(runs.count) runs for a language switch: \(rescued ? "rescued" : "kept the whole", privacy: .public)")
        return rescued ? texts.filter { !$0.isEmpty }.joined(separator: " ") : whole.text
    }

    /// Parakeet's text for `range` of the samples, with the user's words, and the tokens it heard; nil when it fails.
    private func recognize(_ range: Range<Int>) async -> (text: String, tokens: [TokenTiming])? {
        var audio = Array(samples[range])
        if audio.count < 16000 { audio += [Float](repeating: 0, count: 16000 - audio.count) }  // the model wants at least 0.3 s
        do {
            let started = Date()
            async let heard = try? words?.listen(audio)
            var decoder = TdtDecoderState.make(decoderLayers: await asr.decoderLayerCount)
            let result = try await asr.transcribe(audio, decoderState: &decoder, language: language)
            guard let words, let heard = await heard else {
                log.info("transcribed \(Double(audio.count) / 16000, format: .fixed(precision: 1)) s in \(result.processingTime * 1000, format: .fixed(precision: 0)) ms")
                return (result.text, result.tokenTimings ?? [])
            }
            let text = words.apply(to: result, heard: heard)
            log.info("transcribed \(Double(audio.count) / 16000, format: .fixed(precision: 1)) s with the user's words in \(Date().timeIntervalSince(started) * 1000, format: .fixed(precision: 0)) ms")
            return (text, result.tokenTimings ?? [])
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

    /// Where to close a background segment that starts at window `start`, if it is time: at the first pause
    /// past its first `after` windows, or at the quietest window once `force` windows wait without one. A pause
    /// is one quiet window, a breath (Silero reads about 0.2 between sentences): fluent speech seldom pauses for
    /// two. The quiet window starts the next segment, which kept more words than ending this one with it.
    static func cut(_ probabilities: [Float], from start: Int, after: Int, force: Int, quiet: Float = 0.4) -> Int? {
        if let pause = probabilities.indices.dropFirst(start + after).first(where: { probabilities[$0] < quiet }) { return pause }
        guard probabilities.count - start >= force else { return nil }
        return ((probabilities.count - after)..<probabilities.count).min { probabilities[$0] < probabilities[$1] }
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
