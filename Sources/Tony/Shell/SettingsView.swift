import FluidAudio
import SwiftUI

/// Options exist only where people really differ: the key, the mic, the language.
struct SettingsView: View {
    let dictation: Dictation
    let updates: Updates
    @AppStorage(Prefs.hotkeyKey) private var hotkeyCode = Int(HotkeyKey.fn.keyCode)
    @AppStorage(Prefs.micKey) private var mic = ""
    @AppStorage(Prefs.languageKey) private var language = ""
    @State private var devices = Devices.inputs()
    @State private var launchAtLogin = LoginItem.isOn
    @State private var fnConflict = FnKeyAction.conflicts
    @State private var recorder: Any?

    private var keys: [HotkeyKey] {
        let current = HotkeyKey(keyCode: UInt16(hotkeyCode))
        return HotkeyKey.choices.contains(current) ? HotkeyKey.choices : HotkeyKey.choices + [current]
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Hold to dictate") {
                    HStack {
                        Picker("Hold to dictate", selection: $hotkeyCode) {
                            ForEach(keys, id: \.keyCode) { Text($0.name).tag(Int($0.keyCode)) }
                        }
                        .labelsHidden()
                        .fixedSize()
                        Button(recorder == nil ? "Record" : "Press a modifier…") { toggleRecording() }
                    }
                }
                if hotkeyCode == Int(HotkeyKey.fn.keyCode), fnConflict {
                    LabeledContent {
                        Button("Fix") {
                            FnKeyAction.setDoNothing()
                            fnConflict = FnKeyAction.conflicts
                        }
                    } label: {
                        Label("Pressing fn alone also \(FnKeyAction.name).", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            } footer: {
                Text("Double-tap for hands-free, tap again to finish. Esc cancels.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                Picker("Microphone", selection: $mic) {
                    Text("Automatic").tag("")
                    Divider()
                    ForEach(devices) { Text($0.name).tag($0.uid) }
                }
                Picker("Language", selection: $language) {
                    Text("Detect automatically").tag("")
                    Divider()
                    ForEach(Self.languages, id: \.rawValue) { Text(Self.name($0)).tag($0.rawValue) }
                }
            } footer: {
                Text("Automatic prefers the built-in mic: a Bluetooth headset sounds like a phone call while its mic is open.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { LoginItem.set(launchAtLogin) }
                LabeledContent("Version \(Bundle.main.version)") {
                    Button("Check for Updates") { updates.check() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: hotkeyCode) { dictation.hotkey.setKey(HotkeyKey(keyCode: UInt16(hotkeyCode))) }
        .onChange(of: mic) { dictation.mic.use(uid: mic.isEmpty ? nil : mic) }
        .onChange(of: language) { dictation.language = Language(rawValue: language) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            devices = Devices.inputs()
            fnConflict = FnKeyAction.conflicts
        }
        .onDisappear { stopRecording() }
    }

    /// Captures the next modifier the user presses on its own.
    private func toggleRecording() {
        if recorder != nil { return stopRecording() }
        recorder = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { event in
            if event.type == .flagsChanged, HotkeyKey.isModifier(event.keyCode), event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty == false {
                hotkeyCode = Int(event.keyCode)
                stopRecording()
                return nil
            }
            if event.type == .keyDown {
                NSSound.beep()  // only a modifier on its own types nothing
                return nil
            }
            return event
        }
    }

    private func stopRecording() {
        if let recorder { NSEvent.removeMonitor(recorder) }
        recorder = nil
    }

    private static let languages = Language.allCases.sorted { name($0) < name($1) }
    private static func name(_ language: Language) -> String {
        Locale.current.localizedString(forLanguageCode: language.rawValue)?.localizedCapitalized ?? language.rawValue
    }
}

extension Bundle {
    var version: String { object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev" }
}
