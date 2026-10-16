# 0005 - Releases from Conventional Commits, updates through Sparkle

Status: accepted

## Context

Tony ships from squash-merged pull requests, and users run a signed app that should update itself (ADR 0004).
Grip, Tony's sibling, already solved Developer ID signing, notarization, release automation, and in-app updates, so Tony ports its approach.

## Decision

- Pull request titles are Conventional Commits; the squash merge makes the title the commit subject.
- After each merge to `main`, `scripts/version.ts` picks the next version: a breaking change bumps the major, a `feat` the minor, a `fix` or `perf` the patch, and anything else releases nothing.
  Versions live in `v*` tags, and CI writes the version into both `CFBundleShortVersionString` and `CFBundleVersion`, since Sparkle compares the latter.
- The `release` job in `.github/workflows/ci.yml` signs with the hardened runtime, notarizes and staples the DMG, signs the update zip with Sparkle's EdDSA key, writes `appcast.xml`, and publishes all three to GitHub Releases.
- Sparkle 2 reads `https://github.com/bestboyhq/tony/releases/latest/download/appcast.xml` (`SUFeedURL` in `build/Info.plist`).
- `scripts/update-e2e.ts` proves a signed build updates itself, with a throwaway EdDSA key, on every pull request and before every release.

## Consequences

- The pull request title is the release decision: `feat`, `fix`, and `perf` ship, other types do not.
- The repository must be public, since Sparkle reads the appcast from its releases.
- A change that breaks updating fails on its pull request, not after release.
- Enforced by `.github/workflows/pr-title.yml`, `scripts/version.test.ts`, and the `test` and `release` jobs in `.github/workflows/ci.yml`.
