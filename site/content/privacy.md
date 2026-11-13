---
title: Private, offline speech to text on your Mac
nav: Privacy and offline use
description: Tony transcribes on your Mac's Neural Engine. Audio and text never leave the Mac, there is no account, dictation works offline, and usage stats hold none of your words.
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

There is no account, and crash reports stay on your Mac.

## Usage stats

Tony shares usage stats, like a finished dictation and how long it was, so we see what to make better.
Never what you say or type, and never which app.
Onboarding says so, under "Meet Tony".
Turn it off in [Settings](/tony/docs/settings.md#share-usage-stats): Tony sends one last stat saying so, and then nothing.
Set `DO_NOT_TRACK=1` in Tony's environment, and it sends nothing at all.
They are not your stats in the menu bar, which stay on your Mac.

Each stat is one event, with numbers, yes-or-no flags, and Tony's own names only:

- **Tony launched**, and whether you have finished onboarding.
- **Onboarding closed**, the step it ended on, and whether the practice field had text.
- **The speech model downloaded**, and how long that took.
- **A dictation finished**: the seconds you spoke, the word count rounded down to one digit (14 words count as 10), the time from key up to text, and whether it was hands-free.
- **Your words added**: how many you have, never which.
- **Your key changed**, and its name, like Right ⌥.
- **Usage stats turned off**, once, as you turn it off, with nothing else.
- **Your first days with Tony**, each once: the first open, each onboarding step you reach and the seconds since the first, onboarding closed, your first dictation, and coming back within a week or a month.
  Each carries the day of your first open and how many days have passed since.
- **A day you used Tony**, once a day: whether it is your first that week or that month, and how long you have had Tony, like "first week".
- **A month you used Tony**, once, early in the next one: the month and on how many days.

Never sent: what you say or type, your audio, which app the text went to, your words, your mic's name, or any file path or name.

The stats go to bestboy.dev with Tony's version, your IP address, and a User-Agent naming Tony and macOS, and no account or ID.
bestboy.dev passes them on to Logdash, which turns the address into a visitor that changes every day: it counts events and people per day, and follows nobody.

## When Tony goes online

Tony goes online for four things only:

1. **The speech model, once.** Parakeet Ultra, about 600 MB, from Hugging Face on first launch.
2. **The model for your words, once.** Parakeet CTC 110M, about 100 MB, the first time you add [your words](/tony/docs/your-words.md).
3. **Update checks.** Tony reads its update feed on GitHub Releases at launch, every four hours, and when your Mac wakes.
4. **Usage stats.** One small call to bestboy.dev as each one happens, unless you turn it off in Settings.

Once the models are on your Mac, dictation needs no connection at all.
Turn off Wi-Fi and Tony keeps typing; a stat made offline is dropped, except your first days with Tony, which wait for the next launch or dictation.

## This website

This site counts page views and clicks on its Download buttons, never who you are.
Your browser sends them to bestboy.dev, which passes them on to Logdash with your IP address and User-Agent, the same way as Tony's usage stats.
The site sets no cookies.

## Only while you hold the key

The microphone opens when your key goes down and closes when you let go, so the orange dot in the menu bar shows only while Tony listens.
Between dictations the mic is closed and the CPU rests.
Tony's microphone prompt says it plainly: "Tony hears you only while you hold the dictation key. Audio stays on this Mac."

## Open source, so you can check

Tony is free and open source under [AGPL-3.0](https://github.com/bestboyhq/tony/blob/main/LICENSE).
Every release is built by CI from a tagged commit, so the code behind each download is public on [GitHub](https://github.com/bestboyhq/tony).
Tony's [architecture decisions](https://github.com/bestboyhq/tony/tree/main/docs/adr) are written down, including the one that keeps it private and lists what it counts.

## Related

- [Speed and accuracy](/tony/docs/speed-and-accuracy.md): what running on device costs, which is nothing.
- [Install and permissions](/tony/docs/install.md): why Tony asks for the microphone and Accessibility.
- [FAQ](/tony/docs/faq.md)
