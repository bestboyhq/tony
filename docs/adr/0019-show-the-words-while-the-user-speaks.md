# 0019 - Show the words while the user speaks

Status: accepted

## Context

The user found that Tony does not feel instant, and that nothing happens until they stop talking and let go of the key.
Key up was already fast: their last 100 dictations landed 88 ms after key up (median) and 128 ms at p90.
What they felt was the time while they speak, when Tony showed only the mic level.
The streaming models FluidAudio ships answer with about 320 ms of lag, but they are English only or have no Polish.
Typing each word into the field as it is heard would break the one ⌘Z that undoes a dictation and the copy of it on the clipboard (ADR 0007).
Of two prototypes, the words in the pill or a caption above it, the user chose the caption, with text that arrives like the text Malini streams, "so it feels like magic and super smooth".

## Decision

- While the user speaks, `Session` drafts the open segment again after each `Session.draftEvery` of audio (7,200 samples, ~0.45 s), one draft at a time, and still at each breath.
  `Session.preview` is the closed segments and the open one's latest draft, and `Dictation.preview`, without filler words, is what the HUD shows.
  The feeder hands it to the main thread without waiting, so the voice activity detection never waits on the HUD's frames.
- A segment with no pause closes by about 14 s (`Session.forceAfter`), so every draft fits the model's one window and costs one pass.
- At key up, a draft whose speech is the speech key up would transcribe is the text, so drafting changes no word and costs key up no pass.
- `Caption` in `HUDView.swift` shows the preview above the pill, 532 pt wide, on the pill's glass, at most three lines.
  - Each word is a view of its own, named by the time it arrived, so a word the next draft keeps stays where it is.
  - Each draft moves the card and every word in one transaction, `.smooth(duration: 0.5)`, long enough to run into the next draft.
  - A new word arrives 0.1 s after its draft (`Caption.lead`), once the card has made room, each a beat after the one before it (at most 60 ms, a burst within 0.4 s).
    It fades in from blurred and 4 pt low over 0.5 s on Malini's expo-out curve.
  - The word being said is at half strength, without the period Parakeet ends each draft with, until a draft keeps it.
  - A word the draft drops blurs out where it was in 0.2 s.
  - `Caption.lines` breaks the lines in the view, and a line's index names it, so a word that wraps onto another line crossfades instead of flying across the card.
  - Past three lines, the lines scroll up under a fade one line high, and the line that leaves fades out in 0.15 s, before the card's edge can cut it.
  - With Reduce Motion, words only fade, and the card takes its new size at once.
- `HUD.size` grows to 640×200 for the caption and its shadow.
- `Tony --transcribe <file> -realtime YES -hud YES` draws the HUD's view in a window under the desktop picture, so a window recording shows the caption on real drafts and the user's screen shows none of it.

## Consequences

- The user sees what Tony heard about half a second after saying it, in every language Parakeet Ultra knows.
- The text is the same as without drafts, and key up measured 62 to 75 ms on real-time runs, against 56 to 113 ms before.
- The Neural Engine works every half second while the user speaks; between dictations Tony is still idle.
- Key up can wait behind a draft that is still running, at most one pass.
- The caption keeps up through talk with no pause, since a segment never outgrows the model's window.
- `CaptionTests` fails when a kept word loses its time, new words come out of order, the word being said keeps its period, or lines break out of order.
  Nothing automatic checks the motion: the HUD skill's done check, a recording at 0.25x, does.
