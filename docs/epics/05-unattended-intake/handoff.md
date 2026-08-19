# Handoff — epic 05, unattended intake

**Written:** 2026-08-19 · **Branch (orchestrator):** main, clean, pushed
**Epic state:** in flight — item 1 executing, item 2 not started

## Where things actually are

- **Epics 01–04: closed and merged.** Backlog surfacing, executor attribution + worktree
  isolation, active-epic resolution, and the epic queue are all shipped, installed, and
  verified live. Parallel dispatch works (epic 04 ran two executors concurrently).
- **Epic 05 item 1** — branch `docs/unattended-intake-contract`, two commits pushed
  (`678820e` contract, `f1b619c` queue split preserved from a cancelled run). An executor is
  finishing verification and will open a PR. **No PR yet at time of writing.**
- **Epic 05 item 2** — not started. Re-planned around `claude setup-token`.

## Verified

- Items 1's two commits are pushed; worktree clean at `f1b619c`.
- The cancel gate works for real: item 1's first executor was cancelled by scoped sentinel,
  stopped cleanly, and the orchestrator was never gated. Sentinel removed.
- `claude setup-token` exists and is subscription-backed (not API-metered).

## Claimed but NOT verified

- Item 1's harness results. The cancelled run reported `session-start` 125/0 and a 4-case
  intended delta against epic 04's unchanged harness, but **never completed** the three
  regression harnesses (`active-epic` 380, `lifecycle` 107, `cancel-gate` 111). The resumed
  executor was told to run them to completion. Do not merge item 1 without seeing them pass.
- `f1b619c` was committed by the orchestrator to preserve interrupted work. It is unreviewed.

## Exact next action

1. When item 1's executor returns: verify cold (diff scope, three regressions to completion,
   byte-identity of the injection when both queues are empty), then merge, install, land-and-reset.
2. **Jonathan's step before item 2 can be dispatched:** run `claude setup-token`, then put the
   token in `~/.config/claude-intake/env` as `CLAUDE_CODE_OAUTH_TOKEN=...`, file mode 0600.
   Claude does not handle the token value.
3. Then dispatch item 2 (local scheduled runner) into its own worktree.

## Open tracker items

- #16 epic 05 source · #15 harness sandbox guard · #12 branch-name cancel selectors

## Live state

- Worktree `../claude-skills-docs-unattended-intake-contract` on `docs/unattended-intake-contract`.
- Pointer `.claude/signals/active-epic` = `05-unattended-intake`.
- Nothing installed since epic 04; `~/.claude/hooks/` matches `main`.
