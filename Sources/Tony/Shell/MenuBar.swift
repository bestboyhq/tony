import AppKit
import Carbon.HIToolbox
import Observation
import SwiftUI

/// The menu bar icon and its panel: what Tony is doing, the last dictation, stats, and settings.
/// The panel is non-activating, like the HUD: it takes the keyboard for its fields, but the user's app stays
/// active, so focus goes straight back to it, and a pasted dictation lands there.
@Observable
final class MenuBar: NSObject, NSWindowDelegate {
    enum Page { case home, settings }

    var page = Page.home
    @ObservationIgnored private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    @ObservationIgnored private var panel: Panel!
    @ObservationIgnored private let permissions: Permissions
    /// Clicks in other apps and Esc close the panel.
    @ObservationIgnored private var monitors: [Any] = []

    init(app: AppDelegate) {
        permissions = app.permissions
        super.init()
        item.button?.image = Mark.menuBarImage(listening: false)
        item.button?.setAccessibilityLabel("Tony")
        item.button?.target = self
        item.button?.action = #selector(toggle)
        // On mouse down, like a menu.
        item.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        // Non-activating from the start: set later, the window server still activates Tony on a click.
        panel = Panel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.contentViewController = NSHostingController(rootView: MenuBarView(app: app, menuBar: self))
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow
        panel.delegate = self
    }

    func setListening(_ listening: Bool) {
        item.button?.image = Mark.menuBarImage(listening: listening)
        // The panel holds the keyboard: a dictation lands in its field, or, from Home, back in the user's app.
        if listening, page == .home { close() }
    }

    @objc private func toggle() {
        if panel.isVisible { close() } else { show(.home) }
    }

    func show(_ page: Page) {
        self.page = page
        guard !panel.isVisible, let icon else { return }
        permissions.refresh()
        // Under the icon, clear of the screen's edges.
        let screen = (item.button?.window?.screen ?? NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        panel.layoutIfNeeded()
        let size = panel.frame.size
        let x = min(max(icon.midX - size.width / 2, screen.minX + 8), screen.maxX - size.width - 8)
        panel.setFrameTopLeftPoint(NSPoint(x: x.rounded(), y: icon.minY - 6))
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()  // its shape is the content's, drawn by now
        item.button?.highlight(true)
        monitors = [
            NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
                if self?.clickingIcon == false { self?.close() }
            },
            // Before a text field, which takes Esc for completions.
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard event.keyCode == kVK_Escape, event.window === self?.panel else { return event }
                self?.close()
                return nil
            },
        ].compactMap { $0 }
    }

    /// The icon's frame on screen.
    private var icon: NSRect? {
        guard let button = item.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    /// A click on the icon reaches Tony as a click in another app (the menu bar draws it), and takes the keyboard
    /// from the panel, before `toggle`: it is `toggle`'s to close the panel, or it opens again.
    private var clickingIcon: Bool {
        NSEvent.pressedMouseButtons != 0 && icon?.contains(NSEvent.mouseLocation) == true
    }

    func close() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        item.button?.highlight(false)
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
    }

    /// Another app or window took the keyboard.
    func windowDidResignKey(_ notification: Notification) {
        if !clickingIcon { close() }
    }

    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }

        /// Resizes grow and shrink downward, so the panel stays under the menu bar.
        override func setFrame(_ frame: NSRect, display: Bool) {
            var frame = frame
            if isVisible { frame.origin.y = self.frame.maxY - frame.height }
            super.setFrame(frame, display: display)
            invalidateShadow()
        }
    }
}

private struct MenuBarView: View {
    let app: AppDelegate
    let menuBar: MenuBar

    var body: some View {
        Group {
            switch menuBar.page {
            case .home: Home(app: app, menuBar: menuBar)
            case .settings: SettingsPage(app: app, menuBar: menuBar)
            }
        }
        .frame(width: 391)  // the activity grid's 26 weeks, edge to edge
        .modifier(PanelBackground())
    }
}

private struct Home: View {
    let app: AppDelegate
    let menuBar: MenuBar
    @AppStorage(Prefs.hotkeyKey) private var hotkeyCode = Int(HotkeyKey.fn.keyCode)

