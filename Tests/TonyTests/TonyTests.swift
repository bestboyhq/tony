import Carbon
import FluidAudio
import Testing
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
        #expect(run([.down(0, othersHeld: false), .up(0.1), .down(0.2, othersHeld: false), .up(0.3), .otherKey, .down(5, othersHeld: false), .up(5.1)])
            == [.start, .lock, .stop])
    }

    @Test func chordCancels() {
        // ⌥← while right ⌥ is the hotkey: a shortcut, not a dictation.
        #expect(run([.down(0, othersHeld: false), .otherKey, .up(1)]) == [.start, .cancel])
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
}

@Suite struct SegmentsTests {
    @Test func speechIsTrimmedAndPadded() {
        let p: [Float] = [0, 0, 0, 0.9, 0.9, 0, 0, 0]
        #expect(Segments.speech(p, in: 0..<8, threshold: 0.6) == 2..<6)
        #expect(Segments.speech([0, 0.1, 0.3], in: 0..<3, threshold: 0.6) == nil)
    }

    @Test func cutsInsideAPause() {
        var p = [Float](repeating: 0.9, count: 40)
        p[20] = 0.1
        p[21] = 0.1
        #expect(Segments.cut(p, from: 0, after: 30, force: 100) == 21)
        #expect(Segments.cut(p, from: 0, after: 50, force: 100) == nil)  // not time yet
    }

    @Test func forcesACutWithoutAPause() {
        var p = [Float](repeating: 0.9, count: 120)
        p[100] = 0.5
        #expect(Segments.cut(p, from: 0, after: 30, force: 100) == 101)
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
}

/// Fades the Mac's real output for about three seconds; skipped where software can't set its volume.
@Suite struct DuckingTests {
    @Test(.enabled(if: (Devices.defaultOutput.flatMap(Devices.volume) ?? 0) > 0))
    func fadesOutAndBackToTheUsersVolume() async throws {
        let id = try #require(Devices.defaultOutput)
        let volume = try #require(Devices.volume(id))
        defer { Devices.setVolume(id, volume) }
        let ducking = Ducking()
        func settle(_ seconds: Double) async throws { try await Task.sleep(for: .seconds(seconds + 0.2)) }

        ducking.duck()
        try await settle(Ducking.fadeOut)
        #expect(Devices.volume(id) == 0)
        ducking.restore()
        try await settle(Ducking.fadeIn)
        #expect(Devices.volume(id) == volume)

        // Turned up while Tony listened: the user's volume stays.
        ducking.duck()
        try await settle(Ducking.fadeOut)
        Devices.setVolume(id, volume / 2)
        let turnedUp = Devices.volume(id)
        ducking.restore()
        try await settle(Ducking.fadeIn)
        #expect(Devices.volume(id) == turnedUp)

        // Tony quit while faded out: the next launch brings the sound back.
        ducking.duck()
        try await settle(Ducking.fadeOut)
        _ = Ducking()
        try await settle(0)
        #expect(Devices.volume(id) == turnedUp)
    }
}
