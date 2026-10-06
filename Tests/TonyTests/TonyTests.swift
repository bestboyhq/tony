import Carbon
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
