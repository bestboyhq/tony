import FluidAudio
import Foundation
import OSLog

/// One dictation: takes 16 kHz samples as they arrive, tracks speech with voice activity detection,
/// and turns them into text.
///
/// Long dictation transcribes in the background while the user still speaks: every pause after half a
/// minute of talk closes a segment, so key up only waits for the last one, and Parakeet never sees the
/// several minutes of audio where it degrades. Cutting inside a pause means no word is cut.
actor Session {
    static let speechThreshold: Float = 0.6
    static let window = VadManager.chunkSize  // 256 ms at 16 kHz
    /// Background segments start once this much audio waits (in VAD windows): ~30 s.
    static let segmentAfter = 117
    /// Past this (~2 min) with no pause, cut at the quietest window anyway.
    static let forceAfter = 470

    private let asr: AsrManager
    private let vad: VadManager
    private let language: Language?
    private var samples: [Float] = []
    private var vadState: VadStreamState
    /// Speech probability per VAD window.
    private var probabilities: [Float] = []
    /// Windows already handed to the model.
    private var committed = 0
    private var texts: [String] = []
    private var background: Task<Void, Never>?
    private let log = Logger(subsystem: "com.bestboyhq.tony", category: "speech")

    init(asr: AsrManager, vad: VadManager, language: Language?) {
        self.asr = asr
        self.vad = vad
        self.language = language
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
    private func transcribe(_ windows: Range<Int>) async -> String {
        guard let speech = Segments.speech(probabilities, in: windows, threshold: Self.speechThreshold) else { return "" }
        let start = speech.lowerBound * Self.window
        let end = min(speech.upperBound * Self.window, samples.count)
        var audio = Array(samples[start..<end])
        if audio.count < 16000 { audio += [Float](repeating: 0, count: 16000 - audio.count) }  // the model wants at least 0.3 s
        do {
            var decoder = TdtDecoderState.make(decoderLayers: await asr.decoderLayerCount)
            let result = try await asr.transcribe(audio, decoderState: &decoder, language: language)
            log.info("transcribed \(Double(audio.count) / 16000, format: .fixed(precision: 1)) s in \(result.processingTime * 1000, format: .fixed(precision: 0)) ms")
            return result.text
        } catch {
            log.error("transcription failed: \(error.localizedDescription, privacy: .public)")
            return ""
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

    /// Where to close a background segment that starts at window `start`, if it is time: the middle of
    /// the first pause (two quiet windows, half a second; Silero reads about 0.2 in a pause between sentences) once `after` windows wait, or the quietest
    /// window once `force` windows wait without a pause.
    static func cut(_ probabilities: [Float], from start: Int, after: Int, force: Int, quiet: Float = 0.4) -> Int? {
        guard probabilities.count - start >= after else { return nil }
        var i = start + after / 3  // no tiny segments
        while i + 1 < probabilities.count {
            if probabilities[i] < quiet, probabilities[i + 1] < quiet { return i + 1 }
            i += 1
        }
        guard probabilities.count - start >= force else { return nil }
        let recent = (probabilities.count - after)..<probabilities.count
        return recent.min { probabilities[$0] < probabilities[$1] }.map { $0 + 1 }
    }
}
