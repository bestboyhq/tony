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

    var isReady: Bool { state == .ready }

    func prepare() async {
        switch state {
        case .idle, .failed: break
        default: return
        }
        let started = Date()
        do {
            state = .downloading(0)
            // From Hugging Face once, resumable, and downloaded again if missing or corrupt.
            let vad = try await VadManager(config: VadConfig(defaultThreshold: Session.speechThreshold))
            let models = try await AsrModels.downloadAndLoad(version: Self.version) { [weak self] progress in
                let next: State = if case .compiling = progress.phase { .loading } else { .downloading(progress.fractionCompleted) }
                Task { @MainActor in
                    switch self?.state {
                    case .downloading, .loading: self?.state = next
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

    func session(language: Language?) -> Session? {
        guard let asr, let vad else { return nil }
        return Session(asr: asr, vad: vad, language: language, words: words)
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
