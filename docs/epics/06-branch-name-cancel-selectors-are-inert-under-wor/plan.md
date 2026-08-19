# Epic: branch-name cancel selectors resolve through status.json ownership

**Status:** planning
**Source:** GH #12
**Live branch:** main   **Integration branch:** main   **Pre-epic tag:** n/a

## Outcome
A branch name written into a `CANCEL` sentinel cancels that item's executor even under
worktree dispatch, by resolving the branch to its owning `agent_id` via the epic's
`status/*.json` files — the same ownership binding agent-id selectors already rely on,
minus the step of digging an agent id out of a marker file or a `SUBAGENT START` bracket
first.

## Grounding
- **Verified:** `cancel-gate.sh` (lines 94-98, 130-132) — `LEGACY_BRANCH` is populated only
  when `git worktree list` reports exactly one checkout, so a branch-name selector matches
  only under direct (single-checkout) dispatch. Under worktree dispatch it is compared
  against nothing and can never match.
- **Verified:** `cancel-gate.sh` always runs with cwd = `CLAUDE_PROJECT_DIR`, and per its own
  header comment (also cross-referenced in `references/executor-control-plane.md`) this is
  "the orchestrator's checkout" for every hook invocation, regardless of which agent's tool
  call triggered it. That's what already makes `docs/epics/*/CANCEL` and
  `.claude/signals/*` sentinel reads reliable under worktree dispatch, and it's also exactly
  why a `git branch --show-current` comparison in that same cwd can never read an executor's
  branch — the fixed cwd is the root cause the issue describes, not a bug to route around.
- **Verified:** `work-item-executor.md`'s status contract (lines 40-51) — the executor writes
  `item`, `branch`, `state`, `detail`, `commit`, `updated` into
  `status/<branch-slug>.json`, always resolved to the canonical repo root (its own
  `git rev-parse --git-common-dir` computation), which is the same directory `cancel-gate.sh`
  already operates in.
- **Verified:** `subagent-tool-logger.sh` (lines 202-234) and `subagent-lifecycle.sh`'s
  `json_claim`/`json_owner` — a status file gets `agent_id` bound to it either when the
  owning agent's own tool call names the file, or, failing that, at `SubagentStop` for an
  unowned file touched during that agent's life when it was the sole live executor. Binding
  is best-effort: a status file can exist with `branch` set and no `agent_id` yet (before
  binding lands), and in principle two files could both carry the same `branch` value.
