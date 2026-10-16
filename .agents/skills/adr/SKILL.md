---
name: adr
description: Record an architecture decision for Tony in `docs/adr/`. Use when a change makes or reverses a decision about an invariant in `AGENTS.md`, a domain boundary, a platform API Tony builds on, a model, a dependency, the build or release pipeline, or anything that leaves the Mac; or when someone asks why Tony is built a certain way and no ADR answers it.
---

# Architecture decision records

`docs/adr/` holds one decision per file, `NNNN-kebab-title.md`, numbered in order and listed in `docs/adr/README.md`.
An ADR says why; `AGENTS.md`, the domain skills in `.agents/skills/` and `README.md` say what is true now.
Features, fixes and tuning inside an existing decision need no ADR.

## Write one

1. Read `docs/adr/README.md`.
   An ADR that already covers the area is either still true, and needs nothing, or being reversed, and gets superseded in step 4.
2. Take the next number and write `docs/adr/NNNN-kebab-title.md`:

   ```markdown
   # NNNN - Title in plain words

   Status: accepted

   ## Context

   The forces at play: constraints, goals, what hurt. Three to six sentences.

   ## Decision

   What Tony does, concretely: files, types, APIs, values.

   ## Consequences

   What became easier, what became harder, what must now stay true, and the check that enforces it.
   ```

3. Add a row to the table in `docs/adr/README.md`: the number linked to the file, and the decision in one line.
4. Superseding: keep the old ADR's text, set its status to `superseded by NNNN`, and open the new ADR's context with what changed.
   The new ADR restates what still holds from the old one, so a reader needs only the new one.
5. In the same change, update whatever states the "what": the invariants and sections of `AGENTS.md`, the domain skill, `README.md`, and doc comments that cite the old ADR.
6. Run `node --test 'scripts/*.test.ts'`: it fails when the index and the files disagree.

Done when the ADR, its index row and every "what" document agree.

## Rules

- Ground every reason in the code, the history or the user's words.
  A reason you cannot find is a question for the user.
- Name the enforcer: the test, compiler setting or CI workflow that fails when the decision is broken.
  When nothing enforces it, say so.
- Status is `accepted`, `superseded by NNNN` or `deprecated`; an accepted decision is never rewritten.
- One sentence per line.
