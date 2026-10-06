import AppKit
import Carbon.HIToolbox
import IOKit

/// Secure input (a focused password field, Terminal's Secure Keyboard Entry, a password manager that
/// left it on) hides keys from the tap and blocks synthetic paste.
enum SecureInput {
    static var isOn: Bool { IsSecureEventInputEnabled() }

    /// The app holding secure input, from the console user's `kCGSSessionSecureInputPID` in the IORegistry.
    static var holder: String? {
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        defer { IOObjectRelease(root) }
        guard let users = IORegistryEntryCreateCFProperty(root, "IOConsoleUsers" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? [[String: Any]] else { return nil }
        for user in users {
            if let pid = user["kCGSSessionSecureInputPID"] as? Int, pid > 0 {
                return NSRunningApplication(processIdentifier: pid_t(pid))?.localizedName
            }
        }
        return nil
    }

    static var message: String {
        if let holder { "\(holder) has secure input on, so Tony can't type there." } else { "Secure input is on, so Tony can't type there." }
    }
}

/// The fn (Globe) key also runs the action set in Keyboard settings ("Press 🌐 key to"), which fights
/// fn as the hotkey: Tony offers to set it to Do Nothing.
enum FnKeyAction {
    private static let domain = "com.apple.HIToolbox" as CFString
    private static let key = "AppleFnUsageType" as CFString

    /// 0 Do Nothing, 1 Change Input Source, 2 Show Emoji & Symbols, 3 Start Dictation. Unset means emoji.
    static var current: Int {
        (CFPreferencesCopyAppValue(key, domain) as? Int) ?? 2
    }

    static var conflicts: Bool { current != 0 }

    static var name: String {
        switch current {
        case 1: "changes the input source"
        case 3: "starts Apple Dictation"
        default: "opens Emoji & Symbols"
        }
    }

    static func setDoNothing() {
        CFPreferencesSetAppValue(key, 0 as CFNumber, domain)
        CFPreferencesAppSynchronize(domain)
    }

    static func openKeyboardSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
    }
}
