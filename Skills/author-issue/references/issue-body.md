# Issue body — the section skeleton

Every issue this skill files or enriches uses exactly these sections, in this order. The
skeleton is fixed so the loop's admission check, and any human scanning the tracker, always
finds the same thing in the same place. Sections marked *(bugs)* are omitted for features;
nothing else is optional — a section with nothing to say says "none" rather than vanishing.

## The skeleton

```markdown
## Summary
## Meta            (type · priority · repo · base branch · author · grounded-at sha)
## Human-authored
### Requirements
### Acceptance criteria
### Reproduction & evidence        (bugs)
### Constraints & not in scope
## Claude-derived (grounded in <repo>@<sha>)
### Codebase context               (files/symbols with file:line, current behaviour)
### Implementation plan            (ordered steps: files · symbols · changes · tests · gate)
### Derived acceptance criteria    (DAC1… → traces to R/AC, verification command)
### Tests
### Gates & verification commands
### Risks & rollback
### Open questions
### Size                           (single item | decompose → suggested items)
## Loop admission
- [ ] Human-authored requirements present   - [ ] Human-authored acceptance criteria present
- [ ] Every derived claim cited or [unverified]   - [ ] Label/tag `epic-loop-ready` applied
```

## Authoring note, section by section

| Section | One-line note |
|---|---|
| `## Summary` | Two or three sentences a stranger can act on — what is wrong or missing, and what changes when this lands. |
| `## Meta` | One line of facts, no prose: type, priority, repo, base branch, author, and the short SHA the derived half was grounded at. |
| `## Human-authored` | A container heading only; everything under it is Jonathan's text, copied verbatim with its numbering intact. |
| `### Requirements` | His `R1…` list, unedited — never renumbered, never merged, never "tightened". |
| `### Acceptance criteria` | His `AC1…` list, unedited; if he wrote a criterion that is really a requirement, note it in Open questions rather than moving it. |
| `### Reproduction & evidence` *(bugs)* | Steps, expected, actual and the evidence excerpt, as filled in — trimmed only by removing empty template hints. |
| `### Constraints & not in scope` | His limits, verbatim; this is what stops the derived half from growing the item. |
| `## Claude-derived (grounded in <repo>@<sha>)` | The heading itself carries the SHA — the derived half expires when the tree moves, and the heading is the timestamp. |
| `### Codebase context` | What is true **today**: files, symbols and current behaviour, each with `file:line`, or the literal tag `[unverified]`. |
| `### Implementation plan` | Ordered steps; each names files, symbols, signature/schema changes, data or migration notes, tests to add or change by name, and the gate that proves it. |
| `### Derived acceptance criteria` | `DAC1…`, each testable, each with a verification command or observable, each written with its trace inline (`DAC2 → AC1`); untraceable ones move to Open questions. |
| `### Tests` | The specific test files and test names to add or change, and which existing suite covers the regression. |
| `### Gates & verification commands` | The exact commands, copy-pasteable, that decide whether the item is done — the repo's own `make`/CI target where one exists. |
| `### Risks & rollback` | What could break outside the diff, and the concrete undo — revert the commit, down-migration, feature flag off. |
| `### Open questions` | Everything Claude would otherwise have invented, phrased as a question for Jonathan; an empty list here on a non-trivial item is a smell. |
| `### Size` | The verdict — `single work item`, or `decompose` with the suggested split numbered and `dev-epic-workflow` recommended. |
| `## Loop admission` | The four checkboxes, checked only when actually true; this is what the session-scoped issue loop reads to admit the item. |

## Worked example — a short bug, filed end to end

```markdown
## Summary
`gh label create` is called with no `--force`, so re-running intake on a repo that
already has the `epic-loop-ready` label aborts the whole filing step and no issue is
created. Every repo after its first issue hits this.

## Meta
type: bug · priority: P2 · repo: GreatFigure8/Claude-Skills · base: main ·
author: Jonathan Stevenson · grounded-at: a1b2c3d

## Human-authored

### Requirements
R1. Filing must succeed on a repo where the `epic-loop-ready` label already exists.
R2. Filing must still create the label on a repo that does not have it yet.

### Acceptance criteria
AC1. Running the filing step twice in the same repo creates two issues and errors neither time.
AC2. Running it in a fresh repo with no labels creates the label and the issue.

### Reproduction & evidence
1. In a repo that already has `epic-loop-ready`, run the filing step.
2. Expected: the issue is created.
3. Actual: `gh label create` exits 1 with `already exists`, and filing stops before
   `gh issue create` runs.

Evidence — stderr from the failing call:

    GraphQL: Name has already been taken (createLabel)

### Constraints & not in scope
Do not change the label name. No change to the ADO path.

## Claude-derived (grounded in GreatFigure8/Claude-Skills@a1b2c3d)

### Codebase context
- The bootstrap runs unconditionally before filing at `Skills/author-issue/references/trackers.md:41`.
- The label constant `epic-loop-ready` is defined once at `Skills/author-issue/references/trackers.md:12`.
- No test covers the bootstrap path. [unverified] — no test file references `label create`.

### Implementation plan
1. `Skills/author-issue/references/trackers.md` — in the bootstrap block, change the
   `gh label create` invocation to tolerate an existing label (`--force`, or guard it
   behind a `gh label list` check). No schema or signature change.
   Gate: `grep -n 'label create' Skills/author-issue/references/trackers.md`.
2. Add a fixture `tests/fixtures/author-issue-label-bootstrap.sh` asserting the
   invocation is idempotent-safe.
   Gate: `bash tests/fixtures/author-issue-label-bootstrap.sh`.

### Derived acceptance criteria
- DAC1 → R1 / AC1: re-running the bootstrap against an existing label exits 0.
  Verify: `gh label create epic-loop-ready --force --repo <repo>; echo $?` → `0`.
- DAC2 → R2 / AC2: the label exists after a run in a repo that lacked it.
  Verify: `gh label list --repo <repo> --search epic-loop-ready` lists it.
- DAC3 → cited invariant (`trackers.md:12`): the label string is unchanged in the diff.
  Verify: `git diff main...HEAD -- Skills/author-issue/references/trackers.md | grep -c 'epic-loop-ready'`.

### Tests
Add `tests/fixtures/author-issue-label-bootstrap.sh`. No existing test changes.

### Gates & verification commands
`bash tests/fixtures/author-issue-label-bootstrap.sh` → exit 0.

### Risks & rollback
`--force` also resets an existing label's colour and description. Rollback is a single
revert of the commit; no data or migration involved.

### Open questions
1. Is resetting the label's colour/description acceptable, or should this guard with a
   `gh label list` check instead of `--force`?

### Size
single work item — one file, one fixture.

## Loop admission
- [x] Human-authored requirements present   - [x] Human-authored acceptance criteria present
- [x] Every derived claim cited or [unverified]   - [x] Label/tag `epic-loop-ready` applied
```
