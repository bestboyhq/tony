# Architecture decision records

Why Tony is built the way it is, one decision per file: `NNNN-kebab-title.md`, with status `accepted`, `superseded by NNNN` or `deprecated`.
A change that makes or reverses a decision writes a new record with the `adr` skill (`.agents/skills/adr`), and an accepted record is never rewritten, only superseded.

| #                                                                          | Decision                                                                                                 |
| -------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| [0001](0001-local-only-and-private.md)                                     | No backend, account, or telemetry; audio in memory; online only for model downloads and update checks    |
| [0002](0002-native-swift-and-swiftpm-only.md)                              | Swift 6, SwiftUI and AppKit, `MainActor` by default; `Package.swift` is the only project file            |
| [0003](0003-on-device-speech-with-parakeet.md)                             | Parakeet Ultra, Silero VAD, and Parakeet CTC 110M through FluidAudio on the Neural Engine                |
| [0004](0004-agpl-and-a-developer-id-download.md)                           | `AGPL-3.0-only`, shipped as a signed, notarized download, never through the Mac App Store                |
| [0005](0005-releases-from-conventional-commits-and-sparkle-updates.md)     | Conventional Commit titles pick the version; CI signs, notarizes, publishes; Sparkle updates             |
| [0006](0006-paste-through-the-clipboard-then-restore-it.md)                | Superseded by 0007: paste through the clipboard, then restore it                                         |
| [0007](0007-the-dictation-stays-on-the-clipboard.md)                       | Paste through the clipboard and leave the dictation there, so a failed paste is one ⌘V away              |
| [0008](0008-pause-now-playing-through-osascript.md)                        | Fade other audio out, then pause Now Playing through MediaRemote in `osascript`; play what it paused     |
| [0009](0009-a-prerendered-website-at-bestboy-dev-tony.md)                  | A prerendered SvelteKit site in `site/`, served by a Cloudflare Worker on `bestboy.dev/tony*`            |
| [0010](0010-fluidaudio-from-our-fork-for-per-language-letters.md)          | FluidAudio from `bestboyhq/FluidAudio`, which keeps Parakeet to the letters of the user's languages      |
| [0011](0011-trademarks-apart-from-the-agpl-and-a-cla-for-contributions.md) | Copyright with Szymon Grącki and contributors; names under `TRADEMARKS.md`, contributions under `CLA.md` |
