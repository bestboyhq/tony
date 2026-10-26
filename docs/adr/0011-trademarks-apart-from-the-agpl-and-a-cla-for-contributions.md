# 0011 - Trademarks apart from the AGPL, and a CLA for contributions

Status: accepted

## Context

Tony is `AGPL-3.0-only` (ADR 0004), and its copyright said "Best Boy", a brand that is not a legal entity.
The copyright holder is Szymon Grącki, a private person, with every contributor holding the copyright in their own work.
The AGPL lets anyone fork Tony, but a fork shipped as "Tony" with Tony's icon would look like ours, and the license by itself says nothing about names.
The owner wants to reuse contributions in his closed hosted platform and to relicense them, which the AGPL alone does not allow for code he did not write.
The AGPL's notices, and the BSD and MIT code inside Sparkle and FluidAudio, require their license texts to travel with the binary, and the `.app` carried none.

## Decision

- The copyright line everywhere is `Copyright (C) 2026 Szymon Grącki and Tony contributors`, with © where the UI uses it: About, `NSHumanReadableCopyright` in `build/Info.plist`, `NOTICE`, the README, and the website's footer.
- `TRADEMARKS.md` keeps the names Tony and Best Boy and their logos out of the license, as AGPL section 7(e) allows: a modified version needs its own name and icon.
- Contributions require the Contributor License Agreement in `CLA.md`, adapted from the Apache Individual CLA v2.2: contributors keep their copyright and grant the maintainer, or a successor such as a company he founds, a license to distribute their work under any terms.
- `.github/workflows/cla.yml` collects signatures with CLA Assistant Lite (`contributor-assistant/github-action`, pinned to v2.6.1, its last release): a contributor signs with a comment on their first pull request, and the signatures live in `signatures/cla.json` on the `cla-signatures` branch, apart from main and its branch protection.
  The workflow creates that branch on its first run, since the action fails when the file does not exist yet, and allowlists `szymeo` and bots.
- The `main` ruleset, `main: CI must pass`, requires the bot's check, `cla`, next to `test` and `conventional`, with no bypass.
  The check joins the ruleset only once `cla.yml` is on main: `pull_request_target` runs the workflow from main, so the pull request that adds it never gets the check and would wait on it forever.
- `NOTICE` lists every third-party component Tony ships or downloads, with its license and the notices that license requires, and `scripts/package.ts` copies it and `LICENSE` into the app's `Contents/Resources`.
  About credits the same components.

## Consequences

- Forks stay free to use the code, and need their own name and icon.
- The maintainer can ship contributions in closed products and relicense Tony, while the public code stays AGPL.
- A first-time contributor signs once before their pull request can merge: the ruleset holds it until the `cla` check passes, which the bot reruns once they sign.
- The ruleset names the check by the job's id, so renaming the job blocks every pull request until the ruleset follows.
- CLA Assistant Lite is archived, so a GitHub change that breaks it gets no fix upstream; the replacement is a fork of the action or the hosted CLA Assistant.
- A new dependency or model adds a section to `NOTICE` and a credit to About.
  `scripts/notice.test.ts` fails when About and `NOTICE` credit different components, when a pin in `Package.resolved` is missing from `NOTICE`, or when a file loses the copyright line.
- Nothing checks a new model's license or that a component's notice in `NOTICE` is current.
