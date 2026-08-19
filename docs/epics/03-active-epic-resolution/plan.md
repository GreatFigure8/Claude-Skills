# Epic: active-epic resolution

**Status:** approved
**Source:** GH #9
**Live branch:** main   **Integration branch:** main   **Pre-epic tag:** n/a

## Outcome
The control-plane hooks write telemetry to the epic that is actually in flight, decided by
an explicit signal rather than by which `plan.md` happened to be touched most recently.
Editing an old or closed epic's plan — a normal, legitimate act — no longer redirects a
running executor's status and logs into it.

## Grounding
- **Verified (code, current `main`):** both hooks still resolve the epic by mtime —
  `EPIC_PLAN="$(ls -t "$REPO_ROOT"/docs/epics/*/plan.md | head -1)"` at
  `subagent-lifecycle.sh:107` and `subagent-tool-logger.sh:85`. Epic 02 item 3 fixed the
  *root* resolution (`REPO_ROOT` via `--git-common-dir`) but deliberately left epic
  selection alone.
- **Verified (observed):** during epic 02 item 1, the executor legitimately edited epic 01's
  `plan.md` (retro correction), making the **closed** epic 01 newest. Two `SUBAGENT STOP`
  brackets (17:00:03Z, 17:07:19Z) were written into
  `docs/epics/01-session-start-backlog-check/status/main.log` while epic 02 was the epic in
  flight — its own bracket landed at 17:09. One dispatch's telemetry split across two epic
  folders.
- **Verified (format):** every plan carries a uniform, parseable `**Status:** <state>` line
  on line 3; the closed marker is exactly `**Status:** closed`.
- **Verified (layout):** `.claude/signals/` already exists and is gitignored, alongside
  `docs/epics/*/status/` and `docs/epics/*/CANCEL`.
- **Verified (behaviour):** with no epic resolvable, both hooks already exit 0 silently —
  the degrade-to-nothing path exists and must be preserved.
- **Verified (state):** all seven installed hooks are byte-identical to `main`; both existing
  epics are closed, so today nothing is resolvable as "in flight" at all.
- **Assumed:** `CLAUDE_PROJECT_DIR` and `REPO_ROOT` resolve to the same directory in worktree
  dispatch (observed true in epic 02, where `CLAUDE_PROJECT_DIR` was the main checkout).
  The pointer should be written and read relative to `REPO_ROOT` regardless, so the hooks
  never depend on that coincidence.

## Invariants
- Hooks fail open and stay silent: no resolvable epic, unreadable pointer, malformed plan →
  exit 0, no telemetry, no error. Never fail a session or a subagent.
- No new dependency: correct with `jq` absent, `python3` absent. Runs under bash 3.2.
- Epic 02's attribution behaviour is untouched: `cancel-gate.sh` unchanged, ownership
  stamping and per-agent log naming unchanged.
- Runtime state stays gitignored; the pointer is never committed.

## Work items

### 1. Explicit active-epic signal, with a closed-aware fallback
- **Branch:** `fix/active-epic-resolution-pointer`
- **Depends on:** none
- **Scope:** `subagent-lifecycle.sh` and `subagent-tool-logger.sh` — replace bare mtime
  selection with, in order: (a) an explicit pointer file under `REPO_ROOT` (proposed
  `.claude/signals/active-epic`, holding the epic folder name or path) when it exists and
  resolves to a real epic directory; (b) otherwise the newest `plan.md` whose `**Status:**`
  is **not** `closed`; (c) otherwise nothing, exiting 0 silently as today. Then the
  orchestrator side: `SKILL.md` Phase 3 step 2 (dispatch setup, where the worktree is
  created) writes the pointer, and Phase 5 removes it at epic close; mirror into
  `references/executor-control-plane.md` runtime-state and dispatch-conventions sections;
  add the pointer to the repo `.gitignore` guidance if `.claude/signals/` does not already
  cover it (it does — confirm rather than duplicate).
- **Not in scope:** binding the owning agent at dispatch time (epic 02's deferred stamping
  gap); restoring branch-selector cancel granularity; any change to `cancel-gate.sh`,
  sentinel semantics, the `status.json` milestone vocabulary, or per-agent log naming.
- **Definition of done:**
  - Pointer present and valid → telemetry lands in that epic even when another epic's
    `plan.md` is newer.
  - Pointer absent, one open + one closed epic, **closed one touched most recently** →
    telemetry lands in the open epic. (This is the exact observed failure.)
  - Pointer absent, two open epics → newest open plan wins, closed ones never considered.
  - Pointer pointing at a nonexistent or deleted epic → falls back to (b), does not error.
  - No open epic and no pointer → exit 0, nothing written, no stderr.
  - Malformed plan with no `Status:` line → treated as open (fail toward writing telemetry
    rather than silently losing it), and still exit 0.
  - `jq` and `python3` both absent → identical behaviour.
  - Runs under `/bin/bash` 3.2.
- **Verification:** a committed fixture harness in the shape of the existing
  `hooks/tests/*-fixtures.sh`, driving each condition in a disposable sandbox with real
  status trees, plus `bash -n` over every script, plus re-running both existing harnesses
  (`cancel-gate-fixtures.sh`, `lifecycle-fixtures.sh`) unchanged as regression. Paste real
  output per condition. **Live verification after install** is the orchestrator's, on the
  next real dispatch.
- **Rollback:** revert the merge commit, re-run `install.sh --user`. Worst case resolution
  reverts to mtime, which is today's behaviour — degraded, not destructive.

## Sequence
Single item.

## Risks
| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| A resolution bug silently sends telemetry nowhere | Medium | Observability lost; work still safe (these are SubagentStart/Stop + PostToolUse hooks, not `PreToolUse` — they cannot deny a tool call) | Fixture per branch of the decision; "no `Status:` line" fails toward writing, not skipping |
| Pointer goes stale after epic close and misdirects the next epic | Medium | Telemetry into a closed epic — the very bug being fixed | Phase 5 removes it; a pointer to a missing dir falls back; consider ignoring a pointer whose plan reads `closed` |
| Orchestrator forgets to write the pointer | High (human step) | Falls back to closed-aware mtime — still correct in the observed case | The fallback is the real fix; the pointer is the precision layer, not the safety net |
| Divergence between the two hooks' resolution logic | Medium | Lifecycle and logger disagree about the epic | Identical resolution block in both, asserted by a fixture that runs both and compares |

## Deferred / out of scope
- Epic 02 follow-on: bind the owning agent at dispatch so multi-executor stamping cannot go
  unbound. Related — a dispatch record could carry both — but it needs a claim protocol
  (the orchestrator cannot know `agent_id` before `SubagentStart`), so it is its own item.
- Epic 02 follow-on: map a branch selector back to its owning agent to restore branch-scoped
  cancel under worktrees.
- The `agent_id` extraction block now exists in three copies; sharing needs a fourth file
  and a sourcing dependency.
- `references/stack-gates.md` still has no shell/hook section, now with two harnesses as the
  concrete shape.
- Azure DevOps twin of the backlog query, and `Source: AB#<n>` in the correlation grep.

## Log
- 2026-08-19 — filed from GH #9, found during epic 02's Phase 5 cleanup. Phase 0 confirmed
  the mtime selection survives epic 02 untouched, and that the `Status:` marker is uniform
  enough to drive a closed-aware fallback.
