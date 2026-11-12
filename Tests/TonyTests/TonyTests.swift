import AVFoundation
import Carbon
import FluidAudio
import Synchronization
import Testing
import os
@testable import Tony

@Suite struct HotkeyMachineTests {
    private func run(_ inputs: [HotkeyMachine.Input]) -> [HotkeyMachine.Action] {
        var machine = HotkeyMachine()
        return inputs.compactMap { machine.handle($0) }
    }

    @Test func holdToTalk() {
        #expect(run([.down(0, othersHeld: false), .up(1)]) == [.start, .stop])
    }

    @Test func shortTapInsertsNothing() {
        #expect(run([.down(0, othersHeld: false), .up(0.1), .tick(0.5)]) == [.start, .cancel])
    }

    @Test func shortTapEndsAtRealUptimes() {
        // Uptimes run to hundreds of thousands of seconds, where at + 0.35 - at can round below 0.35.
        let at = 392_766.6397
        #expect(run([.down(at - 0.1, othersHeld: false), .up(at), .tick(at + HotkeyMachine.doubleTapWindow)]) == [.start, .cancel])
    }

    @Test func doubleTapLocksHandsFreeUntilTheNextTap() {
        #expect(run([.down(0, othersHeld: false), .up(0.1), .down(0.2, othersHeld: false), .up(0.3), .otherKey(1), .down(5, othersHeld: false), .up(5.1)])
            == [.start, .lock, .stop])
    }

    @Test func chordCancels() {
        // ⌥← while right ⌥ is the hotkey: a shortcut, not a dictation.
        #expect(run([.down(0, othersHeld: false), .otherKey(0.1), .up(1)]) == [.start, .cancel])
    }

    @Test func strayKeyKeepsListening() {
        // An arrow or ⇧ bumped mid-sentence: the words are worth more than the key.
        #expect(run([.down(0, othersHeld: false), .otherKey(2), .otherKey(3), .up(5)]) == [.start, .stop])
    }

    @Test func escapeCancels() {
        #expect(run([.down(0, othersHeld: false), .escape, .up(2)]) == [.start, .cancel])
    }

    @Test func modifierWithAnotherHeldIsNotOurs() {
        #expect(run([.down(0, othersHeld: true), .up(1)]) == [])
    }

    @Test func lostReleaseRecovers() {
        #expect(run([.down(0, othersHeld: false), .down(3, othersHeld: false), .up(3.1), .down(4, othersHeld: false), .up(5)])
            == [.start, .stop, .start, .stop])
    }
}

@Suite struct CleanupTests {
    @Test func fillers() {
        #expect(Cleanup.removeFillers("Um, I think so.") == "I think so.")
        #expect(Cleanup.removeFillers("I, uh, think so.") == "I think so.")
        #expect(Cleanup.removeFillers("Fine, um.") == "Fine.")
        #expect(Cleanup.removeFillers("Hello. Um, how are you?") == "Hello. How are you?")
        #expect(Cleanup.removeFillers("So um I went") == "So I went")
        #expect(Cleanup.removeFillers("Yyy, no to idziemy.") == "No to idziemy.")
        #expect(Cleanup.removeFillers("Um.") == "")
        #expect(Cleanup.removeFillers("Ah, I see.") == "Ah, I see.")
    }

    @Test func unknownTokens() {
        #expect(Cleanup.dropUnknown("jonów wodoru <unk>literę H") == "jonów wodoru literę H")
        #expect(Cleanup.dropUnknown("rzędu <unk> Sachin") == "rzędu Sachin")
    }

    @Test func fitsTheCursor() {
        #expect(Cleanup.fit("Hello there.", after: nil) == "Hello there.")
        #expect(Cleanup.fit("Hello there.", after: "") == "Hello there.")
        #expect(Cleanup.fit("Hello there.", after: "ok.") == " Hello there.")
        #expect(Cleanup.fit("Hello there.", after: "and") == " hello there.")
        #expect(Cleanup.fit("Hello there.", after: "and ") == "hello there.")
        #expect(Cleanup.fit("Hello there.", after: "s.\n") == "Hello there.")
        #expect(Cleanup.fit("Hello there.", after: "(") == "hello there.")
        #expect(Cleanup.fit("I think so.", after: "and") == " I think so.")
        #expect(Cleanup.fit("NASA called.", after: "and") == " NASA called.")
        #expect(Cleanup.fit("Szymon called.", after: "and", keeping: ["Szymon"]) == " Szymon called.")
        #expect(Cleanup.fit("Szymonek called.", after: "and", keeping: ["Szymon"]) == " szymonek called.")
    }
}

