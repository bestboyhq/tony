---
title: Frequently asked questions
nav: FAQ
description: Answers about Tony, the free dictation app for Mac - price, privacy, offline use, languages, accuracy, the apps it types into, and what it needs to run.
---

## Is Tony free?

Yes.
Tony is free and open source under AGPL-3.0, with no account and no subscription.

## Can I dictate prompts to AI agents like Claude Code or Codex?

Yes.
Tony pastes where your cursor is, so a prompt lands in your agent in the terminal, in your editor, or in any chat box.
Double-tap your key for a long brief, and add your project's names under Your words.
See [Prompting AI agents](/tony/docs/ai-agents.md).

## Does Tony work offline?

Yes.
Tony downloads its speech model once, about 600 MB, and from then on it transcribes on your Mac with no connection.
It goes online only for that download, the model for your words if you add any, and update checks.
See [Privacy and offline use](/tony/docs/privacy.md).

## Does my voice leave my Mac?

No.
Audio stays in memory on your Mac and is never written to disk, and there is no account and no telemetry.
Tony's stats are counts, never what you said.

## Which Macs does Tony run on?

Macs with Apple silicon on macOS 15 or later.
The speech model runs on the Neural Engine, which Intel Macs don't have.

## Which languages does Tony speak?

25 European languages, detected as you speak: Bulgarian, Croatian, Czech, Danish, Dutch, English, Estonian, Finnish, French, German, Greek, Hungarian, Italian, Latvian, Lithuanian, Maltese, Polish, Portuguese, Romanian, Russian, Slovak, Slovenian, Spanish, Swedish, and Ukrainian.
See [Languages](/tony/docs/languages.md).

## How accurate is it?

Tony runs Parakeet Ultra, with a 5.8% word error rate across the Open ASR Leaderboard's English sets, against 7.44% for Whisper large-v3.
See [Speed and accuracy](/tony/docs/speed-and-accuracy.md).

## How fast is it?

About 50 ms for a sentence, and 147 ms for 26 seconds of talk, on a MacBook Pro with M5 Pro.
Long dictations transcribe in the background at each pause while you talk, so letting go is as quick after five minutes as after one sentence.

## Which apps can I dictate into?

Any app that takes paste: native apps, Safari and Chrome, Slack and VS Code, Terminal.
Tony pastes with ⌘V, on QWERTY, Dvorak, and Cyrillic layouts alike.

## What if the text can't be typed?

Every dictation stays on your clipboard, so when a paste can't land, in a password field or an app that refuses paste, ⌘V brings it back.
Your last dictation also waits in the menu bar panel to copy or paste again.

## Which key do I hold?

fn, until you pick another: right ⌥, right ⌘, or any other modifier, in [Settings](/tony/docs/settings.md).
Double-tap it for hands-free, and press Esc to cancel.

## Can Tony spell names and jargon?

Yes.
Add them under Your words, and "super base" lands as Supabase.
See [Your words](/tony/docs/your-words.md).

## Does Tony remove "um" and "uh"?

Yes.
Filler words come out, and the sentence around them keeps its commas and capitals.

## What happens to my music while I talk?

It fades out when you press the key and back in after you let go.
On macOS 15.4 and later, the song or video playing pauses once it's quiet and plays on from the same spot, and music you had off stays off.

## How does Tony update?

It updates itself from GitHub Releases, checking quietly at launch, every four hours, and when your Mac wakes.
When an update is ready, Restart installs it in a few seconds, and it waits until you finish talking.

## Can I read the code?

Yes, on [GitHub](https://github.com/bestboyhq/tony).
Every release is built by CI from a tagged commit, and issues and pull requests are welcome.
