import FluidAudio
import Foundation
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
    @ObservationIgnored private var asr: AsrManager?
    @ObservationIgnored private var vad: VadManager?
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
        return Session(asr: asr, vad: vad, language: language)
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
