# Epic: epic queue — plan ahead, pick up in order

**Status:** closed
**Source:** GH #11
**Live branch:** main   **Integration branch:** main   **Pre-epic tag:** n/a

## Outcome
Epics can be planned and filed ahead of time without disturbing the epic currently running,
and a fresh session can see what is queued and in what order. Filing epic 06 while epic 05 is
in flight leaves epic 05's telemetry exactly where it belongs, and session start reports
"2 epics awaiting dispatch: 05-…, 06-…" instead of leaving the queue invisible.

## Grounding
- **Verified (code, `main`):** `plan_is_open()` returns false **only** when the Status line's
  first word is `closed`. `approved` and `in flight` are therefore indistinguishable, and
  `resolve_epic_dir()` takes the newest open plan — so a queued `approved` epic, being newest,
  wins over the epic actually running.
- **Verified (tested against the shipped resolver):** filing an `approved` epic while another
  is `in flight` routes the running epic's telemetry to the queued one
  (`got=06-queued`, expected `05-running`).
- **Verified (code):** the resolution block is **byte-identical** in `subagent-lifecycle.sh`
  and `subagent-tool-logger.sh` (`diff` of the extracted block), and its header states that
  drift between them is a fixture failure. Any change must be applied identically to both.
- **Verified (code):** the Status parser takes the *first word* after the marker, so
  `in flight (item 1 of 3)` yields `in`. A state test must not rely on that being a
  meaningful token — match the phrase, not the truncation.
- **Verified (code):** `session-start-context.sh` has `backlog_section()` (line 96, emitting at
  166, invoked at 169) as a clean seam; an epics-awaiting-dispatch line is a sibling function,
  not a modification of the issue query.
- **Verified (behaviour):** a pointer naming a **closed** epic is still honoured — confirmed by
  fixture. Phase 5 removes the pointer at close, so this only bites when that cleanup is missed.
- **Verified (state):** all seven installed hooks byte-identical to `main`; three epics filed,
  all closed; working tree clean.
- **Assumed:** epic folder numbering (`NN-slug`) is the intended queue order. It is what the
  skill's Phase 1 prescribes ("numbered by implementation sequence"), so item 2 sorts by folder
  number rather than by mtime or by filing date.

## Invariants
- Hooks fail open and stay silent: unresolvable epic, unreadable pointer, malformed plan →
  exit 0, no telemetry, no error.
- The two hooks' resolution blocks stay byte-identical; a fixture asserts it.
- Epic 03's guarantees hold: a closed epic is never chosen by the fallback; a missing pointer
  falls back rather than erroring; a plan with no Status line still counts as open.
- Session start stays silent and fast when offline, unauthenticated, or outside a repo, and
  never delays startup (the existing ~2s cap governs the tracker call; the epic scan is local
  and must add no network work).
- No new dependency (`jq`/`python3` optional); bash 3.2.

## Work items

### 1. Prefer the in-flight epic over queued ones
- **Branch:** `fix/epic-queue-resolution-precedence`
- **Depends on:** none
- **Scope:** the shared resolution block in `subagent-lifecycle.sh` and
  `subagent-tool-logger.sh` — classify a plan's Status as *in-flight*, *open-but-not-started*,
  or *closed*, and resolve in order: pointer (unless it names a closed epic) → newest
  **in-flight** plan → newest other open plan → nothing. Match the `in flight` phrase rather
  than the first-word truncation. Update the block's header comment and the Layer 1 / runtime
  state wording in `references/executor-control-plane.md`.
- **Not in scope:** the session-start surface (item 2); `cancel-gate.sh`; sentinel semantics;
  ownership stamping; per-agent log naming; the pointer's file location.
