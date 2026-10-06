import AppKit
import FluidAudio
import SwiftUI

@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let speech = Speech()
    let permissions = Permissions()
    let updates = Updates()
    private(set) lazy var dictation = Dictation(speech: speech)
    private var hud: HUD!
    private var menuBar: MenuBar!
    private var windows: [String: NSWindow] = [:]

    static func main() {
        if CommandLine.arguments.count >= 3, CommandLine.arguments[1] == "--transcribe" {
            Task { exit(await transcribe(CommandLine.arguments[2])) }
            RunLoop.main.run()
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    /// `Tony --transcribe <audio file> [-words '(Szymon, Supabase)']`: the speech path of a dictation (model,
    /// voice activity detection, the user's words, cleanup) without the mic or the key, fed in 20 ms chunks
    /// like the mic does. For checking speech changes.
    private static func transcribe(_ path: String) async -> Int32 {
        let speech = Speech()
        await speech.prepare()
        await speech.learn(Prefs.words)
        guard let session = speech.session(language: Prefs.language) else {
            print("speech not ready: \(speech.state)")
            return 1
        }
        guard let samples = try? AudioConverter().resampleAudioFile(path: path) else {
            print("can't read \(path)")
            return 1
        }
        let started = Date()
        for start in stride(from: 0, to: samples.count, by: 320) {
            await session.append(Array(samples[start..<min(start + 320, samples.count)]))
        }
        let text = Cleanup.removeFillers(await session.finish())
        print(text)
        let timing = String(format: "%.1f s of audio, %.0f ms\n", Double(samples.count) / 16000, Date().timeIntervalSince(started) * 1000)
        FileHandle.standardError.write(Data(timing.utf8))
        return 0
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        MoveToApplications.offerIfNeeded()
        NSApp.mainMenu = Self.mainMenu()

        dictation.hotkey.setKey(Prefs.hotkey)
        dictation.mic.use(uid: Prefs.micUID)
        dictation.language = Prefs.language
        dictation.onAction = { [weak self] in self?.perform($0) }
        hud = HUD(dictation: dictation, mic: dictation.mic)
        menuBar = MenuBar(app: self)
        let hudUpdate = dictation.onPhase
        dictation.onPhase = { [weak self] phase in
            hudUpdate?(phase)
            self?.menuBar.setListening(phase == .listening || phase == .transcribing)
            if phase == .idle { self?.updates.idle() }
        }

        updates.isBusy = { [weak self] in self?.dictation.isBusy ?? false }
        updates.start()

        permissions.onAccessibility = { [weak self] trusted in
            guard let self else { return false }
            if trusted { return dictation.hotkey.start() }
            dictation.hotkey.stop()
            if Prefs.onboarded { dictation.notify("Tony lost Accessibility access, so the hotkey is off.", .openAccessibility) }
            return false
        }
        permissions.onMicrophone = { [weak self] in self?.dictation.mic.use(uid: Prefs.micUID) }
        if permissions.accessibility, !dictation.hotkey.start() {
            permissions.tapFailed()
        }
        permissions.startPolling()

        // The tap and the update timer stop while the Mac sleeps.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.permissions.accessibility, !self.dictation.hotkey.start() { self.permissions.tapFailed() }
                self.updates.checkInBackground()
            }
        }

        Task { await speech.prepare() }
        Task { await speech.learn(Prefs.words) }

        // Once onboarded, a missing permission is explained in the HUD and the menu instead.
        if !Prefs.onboarded { showOnboarding() }
    }

    /// Opening Tony again (Finder, Spotlight) while it runs: the menu bar panel, or onboarding until it's done.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if Prefs.onboarded { menuBar.show(.home) } else { showOnboarding() }
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // A dictation still running lands first, and the user's clipboard comes back before Tony goes.
        guard dictation.isBusy || Paste.restore != nil else { return .terminateNow }
        Task {
            await dictation.finishForQuit()
            await Paste.restore?.value
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    /// Shown while a window is open. Text fields need Edit's key equivalents: ⌘V, Tony's own paste
    /// included, goes nowhere without a Paste item.
    private static func mainMenu() -> NSMenu {
        let main = NSMenu()
        let app = NSMenu(title: "Tony")
        app.addItem(withTitle: "About Tony", action: #selector(showAbout), keyEquivalent: "")
        app.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        app.addItem(.separator())
        app.addItem(withTitle: "Quit Tony", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        for menu in [app, edit, window] {
            let item = NSMenuItem()
            item.submenu = menu
            main.addItem(item)
        }
        return main
    }

    // MARK: Windows

    func showOnboarding() {
        show("onboarding", title: "Welcome to Tony") {
            OnboardingView(permissions: permissions, speech: speech) { [weak self] in
                Prefs.onboarded = true
                self?.windows["onboarding"]?.close()
            }
        }
    }

    @objc func showSettings() {
        menuBar.show(.settings)
    }

    @objc func showAbout() {
        show("about", title: "About Tony") { AboutView() }
    }

    /// The dock icon shows only while a window is open.
    private func show<Content: View>(_ id: String, title: String, @ViewBuilder content: () -> Content) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        if let window = windows[id] {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: content()))
        window.title = title
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        windows[id] = window
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, let id = windows.first(where: { $0.value === window })?.key else { return }
        windows[id] = nil
        if windows.isEmpty { NSApp.setActivationPolicy(.accessory) }
    }

    private func perform(_ action: Dictation.Action) {
        switch action {
        case .copy: break
        case .openAccessibility: Permissions.openPrivacy("Privacy_Accessibility")
        case .openMicrophone: Permissions.openPrivacy("Privacy_Microphone")
        case .openSettings: showSettings()
        case .retryModel: Task { await speech.prepare() }
        }
    }
}
