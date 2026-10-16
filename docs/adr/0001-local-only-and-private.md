# 0001 - Local only and private

Status: accepted

## Context

A dictation app hears everything the user says and reads what they write.
Cloud dictation apps wait on a server for every dictation and keep what they hear.
Tony promises that audio and text stay on the Mac, with no account and no telemetry (`AGENTS.md`, Private).
Apple silicon's Neural Engine runs a strong speech model locally, fast enough to land text about 100 ms after key up (ADR 0003).

## Decision

- No backend, no account, no telemetry.
- Audio stays in memory: the mic feeds `Session` through an `AsyncStream`, and nothing writes samples to disk.
- The last dictation lives only in memory (`Dictation.lastText`), for the menu bar panel to copy or paste again.
- Stats are counts by day and by app in `~/Library/Application Support/Tony/stats.json`, never what was said.
- Tony goes online for three things only: the speech model's one-time download, the model for the user's words once they add some, and Sparkle's update checks (ADR 0005).

## Consequences

- Dictation works offline once the models are on the Mac, and nothing the user says reaches a server Tony runs.
- Tony has no crash reports or usage data to learn from; bugs arrive as user reports.
- A new outbound call is a new decision: it needs its own ADR and an update to `AGENTS.md`.
- Nothing enforces this automatically.
