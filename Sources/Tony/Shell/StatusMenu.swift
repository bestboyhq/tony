import AppKit

/// The menu bar item: what Tony is doing, the last dictation, and the app's windows.
final class StatusMenu: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let app: AppDelegate

    init(app: AppDelegate) {
        self.app = app
        super.init()
        item.button?.image = Mark.menuBarImage(listening: false)
        item.button?.setAccessibilityLabel("Tony")
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
    }

    func setListening(_ listening: Bool) {
        item.button?.image = Mark.menuBarImage(listening: listening)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        app.permissions.refresh()
        menu.removeAllItems()
        let (status, fix) = statusLine
        let statusItem = menu.addItem(withTitle: status, action: fix == nil ? nil : #selector(runFix), keyEquivalent: "")
        statusItem.target = self
        statusItem.isEnabled = fix != nil
        statusItem.representedObject = fix

        if let last = app.dictation.lastText {
            menu.addItem(.separator())
            let preview = menu.addItem(withTitle: "“\(last.count > 40 ? last.prefix(40) + "…" : last)”", action: nil, keyEquivalent: "")
            preview.isEnabled = false
            add(menu, "Paste Last Dictation", #selector(pasteLast))
            add(menu, "Copy Last Dictation", #selector(copyLast))
        }

        menu.addItem(.separator())
        add(menu, "Settings…", #selector(settings), key: ",")
        if app.updates.ready {
            add(menu, "Restart to Update", #selector(restartToUpdate))
        } else {
            add(menu, "Check for Updates…", #selector(checkForUpdates))
        }
        add(menu, "About Tony", #selector(about))
        menu.addItem(.separator())
        add(menu, "Quit Tony", #selector(quit), key: "q")
    }

    /// One line on what Tony is doing, and the action that fixes it when something is wrong.
    private var statusLine: (String, (() -> Void)?) {
        let permissions = app.permissions
        if permissions.microphone != .authorized { return ("Tony needs microphone access…", { self.app.showOnboarding() }) }
        if permissions.needsRelaunch { return ("Relaunch Tony to finish setup", { Permissions.relaunch() }) }
        if !permissions.accessibility { return ("Tony needs Accessibility access…", { self.app.showOnboarding() }) }
        switch app.speech.state {
        case let .downloading(progress): return ("Downloading speech model… \(Int(progress * 100))%", nil)
        case .idle, .loading: return ("Getting ready…", nil)
        case let .failed(message): return ("\(message) Try again", { Task { await self.app.speech.prepare() } })
        case .ready: break
        }
        if SecureInput.isOn { return (SecureInput.message, nil) }
        return ("Hold \(Prefs.hotkey.name) to dictate", nil)
    }

    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, key: String = "") {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.target = self
    }

    @objc private func runFix(_ sender: NSMenuItem) { (sender.representedObject as? () -> Void)?() }
    @objc private func pasteLast() {
        // The menu has to close and focus return to the user's app before ⌘V.
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            app.dictation.pasteLast()
        }
    }
    @objc private func copyLast() {
        guard let last = app.dictation.lastText else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(last, forType: .string)
    }
    @objc private func settings() { app.showSettings() }
    @objc private func checkForUpdates() { app.updates.check() }
    @objc private func restartToUpdate() { app.updates.restartToUpdate() }
    @objc private func about() { app.showAbout() }
    @objc private func quit() { NSApp.terminate(nil) }
}