@Suite struct WordsTests {
    @Test func swapsKeepPunctuation() {
        let text = "Ask Simon, then fluid audio."
        let simon = text.utf8.count - "Simon, then fluid audio.".utf8.count
        let fluid = text.utf8.count - "fluid audio.".utf8.count
        #expect(Words.replace(text, [(simon..<simon + 5, "Szymon"), (fluid..<fluid + 11, "FluidAudio")]) == "Ask Szymon, then FluidAudio.")
        #expect(Words.replace("a b", [(0..<3, "x"), (2..<3, "y")]) == "a y")  // of two overlapping swaps, one lands
    }

    @Test func respellsWholeWordsOnly() {
        #expect(Words.respell("I use tailscale, TAILSCALE and tailscaled.", ["Tailscale"]) == "I use Tailscale, Tailscale and tailscaled.")
        #expect(Words.respell("Ping bestboyhq.", ["bestboyhq", "C++"]) == "Ping bestboyhq.")
    }

    @Test func inflectedFormsStay() {
        #expect(Words.inflects("Mokotowie", "Mokotów"))
        #expect(Words.inflects("Tailscales", "Tailscale"))
        #expect(!Words.inflects("Mokotow", "Mokotów"))
        #expect(!Words.inflects("tail scale", "Tailscale"))
        #expect(!Words.inflects("Simon", "Szymon"))
    }

    /// A word no dictionary of the user's languages knows was misheard, however sure Parakeet was of it.
    @Test func namesNoDictionaryKnows() {
        #expect(!Words.isWord("Molini.", in: [.english, .polish]))
        #expect(Words.isWord("grid,", in: [.english, .polish]))
        #expect(Words.isWord("Malina", in: [.english, .polish]))  // Polish
        #expect(!Words.isWord("Malina", in: [.english]))
        #expect(Words.isWord("practised", in: [.english]))  // British
    }
}

@Suite struct SegmentsTests {
    @Test func speechIsTrimmedAndPadded() {
        let p: [Float] = [0, 0, 0, 0.9, 0.9, 0, 0, 0]
        #expect(Segments.speech(p, in: 0..<8, threshold: 0.6) == 2..<6)
        #expect(Segments.speech([0, 0.1, 0.3], in: 0..<3, threshold: 0.6) == nil)
    }

    /// `Session` drafts at a breath and keeps the draft at key up when nothing was said since.
    @Test func aDraftAtABreathHearsWhatKeyUpWould() {
        let breath: [Float] = [0, 0.9, 0.9, 0.9, 0.2]
        let keyUp = breath + [0.1, 0.5, 0.3]
        #expect(Segments.speech(breath, in: 0..<5, threshold: 0.6) == Segments.speech(keyUp, in: 0..<8, threshold: 0.6))
    }

    @Test func cutsInTheFirstPauseOfASegment() {
        var p = [Float](repeating: 0.9, count: 40)
        p[4...5] = [0.1, 0.1]  // too soon: a segment has `after` windows first
        p[22] = 0.1  // a breath, not a pause
        p[25...26] = [0.1, 0.1]
        p[32...33] = [0.1, 0.1]
        #expect(Segments.cut(p, from: 0, after: 20, force: 100) == 25)  // the next segment keeps the pause
        #expect(Segments.cut(p, from: 25, after: 4, force: 100) == 32)
        #expect(Segments.cut(Array(p[..<26]), from: 0, after: 20, force: 100) == nil)  // no pause yet
    }

    @Test func cutsOnceTheWordsAfterItAreHeard() {
        var p = [Float](repeating: 0.9, count: 30)
        p[25...26] = [0.1, 0.1]
        #expect(Segments.cut(p, from: 0, after: 20, force: 100, context: 8) == nil)  // 5 windows past the cut
        #expect(Segments.cut(p + [0.9, 0.9, 0.9, 0.9], from: 0, after: 20, force: 100, context: 8) == 25)
    }

