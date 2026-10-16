---
name: insert
description: Putting the dictated text where the cursor is. Use when changing paste, the clipboard, keyboard layout handling, spacing and capitals around the cursor, or what happens when insertion fails.
---

# Insert

Putting the text where the cursor is.

- Paste is the one path that works in every app: put the text on the pasteboard, then post ⌘V.
  Typing characters one by one is slow and fights autocomplete, and Accessibility text insertion works in native text views only.
- The dictation stays on the clipboard (ADR 0007).
  Tony can't tell when ⌘V lands nowhere (no text field, an app that ignores it), so the clipboard is where every word survives.
- Write it for this Mac only (`.currentHostOnly`), so Universal Clipboard keeps dictations off the user's other devices.
- Post ⌘V with the key code that types "v" while ⌘ is held in the active layout (`UCKeyTranslate` with the command modifier), so Dvorak pastes instead of firing another shortcut.
  When no key types "v" (Cyrillic, Greek), use the ANSI V key code: macOS matches shortcuts by QWERTY position there.
  Read the layout on the main thread: TIS asserts the main queue on macOS 14+ (Grip learned this).
- Secure fields refuse synthetic paste, and posting ⌘V needs Accessibility.
  When either stops Tony, the text is already on the clipboard, and the HUD says to press ⌘V.
- Where the app exposes it through Accessibility, read the text before the cursor to fix spacing and capitals: no capital mid-sentence, a space after a word, none after an opening bracket or at a line start.
  Apps that expose nothing get the text as transcribed.
- One ⌘Z undoes a whole dictation.
- The menu bar panel offers the last dictation to copy or paste again, kept in memory only.

Done when dictation lands right in TextEdit, Safari, Chrome, Slack, VS Code, and Terminal, a password field refuses it gracefully, QWERTY, Dvorak, and Russian layouts all work, and the dictation is on the clipboard afterwards, also when the paste found no text field.
