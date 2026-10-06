import FluidAudio
import Foundation

/// The few options Tony has: where people really differ. Everything else is a tuned default.
enum Prefs {
    static let hotkeyKey = "hotkey"
    static let micKey = "mic"
    static let languageKey = "language"
    static let onboardedKey = "onboarded"

    static var hotkey: HotkeyKey {
        let code = UserDefaults.standard.object(forKey: hotkeyKey) as? Int
        return code.map { HotkeyKey(keyCode: UInt16($0)) } ?? .fn
    }

    /// The picked mic's UID; nil picks automatically.
    static var micUID: String? {
        UserDefaults.standard.string(forKey: micKey).flatMap { $0.isEmpty ? nil : $0 }
    }

    /// The spoken language as a hint for the model; nil detects it.
    static var language: Language? {
        UserDefaults.standard.string(forKey: languageKey).flatMap(Language.init(rawValue:))
    }

    static var onboarded: Bool {
        get { UserDefaults.standard.bool(forKey: onboardedKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardedKey) }
    }
}
