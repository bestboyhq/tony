---
title: Install Tony and allow its permissions
nav: Install and permissions
description: Download Tony, the free dictation app for Mac, allow the microphone and Accessibility, and dictate your first sentence in about a minute.
---

## Requirements

- macOS 15 or later.
- A Mac with Apple silicon: the speech model runs on its Neural Engine.
- Room for the speech model, about 600 MB, which downloads once on first launch.

## Install

1. [Download Tony](https://github.com/bestboyhq/tony/releases/latest), open the disk image, and drag Tony to Applications.
   Open it from the disk image or Downloads instead, and Tony offers to move itself there, since it can only update itself from the Applications folder.
2. Open it.
   Tony asks which key you'll hold, then for the microphone and Accessibility, one at a time, while the speech model downloads.
   Add your words now or later.
3. Hold your key and say something into the practice field.
   That's it.

Tony lives in the menu bar, opens at login, and updates itself.

## First launch, step by step

Tony's welcome window shows one step at a time, and the first one left is open.

1. **Your key.** Pick the key you'll hold to talk: fn, right ⌥, right ⌘, or any other modifier (pick Other… and press it).
2. **Microphone.** So Tony hears you while you hold the key.
   Click Allow, and macOS asks once.
3. **Accessibility.** So Tony notices the key and types for you.
   Click Allow, then turn on Tony in the list.
   While System Settings is open, a tile under its window holds Tony, so you can drag it into the list.
4. **Speech model.** It runs on this Mac, and your voice never leaves it.
   The download shows its progress and the time left, then Tony prepares the model for your Mac's Neural Engine.
5. **Your words.** Names, brands, and jargon, spelled your way.
   Optional, and [Settings](/tony/docs/settings.md) has them later.
6. **Try it.** Hold your key, say "Hello, Tony," and let go.
   Your first dictation lands in the practice field.

Open Tony at login is on unless you turn it off at the bottom of the window.
You can close the window before the model is ready: the menu bar icon fills a ring around itself while it downloads.

## Permissions Tony asks for

| Permission | Why Tony needs it | Where to turn it on |
| --- | --- | --- |
| Microphone | To hear you while you hold the key | System Settings > Privacy & Security > Microphone |
| Accessibility | To notice the key from any app, and to press ⌘V for you | System Settings > Privacy & Security > Accessibility |

The mic opens only while you dictate, so the orange dot in the menu bar shows only then.
Accessibility also lets Tony read the few characters before the cursor, to fit the spacing and capitals of what it types.
When a permission is missing, the [menu bar panel](/tony/docs/menu-bar.md) says so in one line, next to the button that fixes it.

## When fn opens the emoji picker

macOS can run its own action when you press fn, set under System Settings > Keyboard, "Press 🌐 key to".
With fn as your key, Tony warns that fn also opens Emoji & Symbols, changes the input source, or starts Apple Dictation, and its Fix button sets that option to Do Nothing.

## If something is off

- **"Relaunch Tony to finish setup."** macOS sometimes needs Tony to restart before Accessibility takes effect.
  Click Relaunch.
- **"Relaunch Tony to use the microphone."** macOS mutes the mic of an app that was moved while it runs.
  Click Relaunch.
- **"The lid is closed, so the built-in mic is off."** Open the lid, or pick another mic in [Settings](/tony/docs/settings.md).
- **The mic sends only silence.** Check that it isn't muted, or pick another one in Settings.
- **"Secure input is on, so Tony can't type there."** A password field, Terminal's Secure Keyboard Entry, or a password manager can hide keys from every app.
  Tony names the app holding it when it can, and your text waits on the clipboard for ⌘V.
- **"Tony can't download its speech model."** Check your connection and click Try Again.
  The download resumes where it stopped.

## Updates

Tony updates itself from GitHub Releases.
It checks at launch, every four hours, and when your Mac wakes, quietly, never with a window over your work.
When an update is ready, the menu bar icon wears a dot and the panel offers Restart, which installs the newest release in a few seconds.
A restart waits until you finish talking.
You can also check by hand: Check for Updates in [Settings](/tony/docs/settings.md), or right-click the menu bar icon.

## Build from source

You need macOS 15 or later on Apple silicon, Xcode 26, and Node 24.

```sh
git clone https://github.com/bestboyhq/tony && cd tony
node scripts/package.ts --debug && open release/Tony.app
```

Run the tests with `swift test` and `node --test 'scripts/*.test.ts'`.
To check a speech change without the mic or the key, `--transcribe` prints what Tony would type:

```sh
release/Tony.app/Contents/MacOS/Tony --transcribe clip.wav
```
