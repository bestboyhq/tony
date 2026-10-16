# 0006 - Paste through the clipboard, then restore it

Status: superseded by 0007

## Context

Text has to land where the cursor is in every app: native apps, browsers, Electron apps, and terminals.
Typing characters one by one is slow and fights autocomplete, and Accessibility text insertion works in native text views only.
Pasting works everywhere, but goes through the clipboard, which holds what the user copied.

## Decision

- `Paste.paste(_:)` saves every item and type on the pasteboard, writes the dictation, and posts ⌘V with the key that types "v" in the active layout.
- 600 ms later it puts the saved items back, unless `changeCount` shows the user copied something in between; slow apps (Electron, browsers) read the pasteboard after ⌘V returns.
- Tony's item is marked transient, concealed, and auto-generated (nspasteboard.org), so clipboard managers skip it.
- With secure input on, Tony doesn't paste, and the HUD offers a Copy button.
- Quitting waits for the restore.

## Consequences

- The clipboard holds what the user copied before and after every dictation.
- A paste that lands nowhere (no text field, an app that ignores ⌘V) still shows "Inserted", and the words survive only in the menu bar panel.
- An app that reads the pasteboard after 600 ms pastes the user's old clipboard instead of the dictation.
