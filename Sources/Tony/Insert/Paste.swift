import AppKit
import Carbon.HIToolbox

/// Puts text where the cursor is: on the clipboard, then ⌘V. Paste is the one path that works in every app;
/// typing characters fights autocomplete, and Accessibility text insertion works in native text views only.
/// The text stays on the clipboard, so a paste that didn't land (no text field, an app that ignores ⌘V) is
/// one ⌘V away (ADR 0007).
enum Paste {
    /// Marks Tony's synthetic key events, so the hotkey tap lets them through.
    nonisolated static let marker: Int64 = 0x746F_6E79  // "tony"

    /// False when Tony can't press ⌘V (no Accessibility, or secure input): the text waits on the clipboard.
    static func paste(_ text: String) -> Bool {
        copy(text)
        guard AXIsProcessTrusted(), !SecureInput.isOn else { return false }
        pressCommandV()
        return true
    }

    /// On this Mac only: Universal Clipboard doesn't hand dictations to the user's other devices.
    static func copy(_ text: String) {
        NSPasteboard.general.prepareForNewContents(with: .currentHostOnly)
        NSPasteboard.general.setString(text, forType: .string)
    }

    private static func pressCommandV() {
        // No local event suppression: it would swallow the hotkey's release when it comes right after.
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.userData = marker
        let key = vKeyCode()
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down)
            event?.flags = .maskCommand
            event?.setIntegerValueField(.eventSourceUserData, value: marker)
            event?.post(tap: .cghidEventTap)
        }
    }

    /// The key that types "v" while ⌘ is held in the active layout, so Dvorak pastes instead of firing
    /// another shortcut. Layouts with no "v" (Russian, Greek) get the ANSI V key: macOS matches shortcuts
    /// by QWERTY position there. On the main thread: TIS asserts the main queue on macOS 14+.
    static func vKeyCode(layout: TISInputSource? = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()) -> CGKeyCode {
        let ansiV = CGKeyCode(kVK_ANSI_V)
        guard let layout, let pointer = TISGetInputSourceProperty(layout, kTISPropertyUnicodeKeyLayoutData) else { return ansiV }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        return data.withUnsafeBytes { raw -> CGKeyCode in
            guard let keys = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return ansiV }
            for code in 0..<UInt16(128) {
                var deadKeys: UInt32 = 0
                var length = 0
                var chars = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(keys, code, UInt16(kUCKeyActionDown), UInt32((cmdKey >> 8) & 0xFF), UInt32(LMGetKbdType()),
                                            OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars)
                if status == noErr, length == 1, chars[0] == UniChar(("v" as Unicode.Scalar).value) { return CGKeyCode(code) }
            }
            return ansiV
        }
    }
}
