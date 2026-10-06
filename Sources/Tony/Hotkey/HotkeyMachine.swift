import Foundation

/// Turns hotkey events into dictation actions: hold to talk, a double tap locks hands-free mode,
/// a chord or Esc cancels, and a tap too short to hold a word inserts nothing.
nonisolated struct HotkeyMachine: Equatable, Sendable {
    enum Input: Equatable, Sendable {
        /// The hotkey went down; `othersHeld` when another modifier was already down (a chord, not ours).
        case down(TimeInterval, othersHeld: Bool)
        case up(TimeInterval)
        /// A key typed or another modifier pressed while the hotkey is held or Tony listens.
        case otherKey
        case escape
        /// The double-tap window may have run out.
        case tick(TimeInterval)
    }

    enum Action: Equatable, Sendable {
        case start, lock, stop, cancel
    }

    enum State: Equatable, Sendable {
        case idle
        case held(since: TimeInterval)
        /// Released quickly: a double tap may follow. Listening goes on meanwhile, so nothing is lost.
        case tapped(at: TimeInterval)
        /// The second tap of a double tap, still down.
        case locking
        case handsFree
        /// The key that stopped or cancelled is still down: its release means nothing.
        case ending
    }

    static let minHold: TimeInterval = 0.3
    static let doubleTapWindow: TimeInterval = 0.35

    private(set) var state = State.idle

    var isKeyDown: Bool {
        switch state {
        case .held, .locking, .ending: true
        default: false
        }
    }

    mutating func handle(_ input: Input) -> Action? {
        switch (state, input) {
        case (.idle, .down(_, othersHeld: true)):
            return nil
        case let (.idle, .down(t, _)):
            state = .held(since: t)
            return .start
        case let (.held(since), .up(t)):
            if t - since >= Self.minHold {
                state = .idle
                return .stop
            }
            state = .tapped(at: t)
            return nil
        case (.held, .down):  // the release got lost (the tap was off): end what is running
            state = .ending
            return .stop
        case (.held, .otherKey), (.held, .escape), (.locking, .escape):
            state = .ending
            return .cancel
        case (.tapped, .down):
            state = .locking
            return .lock
        case let (.tapped(at), .tick(t)) where t - at >= Self.doubleTapWindow - 0.001:  // uptimes are large: allow rounding
            state = .idle
            return .cancel
        case (.tapped, .otherKey), (.tapped, .escape), (.handsFree, .escape):
            state = .idle
            return .cancel
        case (.locking, .up):
            state = .handsFree
            return nil
        case (.handsFree, .down):
            state = .ending
            return .stop
        case (.ending, .up):
            state = .idle
            return nil
        case let (.ending, .down(t, _)):  // the release got lost: this is a fresh press
            state = .held(since: t)
            return .start
        default:
            return nil
        }
    }

    /// Dictation ended for another reason (an error, an unplugged mic): wait for the key to come up.
    mutating func reset() {
        state = isKeyDown ? .ending : .idle
    }
}
