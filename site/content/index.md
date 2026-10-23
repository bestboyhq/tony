---
title: How Tony works
nav: How Tony works
description: Tony is free, open source dictation for the Mac. Hold a key, speak, and let go, and your words land where the cursor is, in any app, transcribed on your Mac.
---

Tony is a menu bar app for the Mac that turns your voice into text where the cursor is.
Hold a key, speak, and let go: a message, a note, or a prompt for your AI agent.
Tony transcribes on your Mac's Neural Engine with Parakeet Ultra, one of the most accurate open speech models there is, and types the result into whatever app you are in.
A sentence takes about 50 ms, and your voice never leaves the Mac.

Tony is free and open source under AGPL-3.0, with no account and no telemetry.
It needs macOS 15 or later on Apple silicon.

## Hold a key, speak, let go

| Key | What it does |
| --- | --- |
| Hold **fn** | Dictate, and let go to type it |
| Double-tap **fn** | Hands-free: talk as long as you like, tap again to finish |
| **Esc** | Cancel, nothing is typed |

fn is the key until you pick another one: right ⌥, right ⌘, or any other modifier.
A tap too short to hold a word types nothing, and pressing another key with yours, like a shortcut, lets the shortcut through.
Esc keeps what you said as your last dictation in the menu bar panel, so a cancel by habit costs you no words.
See [Settings](/tony/docs/settings.md) to change the key.

## What happens to your words

1. **Your key goes down.** Listening starts at once, so your first word counts.
   Other audio fades out, so neither you nor the mic hears it.
2. **You speak.** Silero voice activity detection follows your voice, and Tony trims the silence around it, so a quiet room never turns into a phantom sentence.
   Tony transcribes in the background at each pause while you keep talking.
3. **You let go.** Parakeet Ultra writes the text with punctuation and capitals.
   If you added [your words](/tony/docs/your-words.md), Parakeet CTC 110M listens for them in the same audio.
4. **Tony fits it to the cursor.** Filler words come out, and Tony reads the text before the cursor: a space after a word, none after an opening bracket, and no capital in the middle of a sentence.
5. **It lands.** Tony puts the text on the clipboard and presses ⌘V, so one ⌘Z undoes the whole dictation.

```
fn down → event tap → other audio fades, media pauses
        → AVAudioEngine, 16 kHz → Silero VAD
        → Parakeet Ultra and Parakeet CTC 110M on the Neural Engine
        → fillers out, fit to the cursor → clipboard → ⌘V
```

## Works in every app

- **Every app.** Native apps, Safari and Chrome, Slack and VS Code, Terminal: if it takes paste, it takes Tony.
- **Every layout.** QWERTY, Dvorak, and Cyrillic layouts all paste correctly.
- **Every word survives.** Every dictation stays on your clipboard, so when a paste can't land (a password field, no text field, an app that refuses paste), ⌘V brings it back.
  Your last dictation also waits in the [menu bar panel](/tony/docs/menu-bar.md) to paste again.
- **Back to back.** Press the key again while your last dictation is still landing: it lands first, and the new one follows it.
- **Quit without losing a word.** Quitting mid-dictation types it first.
- **Unplug mid-sentence, keep the sentence.** When your mic goes away while you talk, Tony types what it heard.

## Out of your way

- **The pill.** While you talk, a small pill floats at the bottom of your screen, over full-screen apps and on every Space.
  Nine bars follow your voice, and the dot, Tony's blue-to-orange mark, swells as you speak.
  It never takes focus or a click from the app beneath it.
- **Your music waits while you talk.** Other audio fades out the moment you press the key and back in after you let go.
  On macOS 15.4 and later, the song or video playing pauses once it's quiet and plays on from the same spot, and music you had off stays off.
- **Your AirPods keep sounding good.** Tony prefers the built-in mic, since opening an AirPods mic drops your music to phone-call quality.
- **Problems in plain words.** A closed lid, a muted mic, an app holding secure input, or a Tony moved while running gets one plain sentence and, where it helps, a button that fixes it.
- **Plays by your settings.** Light and dark, Reduce Motion, Reduce Transparency, Increase Contrast, and VoiceOver, which hears when Tony listens, types, or cancels.

## Read on

- [Install and permissions](/tony/docs/install.md): download Tony, allow the microphone and Accessibility, and dictate for the first time.
- [Prompting AI agents](/tony/docs/ai-agents.md): talk to Claude Code, Codex, or any agent in your terminal, your editor, or a chat box.
- [Privacy and offline use](/tony/docs/privacy.md): what stays on your Mac, and the three times Tony goes online.
- [Languages](/tony/docs/languages.md): the 25 languages Tony speaks, and switching between them mid-dictation.
- [Your words](/tony/docs/your-words.md): names, brands, and jargon, spelled your way.
- [Speed and accuracy](/tony/docs/speed-and-accuracy.md): how fast Tony transcribes, and how often it gets a word wrong.
- [Menu bar panel and stats](/tony/docs/menu-bar.md): your last dictation, words dictated, and time saved.
- [Settings](/tony/docs/settings.md): the key, the mic, the languages, and your words.
- [FAQ](/tony/docs/faq.md): short answers to common questions.

## For agents reading this

Every page of these docs is plain markdown at its URL plus `.md`.
[llms.txt](https://bestboy.dev/tony/llms.txt) lists every page, and [llms-full.txt](https://bestboy.dev/tony/llms-full.txt) holds all of them in one file.
