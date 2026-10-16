# 0007 - The dictation stays on the clipboard

Status: accepted

## Context

ADR 0006 restored the clipboard 600 ms after ⌘V.
Tony learns that a paste failed only when it can't press ⌘V at all (secure input, no Accessibility).
When ⌘V lands nowhere (no text field focused, an app that ignores it, focus moved while Tony transcribed), the HUD says "Inserted", the old clipboard comes back, and the words survive only under Last dictation in the menu bar panel.
To the user, "it's as if the recording never happened".
An app that reads the pasteboard after 600 ms also pastes the old clipboard instead of the dictation.
Checking through Accessibility whether the paste landed would be a guess, since Chrome and Electron apps often expose nothing.

## Decision

- Still from ADR 0006: Tony pastes through the clipboard with ⌘V, posted with the key that types "v" in the active layout.
- `Paste.paste(_:)` puts the dictation on the clipboard first, then presses ⌘V when it can, and never restores the clipboard.
- `Paste.copy(_:)` writes for this Mac only (`prepareForNewContents(with: .currentHostOnly)`), so Universal Clipboard doesn't send dictations to the user's other devices.
- The dictation is a plain clipboard item without the nspasteboard.org markers, so clipboard managers keep it like anything the user copies.
- `Paste.paste(_:)` returns false without Accessibility or with secure input on, and the HUD says "…: press ⌘V to paste."; the HUD's Copy action is gone.
  It checks Accessibility itself, so the menu's Paste gets the same check as a dictation.
- Esc keeps the words as the last dictation without touching the clipboard, since the user cancelled on purpose.

## Consequences

- Every dictation is one ⌘V away until the user copies something else, also after a paste that failed silently.
- Dictating replaces what the user had copied, and Tony can't bring it back.
- No race with slow apps, no snapshot of the pasteboard, and nothing for quitting to wait for.
- Nothing enforces this automatically; the insert skill's done check names it.