    /// "like fire and forget," heard across a cut at 1 s: each side writes the words that start on it.
    @Test func keepsTheWordsThatStartOnItsSideOfACut() {
        let timings = [(" like", 0.2), (" fi", 0.6), ("re", 0.7), (" and", 1.2), (" for", 1.5), ("get", 1.6), (",", 1.8)].map {
            TokenTiming(token: $0.0, tokenId: 0, startTime: $0.1, endTime: $0.1 + 0.08, confidence: 1)
        }
        let result = ASRResult(text: "like fire and forget,", confidence: 1, duration: 2, processingTime: 0, tokenTimings: timings)
        #expect(Segments.words(of: result, startingIn: 0..<1).text == "like fire")
        #expect(Segments.words(of: result, startingIn: 1..<2).text == "and forget,")
        #expect(Segments.words(of: result, startingIn: 0..<2).text == "like fire and forget,")
    }

    /// The segment before a cut heard the word after it mid-sentence, the segment after as its first word.
    @Test func joinsInTheCaseHeardBeforeTheCut() {
        #expect(Segments.join([("to wyślij mi", "proszę"), ("Proszę zaproszenie.", nil)]) == "to wyślij mi proszę zaproszenie.")
        #expect(Segments.join([("bo w czwartek?", "Mam"), ("mam już", nil)]) == "bo w czwartek? Mam już")
        #expect(Segments.join([("I talked to", "malina"), ("Malini, and", nil)]) == "I talked to Malini, and")  // another word
        #expect(Segments.join([("so", "for"), ("", nil), ("For", nil)]) == "so For")  // silence between
    }

    @Test func forcesACutWithoutAPause() {
        var p = [Float](repeating: 0.9, count: 120)
        p[110] = 0.5
        #expect(Segments.cut(p, from: 0, after: 20, force: 100) == 110)
        #expect(Segments.cut(Array(p[..<99]), from: 0, after: 20, force: 100) == nil)  // not past `force` yet
    }

    /// "Can you send me the report", a pause, "do końca dnia": 20 windows of 256 ms, the pause in windows 6 and 7.
    private let switched: [Float] = [Float](repeating: 1, count: 6) + [0.2, 0.2] + [Float](repeating: 1, count: 11) + [0.2]
    private func words(from start: Double, to end: Double, confidence: Float = 1) -> [TokenTiming] {
        stride(from: start, to: end, by: 0.24).map { TokenTiming(token: " a", tokenId: 0, startTime: $0, endTime: $0 + 0.08, confidence: confidence) }
    }

    @Test func splitsWhereALanguageGoesMissing() {
        let runs = Segments.languages(switched, tokens: words(from: 2, to: 4.6), threshold: 0.6, window: 4096)
        #expect(runs?.map(\.samples) == [0..<32000, 32000..<81920])
        #expect(runs?.map(\.unsure) == [true, false])
    }

    @Test func splitsWhereALanguageComesOutUnsure() {
        let runs = Segments.languages(switched, tokens: words(from: 0, to: 1.5) + words(from: 2, to: 4.6, confidence: 0.6), threshold: 0.6, window: 4096)
        #expect(runs?.map(\.samples) == [0..<28672, 28672..<81920])
        #expect(runs?.map(\.unsure) == [false, true])
    }

    @Test func keepsOneLanguageWhole() {
        #expect(Segments.languages(switched, tokens: words(from: 0, to: 1.5) + words(from: 2, to: 4.6), threshold: 0.6, window: 4096) == nil)
        // A long pause between words is no missing language.
        let paused = [Float](repeating: 1, count: 6) + [Float](repeating: 0.1, count: 6) + [Float](repeating: 1, count: 6)
        #expect(Segments.languages(paused, tokens: words(from: 0, to: 1.5) + words(from: 3.1, to: 4.6), threshold: 0.6, window: 4096) == nil)
    }
}

@Suite struct PasteKeyTests {
    private func layout(_ id: String) -> TISInputSource {
        let list = TISCreateInputSourceList([kTISPropertyInputSourceID as String: id] as CFDictionary, true).takeRetainedValue() as! [TISInputSource]
        return list[0]
    }

