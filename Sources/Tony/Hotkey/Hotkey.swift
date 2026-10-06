import AppKit
import Carbon.HIToolbox
import OSLog
import Synchronization

/// A modifier key that starts dictation when pressed alone: it types nothing by itself.
nonisolated struct HotkeyKey: Hashable, Sendable {
    let keyCode: UInt16

    static let fn = HotkeyKey(keyCode: UInt16(kVK_Function))
    static let rightOption = HotkeyKey(keyCode: UInt16(kVK_RightOption))
    static let rightCommand = HotkeyKey(keyCode: UInt16(kVK_RightCommand))
    static let rightControl = HotkeyKey(keyCode: UInt16(kVK_RightControl))
    static let rightShift = HotkeyKey(keyCode: UInt16(kVK_RightShift))
    static let leftOption = HotkeyKey(keyCode: UInt16(kVK_Option))
    static let leftControl = HotkeyKey(keyCode: UInt16(kVK_Control))
    static let choices: [HotkeyKey] = [.fn, .rightOption, .rightCommand, .rightControl, .rightShift, .leftOption, .leftControl]

    /// The device-specific flag bit (IOKit's NX_DEVICE*KEYMASK) set while each modifier is down.
    private static let masks: [UInt16: UInt64] = [
        UInt16(kVK_Function): CGEventFlags.maskSecondaryFn.rawValue,
        UInt16(kVK_Control): 0x01, UInt16(kVK_Shift): 0x02, UInt16(kVK_RightShift): 0x04,
        UInt16(kVK_Command): 0x08, UInt16(kVK_RightCommand): 0x10, UInt16(kVK_Option): 0x20,
        UInt16(kVK_RightOption): 0x40, UInt16(kVK_RightControl): 0x2000,
    ]
    static let allMasks = masks.values.reduce(0, |)

    static func isModifier(_ keyCode: UInt16) -> Bool { masks[keyCode] != nil }

    var mask: UInt64 { Self.masks[keyCode] ?? 0 }

    var name: String {
        switch Int(keyCode) {
        case kVK_Function: "fn"
        case kVK_RightOption: "Right ⌥"
        case kVK_RightCommand: "Right ⌘"
        case kVK_RightControl: "Right ⌃"
        case kVK_RightShift: "Right ⇧"
        case kVK_Option: "Left ⌥"
        case kVK_Control: "Left ⌃"
        case kVK_Command: "Left ⌘"
        case kVK_Shift: "Left ⇧"
        default: "Key \(keyCode)"
        }
    }
}

/// The global push-to-talk key: an active event tap on its own thread. Active, because it needs only
/// Accessibility (which pasting needs anyway) and lets Esc cancel a dictation without reaching the app.
/// The callback sits in front of every keystroke on the Mac, so it only compares flags and dispatches.
nonisolated final class Hotkey: @unchecked Sendable {
    /// Set by the main thread while Tony listens: then Esc is Tony's and other keys matter.
    let dictating = Atomic<Bool>(false)
    private let key = Atomic<UInt16>(HotkeyKey.fn.keyCode)
    private let keyDown = Atomic<Bool>(false)
    private let onInput: @Sendable (HotkeyMachine.Input) -> Void
    private let lock = NSLock()
    private var tap: CFMachPort?
    private var runLoop: CFRunLoop?
    private let log = Logger(subsystem: "com.bestboyhq.tony", category: "hotkey")

    /// `onInput` runs on the main queue.
    init(onInput: @escaping @Sendable @MainActor (HotkeyMachine.Input) -> Void) {
        self.onInput = { input in DispatchQueue.main.async { onInput(input) } }
    }

    func setKey(_ newKey: HotkeyKey) { key.store(newKey.keyCode, ordering: .relaxed) }

    var isRunning: Bool {
        lock.withLock { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }
    }

    /// (Re)creates the tap: after launch, wake, and a permission change. False without Accessibility.
    @discardableResult
    func start() -> Bool {
        stop()
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue) | CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                Unmanaged<Hotkey>.fromOpaque(refcon!).takeUnretainedValue().handle(type, event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            log.error("event tap refused: no Accessibility permission")
            return false
        }
        let ready = DispatchSemaphore(value: 0)
        nonisolated(unsafe) let port = tap  // handed to the thread once, then guarded by `lock`
        let thread = Thread { [self] in
            let source = CFMachPortCreateRunLoopSource(nil, port, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            lock.withLock {
                self.tap = port
                runLoop = CFRunLoopGetCurrent()
            }
            ready.signal()
            CFRunLoopRun()
        }
        thread.name = "Tony hotkey"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
        keyDown.store(false, ordering: .relaxed)
        return true
    }

    func stop() {
        lock.withLock {
            guard let tap, let runLoop else { return }
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            CFRunLoopStop(runLoop)
            self.tap = nil
            self.runLoop = nil
        }
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = lock.withLock({ tap }) { CGEvent.tapEnable(tap: tap, enable: true) }
            log.notice("event tap re-enabled after \(type == .tapDisabledByTimeout ? "a timeout" : "user input")")
        case .flagsChanged:
            let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let ours = HotkeyKey(keyCode: key.load(ordering: .relaxed))
            let flags = event.flags.rawValue
            let now = ProcessInfo.processInfo.systemUptime
            if code == ours.keyCode {
                let down = flags & ours.mask != 0
                guard down != keyDown.load(ordering: .relaxed) else { break }  // a repeat
                keyDown.store(down, ordering: .relaxed)
                onInput(down ? .down(now, othersHeld: flags & HotkeyKey.allMasks & ~ours.mask != 0) : .up(now))
            } else {
                if keyDown.load(ordering: .relaxed), flags & ours.mask == 0 {
                    // The release got lost (the tap was off for a moment): the flags tell.
                    keyDown.store(false, ordering: .relaxed)
                    onInput(.up(now))
                }
                if HotkeyKey.isModifier(code), isActive { onInput(.otherKey) }
            }
        case .keyDown:
            guard isActive, event.getIntegerValueField(.eventSourceUserData) != Paste.marker else { break }
            if event.getIntegerValueField(.keyboardEventKeycode) == kVK_Escape {
                onInput(.escape)
                return nil  // Esc was meant for Tony, not for the app
            }
            onInput(.otherKey)
        default:
            break
        }
        return pass
    }

    private var isActive: Bool { keyDown.load(ordering: .relaxed) || dictating.load(ordering: .relaxed) }
}
