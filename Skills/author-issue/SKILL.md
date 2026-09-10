---
name: author-issue
description: Turn a bug or feature Jonathan describes in chat into a fully specified, codebase-grounded GitHub issue or Azure DevOps work item — his requirements and acceptance criteria collected verbatim through an intake template, Claude's implementation plan and derived acceptance criteria grounded in real file:line citations. Use whenever Jonathan says "file a bug", "log a bug", "raise a bug", "create an issue", "open an issue", "new feature", "feature request", "work item", "ADO work item", "add this to the backlog", "write this up", "write up a proper issue", "turn this into an issue", "spec this out for the tracker", or runs /author-issue — and also for enrich mode, when he names an existing issue or work-item number and wants it filled out ("flesh out #42", "enrich that work item", "add the implementation detail to #17"). Produces the admission input for the session-scoped issue loop: nothing is drafted without human-authored requirements AND acceptance criteria, nothing is filed without explicit approval, and every derived claim is cited or tagged [unverified]. Do NOT use to plan an epic (dev-epic-workflow), to run a story (dev-story-sprint), or to pick up an issue that already exists and is already specified (dev-epic-workflow's issue intake).
---

# Author Issue

Jonathan describes a problem in chat. This skill turns that into an issue a coding session
can actually execute against — without inventing a single requirement he didn't state.

The output is split down the middle, and the split is the whole point:

| Half | Author | Rule |
|---|---|---|
| **Human-authored** | Jonathan, via the intake template | Copied **verbatim**. `R1…`/`AC1…` numbering preserved. Claude never rewrites, reorders, or "clarifies" it. |
| **Claude-derived** | This skill, after grounding | Every statement carries a `file:line` citation or the literal tag `[unverified]`. Never drafted from recall. |

That split is what makes the issue admissible to the session-scoped issue loop, which only
admits work carrying explicit human-authored requirements and acceptance criteria.

## The two rules that outrank everything else

1. **The R/AC gate.** Requirements and acceptance criteria must be present, non-empty, and
   written by Jonathan. With either missing, this skill **does not draft**. It asks once,
   specifically, for exactly what is absent — and waits.
2. **The anti-invention rule.** This skill never adds a requirement. Not a helpful one, not
   an obvious one, not an implied one. This is not a hypothetical failure mode: LODE's
   QA-capture elaborator fabricated an entire modal-drawer specification from a one-line
   note, and that spec was built. Anything Claude thinks *should* be a requirement goes in
   **Open questions**, phrased as a question, and Jonathan decides.

Everything below is machinery in service of those two.

## Flow

```
trigger ──► collect (template) ──► R/AC gate ──► ground (Explore, sonnet) ──► draft
                                       │                                        │
                                  missing? ask                          review gate (approval)
                                                                                │
                                                                          file ──► URL
```

### 1. Trigger and detect

Triggers: "file a bug", "create an issue", "new feature", "work item", "write this up",
`/author-issue`.

Detect the tracker and verify auth per
`Skills/dev-epic-workflow/references/issue-intake.md` — origin remote URL, with a
`Tracker:` line in the repo's `CLAUDE.md` as the override. Auth checks live there too
(`gh auth status`, or the `az boards query --top 1` probe). **Do not re-implement detection
or auth here**; that file owns them, and a second copy would drift.

If auth is missing, say what is missing in one line and stop. Do not draft an issue that
cannot be filed.

### 2. Collect

Post the right intake template — `templates/bug.md` or `templates/feature.md` — as **one
fenced block**, and ask Jonathan to fill it in in chat. Nothing else in that turn.

Multiple items in one message are allowed: repeat the template once per item, and from
there each item is processed **independently** — its own grounding subagent, its own draft,
its own review gate, its own filed issue. One item blocked on missing R/AC never holds up
another.

**The hard gate.** Before any drafting, for each item:

- Requirements (`R1…`) — present, non-empty, human-written.
- Acceptance criteria (`AC1…`) — present, non-empty, human-written.

If either is absent, ask **once**, and ask **specifically**: name which of the two is
missing and what it needs to say, rather than re-posting the whole template. Then wait.
There is no "I'll draft something to get us started" here, and no inferring `R1` from the
summary paragraph. **This skill never writes requirements on Jonathan's behalf.**

### 3. Ground

Per item, dispatch exactly **one** `Explore` subagent with `model: "sonnet"`, announced in
the same turn with the global model-announcement table:

| Task | Scope | Model |
| --- | --- | --- |
| Ground issue draft — <item title> | modules, entry points, call sites, config, tests | Sonnet 5 |

