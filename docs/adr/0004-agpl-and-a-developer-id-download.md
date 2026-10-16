# 0004 - AGPL-3.0, shipped as a Developer ID download

Status: accepted

## Context

Most dictation apps are closed source; Tony is open source, like its sibling Grip (`AGENTS.md`, Product).
The AGPL keeps every fork open, including one that runs as a service.
The Mac App Store's terms conflict with the AGPL.

## Decision

- Tony is `AGPL-3.0-only` (`LICENSE`).
- Every dependency, copied snippet, and model has a license compatible with the AGPL; models must also allow commercial use and redistribution.
- Tony ships as a Developer ID signed, notarized download that updates itself (ADR 0005), never through the Mac App Store.
- About shows the copyright, the no-warranty notice, the license, a link to the source, and credits for Parakeet, Parakeet CTC 110M, Silero VAD, FluidAudio, and Sparkle.
- A server written for Tony is AGPL too, lives in this repo, and offers its source to its users.

## Consequences

- Anyone can read, build, and fork Tony, and must keep their fork open.
- Distribution, signing, and updates are Tony's job rather than Apple's.
- Adding a dependency starts with checking its license.
- Nothing enforces license compatibility automatically.
