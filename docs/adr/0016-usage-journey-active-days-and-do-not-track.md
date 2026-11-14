# 0016 - Usage counts add the install journey and active days, sent once each

Status: superseded by 0017

## Context

ADR 0013 counts what Tony does, but the counts cannot show how many installs reach a first dictation, where onboarding loses people, or who comes back.
Malini's Logdash dashboard on bestboy.dev answers those questions from journey markers, active days, and active months (`apps/malini/src/lib/app/platform/usage-data.ts` in `bestboyhq/malini`), and the owner wants Tony's dashboard to match it event for event.
A journey marker counts only when it arrives exactly once, so the 0013 rule that a failed count is dropped is wrong for markers.
Malini also respects `DO_NOT_TRACK`, and Tony did not.
Everything else in 0013 still holds, and this record restates it, so a reader needs only this one.

## Decision

- No backend of Tony's own and no account: the only server Tony talks to besides Hugging Face and GitHub is the Bestboy platform's relay, `POST https://bestboy.dev/api/events`, which passes each event to Logdash, so Tony holds no key.
  Logdash counts events and daily unique people from the caller's IP address and User-Agent, follows nobody, and drops a script's User-Agent.
- Audio stays in memory: the mic feeds `Session` through an `AsyncStream`, and nothing writes samples to disk.
- Audio and text never leave the Mac.
  The last dictation lives only in memory (`Dictation.lastText`), for the menu bar panel to copy or paste again.
- Stats are counts by day and by app in `~/Library/Application Support/Tony/stats.json`, never what was said, and they stay on the Mac.
- Tony goes online for four things only: the speech model's one-time download, the model for the user's words once they add some, Sparkle's update checks (ADR 0005), and usage counts.
- `Usage.request` (`Sources/Tony/Shell/Usage.swift`) builds each call: `{ "app": "tony", "version": "<version>", "events": [{ "name": "tony_<event>", "props": { … } }] }`, with the User-Agent `Tony/<version> (Macintosh; Mac OS X <macOS version>)`, from an ephemeral `URLSession` with no cookies, no auth, and a 5 s timeout.
- `Usage.count` sends a count as it happens and never waits; a failed or slow call is dropped:
  - `tony_launched`: `onboarded`.
  - `tony_onboarding_finished`: the `step` it ended on, and `practiced`, whether the practice field had text.
  - `tony_model_downloaded`: `seconds` from the start of the download to the model ready.
  - `tony_dictation_finished`: `seconds` spoken, rounded; `words`, rounded down to one significant digit; `latency_ms`, key up to text in tens of milliseconds; and `hands_free`.
  - `tony_words_added`: `count`, how many words the user has.
  - `tony_hotkey_changed`: `key`, the key's name, like `Right ⌥`.
  - `tony_stats_off`: no props, sent once as the switch turns off.
- `Journey` (`Usage.journey`, in the same file) sends Malini's journey, day, and month events, each once.
  It stores an event as sent in `UserDefaults` only after the relay answers 2xx; a marker that fails waits in `usagePending` with the props it had when it happened, and goes again at the next launch or dictation.
  - A fresh install is a Mac with an empty `com.bestboyhq.tony` preferences domain at launch, checked before anything writes one and before the move to Applications.
    It stores `usageFirstOpen`, the local `YYYY-MM-DD` of that launch: the `cohort`.
    An install that had data before this change has no cohort, and sends no journey marker.
  - Every journey marker carries `cohort` and `days`, whole local days since the first open:
    `tony_first_open`; `tony_setup_<step>` for each onboarding step the user reaches, from `OnboardingView.Step` (`key`, `microphone`, `accessibility`, `model`, `words`, `practice`), with `setup_seconds` since the first step; `tony_setup_finished`, with `setup_seconds`, when the onboarding window closes; `tony_first_dictation`; `tony_returned_week_1` at a launch or dictation 1 to 7 days after the first open; and `tony_returned_month_1` at one 8 to 30 days after.
  - `tony_day`, once per local day with a launch or a dictation: `week_first`, `yes` on the first active day of the ISO week (Monday first); `month_first`, `yes` on the first of the month; and `age`, `day_1`, `week_1`, `month_1`, or `later` at 0, 1 to 6, 7 to 29, and 30 or more days since the first open, `later` without one.
  - `tony_month`, once, in the first active day of a new month, for the last earlier month with an active day: `month`, `YYYY-MM`, and `active_days`.
- Never sent: what was said or typed, audio, which app the text went to, the user's words, a device's name, or any path or name.
- Only the switch and `DO_NOT_TRACK` decide whether anything is sent: there is no terms or account gate.
  `Prefs.usageCounts` is true until the user turns off Share usage stats in Settings, and `DO_NOT_TRACK` set to anything but empty, `0`, or `false` turns counts off the same way.
  `Usage.share` sends `tony_stats_off` before it flips the switch.
  While counts are off, `Journey` notes nothing, so turning them back on sends nothing from that time, and asks nothing.
- Said, not asked, at the end of the description under "Meet Tony", which onboarding shows on every step: "Tony shares usage stats, never what you say or type. Turn it off in Settings."
- A development build (version 0.0.0) sends only to `TONY_EVENTS_URL`, a local stand-in for the relay, and nothing without it.

## Consequences

- The owner sees Tony's install journey, onboarding funnel, first dictation, return, and active days and months on the same dashboard as Malini's.
- The relay answers 204 for any well-formed call and passes it to Logdash without waiting, so "sent" means the relay took it, not that Logdash stored it.
- A count made offline is still lost; a journey marker waits for the next launch or dictation instead, and a day or month goes at the next active day.
- The preferences domain grows by a few `usage*` keys, and an install that loses its preferences counts as a fresh install again.
- Dictation still works offline once the models are on the Mac, and nothing the user says or types reaches a server.
- A new outbound call, event, or prop is a new decision: it needs its own ADR, an update to `AGENTS.md`, and the privacy page on the site.
- `UsageTests` in `Tests/TonyTests/TonyTests.swift` fails when an event is sent while the switch is off, when turning it off sends no `tony_stats_off` or turning it on sends one, when a dictation's or the user's words' event carries a string or a word of what was said, or when a journey marker goes twice, is lost after a failed call, loses its cohort or days, or `tony_day` misreads the week, the month, or the age.
  Nothing checks the props of the other events; each is one line at its call site.
