import ServiceManagement
import SwiftUI

/// From install to a first dictation in a minute, without docs. Each permission is asked just in time
/// with a one-line reason; the model downloads meanwhile; a practice field ends it with a first dictation.
struct OnboardingView: View {
    let permissions: Permissions
    let speech: Speech
    let done: () -> Void
    @AppStorage(Prefs.hotkeyKey) private var hotkeyCode = Int(HotkeyKey.fn.keyCode)
    @State private var launchAtLogin = true
    @State private var practice = ""
    @State private var fnConflict = FnKeyAction.conflicts
    @FocusState private var practiceFocused: Bool

    private var key: String { HotkeyKey(keyCode: UInt16(hotkeyCode)).name }
    private var ready: Bool { permissions.ready && speech.isReady }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 88, height: 88)
                Text("Meet Tony")
                    .font(.system(size: 26, weight: .bold))
                Text("Hold \(key), speak, and let go.\nYour words land where the cursor is.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 0) {
                Step(icon: "mic.fill", title: "Microphone", detail: "So Tony hears you while you hold the key.", done: permissions.microphone == .authorized) {
                    Button(permissions.microphone == .notDetermined ? "Allow" : "Open Settings") { permissions.requestMicrophone() }
                }
                Divider().padding(.leading, 52)
                Step(icon: "keyboard.fill", title: "Accessibility", detail: "So Tony notices the key and types for you.", done: permissions.accessibility && !permissions.needsRelaunch) {
                    if permissions.needsRelaunch {
                        Button("Relaunch") { Permissions.relaunch() }
                    } else {
                        Button("Allow") { permissions.requestAccessibility() }
                    }
                }
                Divider().padding(.leading, 52)
                Step(icon: "waveform", title: "Speech model", detail: modelDetail, done: speech.isReady) {
                    switch speech.state {
                    case let .downloading(progress):
                        ProgressView(value: progress).frame(width: 72)
                    case .failed:
                        Button("Try Again") { Task { await speech.prepare() } }
                    default:
                        ProgressView().controlSize(.small)
                    }
                }
                if hotkeyCode == Int(HotkeyKey.fn.keyCode), fnConflict {
                    Divider().padding(.leading, 52)
                    Step(icon: "globe", title: "The fn key", detail: "Pressing fn alone also \(FnKeyAction.name).", done: false) {
                        Button("Fix") {
                            FnKeyAction.setDoNothing()
                            fnConflict = FnKeyAction.conflicts
                        }
                        .help("Sets Keyboard > Press 🌐 key to: Do Nothing")
                    }
                }
            }
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("Words Tony should know").font(.system(size: 13, weight: .semibold))
                WordsField(speech: speech)
                WordsFooter(speech: speech, detail: "Press Return after each one. Optional.")
                    .font(.system(size: 12))
            }

            TextField(ready ? "Hold \(key) and say “Hello, Tony.”" : "Your first dictation goes here", text: $practice, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
                .disabled(!ready)
                .focused($practiceFocused)
                .onChange(of: ready) { if ready { practiceFocused = true } }
                .onAppear { if ready { practiceFocused = true } }

            HStack {
                Toggle("Open Tony at login", isOn: $launchAtLogin)
                Spacer()
                Button(practice.isEmpty ? "Finish Later" : "Done") {
                    LoginItem.set(launchAtLogin)
                    done()
                }
                    .keyboardShortcut(practice.isEmpty ? .cancelAction : .defaultAction)
            }
        }
        .padding(28)
        .frame(width: 440)
    }

    private var modelDetail: String {
        switch speech.state {
        case let .failed(message): message
        case .loading: "Preparing it for this Mac's Neural Engine."
        default: "Runs on this Mac. Your voice never leaves it."
        }
    }
}

private struct Step<Action: View>: View {
    let icon: String
    let title: String
    let detail: String
    let done: Bool
    @ViewBuilder let action: Action

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(done ? Color.green : Color.accentColor, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.green)
                    .accessibilityLabel("Done")
            } else {
                action.controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .animation(.default, value: done)
    }
}

/// Launch at login through SMAppService.
enum LoginItem {
    static var isOn: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ on: Bool) {
        guard on != isOn else { return }
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Tony: login item: \(error.localizedDescription)")
        }
    }
}
