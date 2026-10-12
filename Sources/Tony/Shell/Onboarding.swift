import ServiceManagement
import SwiftUI

/// From install to a first dictation in a minute, without docs. One step at a time: the first one left is
/// open, the rest are a line each. It asks for the key first, then each permission just in time with a
/// one-line reason; the model downloads meanwhile; a practice field ends it with a first dictation.
struct OnboardingView: View {
    let permissions: Permissions
    let speech: Speech
    let hotkey: Hotkey
    let done: () -> Void
    @AppStorage(Prefs.hotkeyKey) private var hotkeyCode = Int(HotkeyKey.fn.keyCode)
    @State private var launchAtLogin = true
    @State private var practice = ""
    @State private var keyDone = false
    @State private var wordsDone = false
    @FocusState private var practiceFocused: Bool

    private enum Step { case key, microphone, accessibility, model, words, practice }

    private var key: String { HotkeyKey(keyCode: UInt16(hotkeyCode)).name }
    private var accessibilityDone: Bool { permissions.accessibility && !permissions.needsRelaunch }

    /// The first step left; the model downloads from launch, so it can be done before the permissions are.
    private var current: Step {
        if !keyDone { .key }
        else if permissions.microphone != .authorized { .microphone }
        else if !accessibilityDone { .accessibility }
        else if !speech.isReady { .model }
        else if !wordsDone { .words }
        else { .practice }
    }

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
                StepRow(number: 1, title: "Your key", done: keyDone, open: current == .key) {
                    Text("Which key will you hold to talk?")
                    HotkeyPicker(hotkey: hotkey)
                    FnWarning()
                    Button("Continue") { keyDone = true }
                        .buttonStyle(.borderedProminent)
                }
                Divider()
                StepRow(number: 2, title: "Microphone", done: permissions.microphone == .authorized, open: current == .microphone) {
                    Text(permissions.microphone == .notDetermined ? "So Tony hears you while you hold the key." : "Turn on Tony in Privacy & Security > Microphone.")
                    Button(permissions.microphone == .notDetermined ? "Allow" : "Open System Settings") { permissions.requestMicrophone() }
                        .buttonStyle(.borderedProminent)
                }
                Divider()
                StepRow(number: 3, title: "Accessibility", done: accessibilityDone, open: current == .accessibility) {
                    if permissions.needsRelaunch {
                        Text("Allowed. macOS needs Tony to restart to use it.")
                        Button("Relaunch") { Permissions.relaunch() }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Text("So Tony notices the key and types for you.")
                        Button("Allow") { permissions.requestAccessibility() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                Divider()
                StepRow(number: 4, title: "Speech model", done: speech.isReady, open: current == .model, status: modelStatus) {
                    if case let .failed(message) = speech.state {
                        Text(message)
                        Button("Try Again") { Task { await speech.prepare() } }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Text("Runs on this Mac. Your voice never leaves it.")
                        // nil while loading: the bar sweeps, as compiling reports no progress.
                        let progress: Double? = if case let .downloading(progress) = speech.state { progress } else { nil }
                        ProgressView(value: progress) {
                            EmptyView()
                        } currentValueLabel: {
                            Text(progress == nil ? "Preparing it for this Mac's Neural Engine…" : downloading)
                        }
                    }
                }
                Divider()
                StepRow(number: 5, title: "Your words", done: wordsDone, open: current == .words) {
                    Text("Names, brands, and jargon, spelled your way. Optional.")
                    WordsField(speech: speech)
                    WordsFooter(speech: speech, detail: "Press Return after each one.")
                    Button("Continue") { wordsDone = true }
                        .buttonStyle(.borderedProminent)
                }
                Divider()
                StepRow(number: 6, title: "Try it", done: false, open: current == .practice) {
                    Text("Hold \(key), say “Hello, Tony,” and let go.")
                    FnWarning()
                    TextField("Your first dictation lands here", text: $practice, axis: .vertical)
                        .font(.system(size: 13))
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                        .focused($practiceFocused)
                        .onAppear { practiceFocused = true }
                }
            }
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack {
                Toggle("Open Tony at login", isOn: $launchAtLogin)
                Spacer()
                // Before the last step there is only closing the window: the menu bar icon shows the download.
                if current == .practice {
                    Button("Done", action: done)
                        .keyboardShortcut(practice.isEmpty ? nil : .defaultAction)
                }
            }
        }
        .padding(28)
        .frame(width: 440)
        .onDisappear { LoginItem.set(launchAtLogin) }  // Done, or the window closed
    }

    /// "Downloading, 38% · ~2min left", once the pace is known.
    private var downloading: String {
        let percent = "Downloading, \(modelStatus ?? "")"
        guard let remaining = speech.downloadRemaining else { return percent }
        return "\(percent) · ~\(Int((remaining / 60).rounded(.up)))min left"
    }

    /// The model's progress in a word, for its line while another step is open.
    private var modelStatus: String? {
        switch speech.state {
        case let .downloading(progress): progress.formatted(.percent.precision(.fractionLength(0)))
        case .loading: "Preparing"
        case .failed: "Failed"
        default: nil
        }
    }
}

/// A step: a number, or a check once done, and its title. Open, it shows its reason and action below.
private struct StepRow<Content: View>: View {
    let number: Int
    let title: String
    let done: Bool
    let open: Bool
    var status: String?
    @ViewBuilder let content: Content
    @State private var shown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Group {
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.tint)
                            .accessibilityLabel("Done")
                    } else {
                        Text("\(number)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(open ? Color.white : Color.secondary)
                            .accessibilityLabel("Step \(number)")
                    }
                }
                .frame(width: 20, height: 20)
                .background {
                    if done { Circle().fill(.quaternary) } else if open { Circle().fill(.tint) } else { Circle().strokeBorder(.tertiary) }
                }
                .animation(.easeOut(duration: 0.25), value: done)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(open ? .primary : .secondary)
                Spacer(minLength: 8)
                if let status, !open, !done {
                    Text(status).font(.system(size: 12)).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            if open {
                // Fades in, but opens at once: the window takes its new height outside any SwiftUI animation,
                // so an animated height moves the steps around their center for a moment.
                VStack(alignment: .leading, spacing: 10) { content }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)  // wraps a long reason or error, never truncates
                    .padding(.leading, 30)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(shown ? 1 : 0)
                    .onAppear { withAnimation(.easeOut(duration: 0.25)) { shown = true } }
                    .onDisappear { shown = false }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
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