    private var key: String { HotkeyKey(keyCode: UInt16(hotkeyCode)).name }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                status
                Spacer(minLength: 8)
                Button { menuBar.page = .settings } label: {
                    Image(systemName: "gearshape").frame(width: 24, height: 24).contentShape(Rectangle())
                }
                .help("Settings")
                .keyboardShortcut(",")
                Menu {
                    Button("About Tony") {
                        menuBar.close()
                        app.showAbout()
                    }
                    Divider()
                    Button("Quit Tony") { NSApp.terminate(nil) }.keyboardShortcut("q")
                } label: {
                    Image(systemName: "ellipsis").frame(width: 24, height: 24).contentShape(Rectangle())
                }
                .menuStyle(.button)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("More")
            }
            .buttonStyle(.borderless)
            .font(.system(size: 13))

            if app.updates.ready {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill").foregroundStyle(.tint)
                    Text("A new version of Tony is ready.")
                    Spacer(minLength: 0)
                    Button("Restart") { app.updates.restartToUpdate() }.controlSize(.small)
                }
                .padding(10)
                .card()
            }

            if let last = app.dictation.lastText {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Last dictation").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        Spacer()
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(last, forType: .string)
                            menuBar.close()
                        }
                        Button("Paste") {
                            menuBar.close()
                            // Focus has to be back in the user's app before ⌘V.
                            Task {
                                try? await Task.sleep(for: .milliseconds(150))
                                app.dictation.pasteLast()
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    Text(last)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .card()
            }

            StatsView(stats: app.dictation.stats, key: key)
        }
        .padding(16)
    }

    /// What Tony is doing, and the fix when something is wrong.
    @ViewBuilder private var status: some View {
        let permissions = app.permissions
        if Permissions.moved {
            problem("Relaunch Tony to use the microphone.", fix: Permissions.home == nil ? nil : "Relaunch") { Permissions.relaunch() }
        } else if permissions.microphone != .authorized {
            problem("Tony needs the microphone.", fix: "Allow", onboarding)
        } else if permissions.needsRelaunch {
            problem("Relaunch Tony to finish setup.", fix: "Relaunch") { Permissions.relaunch() }
        } else if !permissions.accessibility {
            problem("Tony needs Accessibility access.", fix: "Allow", onboarding)
        } else {
            switch app.speech.state {
            case let .downloading(progress):
                HStack(spacing: 8) {
                    Text("Downloading speech model").foregroundStyle(.secondary)
                    ProgressView(value: progress).frame(width: 64)
                }
            case .idle, .loading:
                HStack(spacing: 8) {
                    Text("Getting ready").foregroundStyle(.secondary)
                    ProgressView().controlSize(.small)
                }
            case let .failed(message):
                problem(message, fix: "Try Again") { Task { await app.speech.prepare() } }
            case .ready:
                if SecureInput.isOn {
                    problem(SecureInput.message)
                } else {
                    HStack(spacing: 5) {
                        Text("Hold")
                        Text(key)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(.tertiary))
                        Text("to dictate")
                    }
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func onboarding() {
        menuBar.close()
        app.showOnboarding()
    }

    private func problem(_ message: String, fix: String? = nil, _ action: @escaping () -> Void = {}) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
            Text(message).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            if let fix { Button(fix, action: action).buttonStyle(.bordered).controlSize(.small) }
        }
    }
}

private struct SettingsPage: View {
    let app: AppDelegate
    let menuBar: MenuBar

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Settings").font(.headline)
                HStack {
                    Button { menuBar.page = .home } label: {
                        Image(systemName: "chevron.left").frame(width: 24, height: 24).contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .keyboardShortcut("[")
                    .help("Back")
                    .accessibilityLabel("Back")
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            SettingsView(dictation: app.dictation, speech: app.speech, updates: app.updates)
        }
    }
}

/// Liquid Glass where the system has it, vibrancy before that, outlined with Increase Contrast.
private struct PanelBackground: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    func body(content: Content) -> some View {
        Group {
            if #available(macOS 26, *) {
                content.glassEffect(.regular, in: shape)
            } else {
                content.background(.regularMaterial, in: shape)
            }
        }
        .overlay(shape.strokeBorder(.primary.opacity(contrast == .increased ? 0.5 : 0.1), lineWidth: contrast == .increased ? 1 : 0.5))
    }
}

extension View {
    /// A grouped area on the panel, like the system's grouped forms.
    func card() -> some View {
        background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}