    @Test func commandVOnEveryLayout() {
        #expect(Paste.vKeyCode(layout: layout("com.apple.keylayout.US")) == CGKeyCode(kVK_ANSI_V))
        #expect(Paste.vKeyCode(layout: layout("com.apple.keylayout.Dvorak")) == CGKeyCode(kVK_ANSI_Period))  // "v" sits on QWERTY's "."
        #expect(Paste.vKeyCode(layout: layout("com.apple.keylayout.DVORAK-QWERTYCMD")) == CGKeyCode(kVK_ANSI_V))  // QWERTY while ⌘ is held
        #expect(Paste.vKeyCode(layout: layout("com.apple.keylayout.Russian")) == CGKeyCode(kVK_ANSI_V))  // no "v": QWERTY position
        #expect(Paste.vKeyCode(layout: layout("com.apple.keylayout.Polish")) == CGKeyCode(kVK_ANSI_V))
    }
}

@Suite struct StatsTests {
    @Test func countsADictation() {
        var stats = Stats()
        stats.record(raw: "Um, ask Szymon about Tailscale.", text: "Ask Szymon about Tailscale.", yourWords: ["Szymon", "Tailscale"],
                     seconds: 2, latency: 90, app: "com.apple.Notes", on: 10)
        stats.record(raw: "Done.", text: "Done.", yourWords: [], seconds: 1, latency: 110, app: "com.apple.Notes", on: 10)
        #expect(stats.total == Stats.Day(dictations: 2, words: 5, seconds: 3, fillers: 1, yourWords: 2))
        #expect(stats.wordsPerMinute == 100)
        #expect(stats.apps == ["com.apple.Notes": 5])
        #expect(stats.medianLatency == 110)
        #expect(stats.secondsSaved == 4.5)  // 5 words typed at 40 wpm take 7.5 s
    }

    @Test func streaks() {
        var stats = Stats()
        for day in [1, 2, 3, 7, 8] { stats.days[day] = Stats.Day(dictations: 1) }
        #expect(stats.streak(on: 8) == 2)
        #expect(stats.streak(on: 9) == 2)  // alive until a whole day passes
        #expect(stats.streak(on: 10) == 0)
        #expect(stats.longestStreak == 3)
    }

    @Test func appsOfOneNameAddUp() {
        let names = ["app.malini.desktop.dev": "Malini", "app.malini.desktop": "Malini", "com.tdesktop.Telegram": "Telegram"]
        let rows = Apps.rows(["app.malini.desktop": 2626, "com.tdesktop.Telegram": 8431, "app.malini.desktop.dev": 95903]) { names[$0]! }
        #expect(rows.map(\.name) == ["Malini", "Telegram"])
        #expect(rows.map(\.words) == [98529, 8431])
        #expect(rows[0].id == "app.malini.desktop.dev")  // the icon of the one used most
    }
}

