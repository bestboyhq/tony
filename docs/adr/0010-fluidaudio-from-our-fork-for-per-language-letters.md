# 0010 - FluidAudio from our fork, for per-language letters

Status: accepted

## Context

With Polish and English picked, the user still got words "by some random language".
Parakeet picks its language per clip, and where the audio is unclear it drifts into another language of the same alphabet: FLEURS Polish under pink noise came out with Czech "pořád", Hungarian "részünk", and whole Lithuanian sentences.
FluidAudio's language hint filtered the decoder's tokens by alphabet only, so Latin letters of any language passed, and it took one language, so Tony could not say Polish and German, or Polish and Ukrainian.
Its filter is internal to FluidAudio, and its documentation planned per-language letters at that same spot.
ADR 0003 runs speech through FluidAudio, and ADR 0004 requires dependencies whose license fits the AGPL; FluidAudio is Apache-2.0.

## Decision

- `bestboyhq/FluidAudio`, a fork of `FluidInference/FluidAudio`, gives each Latin-script language its letters (`Language.letters`), and adds `AsrManager.transcribe(_:decoderState:languages:)`, which keeps the decoder's tokens to the letters of any of a set of languages, ASCII always included.
- `Package.swift` pins the fork by revision.
- `Session` passes the user's languages as they are; `Speech.hint`, which picked one of them, is gone.
- The same change is proposed to `FluidInference/FluidAudio`.
  Once a FluidAudio release has it, Tony goes back to `FluidInference/FluidAudio` with `from:`, and an ADR supersedes this one.

## Consequences

- No word lands in letters that none of the user's languages write, and languages in two alphabets keep both instead of leaving Parakeet free.
- A drifted word is still wrong, only now in the user's letters: on FLEURS the word error rate stayed the same.
- Tony runs FluidAudio's `main` past 0.17.7 until a release, and updating FluidAudio means updating the fork first.
- FluidAudio's `TokenLanguageFilterTests` check the letters in the fork; in Tony, only the compiler checks that the fork is there, since `languages:` exists nowhere else.
