import FluidAudio
import SwiftUI

/// Options exist only where people really differ: the key, the mic, the language, the words.
struct SettingsView: View {
    let dictation: Dictation
    let speech: Speech
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
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your words")
                    WordsField(speech: speech)
                }
            } footer: {
                WordsFooter(speech: speech, detail: "Names, brands, and jargon Tony should write your way. Press Return after each one.")
                    .font(.callout)
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

/// The user's words as tags above a field: type one, then Return or a comma. Each word reaches the speech
/// model as it is added or removed.
struct WordsField: View {
    let speech: Speech
    @State private var words = Prefs.words
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !words.isEmpty {
                Flow(spacing: 6) {
                    ForEach(words, id: \.self) { word in
                        HStack(spacing: 3) {
                            Text(word)
                            Button { save(words.filter { $0 != word }) } label: {
                                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Remove \(word)")
                        }
                        .padding(.leading, 8)
                        .padding(.trailing, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                    }
                }
            }
            TextField("Add a word", text: $draft, prompt: Text(words.isEmpty ? "Your name, your team, your jargon" : "Add a word"))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .focused($focused)
                .onSubmit(add)
                .onChange(of: draft) {
                    // Keystrokes arrive in batches: what follows the last comma is still being typed.
                    guard let comma = draft.lastIndex(of: ",") else { return }
                    let done = String(draft[..<comma])
                    draft = String(draft[draft.index(after: comma)...].drop(while: \.isWhitespace))
                    save(words + Self.split(done))
                }
                .onChange(of: focused) { if !focused { add() } }
                .onDisappear(perform: add)
        }
        .animation(.default, value: words)
    }

    /// Adds what is typed.
    private func add() {
        let typed = Self.split(draft)
        draft = ""
        save(words + typed)
    }

    /// One word or phrase per comma.
    private static func split(_ text: String) -> [String] {
        text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// Keeps the first of each word in any capitals, and teaches the speech model.
    private func save(_ list: [String]) {
        var seen = Set<String>()
        let list = list.filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
        guard list != words else { return }
        words = list
        Prefs.words = list
        Task { await speech.learn(list) }
    }
}

/// Lays views out in rows, left to right, starting a new row where the next one doesn't fit.
struct Flow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, in: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, point) in zip(subviews, arrange(subviews, in: bounds.width).points) {
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func arrange(_ subviews: Subviews, in width: CGFloat) -> (points: [CGPoint], size: CGSize) {
        var points: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += row + spacing
                row = 0
            }
            points.append(CGPoint(x: x, y: y))
            widest = max(widest, x + size.width)
            x += size.width + spacing
            row = max(row, size.height)
        }
        return (points, CGSize(width: widest, height: y + row))
    }
}

/// What the words are for, and that Tony is still getting them ready.
struct WordsFooter: View {
    let speech: Speech
    let detail: String

    var body: some View {
        HStack(spacing: 6) {
            if speech.learning { ProgressView().controlSize(.mini) }
            Text(speech.learning ? "Getting ready to listen for them…" : detail)
        }
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
