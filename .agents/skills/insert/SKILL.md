---
name: insert
description: Putting the dictated text where the cursor is. Use when changing paste, clipboard restore, keyboard layout handling, spacing and capitals around the cursor, or what happens when insertion fails.
---

# Insert

Putting the text where the cursor is.

- Paste is the one path that works in every app: put the text on the pasteboard, post ⌘V, restore the clipboard.
  Typing characters one by one is slow and fights autocomplete, and Accessibility text insertion works in native text views only.
- Save every item and every type on the pasteboard first, and restore them all after, but only if `changeCount` shows nobody copied in between.
  Restoring too early pastes the old clipboard in slow apps (Electron, browsers), so wait until the paste has landed.
- Mark Tony's pasteboard item transient and concealed (`org.nspasteboard.TransientType`, `org.nspasteboard.ConcealedType`, see nspasteboard.org), so clipboard managers skip dictations.
- Post ⌘V with the key code that types "v" while ⌘ is held in the active layout (`UCKeyTranslate` with the command modifier), so Dvorak pastes instead of firing another shortcut.
  When no key types "v" (Cyrillic, Greek), use the ANSI V key code: macOS matches shortcuts by QWERTY position there.
  Read the layout on the main thread: TIS asserts the main queue on macOS 14+ (Grip learned this).
- Secure fields refuse synthetic paste.
  Check secure input before pasting, and keep the text in the HUD with a Copy button.
- Where the app exposes it through Accessibility, read the text before the cursor to fix spacing and capitals: no capital mid-sentence, a space after a word, none after an opening bracket or at a line start.
  Apps that expose nothing get the text as transcribed.
- One ⌘Z undoes a whole dictation.
- The menu offers the last dictation to copy or paste again, kept in memory only.

Done when dictation lands right in TextEdit, Safari, Chrome, Slack, VS Code, and Terminal, a password field refuses it gracefully, QWERTY, Dvorak, and Russian layouts all work, and the clipboard is unchanged afterwards.