Ask it for: the modules and entry points the item touches, the call sites, relevant config,
existing tests, and any prior similar implementation in the repo — returned as `file:line`
citations plus a description of **current** behaviour, in ≤ 400 words. Ask for the
conclusion, not the material.

**Never draft from recall.** If the subagent could not find something, that fact is
recorded as `[unverified]` in the draft — not smoothed over.

Record the grounding SHA (short HEAD hash) — the derived half is only true as of a commit,
and its heading says which one.

### 4. Draft

Write the body per `references/issue-body.md`, which owns the exact section skeleton. The
constraints that matter:

- **Citations.** Every derived statement carries a `file:line` citation or the literal tag
  `[unverified]`. There is no third option. "Probably" and "should be" are `[unverified]`.
- **Implementation plan.** Ordered steps. Each step names the files, the symbols, the
  signature or schema changes, any data/migration notes, the tests to add or change **by
  name**, and the gate command that proves it.
- **Derived acceptance criteria (`DAC1…`).** Each is testable, each carries a verification
  command or an observable, and each **traces to an `R`/`AC` number or a cited codebase
  invariant**. Write the trace inline: `DAC3 → R2`. Anything that cannot be traced does not
  get softened into a criterion — it goes to **Open questions**.
- **Size verdict.** Every draft ends with one: **single work item**, or **decompose** — and
  if decompose, suggest the split as a numbered list and recommend `dev-epic-workflow`.
  Erring toward decomposition is cheap; a work item nobody can finish is not.

### 5. Review gate

Post the full draft in chat — complete, nothing abbreviated — and **wait** for Jonathan's
explicit approval or edits.

Filing is outward-facing: it creates a record other people see. Silence is not consent
here, a thumbs-up on an earlier message is not approval of this draft, and "looks good so
far" mid-draft is not approval of the finished one. **Never file unapproved.**

Edits come back as edits to the human half (applied verbatim) or the derived half
(re-derived, not argued with).

### 6. File

Use `references/trackers.md` for **every** `gh` and `az` command — the exact invocations,
the label and tag constants, the `gh label create` bootstrap when a label is missing, the
ADO field names, and how to extract the URL from each command's output. No tracker command
is written inline in this file.

The admission label/tag constant is `epic-loop-ready`, applied alongside the type label
(`bug` or `enhancement` on GitHub; the work-item type plus that tag on ADO).

Then print the URL. **Nothing else** — no summary of what was filed, no next steps.

### 7. Enrich mode

Given an existing issue or work-item number:

1. Fetch it (per `references/trackers.md`).
2. Treat its existing body as the **human-authored** half. It is Jonathan's text; it stays
   verbatim.
3. Run the R/AC gate against it. Missing requirements or acceptance criteria are asked for
   exactly as in step 2 — an existing issue number does not exempt an item from the gate.
4. Run steps 3–6 as an **in-place edit**: ground, draft the derived half, review gate, then
   update the issue. The human sections are preserved byte-for-byte; only the
   Claude-derived half and the Loop admission checklist are added or replaced.

Enrich is never a rewrite. If the existing body reads poorly, that is Jonathan's to change.

## Failure modes this skill exists to prevent

- **Fabricated requirements.** Covered by the anti-invention rule. The tell is a
  requirement in the derived half with no `R`/`AC` trace — which is exactly what the trace
  notation makes visible.
- **Confident recall.** A plan naming a file that moved, or a function signature that
  changed, is worse than no plan. Hence: one `Explore` per item, `file:line` or
  `[unverified]`, and a grounding SHA in the heading.
- **Unadmissible issues.** An issue with no human-authored acceptance criteria cannot enter
  the loop, so drafting one is wasted work. Hence the gate runs *before* grounding, not
  after.
- **Silent filing.** An issue filed without approval is a public artifact Jonathan didn't
  write. Hence the review gate.
- **Scope that outgrows the item.** Hence the Size verdict, at the bottom of every draft,
  where it cannot be skipped.

## Files

| Path | Owns |
|---|---|
| `templates/bug.md` | Bug intake template — the fenced block posted at step 2 |
| `templates/feature.md` | Feature intake template |
| `references/issue-body.md` | The issue body skeleton, section by section, with a worked example |
| `references/trackers.md` | Every `gh` / `az` command, label constants, URL extraction |
| `Skills/dev-epic-workflow/references/issue-intake.md` | Tracker detection, auth, status labels — pointed at, never copied |
