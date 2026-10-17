import Carbon.HIToolbox
import FluidAudio
import SwiftUI

/// Options exist only where people really differ: the key, the mic, the language, the words.
struct SettingsView: View {
    let dictation: Dictation
    let speech: Speech
    let updates: Updates
    @AppStorage(Prefs.micKey) private var mic = ""
    @State private var languages = Prefs.languages
    @State private var devices = Devices.inputs()
    @State private var launchAtLogin = LoginItem.isOn

    var body: some View {
        Form {
            Section {
                LabeledContent("Hold to dictate") { HotkeyPicker(hotkey: dictation.hotkey) }
                FnWarning()
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
                LabeledContent("Languages") {
                    Menu(languageSummary) {
                        Toggle("Any language", isOn: Binding { languages.isEmpty } set: { if $0 { languages = [] } })
                        Divider()
                        ForEach(Self.choices, id: \.rawValue) { language in
                            Toggle(Self.name(language), isOn: Binding { languages.contains(language) } set: { _ in languages.formSymmetricDifference([language]) })
                        }
                    }
                    .fixedSize()
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
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: mic) { dictation.mic.use(uid: mic.isEmpty ? nil : mic) }
        .onChange(of: languages) {
            Prefs.languages = languages
            dictation.languages = languages
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            devices = Devices.inputs()
        }
    }

    private var languageSummary: String {
        if languages.isEmpty { return "Any language" }
        return languages.count > 3 ? "\(languages.count) languages" : languages.map(Self.name).sorted().formatted(.list(type: .and).locale(Self.locale))
    }

    private static let choices = Language.allCases.sorted { name($0) < name($1) }
    /// Tony's own language, not the region's: an English Mac in Poland would name them in Polish.
    private static let locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
    private static func name(_ language: Language) -> String {
        locale.localizedString(forLanguageCode: language.rawValue)?.localizedCapitalized ?? language.rawValue
    }
}

extension Bundle {
    var version: String { object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev" }
}

/// The key held to talk: a modifier from the list, or Other… and a press of any modifier. The tap gets it at once.
struct HotkeyPicker: View {
    let hotkey: Hotkey
    @AppStorage(Prefs.hotkeyKey) private var hotkeyCode = Int(HotkeyKey.fn.keyCode)
    @State private var recorder: Any?

    /// The tag of Other…, which waits for the key instead of naming one.
    private static let other = -1

    private var keys: [HotkeyKey] {
        let current = HotkeyKey(keyCode: UInt16(hotkeyCode))
        return HotkeyKey.choices.contains(current) ? HotkeyKey.choices : HotkeyKey.choices + [current]
    }

    private var selection: Binding<Int> {
        Binding {
            recorder == nil ? hotkeyCode : Self.other
        } set: { tag in
            if tag == Self.other { return startRecording() }
            stopRecording()
            hotkeyCode = tag
        }
    }

    var body: some View {
        Picker("Hold to dictate", selection: selection) {
            ForEach(keys, id: \.keyCode) { Text($0.name).tag(Int($0.keyCode)) }
            Divider()
            Text(recorder == nil ? "Other…" : "Press a modifier…").tag(Self.other)
        }
        .labelsHidden()
        .fixedSize()
        .onChange(of: hotkeyCode) { hotkey.setKey(HotkeyKey(keyCode: UInt16(hotkeyCode))) }
        .onDisappear { stopRecording() }
    }

    /// Captures the next modifier the user presses; Esc gives up.
    private func startRecording() {
        guard recorder == nil else { return }
        recorder = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { event in
            if event.type == .flagsChanged, HotkeyKey.isModifier(event.keyCode), event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty == false {
                hotkeyCode = Int(event.keyCode)
                stopRecording()
                return nil
            }
            if event.type == .keyDown {
                if event.keyCode == kVK_Escape { stopRecording() } else { NSSound.beep() }  // only a modifier on its own types nothing
                return nil
            }
            return event
        }
    }

    private func stopRecording() {
        if let recorder { NSEvent.removeMonitor(recorder) }
        recorder = nil
    }
}

/// With fn as the key, pressing it also runs the action under Keyboard > "Press 🌐 key to": Fix sets Do Nothing.
struct FnWarning: View {
    @AppStorage(Prefs.hotkeyKey) private var hotkeyCode = Int(HotkeyKey.fn.keyCode)
    @State private var conflict = FnKeyAction.conflicts

    var body: some View {
        if hotkeyCode == Int(HotkeyKey.fn.keyCode), conflict {
            HStack {
                Label("fn also \(FnKeyAction.name).", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Spacer(minLength: 8)
                Button("Fix") {
                    FnKeyAction.setDoNothing()
                    conflict = FnKeyAction.conflicts
                }
                .help("Sets Keyboard > Press 🌐 key to: Do Nothing")
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                conflict = FnKeyAction.conflicts
            }
        }
    }
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
