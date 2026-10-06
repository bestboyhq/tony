# Agent rules

The rules in this file apply to all code in the repository.
Domain rules live in `.agents/skills/`, as plain Markdown in the Agent Skills format that belongs to no particular tool, one folder per skill.
`.claude/skills` links to it.
Each product domain has one: `hotkey`, `audio`, `speech`, `insert`, `hud`, `app-shell`.

Read the skill for the domain you are touching before changing code there.

## Product

We are building Tony, a system-wide dictation app for macOS: hold a key, speak, let go, and the text appears where the cursor is.
Most dictation apps are closed source, lack options, or look bad.
Tony is open source, fast, and beautiful.
The domain skills in `.agents/skills/` collect what dictation apps get wrong.
Their gotchas are bugs and limits that shipped in real products; design each one out from the first commit.

Tony is a bestboyhq app, a sibling of [Grip](https://github.com/bestboyhq/grip), the screen recorder.
Grip solved Developer ID signing, notarization, release automation, and in-app updates first: port its approach instead of reinventing it.

Every domain obeys these invariants:

- **Instant.** Listening starts on key down, so the first word is captured, and the text lands about 100 ms after key up.
- **Every word survives.** Text that cannot be inserted (a secure field, an app that ignores paste) stays one click away in the HUD and the menu.
- **Focus stays with the user.** The HUD and every other surface are non-activating, so the text lands in the field the user is in.
- **The clipboard is the user's.** Paste through it, then restore everything it held, unless the user copied something in between.
- **Idle is free.** Between dictations the mic is closed (no orange dot), the CPU is idle, and the model waits warm.
- **Private.** Audio and text stay on the Mac, and audio stays in memory.
  No account, no telemetry; the network is only for the one-time model download and update checks.
- **Works everywhere.** Native apps, browsers, Electron apps, and terminals, on every keyboard layout, Dvorak and Cyrillic included.
- **Beautiful.** Native look, pixel-perfect, smooth at 120 Hz, light and dark, with Reduce Motion and VoiceOver respected.
- **Options behind tuned defaults.** Tony works with zero setup.
  An option exists where people really differ (hotkey, mic, language, the user's words); everything else gets one tuned default.

## License: AGPL-3.0

Tony is `AGPL-3.0-only` (`LICENSE`), like Grip.

- Check the license before adding any dependency or copying any code: it must be AGPL-compatible (MIT, BSD, ISC, zlib, Apache-2.0, MPL-2.0, LGPL, GPL-3.0, AGPL-3.0).
  GPL-2.0-only, SSPL, "source available", non-commercial, closed SDKs, and unlicensed code are out.
  Copied code keeps its notice.
- Models are data, but their license binds us too: it must allow commercial use and redistribution.
  Parakeet Ultra and Parakeet CTC 110M are CC-BY-4.0, which requires credit; Silero VAD is MIT.
- Tony ships as a Developer ID signed, notarized download that updates itself.
  The Mac App Store is out: its terms conflict with the AGPL.
- The About window shows the copyright, the no-warranty notice, the license, a link to the source, and credits for Parakeet (NVIDIA, post-trained by Moondream), Parakeet CTC 110M (NVIDIA), Silero VAD, FluidAudio, and Sparkle: the AGPL's "Appropriate Legal Notices" plus the CC-BY credit.
- CI builds every release from a tagged commit, so each binary's source is public.
- A server we write for Tony (sync, cloud features) is AGPL too, lives in this repo, and offers its source to its users (AGPL section 13).

## Stack

- Native Swift 6 with SwiftUI, and AppKit where SwiftUI falls short: status item, non-activating panels, event taps.
- Swift Package Manager only: `Package.swift` and plain files diff and merge cleanly, an Xcode project's `.pbxproj` does not.
  A script assembles, signs, and notarizes the `.app`.
- Speech: NVIDIA Parakeet TDT v3, post-trained by Moondream as Parakeet Ultra, on the Neural Engine through [FluidAudio](https://github.com/FluidInference/FluidAudio) (Core ML), with Silero voice activity detection, and Parakeet CTC 110M listening for the user's words.
- Swift 6 with `MainActor` as the default isolation: code that runs off the main thread (the event tap, the audio thread, speech) says `nonisolated` or is an actor.
- Updates: [Sparkle 2](https://sparkle-project.org) from GitHub Releases.
- macOS 15+, Apple silicon only: the model runs on the Neural Engine.

## Layout

- `Sources/Tony/<Domain>/`: one folder per domain skill: `Hotkey`, `Audio`, `Speech`, `Insert`, `HUD`, `Shell`.
- `build/`: `Tony.icon`, `Info.plist`, entitlements.
- `scripts/`: build and release tooling.

## Commands

- `swift build` builds, `swift test` runs the unit tests.
- `node scripts/package.ts --debug` builds `release/Tony.app`, signed with the Developer ID when the Mac has it, so permissions survive rebuilds.
  `--dmg` and `--update` add the notarized DMG, the update zip, and `appcast.xml`; CI releases with both.
- `node scripts/update-e2e.ts` proves a signed build updates itself (clicks the menu, so the terminal needs Accessibility).
- `node scripts/icon.ts` redraws the artwork in `build/Tony.icon` from the numbers at its top.
- `node --test 'scripts/*.test.ts'` tests the release tooling and that `build/Tony.icon` matches `scripts/icon.ts` (Node 24).
- Add each new command here in the commit that adds it.

## Releases and updates

Ported from Grip, where each piece is proven.

- Releases are automatic: every merge to `main` whose commits include a `feat`, `fix`, `perf`, or breaking change ships as an in-app update.
  PR titles must be Conventional Commits (`.github/workflows/pr-title.yml`), since the squash commit takes the title and `scripts/version.ts` picks the next version from it.
- Versions live in `v*` tags.
  CI writes the version into both `CFBundleShortVersionString` and `CFBundleVersion`, since Sparkle compares `CFBundleVersion`.
- The release job (`release` in `.github/workflows/ci.yml`, ported from Grip): import the Developer ID certificate into a temporary keychain, build, sign with the hardened runtime, notarize and staple the DMG, sign the update zip with Sparkle's EdDSA key, generate `appcast.xml`, run the update end-to-end test, then `gh release create v<version>` with the DMG, the zip, and the appcast.
- Sparkle reads `https://github.com/bestboyhq/tony/releases/latest/download/appcast.xml`, so the repo must be public before the first release.
- Secrets: `CSC_LINK`, `CSC_KEY_PASSWORD`, `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD` (the same values as Grip), and `SPARKLE_PRIVATE_KEY`, whose public half is `SUPublicEDKey` in `Info.plist`.
  Team ID `59F3NS99CS`, bundle id `com.bestboyhq.tony`.
- An update end-to-end test proves a signed build updates itself: 0.0.1 finds 0.0.2 on a local appcast, installs it, and relaunches as 0.0.2 (`scripts/update-e2e.ts`).
  It signs with a throwaway EdDSA key, so the real one never leaves CI's secrets.
  CI runs it before every release.

## Code: lazy senior developer

Lazy means efficient, not careless.
The best code is the code never written.
Lazy means less code, not less effort: understanding, root cause, and verification still get full effort.

Understand the problem first.
Read the task and the code it touches, and trace the real flow end to end.
Then stop at the first rung that holds:

1. Does this need to be built at all? (YAGNI)
2. Does it already exist in this codebase? Reuse the helper, util, or pattern that is already here.
3. Does the standard library do this? Use it.
4. Does a native platform feature cover it? Use it.
5. Does an already-installed dependency solve it? Use it.
6. Can this be one line? Make it one line.
7. Only then: write the minimum code that works.

Bug fix = root cause, not symptom.
A report names a symptom.
Grep every caller of the function you touch and fix the shared function once.
One guard there is a smaller diff than one per caller, and a fix on only the path the ticket names leaves sibling callers broken.

Rules:

- No abstractions or boilerplate that nobody asked for.
- No new dependency if you can avoid it.
- Deletion over addition. Boring over clever. Fewest files possible.
- Shortest working diff wins, but only once you understand the problem.
  The smallest change in the wrong place is not lazy, it is a second bug.
- Complex request? Ship the lazy version and question it in the same response: "Did Y, it covers X. Need full X? Say so."
- Two stdlib options of the same size? Pick the one that is correct on edge cases.
- Mark deliberate simplifications that cut a real corner with a known ceiling (global lock, O(n²) scan, naive heuristic) with a `ponytail:` comment.
  Name the ceiling and the upgrade path.

Never lazy about:

- Understanding the problem. A small diff you do not understand is laziness dressed up as efficiency.
- Input validation at trust boundaries, error handling that prevents data loss, security, and accessibility.
- Calibration that real hardware needs. A clock drifts, a sensor reads off.
- Anything explicitly requested.
- Tests. Lazy code without its check is unfinished.
  Non-trivial logic leaves ONE runnable check behind: the smallest thing that fails if the logic breaks (an assert-based self-check or one small test file, no frameworks, no fixtures).
  Trivial one-liners need no test.
