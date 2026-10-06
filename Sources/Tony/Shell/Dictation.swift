import AVFoundation
import AppKit
import FluidAudio
import Observation
import OSLog

/// One dictation from key down to text at the cursor: hotkey, mic, speech, and insert in order.
@Observable
final class Dictation {
    enum Phase: Equatable {
        case idle, listening, transcribing
        /// One plain sentence with at most one action.
        case notice(Notice)
    }

    struct Notice: Equatable {
        var message: String
        var action: Action?
    }

    enum Action: Equatable {
        case copy(String), openAccessibility, openMicrophone, openSettings, retryModel

        var title: String {
            switch self {
            case .copy: "Copy"
            case .openAccessibility, .openMicrophone: "Open Settings"
            case .openSettings: "Settings"
            case .retryModel: "Try Again"
            }
        }
    }

    private(set) var phase = Phase.idle {
        didSet { if phase != oldValue { onPhase?(phase) } }
    }
    private(set) var handsFree = false
    /// The last dictation, in memory only, for the menu to copy or paste again.
    private(set) var lastText: String?

    @ObservationIgnored let mic = Mic()
    @ObservationIgnored private(set) var hotkey: Hotkey!
    @ObservationIgnored var language: Language?
    @ObservationIgnored var onPhase: ((Phase) -> Void)?
    @ObservationIgnored var onAction: ((Action) -> Void)?

    @ObservationIgnored private let speech: Speech
    @ObservationIgnored private var machine = HotkeyMachine()
    @ObservationIgnored private var session: Session?
    @ObservationIgnored private var feed: AsyncStream<[Float]>.Continuation?
    @ObservationIgnored private var feeder: Task<Void, Never>?
    @ObservationIgnored private var cursor: Task<String?, Never>?
    @ObservationIgnored private var finishing: Task<Void, Never>?
    @ObservationIgnored private var dismiss: Task<Void, Never>?
    /// Text of an earlier dictation that couldn't land while a newer one listened: it lands with the newer one.
    @ObservationIgnored private var carry: String?
    /// Bumped by every start and cancel, so a stale dictation never touches the current one.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private let log = Logger(subsystem: "com.bestboyhq.tony", category: "dictation")

    init(speech: Speech) {
        self.speech = speech
        hotkey = Hotkey { [weak self] input in self?.handle(input) }
        mic.onInterrupted = { [weak self] in
            Task { @MainActor in self?.interrupted() }
        }
    }

    var isBusy: Bool { phase == .listening || phase == .transcribing }

    func handle(_ input: HotkeyMachine.Input) {
        if input == .escape, phase == .transcribing {
            cancel()
            return
        }
        let action = machine.handle(input)
        if let action { log.info("\(String(describing: input), privacy: .public) -> \(String(describing: action), privacy: .public)") }
        switch action {
        case .start: start()
        case .lock:
            handsFree = true
            announce("Hands-free. Press \(Prefs.hotkey.name) to finish.")
        case .stop: stop()
        case .cancel: cancel()
        case nil: break
        }
        if case .tapped = machine.state {
            Task {
                try? await Task.sleep(for: .seconds(HotkeyMachine.doubleTapWindow))
                handle(.tick(ProcessInfo.processInfo.systemUptime))
            }
        }
    }

    /// The mic went away mid-dictation: keep what was heard.
    private func interrupted() {
        guard phase == .listening else { return }
        machine.reset()
        stop()
    }

    private func start() {
        guard !isBusy || phase == .transcribing else { return }
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            return fail("Tony needs access to the microphone.", .openMicrophone)
        }
        guard let session = speech.session(language: language) else {
            switch speech.state {
            case let .downloading(progress): return fail("Tony is downloading its speech model (\(Int(progress * 100))%).")
            case let .failed(message): return fail(message, .retryModel)
            default: return fail("Tony is getting ready. Try again in a moment.")
            }
        }
        generation += 1
        let generation = generation
        dismiss?.cancel()
        // A dictation still transcribing lands on its own, before this one reads the cursor.
        let previous = finishing
        finishing = nil
        self.session = session
        handsFree = false
        phase = .listening
        hotkey.dictating.store(true, ordering: .relaxed)
        announce("Listening")

