# 0014 - The site's footer names Bestboy, license notices name the holder

Status: accepted

## Context

ADR 0011 put one copyright line, `Szymon Grącki and Tony contributors`, everywhere, the website's footer included.
The Bestboy sites then decided that their footers name the brand: the Terms and Privacy pages on bestboy.dev say Bestboy is Szymon Grącki's brand, and Bestboy's design (`docs/design.md` in `bestboyhq/platform`) follows the same rule.
Bestboy is still a brand and not a legal entity, so a license notice cannot name it as the holder: the copyright holder is Szymon Grącki, a private person, with every contributor holding the copyright in their own work.
The AGPL lets anyone fork Tony, but a fork shipped as "Tony" with Tony's icon would look like ours, and the license by itself says nothing about names.
The owner wants to reuse contributions in his closed hosted platform and to relicense them, which the AGPL alone does not allow for code he did not write.
What 0011 decided about trademarks, the CLA, and `NOTICE` still holds, and this record restates it, so a reader needs only this one.

## Decision

- Every license notice says `Copyright (C) 2026 Szymon Grącki and Tony contributors`, with © where the UI uses it: About, `NSHumanReadableCopyright` in `build/Info.plist`, `NOTICE`, and the README.
- The website's footer (`site/src/lib/Footer.svelte`) says `© 2026 Bestboy and Tony contributors`, like every Bestboy site's footer.
- `TRADEMARKS.md` keeps the names Tony and Best Boy and their logos out of the license, as AGPL section 7(e) allows: a modified version needs its own name and icon.
- Contributions require the Contributor License Agreement in `CLA.md`, adapted from the Apache Individual CLA v2.2: contributors keep their copyright and grant the maintainer, or a successor such as a company he founds, a license to distribute their work under any terms.
- `.github/workflows/cla.yml` collects signatures with `iainmcgin/cla-github-action`, a Node 24 fork of the archived CLA Assistant Lite with the same inputs: a contributor signs with a comment on their first pull request, and the signatures live in `signatures/cla.json` on the `cla-signatures` branch, apart from main and its branch protection.
  The workflow creates that branch on its first run, since the action fails the run in which it creates a missing signatures file.
  It never checks out pull request code, skips the pull requests `szymeo` opens, and allowlists `szymeo`, bots, and the `Co-authored-by:` identities of Copilot, Claude Code, and Cursor.
  The action is pinned by commit SHA to v3.2.0, whose bundle is byte-identical to a build from its source at that commit.
- The `main` ruleset, `main: CI must pass`, requires the bot's check, `cla`, next to `test` and `conventional`, with no bypass.
- `NOTICE` lists every third-party component Tony ships or downloads, with its license and the notices that license requires, and `scripts/package.ts` copies it and `LICENSE` into the app's `Contents/Resources`.
  About credits the same components.

## Consequences

- The site reads as one family with bestboy.dev and the other app sites, while the app and the source still say who holds the copyright.
- Two lines now exist, so a new surface has to pick one: a license notice names Szymon Grącki, a site footer names Bestboy.
- Forks stay free to use the code, and need their own name and icon.
- The maintainer can ship contributions in closed products and relicense Tony, while the public code stays AGPL.
- A first-time contributor signs once before their pull request can merge: the ruleset holds it until the `cla` check passes, which the bot reruns once they sign.
- The ruleset names the check by the job's id, so renaming the job blocks every pull request until the ruleset follows.
- The fork's owner keeps it for their own use and offers no support, so a new pin needs its changelog and diff read first: the action runs with a write token.
  A GitHub change that breaks it may get no fix; the fallback is our own fork of it or the hosted CLA Assistant.
- The fork fails a pull request whose opener wrote none of its commits, and `malini-agent[bot]` writes every commit in the pull requests `szymeo` opens, so the job skips those, and a pull request `szymeo` opens with someone else's commits goes unchecked.
- The fork asks every `Co-authored-by:` identity to sign, and an AI agent cannot sign a contract, so a new agent's trailer fails the check until its identity joins the allowlist.
- A new dependency or model adds a section to `NOTICE` and a credit to About.
  `scripts/notice.test.ts` fails when About and `NOTICE` credit different components, when a pin in `Package.resolved` is missing from `NOTICE`, when a license notice loses the copyright line, or when the site's footer loses the Bestboy line.
- Nothing checks a new model's license or that a component's notice in `NOTICE` is current.
