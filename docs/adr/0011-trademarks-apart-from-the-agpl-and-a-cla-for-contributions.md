# 0011 - Trademarks apart from the AGPL, and a CLA for contributions

Status: accepted

## Context

Tony is `AGPL-3.0-only` (ADR 0004), and its copyright said "Best Boy", a brand that is not a legal entity.
The copyright holder is Szymon Grącki, a private person, with every contributor holding the copyright in their own work.
The AGPL lets anyone fork Tony, but a fork shipped as "Tony" with Tony's icon would look like ours, and the license by itself says nothing about names.
The owner wants to reuse contributions in his closed hosted platform and to relicense them, which the AGPL alone does not allow for code he did not write.
CLA Assistant Lite (`contributor-assistant/github-action`), which collects CLA signatures in the repository itself, is archived, and its last release targets Node 20, which GitHub removed from its runners on 2026-09-23: they force it onto Node 24, with a deprecation warning.
The AGPL's notices, and the BSD and MIT code inside Sparkle and FluidAudio, require their license texts to travel with the binary, and the `.app` carried none.

## Decision

- The copyright line everywhere is `Copyright (C) 2026 Szymon Grącki and Tony contributors`, with © where the UI uses it: About, `NSHumanReadableCopyright` in `build/Info.plist`, `NOTICE`, the README, and the website's footer.
- `TRADEMARKS.md` keeps the names Tony and Best Boy and their logos out of the license, as AGPL section 7(e) allows: a modified version needs its own name and icon.
- Contributions require the Contributor License Agreement in `CLA.md`, adapted from the Apache Individual CLA v2.2: contributors keep their copyright and grant the maintainer, or a successor such as a company he founds, a license to distribute their work under any terms.
- `.github/workflows/cla.yml` collects signatures with `iainmcgin/cla-github-action`, a Node 24 fork of CLA Assistant Lite with the same inputs: a contributor signs with a comment on their first pull request, and the signatures live in `signatures/cla.json` on the `cla-signatures` branch, apart from main and its branch protection.
  The workflow creates that branch on its first run, since the action fails the run in which it creates a missing signatures file.
  It never checks out pull request code, skips the pull requests `szymeo` opens, and allowlists `szymeo`, bots, and the `Co-authored-by:` identities of Copilot, Claude Code, and Cursor.
  The action is pinned by commit SHA to v3.2.0, whose bundle is byte-identical to a build from its source at that commit.
- The `main` ruleset, `main: CI must pass`, requires the bot's check, `cla`, next to `test` and `conventional`, with no bypass.
  The check joins the ruleset only once `cla.yml` is on main: `pull_request_target` runs the workflow from main, so the pull request that adds it never gets the check and would wait on it forever.
- `NOTICE` lists every third-party component Tony ships or downloads, with its license and the notices that license requires, and `scripts/package.ts` copies it and `LICENSE` into the app's `Contents/Resources`.
  About credits the same components.

## Consequences

- Forks stay free to use the code, and need their own name and icon.
- The maintainer can ship contributions in closed products and relicense Tony, while the public code stays AGPL.
- A first-time contributor signs once before their pull request can merge: the ruleset holds it until the `cla` check passes, which the bot reruns once they sign.
- The ruleset names the check by the job's id, so renaming the job blocks every pull request until the ruleset follows.
- The fork's owner keeps it for their own use and offers no support, so a new pin needs its changelog and diff read first: the action runs with a write token.
  The SHA pin keeps its code fixed, and nothing but that review checks a new one.
  A GitHub change that breaks it may get no fix; the fallback is our own fork of it or the hosted CLA Assistant.
- The fork fails a pull request whose opener wrote none of its commits, and `malini-agent[bot]` writes every commit in the pull requests `szymeo` opens, so the job skips those, and a job skipped by `if:` still passes a required check.
  A pull request `szymeo` opens with someone else's commits therefore goes unchecked.
- The fork asks every `Co-authored-by:` identity to sign, and an AI agent cannot sign a contract, so the allowlist names the agents' trailer identities.
  The fork always asks the pull request's opener to sign, so a person still signs for every contribution, and a new agent's trailer fails the check until its identity joins the allowlist.
- A new dependency or model adds a section to `NOTICE` and a credit to About.
  `scripts/notice.test.ts` fails when About and `NOTICE` credit different components, when a pin in `Package.resolved` is missing from `NOTICE`, or when a file loses the copyright line.
- Nothing checks a new model's license or that a component's notice in `NOTICE` is current.
