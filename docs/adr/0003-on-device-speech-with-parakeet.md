# 0003 - On-device speech with Parakeet on the Neural Engine

Status: accepted

## Context

Text has to land about 100 ms after key up, and audio may not leave the Mac (ADR 0001).
NVIDIA's Parakeet TDT v3 covers 25 languages at high speed, and Moondream's post-training ("Ultra") makes fewer errors.
FluidAudio runs these models through Core ML on the Neural Engine, under a license compatible with the AGPL (ADR 0004).
Parakeet degrades on several minutes of audio, and dictation can run that long.

## Decision

- Parakeet Ultra (`AsrModelVersion.ultra`) transcribes, through FluidAudio, on the Neural Engine.
- Silero VAD tracks speech, so long dictation transcribes in the background: every pause after about 30 s of talk closes a segment (`Session.swift`).
- Parakeet CTC 110M listens for the user's words, downloaded only once the user adds some.
- FluidAudio is linked without its traits, since its default trait links an 87 MB text normalizer Tony never calls.
- macOS 15 or later on Apple silicon only: `LSMinimumSystemVersion` is 15.0 and the build is `arm64`.

## Consequences

- No server, no API key, and no per-minute cost; the model waits warm between dictations.
- The first run downloads about 600 MB, and Intel Macs can't run Tony.
- Parakeet Ultra and Parakeet CTC 110M are CC-BY-4.0, so About credits them.
- A new model is a new decision with its own ADR, after checking that its license allows commercial use and redistribution.
- Nothing enforces the model choice automatically.
