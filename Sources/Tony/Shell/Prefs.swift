import Carbon.HIToolbox
import FluidAudio
import Foundation

/// The few options Tony has: where people really differ. Everything else is a tuned default.
enum Prefs {
    static let hotkeyKey = "hotkey"
    static let micKey = "mic"
    static let languagesKey = "languages"
    static let onboardedKey = "onboarded"
    static let wordsKey = "words"

    static var hotkey: HotkeyKey {
        let code = UserDefaults.standard.object(forKey: hotkeyKey) as? Int
        return code.map { HotkeyKey(keyCode: UInt16($0)) } ?? .fn
    }

    /// The picked mic's UID; nil picks automatically.
    static var micUID: String? {
        UserDefaults.standard.string(forKey: micKey).flatMap { $0.isEmpty ? nil : $0 }
    }

    /// The languages the user speaks, empty for any. Until the user picks, the ones the Mac is set up for.
    static var languages: Set<Language> {
        get {
            let defaults = UserDefaults.standard
            // Before Tony took several languages it took one, and "" took any.
            guard let codes = defaults.stringArray(forKey: languagesKey) ?? defaults.string(forKey: "language").map({ [$0] }) else { return systemLanguages }
            return Set(codes.compactMap(Language.init(rawValue:)))
        }
        set { UserDefaults.standard.set(newValue.map(\.rawValue).sorted(), forKey: languagesKey) }
    }

    /// The languages in the Mac's language list and keyboards that Parakeet speaks.
    static var systemLanguages: Set<Language> {
        let filter = [kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String, kTISPropertyInputSourceIsEnabled as String: true] as CFDictionary
        let keyboards = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] ?? []
        // A keyboard lists every language it can type: the first is the one it is for.
        let typed = keyboards.compactMap { keyboard in
            TISGetInputSourceProperty(keyboard, kTISPropertyInputSourceLanguages).flatMap { (Unmanaged<CFArray>.fromOpaque($0).takeUnretainedValue() as? [String])?.first }
        }
        let spoken = Locale.preferredLanguages.compactMap { Locale(identifier: $0).language.languageCode?.identifier }
        return Set((spoken + typed).compactMap(Language.init(rawValue:)))
    }

    /// Names, brands, and jargon the user wants spelled their way.
    static var words: [String] {
        get { UserDefaults.standard.stringArray(forKey: wordsKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: wordsKey) }
    }

    static var onboarded: Bool {
        get { UserDefaults.standard.bool(forKey: onboardedKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardedKey) }
    }
}