/// Fades the Mac's real output for about four seconds; skipped where software can't set its volume.
/// Now Playing is a recorder, so the user's music never pauses.
@Suite(.serialized) struct DuckingTests {
    @Test(.enabled(if: (Devices.defaultOutput.flatMap(Devices.volume) ?? 0) > 0))
    func fadesOutAndBackToTheUsersVolume() async throws {
        let id = try #require(Devices.defaultOutput)
        let volume = try #require(Devices.volume(id))
        defer { Devices.setVolume(id, volume) }
        let playing = Atomic(true)
        let commands = OSAllocatedUnfairLock(initialState: [String]())
        let ducking = Ducking { command in
            commands.withLock { $0.append(command) }
            return command == "pause" && playing.load(ordering: .relaxed)
        }
        /// Waits for it to hold, as long as a loaded CI machine needs.
        func until(_ holds: () -> Bool) async throws {
            let deadline = ContinuousClock.now + .seconds(5)
            while !holds(), .now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        }
        func reaches(_ expected: Float32?, sourceLocation: SourceLocation = #_sourceLocation) async throws {
            try await until { Devices.volume(id) == expected }
            #expect(Devices.volume(id) == expected, sourceLocation: sourceLocation)
        }
        func sent(_ expected: [String], sourceLocation: SourceLocation = #_sourceLocation) async throws {
            try await until { commands.withLock { $0 } == expected }
            #expect(commands.withLock { $0 } == expected, sourceLocation: sourceLocation)
        }

        // Let go before the sound is out: nothing paused.
        ducking.duck()
        ducking.restore()
        try await reaches(volume)
        try await sent([])

        // Music plays: paused once the sound is out, played again after.
        ducking.duck()
        try await reaches(0)
        try await sent(["pause"])
        ducking.restore()
        try await reaches(volume)
        try await sent(["pause", "play"])

        // Turned up while Tony listened: the user's volume stays. Nothing played, so nothing plays after.
        playing.store(false, ordering: .relaxed)
        ducking.duck()
        try await reaches(0)
        try await sent(["pause", "play", "pause"])
        Devices.setVolume(id, volume / 2)
        let turnedUp = Devices.volume(id)
        ducking.restore()
        try await Task.sleep(for: .seconds(Ducking.fadeIn + 0.2))
        #expect(Devices.volume(id) == turnedUp)
        #expect(commands.withLock { $0 } == ["pause", "play", "pause"])

        // Tony quit while faded out: the next launch brings the sound back.
        ducking.duck()
        try await reaches(0)
        _ = Ducking()
        try await reaches(turnedUp)
    }

    /// Tony quit while AirPods it faded out were away: they get their volume back when they are plugged in.
    @Test func keepsTheVolumeOfADeviceThatIsAway() async throws {
        UserDefaults.standard.set(["away": 0.5], forKey: Ducking.savedKey)
        defer { UserDefaults.standard.removeObject(forKey: Ducking.savedKey) }
        _ = Ducking()
        try await Task.sleep(for: .milliseconds(200))
        #expect(UserDefaults.standard.dictionary(forKey: Ducking.savedKey) as? [String: Double] == ["away": 0.5])
    }
}

/// Opens each wired mic for a second and a half; skipped where Tony may not use the mic.
@Suite struct MicTests {
    @Test(.enabled(if: AVCaptureDevice.authorizationStatus(for: .audio) == .authorized))
    func oneEngineHearsEveryMic() async throws {
        let mic = Mic()
        for device in Devices.inputs() where device.isBuiltIn || device.transport == kAudioDeviceTransportTypeUSB {
            let count = Atomic<Int>(0)
            mic.use(uid: device.uid)
            mic.start(keyDownAt: 0, onSamples: { count.add($0.count, ordering: .relaxed) }, onError: { Issue.record($0) })
            try await Task.sleep(for: .seconds(1.5))
            let summary = await mic.stop().value
            #expect(summary.device?.uid == device.uid)
            // 16 kHz for 1.5 s, less the time the device takes to start (half a second for a Studio Display)
            // and to restart after the configuration change its selection posts.
            #expect((8000...25000).contains(count.load(ordering: .relaxed)), "\(device.name)")
        }
    }
}

@Suite struct DownloadTests {
    @Test func timeLeftFollowsThePaceSoFar() {
        #expect(Speech.remaining(elapsed: 30, done: 0.25) == 90)
        #expect(Speech.remaining(elapsed: 1, done: 0.5) == nil)  // too soon to tell
        #expect(Speech.remaining(elapsed: 30, done: 0.01) == nil)  // too little to go on
        #expect(Speech.remaining(elapsed: 30, done: 1) == nil)
    }
}

@Suite struct ShadowTests {
    /// Over the dark gray of a dark window, the shadow below the pill blends between gray levels instead of stepping
    /// through them in rings, and the glass above it stays clear.
    @Test func ditheredOverDarkGray() throws {
        let image = Shadow.image(scale: 2, dark: true)
        let data = try #require(image.dataProvider?.data as Data?)
        let gray = { (x: Int, y: Int) in (43 * (1 - Double(data[y * image.bytesPerRow + x * 4 + 3]) / 255)).rounded() }
        let middle = image.width / 2, strip = middle - 32..<middle + 32  // the straight part, 32 pt wide at 2x
        #expect(gray(middle, image.height / 2) == 43)
        let edge = image.height / 2 + Int(Shadow.height)  // the capsule's bottom, 20 pt below its middle at 2x
        let rows = (edge..<image.height).map { y in strip.map { gray($0, y) }.reduce(0, +) / Double(strip.count) }.filter { $0 < 42.9 }
        let between = rows.filter { abs($0 - $0.rounded()) > 0.1 }
        #expect(rows.count > 30)
        #expect(between.count * 4 > rows.count * 3, "\(rows.count - between.count) of \(rows.count) rows sit on one gray level")
    }
}

