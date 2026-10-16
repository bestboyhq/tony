# 0002 - Native Swift, built with Swift Package Manager only

Status: accepted

## Context

Tony promises a native look, 120 Hz motion, and surfaces that never take focus (`AGENTS.md`, Beautiful and Focus stays with the user).
Its hardest parts are AppKit and system APIs: a status item, non-activating panels, a CGEvent tap, Core Audio, the pasteboard.
Agents write much of the code on parallel branches, and an Xcode project's `.pbxproj` merges badly.

## Decision

- Swift 6 with SwiftUI, and AppKit where SwiftUI falls short: the status item, the non-activating HUD and panel, the event tap.
- `Package.swift` is the only project file: an executable target `Tony`, the `TonyObjC` target for what Swift can't do (catching an Objective-C exception), and `TonyTests`.
- `MainActor` is the default isolation (`.defaultIsolation(MainActor.self)`); code off the main thread (the event tap, the audio thread, speech) says `nonisolated` or is an actor.
- `scripts/package.ts` assembles, signs, and notarizes `Tony.app`; there is no Xcode project.

## Consequences

- Every source file is plain text that diffs and merges cleanly.
- The compiler checks data races, so the threading between the event tap, the audio thread, and the UI is explicit.
- App bundling, Info.plist, entitlements, and signing are the script's job, not Xcode's.
- Enforced by CI's `swift build --build-tests` in `.github/workflows/ci.yml`, which compiles in the Swift 6 language mode.
