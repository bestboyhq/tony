import AppKit
import FluidAudio
import Observation
import OSLog

/// The speech model: downloaded on first run, loaded at launch, kept warm.
@Observable
final class Speech {
    enum State: Equatable {
        case idle
        case downloading(Double)
        /// Loading, and on first run compiling for the Neural Engine, which takes a while.
        case loading
        case ready
        case failed(String)
    }

    /// Parakeet TDT v3 post-trained by Moondream ("Ultra"): v3's 25 languages and speed, fewer errors.
    static let version = AsrModelVersion.ultra

    private(set) var state = State.idle
    /// The user's words are on their way: their model downloading, loading, or warming up.
    private(set) var learning = false
    @ObservationIgnored private var asr: AsrManager?
    @ObservationIgnored private var vad: VadManager?
    /// The user's words, ready to listen for; nil while there are none.
    @ObservationIgnored private var words: Words?
    @ObservationIgnored private var wordList: [String] = []
    @ObservationIgnored private var ctc: Task<CtcModels, Error>?
    @ObservationIgnored private let log = Logger(subsystem: "com.bestboyhq.tony", category: "speech")
    /// When the download began: its pace since gives the time it has left.
    @ObservationIgnored private var downloadStarted = Date()

    var isReady: Bool { state == .ready }

    /// How far the model is on its way, until it is ready: loading counts as downloaded.
    var progress: Double? {
        switch state {
        case let .downloading(fraction): fraction
        case .loading: 1
        default: nil
        }
    }

    /// About how long the download has left, once its pace is known.
    var downloadRemaining: TimeInterval? {
        guard case let .downloading(fraction) = state else { return nil }
        return Self.remaining(elapsed: Date().timeIntervalSince(downloadStarted), done: fraction)
    }

    /// The pace so far, over what is left; nil until there is enough of it to go on.
    // ponytail: the average since the start, so a resumed download, whose first files are on disk already, looks
    // fast for its first seconds; time from the first fresh byte if that estimate ever matters.
    static func remaining(elapsed: TimeInterval, done: Double) -> TimeInterval? {
        guard elapsed >= 3, done >= 0.02, done < 1 else { return nil }
        return elapsed / done * (1 - done)
    }

    func prepare() async {
        switch state {
        case .idle, .failed: break
        default: return
        }
        let started = Date()
        do {
            state = .downloading(0)
            downloadStarted = Date()
            // From Hugging Face once, resumable, and downloaded again if missing or corrupt.
            let vad = try await VadManager(config: VadConfig(defaultThreshold: Session.speechThreshold))
            let models = try await AsrModels.downloadAndLoad(version: Self.version) { [weak self] progress in
                // FluidAudio reports a model's download as the first half of its fraction and compiling as the second,
                // so the download alone fills the bar. In whole percents: bytes arrive hundreds of times a second.
                let downloaded = (min(progress.fractionCompleted / 0.5, 1) * 100).rounded(.down) / 100
                let next: State = if case .compiling = progress.phase { .loading } else { .downloading(downloaded) }
                Task { @MainActor in
                    guard let self, self.state != next else { return }
                    switch self.state {
                    case .downloading, .loading: self.state = next
                    default: break  // a late update must not hide .ready or .failed
                    }
                }
            }
            state = .loading
            let asr = AsrManager(config: .default)
            try await asr.loadModels(models)
            // The first inference pays for Neural Engine setup: pay it now, not on the first key press.
            var decoder = TdtDecoderState.make(decoderLayers: await asr.decoderLayerCount)
            _ = try? await asr.transcribe([Float](repeating: 0, count: 16000), decoderState: &decoder)
            self.asr = asr
            self.vad = vad
            state = .ready
            log.info("speech ready in \(Date().timeIntervalSince(started), format: .fixed(precision: 1)) s")
        } catch {
            log.error("speech failed: \(error.localizedDescription, privacy: .public)")
            state = .failed(Self.plain(error))
        }
    }

    func session(languages: Set<Language>) -> Session? {
        guard let asr, let vad else { return nil }
        return Session(asr: asr, vad: vad, language: Self.hint(languages), words: words)
    }

    /// FluidAudio's language hint keeps Parakeet to that language's alphabet (Polish "Tak" comes out Cyrillic
    /// "Так" without one) and, for French alone, keeps English words out. Languages in several alphabets, or
    /// none, leave Parakeet free.
    static func hint(_ languages: Set<Language>) -> Language? {
        guard Set(languages.map(\.script)).count == 1 else { return nil }
        return languages.count == 1 ? languages.first : languages.first { $0 != .french }
    }

    /// Teaches Tony the user's words. Their model (~100 MB) downloads the first time there are any.
    func learn(_ list: [String]) async {
        wordList = list
        guard !list.isEmpty else {
            words = nil
            learning = false
            return
        }
        learning = true
        let respelled = list.filter {
            NSSpellChecker.shared.checkSpelling(of: $0.lowercased(), startingAt: 0, language: "en", wrap: false, inSpellDocumentWithTag: 0, wordCount: nil).location != NSNotFound
        }
        do {
            if ctc == nil { ctc = Task { try await CtcModels.downloadAndLoad() } }
            let words = try await Words(list, respelled: respelled, models: ctc!.value)
            _ = try? await words.listen([Float](repeating: 0, count: 16000))  // the first run pays for Neural Engine setup: pay it now
            if wordList == list { self.words = words }  // a newer list may have landed meanwhile
        } catch {
            ctc = nil  // try again with the next change or launch
            log.error("words failed: \(error.localizedDescription, privacy: .public)")
        }
        if wordList == list { learning = false }
    }

    private static func plain(_ error: Error) -> String {
        let text = "\(error)".lowercased()
        if text.contains("network") || text.contains("offline") || text.contains("internet") || (error as? URLError) != nil {
            return "Tony can't download its speech model. Check your connection."
        }
        if text.contains("space") { return "There isn't enough disk space for the speech model." }
        return "Tony's speech model didn't load."
    }
}
