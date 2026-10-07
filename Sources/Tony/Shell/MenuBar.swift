import AppKit
import Carbon.HIToolbox
import Observation
import SwiftUI

/// The menu bar icon and its panel: what Tony is doing, the last dictation, stats, settings, and About.
/// The panel is non-activating, like the HUD: it takes the keyboard for its fields, but the user's app stays
/// active, so focus goes straight back to it, and a pasted dictation lands there. A right click opens a menu instead.
@Observable
final class MenuBar: NSObject, NSWindowDelegate {
    enum Page { case home, settings, about }

    var page = Page.home
    @ObservationIgnored private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    @ObservationIgnored private var panel: Panel!
    @ObservationIgnored private let app: AppDelegate
    /// On the icon while an update is available.
    @ObservationIgnored private let dot = NSView()
    @ObservationIgnored private var listening = false
    /// Clicks in other apps and Esc close the panel.
    @ObservationIgnored private var monitors: [Any] = []

    init(app: AppDelegate) {
        self.app = app
        super.init()
        item.button?.image = Mark.menuBarImage(listening: false)
        item.button?.target = self
        item.button?.action = #selector(click)
        // On mouse down, like a menu.
        item.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        if let button = item.button {
            // Over the mark's empty top right corner, in color, since a template image is one.
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 3
            dot.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(dot)
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 6),
                dot.heightAnchor.constraint(equalToConstant: 6),
                dot.centerXAnchor.constraint(equalTo: button.centerXAnchor, constant: 6.5),
                dot.centerYAnchor.constraint(equalTo: button.centerYAnchor, constant: -6.5),
            ])
        }
        showUpdate()
        // Non-activating from the start: set later, the window server still activates Tony on a click.
        panel = Panel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.contentViewController = NSHostingController(rootView: MenuBarView(app: app, menuBar: self))
        // Clipped to its shape: the glass draws a faint shadow past its corners, which the window's shadow
        // would outline as a dark rectangle.
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = PanelBackground.radius
        panel.contentView?.layer?.cornerCurve = .continuous
        panel.contentView?.layer?.masksToBounds = true
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
        self.listening = listening
        item.button?.image = Mark.menuBarImage(listening: listening)
        showUpdate()
        // The panel holds the keyboard: a dictation lands in its field, or, from Home, back in the user's app.
        if listening, page == .home { close() }
    }

    /// The dot on the icon, for as long as an update is available, and again when that changes.
    private func showUpdate() {
        withObservationTracking {
            let available = app.updates.available != nil
            // The listening icon fills the corner.
            dot.isHidden = !available || listening
            dot.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            item.button?.setAccessibilityLabel(available ? "Tony, update available" : "Tony")
        } onChange: { [weak self] in
            Task { @MainActor in self?.showUpdate() }
        }
    }

    @objc private func click() {
        guard let event = NSApp.currentEvent, event.type == .rightMouseDown || event.modifierFlags.contains(.control) else {
            return panel.isVisible ? close() : show(.home)
        }
        close()
        // A status item with a menu opens it on a click, and sends no action.
        item.menu = menu()
        item.button?.performClick(nil)
        item.menu = nil
    }

    private func menu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "About Tony", action: #selector(showAbout), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        let updates = app.updates
        if let version = updates.available {
            // No action while installing: disabled.
            let restart = menu.addItem(withTitle: updates.installing ? "Updating…" : "Restart to Update", action: updates.installing ? nil : #selector(Updates.restartToUpdate), keyEquivalent: "")
            restart.target = updates
            restart.badge = NSMenuItemBadge(string: version)
        } else {
            menu.addItem(withTitle: "Check for Updates…", action: #selector(Updates.check), keyEquivalent: "").target = updates
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Tony", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    @objc private func showAbout() { show(.about) }
    @objc private func showSettings() { show(.settings) }

    func show(_ page: Page) {
        self.page = page
        guard !panel.isVisible, let icon else { return }
        app.permissions.refresh()
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
            case .settings:
                Subpage(title: "Settings", menuBar: menuBar) {
                    SettingsView(dictation: app.dictation, speech: app.speech, updates: app.updates)
                }
            case .about:
                Subpage(menuBar: menuBar) { AboutView() }
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
                .accessibilityLabel("Settings")
                .accessibilityIdentifier("settings")
                Menu {
                    Button("About Tony") { menuBar.page = .about }
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

            if let version = app.updates.available {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white, .tint)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Tony \(version) is available").fontWeight(.semibold)
                        Text("Restarting takes a few seconds.").font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if app.updates.installing {
                        ProgressView().controlSize(.small).accessibilityLabel("Updating")
                    } else {
                        Button("Restart") { app.updates.restartToUpdate() }
                            .buttonStyle(.borderedProminent)
                            .accessibilityLabel("Restart to Update")
                            .accessibilityIdentifier("restart-to-update")
                    }
                }
                .padding(12)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            problem("Tony needs the microphone.", fix: permissions.microphone == .notDetermined ? "Allow" : "Open Settings") { permissions.requestMicrophone() }
        } else if permissions.needsRelaunch {
            problem("Relaunch Tony to finish setup.", fix: "Relaunch") { Permissions.relaunch() }
        } else if !permissions.accessibility {
            problem("Tony needs Accessibility access.", fix: "Allow") { permissions.requestAccessibility() }
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

    private func problem(_ message: String, fix: String? = nil, _ action: @escaping () -> Void = {}) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
            Text(message).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            if let fix { Button(fix, action: action).buttonStyle(.bordered).controlSize(.small) }
        }
    }
}

/// A page under Home: its title, and Back.
private struct Subpage<Content: View>: View {
    var title: String?
    let menuBar: MenuBar
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let title { Text(title).font(.headline) }
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
            content
        }
    }
}

/// Liquid Glass where the system has it, vibrancy before that, outlined with Increase Contrast.
private struct PanelBackground: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    static let radius: CGFloat = 16
    private let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

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



