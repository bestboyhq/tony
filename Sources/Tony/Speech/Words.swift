import CoreML
import FluidAudio
import Foundation

/// The user's words: names, brands, and jargon Parakeet doesn't know. Parakeet can't bias its own
/// decoding, so a second, small model (Parakeet CTC 110M) listens to the same audio, and one of the
/// user's words replaces what Parakeet wrote only where it is spelled alike and the audio fits it better.
nonisolated struct Words: Sendable {
    /// How much the audio may favor what Parakeet wrote and the user's word still win. FluidAudio tunes
    /// 4.5 for recall; at that, "Monday" became "Moondream". A wrong swap costs more trust than a miss.
    static let boost: Float = 3.0

    private let models: CtcModels
    private let vocabulary: CustomVocabularyContext
    private let rescorer: VocabularyRescorer
    private let minSimilarity: Float
    /// Words written the user's way wherever Parakeet heard them, whatever its capitals.
    private let respelled: [String]

    /// `respelled` are the words that aren't everyday English, so their capitals are always the user's:
    /// "tailscale" becomes Tailscale, but the conductor of an orchestra stays lowercase.
    init(_ words: [String], respelled: [String], models: CtcModels) async throws {
        let directory = CtcModels.defaultCacheDirectory(for: models.variant)
        let tokenizer = try await CtcTokenizer.load(from: directory)
        vocabulary = CustomVocabularyContext(terms: words.compactMap { word in
            let ids = tokenizer.encode(word)
            return ids.isEmpty ? nil : CustomVocabularyTerm(text: word, ctcTokenIds: ids)
        })
        self.models = models
        let spotter = CtcKeywordSpotter(models: models, blankId: models.vocabulary.count)
        // No acoustic rescue: it swaps in words spelled nothing alike ("rolled it back" became Wojtek).
        rescorer = try await VocabularyRescorer.create(
            spotter: spotter, vocabulary: vocabulary, config: .init(spotterRescueEnabled: false), ctcModelDirectory: directory)
        minSimilarity = max(ContextBiasingConstants.rescorerConfig(forVocabSize: vocabulary.terms.count).minSimilarity, vocabulary.minSimilarity)
        self.respelled = respelled
    }

    /// What the word model hears in `audio`: log-probabilities per 80 ms frame. Runs alongside Parakeet.
    ///
    /// FluidAudio's `spotKeywordsWithLogProbs` would do this, but it copies every value through NSNumber
    /// (90 ms a call; the models take 10) and leaves the input past the audio uninitialized, which holds
    /// NaNs that make the model deaf. So this runs the two models itself, on 15 s windows that overlap
    /// by 2 s and are averaged where they do, like FluidAudio.
    func listen(_ audio: [Float]) async throws -> Heard {
        let window = ASRConstants.maxModelSamples, overlap = 32_000
        var heard = Heard(logProbs: [], frameDuration: 0)
        var start = 0
        while true {
            let chunk = audio[start..<min(start + window, audio.count)]
            let frames = try await logProbabilities(chunk)
            heard.frameDuration = Double(window) / Double(frames.count) / 16000
            let valid = frames.prefix(Int((Double(chunk.count) / Double(window) * Double(frames.count)).rounded(.up)))
            let shared = start == 0 ? 0 : min(Int(Double(overlap) / 16000 / heard.frameDuration), heard.logProbs.count, valid.count)
            for (i, frame) in valid.prefix(shared).enumerated() {
                let j = heard.logProbs.count - shared + i
                heard.logProbs[j] = zip(heard.logProbs[j], frame).map { a, b in
                    let m = max(a, b)
                    return m + log(exp(a - m) + exp(b - m)) - log(2)  // the mean of the two probabilities
                }
            }
            heard.logProbs += valid.dropFirst(shared)
            if start + window >= audio.count { return heard }
            start += window - overlap
        }
    }

    struct Heard: Sendable {
        var logProbs: [[Float]]
        var frameDuration: Double
    }

    /// Log-probabilities of every token in every frame of one 15 s window, `chunk` padded with silence.
    private func logProbabilities(_ chunk: ArraySlice<Float>) async throws -> [[Float]] {
        let audio = try MLMultiArray(shape: [NSNumber(value: ASRConstants.maxModelSamples)], dataType: .float32)
        audio.withUnsafeMutableBufferPointer(ofType: Float.self) { buffer, _ in
            buffer.update(repeating: 0)
            _ = buffer.update(fromContentsOf: chunk)
        }
        let mel = try await models.melSpectrogram.prediction(from: MLDictionaryFeatureProvider(dictionary: ["audio": audio]))
        let flag = try MLMultiArray(shape: [1, 1, 1, 1], dataType: .float16)
        flag[0] = 1
        let encoded = try await models.encoder.prediction(from: MLDictionaryFeatureProvider(dictionary: [
            "melspectrogram_features": mel.featureValue(for: "melspectrogram_features")!, "input_1": MLFeatureValue(multiArray: flag),
        ]))
        guard let logits = encoded.featureValue(for: "ctc_head_raw_output")?.multiArrayValue, logits.shape.count == 4 else {
            throw ASRError.processingFailed("The words model gave no output")
        }
        // [1, tokens, 1, frames], read through its strides: the Neural Engine pads rows.
        let tokens = logits.shape[1].intValue, frames = logits.shape[3].intValue
        let tokenStride = logits.strides[1].intValue, frameStride = logits.strides[3].intValue
        let values: [Float] = logits.withUnsafeBytes { bytes in
            let count = logits.strides[0].intValue
            return logits.dataType == .float16
                ? bytes.bindMemory(to: Float16.self).prefix(count).map(Float.init)
                : Array(bytes.bindMemory(to: Float.self).prefix(count))
        }
        return (0..<frames).map { frame in
            let row = (0..<tokens).map { values[$0 * tokenStride + frame * frameStride] }
            let m = row.max()!
            let sum = log(row.reduce(0) { $0 + exp($1 - m) })
            return row.map { $0 - m - sum }
        }
    }

    /// `result`'s text with the user's words swapped in, spelled their way, punctuation kept.
    func apply(to result: ASRResult, heard: Heard) -> String {
        guard let timings = result.tokenTimings, !timings.isEmpty, !heard.logProbs.isEmpty else { return result.text }
        let evidence = rescorer.ctcTokenEvaluateCandidates(
            transcript: result.text, tokenTimings: timings, logProbs: heard.logProbs, frameDuration: heard.frameDuration,
            cbw: Self.boost, marginSeconds: 0.5, minSimilarity: minSimilarity
        )
        // FluidAudio's own rewrite drops the punctuation around a swapped word; swap the exact bytes instead.
        let bytes = Array(result.text.utf8)
        let swaps = evidence.candidates.compactMap { candidate -> (Range<Int>, String)? in
            guard candidate.legacyOutcome == .applied, let range = candidate.baseTextUTF8Range, range.upperBound <= bytes.count,
                  !Self.inflects(String(decoding: bytes[range], as: UTF8.self), candidate.canonicalTerm) else { return nil }
            return (range, candidate.canonicalTerm)
        }
        return Self.respell(Self.replace(result.text, swaps), respelled)
    }

    /// Whether `heard` is `word` with an ending, in any capitals and accents: "na Mokotowie" is Mokotów
    /// in Polish, and "Tailscales" is Tailscale. Swapping in the bare word would break the sentence.
    static func inflects(_ heard: String, _ word: String) -> Bool {
        let fold = { (text: String) in text.filter(\.isLetter).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) }
        let heard = fold(heard), word = fold(word)
        return heard.count > word.count && heard.hasPrefix(word)
    }

    /// Replaces UTF-8 byte ranges of `text`, skipping any that overlap one already replaced.
    static func replace(_ text: String, _ swaps: [(Range<Int>, String)]) -> String {
        var bytes = Array(text.utf8)
        var end = bytes.count
        for (range, word) in swaps.sorted(by: { $0.0.lowerBound > $1.0.lowerBound }) where range.upperBound <= end {
            bytes.replaceSubrange(range, with: Array(word.utf8))
            end = range.lowerBound
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// Writes each of `words` the user's way wherever it stands as a whole word, in any capitals.
    static func respell(_ text: String, _ words: [String]) -> String {
        words.reduce(text) { text, word in
            let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: word) + "(?![\\p{L}\\p{N}])"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return text }
            return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: NSRegularExpression.escapedTemplate(for: word))
        }
    }
}