/// Usage stats (ADR 0013): one last event when the switch turns off, nothing while it is off, and never what was said,
/// typed, or spelled the user's way.
@Suite(.serialized) struct UsageTests {
    private let url = URL(string: "http://127.0.0.1:9/api/events")!

    @Test func offSendsNothing() {
        defer { UserDefaults.standard.removeObject(forKey: Prefs.usageCountsKey) }
        UserDefaults.standard.removeObject(forKey: Prefs.usageCountsKey)
        #expect(Usage.request("launched", [:], to: url) != nil)  // on until turned off
        UserDefaults.standard.set(false, forKey: Prefs.usageCountsKey)
        #expect(Usage.request("launched", [:], to: url) == nil)
        #expect(Usage.request("dictation_finished", Usage.dictation(text: "Hello.", seconds: 1, latency: 90, handsFree: false), to: url) == nil)
        UserDefaults.standard.set(true, forKey: Prefs.usageCountsKey)  // back on, without a question
        #expect(Usage.request("launched", [:], to: url) != nil)
        if ProcessInfo.processInfo.environment["TONY_EVENTS_URL"] == nil { #expect(Usage.url == nil, "a development build sends nowhere") }
    }

    @Test func turningOffSendsOneLast() throws {
        defer { UserDefaults.standard.removeObject(forKey: Prefs.usageCountsKey) }
        UserDefaults.standard.removeObject(forKey: Prefs.usageCountsKey)
        let last = try #require(Usage.share(false, to: url)?.httpBody, "sent while still on")
        let event = try #require((try JSONSerialization.jsonObject(with: last) as? [String: Any])?["events"] as? [[String: Any]])
        #expect(event.first?["name"] as? String == "tony_stats_off")
        #expect(!Prefs.usageCounts)
        #expect(Usage.share(false, to: url) == nil)  // already off
        #expect(Usage.share(true, to: url) == nil)  // on sends nothing extra
        #expect(Prefs.usageCounts)
    }

    @Test func noEventCarriesText() throws {
        defer { UserDefaults.standard.removeObject(forKey: Prefs.usageCountsKey) }
        UserDefaults.standard.removeObject(forKey: Prefs.usageCountsKey)
        let said = "Ask Szymon whether Tailscale works in Mokotów, then reply to Ania before lunch."
        let words = ["Szymon", "Tailscale", "Mokotów", "Supabase"]
        let events = [
            ("dictation_finished", Usage.dictation(text: said, seconds: 4.6, latency: 93, handsFree: true)),
            ("words_added", Usage.words(words)),
        ]
        for (name, props) in events {
            let body = try #require(Usage.request(name, props, to: url)?.httpBody)
            let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
            #expect(json["app"] as? String == "tony")
            let event = try #require((json["events"] as? [[String: Any]])?.first)
            #expect((event["name"] as? String)?.wholeMatch(of: /tony_[a-z0-9_]{1,59}/) != nil)
            let sent = try #require(event["props"] as? [String: Any])
            #expect(sent.count <= 9)
            for (key, value) in sent {
                #expect(key.wholeMatch(of: /[a-z][a-z0-9_]{0,39}/) != nil)
                #expect(value is NSNumber, "\(name).\(key) is a count or a flag, never a string")
            }
            let text = String(decoding: body, as: UTF8.self)
            for word in words + ["whether", "Ania", "lunch"] { #expect(!text.contains(word), "\(name) carries \(word)") }
        }
        #expect(NSDictionary(dictionary: events[0].1) == ["seconds": 5, "words": 10, "latency_ms": 90, "hands_free": true])
        #expect([1, 9, 10, 23, 147, 1234].map(Usage.rounded) == [1, 9, 10, 20, 100, 1000])
    }
}