- **Verified:** `references/executor-control-plane.md` (Layer 2, and the "Residual
  limitation" paragraph under Dispatch conventions) and epic 02's Deferred list already
  describe this exact gap and already name `status.json`'s `branch` + `agent_id` pair as the
  fix — this item implements a documented, anticipated follow-on, not new design.
- **Verified:** `hooks/tests/cancel-gate-fixtures.sh` (lines 200-206) — the current
  worktree-mode branch-selector cases assert *inert* (exit 0) against a fixture repo that has
  no `status/` directory at all. They exercise "no bound status file exists yet", not "a
  bound file exists and should still be ignored."
- **Assumed:** no file besides the three above (`cancel-gate.sh`,
  `executor-control-plane.md`, `cancel-gate-fixtures.sh`) documents the current inert
  behavior as user-facing contract. The closed epic plans (02, 03, 05) that mention it are
  historical record of what was true when they were written and are deliberately left
  unedited by this epic.

## Invariants
- The orchestrator is never denied by any sentinel shape, including the new resolution path.
- The gate fails open on a malformed, unreadable, or missing status file — never crashes,
  never denies on ambiguous input.
- The fast path (no sentinel present, or no `agent_id` in the hook payload) does zero extra
  filesystem work — the new lookup runs only once a selector line has already failed every
  cheaper match.
- Existing agent-id and direct-mode (`LEGACY_BRANCH`) selector behavior is unchanged.

## Work items

### 1. Resolve branch selectors via status.json ownership
- **Branch:** `fix/cancel-branch-selector-status-lookup`
- **Depends on:** none
- **Scope:**
  - `cancel-gate.sh`: for a selector line that fails the caller's agent-id match
    (exact/slug/prefix) and fails `LEGACY_BRANCH`, scan `docs/epics/*/status/*.json` for
    files whose `"branch"` value equals the selector and whose `"agent_id"` is present and
    non-empty — plain `grep -oE`/`sed` field extraction (no `jq`/`python3` dependency),
    mirroring the `json_owner` pattern already used in `subagent-lifecycle.sh`. Exactly one
    such file → deny if its `agent_id` equals the caller. Zero matches, or more than one
    (ambiguous) → no match, fall through. The scan is global across every epic's `status/`
    tree, not scoped to the triggering sentinel's own epic folder — consistent with how
    agent-id selectors already aren't epic-scoped either.
  - Update the header comment in `cancel-gate.sh` to describe the resolved worktree-dispatch
    behavior and drop the "ignored by design" framing for that case.
  - `references/executor-control-plane.md`: update the Layer 2 branch-selector bullet, and
    replace the "Residual limitation" paragraph under Dispatch conventions with a short note
    that it's resolved, keeping the GH #12 cross-reference for history.
  - `hooks/tests/cancel-gate-fixtures.sh`: add `status.json` fixtures under the `$ORCH`
    epic's `status/` dir and new cases —
    (a) a file bound to `$AGENT_ID` with `branch: fix/item-a` → sentinel `fix/item-a` denies
        `$AGENT_ID`'s call;
    (b) the same file, called by `$OTHER_ID` → allow;
    (c) two files both claiming `branch: fix/item-a` for different agents → sentinel
        `fix/item-a` → allow for both (ambiguous, no match);
    (d) a file with `branch` set but no `agent_id` (unbound) → allow;
    (e) a malformed / non-JSON status file → allow, no crash.
    The existing case "worktree mode: item branch name (ignored by design)" keeps its `0`
    expectation (still correct at that point in the fixture — no bound file exists yet) but
    gets relabelled to reflect the new reasoning ("no bound status file" rather than
    "ignored by design").
- **Not in scope:** special-casing branch resolution differently for `.claude/signals/cancel`
  vs. an epic-scoped `CANCEL` file (the global scan already covers both uniformly); sharing
  the JSON-field-extraction helpers across `cancel-gate.sh`, `subagent-lifecycle.sh`, and
  `subagent-tool-logger.sh` in a fourth sourced file (already deferred in epic 02, unrelated
  to this fix); any change to how `status.json` ownership binding itself happens
  (`json_claim`, the sole-live-executor heuristic) — this item only reads that binding, it
  doesn't change how it's produced.
- **Definition of done:** `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/cancel-gate-fixtures.sh`
  passes, 0 failures, with the new cases included, across all three parser tiers
  (`full`/`nojq`/`bare`); a branch name written into a `CANCEL` sentinel cancels exactly the
  executor whose bound `status.json` claims that branch under worktree dispatch; an unbound
  or ambiguously-claimed branch name matches nothing (allow); the orchestrator's own calls
  are never denied under any of the new fixture cases.
- **Verification:** run the fixture harness and confirm `cases: N failures: 0`; grep
  `cancel-gate.sh` for the old "ignored by design" framing in the worktree-dispatch context
  and confirm it no longer describes current behavior; hand-trace one `full`-tier and one
  `bare`-tier new fixture case against the updated script.
- **Rollback:** revert the merge commit — the change is additive (one new resolution branch
  inside the existing per-selector loop, plus its fixture cases and two doc paragraphs), with
  no status-file schema change and no change to how or when `agent_id` gets bound.

## Sequence
Single item, no dependencies.

## Risks
| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| Global (cross-epic) scan matches a stale `status.json` left over from an older, uncleaned-up epic that happens to share a branch-slug name | Low | One wrong deny — immediately visible (the executor reports a cancellation) and loss-free to recover from (Layer 2 cancellation never loses pushed work) | Ambiguity (two files claiming the branch) still falls to no-match by design; a single stale-but-bound file is indistinguishable from a live one on purpose — accepted, since Phase 5 close already removes an epic's `status/` tree, so this needs a genuinely skipped cleanup to occur |
| The added scan slows the hot path (every executor tool call passes through this gate) | Low | Latency on every gated tool call | Scan triggers only after a selector has already failed the agent-id and legacy-branch checks — i.e. only when a sentinel is armed with a selector that isn't a recognized agent id, already a rare path |
| `grep -oE` field extraction diverges from how `json_claim`/the executor actually encode a value (e.g. an escaped character in a branch name) | Low | A legitimate selector silently fails to resolve (fails open to allow, not a false deny) | Git ref names can't contain unescaped `"`, and the same extraction pattern already works for `agent_id` elsewhere in this codebase |

## Deferred / out of scope
- Sharing the JSON-field-extraction helpers across `cancel-gate.sh`, `subagent-lifecycle.sh`,
  and `subagent-tool-logger.sh` in a fourth sourced file — carried over from epic 02's
  Deferred list, still not blocking.
- Any change to how `status.json` ownership binding itself happens — this item only reads
  the existing binding.

## Log
- Plan drafted via unattended intake from GH #12; not yet approved.
