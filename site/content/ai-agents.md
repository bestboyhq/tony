---
title: Dictate prompts to your AI agents, like Claude Code and Codex
nav: Prompting AI agents
description: Speak your prompt instead of typing it. Tony pastes it into Claude Code, Codex, your editor's agent, or any chat box, with your project's names spelled right, on your Mac.
---

A good prompt carries context: what you tried, what broke, what you want next.
Saying it is quicker than typing it, and Tony puts what you said where your cursor is.
Hold a key, talk to your agent, and let go.

## Where it works

Tony pastes, so your prompt lands with any agent that takes paste:

- **A coding agent in your terminal**, like Claude Code or Codex, in Terminal or any terminal app.
- **Your editor**, like VS Code, and the agent chat inside it.
- **Any chat box** in a browser or a native app.
- **[Malini](https://bestboy.dev/malini)**, which runs many Claude Code agents side by side, each in its own git worktree.

Tony pastes and stops: you read the prompt, then press Return yourself.

## Short prompt, long brief

- **Hold fn** for a quick instruction: "Run the tests again and fix what fails."
- **Double-tap fn** for a long brief, and talk as long as you like, with your hands free.
  Tap fn again to finish.
  Tony transcribes in the background at each pause, so even a five-minute brief lands the moment you finish.
- **Esc** cancels without typing, and keeps what you said as your last dictation in the [menu bar panel](/tony/docs/menu-bar.md), one click from Paste.
- **Back to back.** Press the key again while your last prompt is still landing: it lands first, and the next one follows it.

## Your stack, spelled right

Agents need the exact names: the library, the service, the table.
Add them under [Your words](/tony/docs/your-words.md), and Tony writes them your way: "super base" lands as Supabase.
A second, small model checks each one against your voice, so a word swaps in only where you said it.

## Clean text, where the cursor is

- **No "um".** Filler words come out, and the sentence keeps its commas and capitals.
  You say "Um, so the super base migration fails. Can you, uh, check the policies?", and with Supabase in your words, Tony types "So the Supabase migration fails. Can you check the policies?"
- **Fits the cursor.** Dictate into the middle of a prompt you are editing and Tony leaves out the capital, adds a space after a word, and none after an opening bracket.
- **Undo is one ⌘Z.** A prompt lands as a single paste.

## When the terminal won't take it

Terminal's Secure Keyboard Entry, and a password manager that left secure input on, hide keys from every app and block paste.
Tony says which app holds secure input, and your prompt waits on the clipboard for ⌘V.

## Your prompts stay yours

Prompts carry your codebase's names and your half-formed ideas.
Tony hears them on your Mac's Neural Engine, keeps the audio in memory, and sends them nowhere: the only place your prompt goes is the app you paste it into.
See [Privacy and offline use](/tony/docs/privacy.md).

## Grip, Tony, and Malini

Tony is a Bestboy app, like its siblings:

- **[Grip](https://bestboy.dev/grip)**, the free and open source screen recorder, shows what you mean.
- **Tony** says it.
- **[Malini](https://bestboy.dev/malini)** runs many Claude Code agents side by side and takes each one to a merged pull request.

Show it with Grip. Say it with Tony. Ship it with Malini.

## Related

- [Install and permissions](/tony/docs/install.md)
- [Settings](/tony/docs/settings.md): pick the key you hold to talk.
- [Speed and accuracy](/tony/docs/speed-and-accuracy.md)