- **Definition of done:**
  - `approved` epic filed while another is `in flight` → telemetry goes to the **in-flight**
    epic. (The exact reproduction in #11.)
  - Two in-flight epics, no pointer → newest in-flight wins (documented, not silently arbitrary).
  - Only `approved` epics exist, none in flight → newest approved wins, as today.
  - Pointer naming a **closed** epic → ignored, falls back. (Gap 3 — decided, not left implicit.)
  - Pointer naming an in-flight or approved epic → still wins, as today.
  - Closed epics never chosen by any fallback path.
  - Plan with no Status line → still counts as open.
  - Resolution block byte-identical across both hooks, asserted by a fixture.
  - `jq` and `python3` both absent → identical results; bash 3.2.
- **Verification:** extend `hooks/tests/active-epic-fixtures.sh` with a case per clause; re-run
  `lifecycle-fixtures.sh` and `cancel-gate-fixtures.sh` **unchanged** as regression; `bash -n`
  over every script. **Include a mutation check** in the shape epic 03's executor used — revert
  the precedence in a scratch copy and show the new cases fail — so the harness is provably not
  vacuous. Live verification after install is the orchestrator's.
- **Rollback:** revert the merge commit, re-run `install.sh --user`; resolution returns to
  epic 03's behaviour, which is correct for the single-epic case.

### 2. Surface epics awaiting dispatch at session start
- **Branch:** `feat/epic-queue-session-start-surface`
- **Depends on:** none (different file from item 1 — see Sequence)
- **Scope:** `session-start-context.sh` — a sibling function to `backlog_section()` that lists
  filed epics whose Status is neither `closed` nor `in flight`, in **folder-number order**, as
  one line: `- 2 epics awaiting dispatch: 05-<slug>, 06-<slug> — dispatch the lowest number first.`
  Emit nothing when there are none. Purely local filesystem work: no `gh`, no network, no
  bearing on the existing ~2s tracker cap. Document the line in
  `references/executor-control-plane.md` or `SKILL.md` wherever the injection is described.
- **Not in scope:** the resolver (item 1); the issue-backlog query; any change to the tracker
  call or its timeout; listing in-flight epics (the handoff/plan sections already cover those).
- **Definition of done:**
  - Two approved epics + one closed + one in flight → names exactly the two approved, in
    folder-number order.
  - No approved epics → no line at all.
  - Outside a git repo, or with no `docs/epics/` → no line, no error, exit 0.
  - Malformed or Status-less plan → does not crash the injection; behaviour documented.
  - Existing git/autosnapshot/handoff/backlog output byte-identical when the new section emits
    nothing.
  - Adds no network call; bash 3.2.
- **Verification:** drive the hook directly with simulated stdin against sandbox repos for each
  condition and paste output; `bash -n`; diff the full injection against the pre-change version
  in the no-approved-epics case to prove byte-identity.
- **Rollback:** revert the merge commit, re-run `install.sh --user`.

## Sequence
Items 1 and 2 touch **disjoint files** — item 1 the two lifecycle/logger hooks, item 2 the
session-start hook — and neither depends on the other's behaviour. They are the first genuine
candidates for **parallel dispatch**, which epics 02 and 03 exist to make safe: one worktree
each, per-agent telemetry, ownership binding proven with multiple live executors, and epic
resolution no longer global-mtime. Running them in parallel is therefore also the first real
test of the capability this whole line of work is for. If parallel dispatch misbehaves, fall
back to serial (1 then 2) — nothing in the plan depends on the parallelism.

Both edit documentation, but different documents/sections; if they collide, item 2 rebases.

## Risks
| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| Precedence change breaks epic 03's guarantees | Low | Telemetry misrouted again | Epic 03's fixtures re-run unchanged as regression; closed-never-chosen asserted directly |
| First parallel dispatch loses observability of one or both items | Medium | Harder to watch; work itself still safe (separate worktrees, separate branches, per-agent logs) | Verify from git and the PRs regardless; fall back to serial on any sign of interleaving |
| The two hooks' resolution blocks drift while both are edited | Medium | Lifecycle and logger disagree about the epic | Byte-identity asserted by a fixture, per the block's own header rule |
| Session-start line adds startup latency | Low | Slower session start | Local filesystem only, no network; existing tracker cap untouched |
| "In flight" phrase matching is brittle if the Status vocabulary changes | Medium | Queued epics could win again, silently | Match the documented phrase, and cover the vocabulary from `plan-template.md` in fixtures |

## Deferred / out of scope
- Branch selectors resolving to their owning agent (the parked epic-04 draft) — polish, not on
  the path to multi-epic.
- Dispatch-time owner binding — evidence says the existing binding already covers real cases.
- The `agent_id` extraction block now exists in three copies.
- `references/stack-gates.md` still has no shell/hook section; four harnesses now exist as the
  concrete shape.
- A `/dispatch` command that writes worktree + pointer in one step, closing the last manual
  coupling (raised by epic 03's executor).
- Roadmap Tier 2 — unattended CI intake. **This epic goes first**: Tier 2 files plans headlessly,
  which makes queued epics the normal case rather than the exception.
- Multi-epic concurrency (several epics in flight at once) — the larger redesign; this epic
  makes queuing safe, not simultaneity.

- **Harness sandbox guard (filed separately):** item 2's harness hit a variable collision that
  produced `git -C "" add -A`, which git treats as "stay here" — it committed the executor's own
  worktree. Recovered on its branch; `main` never affected (verified independently). The new
  harness now aborts on any path outside its `mktemp` sandbox; the three older harnesses do not.
- `bash -n` is necessary but **not sufficient** on bash 3.2: a `case` pattern's `)` inside `$( )`
  parses clean and fails only at runtime. Belongs in the missing `stack-gates.md` shell section.
- The resolution block is now **110 lines copied verbatim into two hooks** — a third instance of
  the shared-logic problem. A `hooks/lib/` source file would replace copy-discipline with a
  mechanism, at the cost of adding a "missing file" failure mode to hooks whose first rule is
  never to fail a session.
- `references/plan-template.md` documents the Status vocabulary but does not say it is **parsed**,
  or that free text after the phrase is fine. Doc-only follow-on.
- Dispatch now has **three** things to remember — worktree, pointer, and the plan's `in flight`
  header — which strengthens the deferred `/dispatch` command.
- Singular phrasing reads `- 1 epic awaiting dispatch: 05-slug.`; one line if uniform phrasing is wanted.

## Log
- 2026-08-19 — filed from GH #11, which was raised by testing the shipped epic 03 resolver
  against the plan-ahead workflow. Phase 0 confirmed the single-line cause (`plan_is_open`
  treats `approved` and `in flight` alike) and that both hooks share a byte-identical block.
- 2026-08-19 — items 1 and 2 dispatched **in parallel** (first real concurrent run), merged as
  PR #13 and #14 (merge commits 36f7656, c37343d), installed, and verified live: with a queued
  `approved` epic made newest by mtime, a real dispatch's telemetry landed in the IN-FLIGHT
  epic, and the installed session-start hook rendered `1 epic awaiting dispatch: 99-…`.
  Epic closed.

## Retro

**The first genuinely parallel dispatch, and it worked.** Two executors, two worktrees, two
branches, concurrent — with cleanly separated telemetry: one owner record and one
`agent-<id>.log` each, no interleaving, no collisions, both status files in the canonical tree.
In epic 01 this same configuration would have produced a single `main.log` with both executors'
calls interleaved, phantom stops marking items terminal at random, and orchestrator commits
landing on whichever branch an executor last switched to. Epics 02 and 03 existed to make this
possible; this is the first time it was used rather than described.

**Both items landed whole.** No splits, no scope negotiation, disjoint files exactly as planned.

**Mutation checking has become the standard, and it earned it twice.** Item 1's executor ran two
disjoint mutants; I rebuilt the precedence mutant independently and reproduced #11 exactly
(`exp=05-running got=06-queued`) across all three tool variants. My first attempt at that
mutation was itself botched — perl interpolated `$(` as its group-id variable and produced
garbage that still parsed — which is a small reminder that a check you didn't watch fail proves
nothing.

**An executor broke something, and the isolation held.** Item 2's harness bug committed its own
worktree mid-run. It recovered on its own branch, force-pushed with lease, and `main` was never
touched — independently verified at `42138c5`, clean tree, no stray artefacts. That is exactly
the failure worktree isolation (epic 02, GH #3) was built for, arriving unannounced.

**One scope call, ruled in the executor's favour.** Item 1's stated scope named
`executor-control-plane.md` only, but three sentences in `SKILL.md` described the fallback as
"the newest **open** plan" — which this change makes false. Shipping a documented lie is worse
than a 6-line diff outside the letter of the scope. It also added the instruction to set
`Status: in flight` at dispatch, which the resolver now reads — making that header load-bearing
rather than decorative.

**What this epic does not do.** It makes *queuing* safe — filing plans ahead without disturbing
what runs. It does **not** deliver multiple epics in flight at once: the resolver still picks
exactly one, and two simultaneous epics would still collapse to the newest in-flight. That
remains the multi-epic redesign.

**Deliberately not done.** No release tag; skill content, not a versioned artifact.