        let (stream, feed) = AsyncStream.makeStream(of: [Float].self)
        self.feed = feed
        feeder = Task.detached { for await chunk in stream { await session.append(chunk) } }
        cursor = Task.detached {
            await previous?.value
            return Cursor.textBefore()
        }
        mic.start(keyDownAt: mach_absolute_time(), onSamples: { feed.yield($0) }, onError: { [weak self] error in
            Task { @MainActor in
                guard let self, self.generation == generation else { return }
                self.generation += 1  // its transcription must not hide this notice
                self.machine.reset()
                self.fail(error.localizedDescription, .openSettings)
            }
        })
    }

    private func stop() {
        guard phase == .listening, let session else { return }
        let generation = generation
        phase = .transcribing
        let stopped = mic.stop()
        let (feed, feeder, cursor) = (feed, feeder, cursor)
        finishing = Task {
            let summary = await stopped.value
            feed?.finish()
            await feeder?.value
            let text = Cleanup.removeFillers(await session.finish())
            let before = await cursor?.value ?? nil
            guard !Task.isCancelled else { return }
            guard self.generation == generation else {
                // A newer dictation is listening: land this one, and leave the HUD to the new one.
                if !text.isEmpty {
                    let fitted = Cleanup.fit(text, after: before)
                    lastText = fitted
                    if !AXIsProcessTrusted() || !Paste.paste(fitted) { carry = [carry, fitted].compactMap { $0 }.joined(separator: " ") }
                }
                return
            }
            end()
            let carried = carry
            carry = nil
            if let carried {
                return insert(text.isEmpty ? carried : carried + Cleanup.fit(text, after: " "))
            }
            if text.isEmpty {
                if summary.silent {
                    let lid = summary.device?.isBuiltIn == true && Devices.lidClosed
                    fail(lid ? "The lid is closed, so the built-in mic is off." : "\(summary.device?.name ?? "The mic") sends only silence.", .openSettings)
                } else {
                    phase = .idle
                }
                return
            }
            insert(Cleanup.fit(text, after: before))
        }
    }

    private func cancel() {
        guard isBusy else { return }
        generation += 1
        finishing?.cancel()
        if phase == .listening { _ = mic.stop() }
        end()
        phase = .idle
        announce("Cancelled")
        if let carried = carry {
            carry = nil
            fail("Tony couldn't type your previous dictation.", .copy(carried))
        }
    }

    private func end() {
        feed?.finish()
        hotkey.dictating.store(false, ordering: .relaxed)
        session = nil
        feed = nil
        feeder = nil
        cursor = nil
        finishing = nil
        handsFree = false
    }

    private func insert(_ text: String) {
        log.info("inserting \(text.count) characters")
        lastText = text
        guard AXIsProcessTrusted() else {
            return fail("Tony needs Accessibility access to type.", .openAccessibility)
        }
        guard Paste.paste(text) else {
            return fail(SecureInput.message, .copy(text))
        }
        phase = .idle
        announce("Inserted")
    }

    /// Pastes the last dictation again, from the menu.
    func pasteLast() {
        guard let lastText else { return }
        if !Paste.paste(lastText) { fail(SecureInput.message, .copy(lastText)) }
    }

    /// Quitting mid-dictation inserts it first.
    func finishForQuit() async {
        if phase == .listening {
            machine.reset()
            stop()
        }
        await finishing?.value
    }

    func perform(_ action: Action) {
        if case let .copy(text) = action {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        onAction?(action)
        dismissNotice()
    }

    func dismissNotice() {
        if case .notice = phase { phase = .idle }
    }

    /// Shows a notice in the HUD, unless a dictation is running.
    func notify(_ message: String, _ action: Action? = nil) {
        if !isBusy { fail(message, action) }
    }

    private func fail(_ message: String, _ action: Action? = nil) {
        log.notice("\(message, privacy: .public)")
        if !isBusy { machine.reset() }
        end()
        phase = .notice(Notice(message: message, action: action))
        announce(message)
        dismiss?.cancel()
        dismiss = Task {
            try? await Task.sleep(for: .seconds(action == nil ? 3 : 8))
            guard !Task.isCancelled else { return }
            dismissNotice()
        }
    }

    private func announce(_ text: String) {
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
            .announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue,
        ])
    }
}
