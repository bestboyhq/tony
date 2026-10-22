---
title: Private, offline speech to text on your Mac
nav: Privacy and offline use
description: Tony transcribes on your Mac's Neural Engine. Audio stays in memory and never leaves the Mac, there is no account and no telemetry, and dictation works offline.
---

Tony is on-device voice typing.
Your voice is transcribed on your Mac's Neural Engine, not on a server, so it works offline and nobody else hears what you say.

## What stays on your Mac

- **Your audio.** It stays in memory while Tony transcribes it, and it is never written to disk.
- **Your text.** It goes to the app you are typing in, through the clipboard, and nowhere else.
  The last dictation waits in memory for the menu bar panel's Copy and Paste.
- **Your clipboard.** Tony puts each dictation on this Mac's clipboard only, so Universal Clipboard doesn't hand it to your other devices.
- **Your stats.** Counts by day and by app, kept in one small file on your Mac, `stats.json` in `~/Library/Application Support/Tony`.
  Never what you said.
- **Your settings and your words.** In Tony's preferences on your Mac.

There is no account and no telemetry.
Tony sends no analytics, no crash reports, and no usage data.

## When Tony goes online

Tony goes online for three things only:

1. **The speech model, once.** Parakeet Ultra, about 600 MB, from Hugging Face on first launch.
2. **The model for your words, once.** Parakeet CTC 110M, about 100 MB, the first time you add [your words](/tony/docs/your-words.md).
3. **Update checks.** Tony reads its update feed on GitHub Releases at launch, every four hours, and when your Mac wakes.

Once the models are on your Mac, dictation needs no connection at all.
Turn off Wi-Fi and Tony keeps typing.

## Only while you hold the key

The microphone opens when your key goes down and closes when you let go, so the orange dot in the menu bar shows only while Tony listens.
Between dictations the mic is closed and the CPU rests.
Tony's microphone prompt says it plainly: "Tony hears you only while you hold the dictation key. Audio stays on this Mac."

## Open source, so you can check

Tony is free and open source under [AGPL-3.0](https://github.com/bestboyhq/tony/blob/main/LICENSE).
Every release is built by CI from a tagged commit, so the code behind each download is public on [GitHub](https://github.com/bestboyhq/tony).
Tony's [architecture decisions](https://github.com/bestboyhq/tony/tree/main/docs/adr) are written down, including the one that keeps it local-only and private.

## Related

- [Speed and accuracy](/tony/docs/speed-and-accuracy.md): what running on device costs, which is nothing.
- [Install and permissions](/tony/docs/install.md): why Tony asks for the microphone and Accessibility.
- [FAQ](/tony/docs/faq.md)
