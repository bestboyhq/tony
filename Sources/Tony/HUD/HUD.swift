import AppKit
import SwiftUI

/// The floating pill: a non-activating panel, so focus stays in the user's app where the paste lands.
/// Created at launch, so showing it costs one frame.
final class HUD {
    private let panel: Panel
    private let dictation: Dictation
    private var hide: Task<Void, Never>?
    static let size = NSSize(width: 520, height: 96)

    init(dictation: Dictation, mic: Mic) {
        self.dictation = dictation
        panel = Panel(contentRect: NSRect(origin: .zero, size: Self.size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .none
        let host = NSHostingView(rootView: HUDView(dictation: dictation, mic: mic))
        host.sizingOptions = []
        panel.contentView = host
        dictation.onPhase = { [weak self] phase in self?.update(phase) }
    }

    private func update(_ phase: Dictation.Phase) {
        hide?.cancel()
        if phase == .idle {
            // Leave the panel up until the pill's exit animation is over.
            hide = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                panel.orderOut(nil)
            }
            panel.ignoresMouseEvents = true
            return
        }
        if case let .notice(notice) = phase { panel.ignoresMouseEvents = notice.action == nil } else { panel.ignoresMouseEvents = true }
        if !panel.isVisible {
            // Bottom center of the display with the focused window, above the Dock.
            let screen = NSScreen.main ?? NSScreen.screens[0]
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: (frame.midX - Self.size.width / 2).rounded(), y: frame.minY + 4))
            panel.orderFrontRegardless()
        }
    }

    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }
}
