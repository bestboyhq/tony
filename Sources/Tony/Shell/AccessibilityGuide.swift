import AppKit
import SwiftUI

/// After Tony asks for Accessibility: a tile under System Settings' window, holding Tony to drag into the
/// list, which adds an app dropped on it. Shown while System Settings is in front, moving with its window;
/// over once Accessibility is granted or System Settings quits.
final class AccessibilityGuide: NSObject {
    private nonisolated static let settings = "com.apple.systempreferences"
    private let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    private var observers: [NSObjectProtocol] = []
    private var link: CADisplayLink?
    private var window: CGWindowID?

    override init() {
        super.init()
        let tile = NSHostingView(rootView: Tile())
        panel.contentView = tile
        panel.setContentSize(tile.fittingSize)
        panel.level = .floating
        panel.collectionBehavior = [.fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false  // SwiftUI's, as on the menu bar panel
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
    }

    func start() {
        guard observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        observers = [
            center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.update() }
            },
            center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                guard app?.bundleIdentifier == Self.settings else { return }
                MainActor.assumeIsolated { self?.stop() }
            },
        ]
        update()
    }

    func stop() {
        observers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        observers = []
        update()
    }

    /// Follows System Settings every frame while it is in front, and only then.
    private func update() {
        let front = !observers.isEmpty && NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Self.settings
        if front, link == nil {
            link = NSScreen.main?.displayLink(target: self, selector: #selector(follow))
            link?.add(to: .main, forMode: .common)
            follow()
        } else if !front {
            link?.invalidate()
            link = nil
            window = nil
            panel.orderOut(nil)
        }
    }

    /// Under System Settings' window, flush with the list's right edge (the sidebar's width varies), or over
    /// the window's bottom edge when the screen ends first.
    @objc private func follow() {
        guard let frame = settingsFrame() else { return panel.orderOut(nil) }
        let size = panel.frame.size
        let margin = PanelBackground.margin
        let screen = (NSScreen.screens.first { $0.frame.intersects(frame) } ?? NSScreen.screens[0]).visibleFrame
        let x = min(max(frame.maxX - 20 + margin - size.width, screen.minX + 8 - margin), screen.maxX - size.width - 8 + margin)
        let y = max(frame.minY - 10 + margin - size.height, screen.minY + 8 - margin)
        panel.setFrameOrigin(NSPoint(x: x.rounded(), y: y.rounded()))
        guard !panel.isVisible else { return }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 1
        }
    }

    /// System Settings' front window in AppKit's coordinates: one window looked up per frame, all of them
    /// only once it is gone (closed, or another one came to the front).
    private func settingsFrame() -> NSRect? {
        if let window, let info = (CGWindowListCopyWindowInfo(.optionIncludingWindow, window) as? [[String: Any]])?.first,
           info[kCGWindowIsOnscreen as String] as? Bool == true, let frame = Self.frame(info) {
            return frame
        }
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
              let front = windows.first(where: { $0[kCGWindowOwnerPID as String] as? pid_t == pid && $0[kCGWindowLayer as String] as? Int == 0 })
        else { return nil }
        window = front[kCGWindowNumber as String] as? CGWindowID
        return Self.frame(front)
    }

    /// Window server bounds run down from the top of the main screen; AppKit's run up from its bottom.
    private static func frame(_ info: [String: Any]) -> NSRect? {
        guard let bounds = info[kCGWindowBounds as String] as? NSDictionary,
              let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return nil }
        return NSRect(x: rect.minX, y: NSScreen.screens[0].frame.maxY - rect.maxY, width: rect.width, height: rect.height)
    }
}

private struct Tile: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Drag Tony to the list above")
                    .font(.system(size: 13, weight: .semibold))
                Text("Already there? Turn it on.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 20)
        .padding(.vertical, 10)
        .overlay(DragSource())
        .accessibilityElement(children: .combine)
        .modifier(PanelBackground())
    }
}

/// The whole tile drags Tony's app, as a file from Finder would. No move or delete: dropped on the Trash,
/// it would throw Tony away.
private struct DragSource: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { View() }
    func updateNSView(_ view: NSView, context: Context) {}

    final class View: NSView, NSDraggingSource {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }

        override func mouseDragged(with event: NSEvent) {
            guard let app = Permissions.home else { return }
            let point = convert(event.locationInWindow, from: nil)
            let item = NSDraggingItem(pasteboardWriter: app as NSURL)
            item.setDraggingFrame(NSRect(x: point.x - 22, y: point.y - 22, width: 44, height: 44), contents: NSApp.applicationIconImage)
            beginDraggingSession(with: [item], event: event, source: self)
        }

        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            [.copy, .link, .generic]
        }
    }
}
