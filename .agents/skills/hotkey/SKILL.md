---
name: hotkey
description: The global push-to-talk key. Use when changing the event tap, the hotkey choice, hold and hands-free modes, cancel, or behavior under secure input.
---

# Hotkey

The global key that starts and stops dictation.

- Hold to talk, release to insert.
  A double tap locks hands-free mode until the next tap, and Esc cancels any dictation without inserting.
- A tap too short to hold a word is an accident: insert nothing.
- The default hotkey is a modifier on its own (fn, right ⌥, right ⌘), since it types nothing.
  Only a modifier pressed and released alone starts dictation; a chord typed while it is held (⌥←, ⌘C) cancels it.
- The fn (Globe) key also runs the system action set under Keyboard > "Press 🌐 key to": emoji, input source, or Apple Dictation.
  When fn is the hotkey, read `AppleFnUsageType` in `com.apple.HIToolbox` and offer to set it to Do Nothing.
- Use an active event tap: it needs only Accessibility, which pasting needs anyway, so onboarding asks for two permissions instead of three.
  A listen-only tap would add Input Monitoring.
- The tap runs on its own thread, and its callback only compares flags and dispatches.
  An active tap sits in front of every keystroke on the Mac: a slow callback lags all typing, and macOS then disables the tap.
  Re-enable it on `tapDisabledByTimeout` and `tapDisabledByUserInput`, and recreate it after wake and after a permission change.
- Secure input (a focused password field, Terminal's Secure Keyboard Entry, a password manager that leaves it stuck on) can hide key events from the tap and blocks synthetic paste.
  Detect it with `IsSecureEventInputEnabled()`, name the app holding it (`kCGSSessionSecureInputPID` in the IORegistry), and say so in the HUD.
- Recording a new hotkey in Settings captures the key the user presses and flags a clash with a system shortcut.

Done when the key works within one frame after login, sleep, a permission change, and an hour of fast typing, and fires only when pressed alone.
