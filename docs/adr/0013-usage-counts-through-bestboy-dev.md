# 0013 - Usage counts through bestboy.dev, on unless turned off

Status: superseded by 0015

## Context

ADR 0001 kept Tony free of telemetry, so its owner cannot tell whether people use Tony, or how much, day by day.
He decided to count usage, on by default, like Grip and Malini, the other Bestboy apps.
The legal basis is legitimate interest: Tony says that it shares usage stats, and a switch in Settings is the way to object.
A page of its own to say so, as Grip first had, is far too big for it.
The Bestboy platform relays app events to Logdash at `POST https://bestboy.dev/api/events`, with no auth, so an app talks only to bestboy.dev and holds no key.
Logdash counts events and daily unique people from the caller's IP address and User-Agent, follows nobody, drops a script's User-Agent, and drops stale timestamps.
What 0001 promised about audio and text still holds, and this record restates it, so a reader needs only this one.

## Decision

- No backend of Tony's own and no account: the only server Tony talks to besides Hugging Face and GitHub is the platform's relay.
- Audio stays in memory: the mic feeds `Session` through an `AsyncStream`, and nothing writes samples to disk.
- Audio and text never leave the Mac.
  The last dictation lives only in memory (`Dictation.lastText`), for the menu bar panel to copy or paste again.
- Stats are counts by day and by app in `~/Library/Application Support/Tony/stats.json`, never what was said, and they stay on the Mac.
- Tony goes online for four things only: the speech model's one-time download, the model for the user's words once they add some, Sparkle's update checks (ADR 0005), and usage counts.
- `Usage.count` (`Sources/Tony/Shell/Usage.swift`) sends each event on its own as it happens: `{ "app": "tony", "version": "<version>", "events": [{ "name": "tony_<event>", "props": { … } }] }`, with the User-Agent `Tony/<version> (Macintosh; Mac OS X <macOS version>)`, from an ephemeral `URLSession` with no cookies, no auth, and a 5 s timeout.
  A failed or slow call is dropped, and the call never waits, so counting never delays or breaks a dictation.
- Seven events, with only counts, flags, and Tony's own names in their props:
  - `tony_launched`: `onboarded`.
  - `tony_onboarding_finished`: the `step` it ended on, and `practiced`, whether the practice field had text.
  - `tony_model_downloaded`: `seconds` from the start of the download to the model ready.
  - `tony_dictation_finished`: `seconds` spoken, rounded; `words`, rounded down to one significant digit; `latency_ms`, key up to text in tens of milliseconds; and `hands_free`.
  - `tony_words_added`: `count`, how many words the user has.
  - `tony_hotkey_changed`: `key`, the key's name, like `Right ⌥`.
  - `tony_stats_off`: no props, sent once as the switch turns off, so the numbers know how many people they leave out.
- Never sent: what was said or typed, audio, which app the text went to, the user's words, a device's name, or any path or name.
- On until turned off: `Prefs.usageCounts` is true until the user turns off Share usage stats in Settings.
  `Usage.share` sends `tony_stats_off` before it flips the switch, and nothing is sent while it is off.
  Turning it back on sends nothing extra and asks nothing.
- Said, not asked, at the end of the description under "Meet Tony", which onboarding shows on every step: "Hold fn, speak, and let go. Your words land where the cursor is. Tony shares usage stats, never what you say or type. Turn it off in Settings."
  It is part of the existing design, one sentence per line like the rest: no page, window, heading, button, or fine print of its own.
  Whoever onboarded before sees nothing new; the switch and the privacy page cover them.
- A development build (version 0.0.0) sends only to `TONY_EVENTS_URL`, a local stand-in for the relay, and nothing without it.

## Consequences

- The owner sees adoption (launches, onboarding, model downloads) and depth (dictations, their length and speed, the user's words, the key) by day, and the speed of real dictations on real Macs.
- Dictation still works offline once the models are on the Mac, and nothing the user says or types reaches a server.
- A count made offline is lost; Logdash would drop it once stale anyway.
- Crash reports still stay on disk; bugs arrive as user reports.
- A new outbound call, event, or prop is a new decision: it needs its own ADR, an update to `AGENTS.md`, and the privacy page on the site.
- `UsageTests` in `Tests/TonyTests/TonyTests.swift` fails when an event is sent while the switch is off, when turning it off sends no `tony_stats_off` or turning it on sends one, or when a dictation's or the user's words' event carries a string, a word of what was said, or one of the user's words.
  Nothing checks the props of the other events; each is one line at its call site.
- The relay accepting `tony` lives in `bestboyhq/platform`; until it ships, the relay answers 400 and the counts are lost.
