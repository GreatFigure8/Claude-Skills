# Session Handoff — 21-session-scoped-issue-loop / between items

**Written:** 2026-09-10T00:00:00Z
**Epic:** docs/epics/21-session-scoped-issue-loop
**Branch:** main (pushed: yes)
**Last commit:** 2f791a8 docs(epic): file 21-session-scoped-issue-loop plan
**Worktree:** main checkout

## Verified this session
- `epic-loop.sh`, `autonomy.sh`, `dispatch.sh`, `phase-session.sh`, `verify-item.sh` all
  live in `Skills/dev-epic-workflow/assets/claude-config/bin/` (shared skill infra, not
  repo-local) — verified by direct reads via subagent this session.
- `epic-loop.sh` is single-pass only (`--once`); no continuous/self-pacing mechanism
  exists anywhere in the repo — verified by grep for `ScheduleWakeup`/self-pacing/
  dynamic-loop, zero hits.
- Zero `gh issue create` calls in any `bin/`/hook code — verified by repo-wide grep.
- `main` and `dev` had zero divergence in `main`'s favor (`dev` was a clean 28-commit
  fast-forward ahead) — verified via `git log --oneline main..dev` / `dev..main` before
  merging.
- `main` fast-forwarded to `dev`'s tip, tagged `pre-loop-redesign` at the prior `main`
  commit (`6a9fb40`) first, pushed; `dev` deleted locally and on `origin` — verified by
  the fast-forward and push output this session.
- Epic 21's plan committed (`2f791a8`) and pushed to `origin/main` — verified by push
  output (`0c1bf3e..2f791a8`).
- `.gitignore` already covers `.claude/signals/`, `docs/epics/*/status/`,
  `docs/epics/*/CANCEL` — verified by grep, no change needed.

## Claimed but NOT yet verified
- The specific file:line citations in the plan's Grounding section and Item 1's Touches
  list (exact functions/line numbers in `autonomy.sh`, `dispatch.sh`, `phase-session.sh`,
  `epic-loop.sh`, `verify-item.sh`) are as reported by investigation subagents this
  session — not independently re-checked by the orchestrator against the files directly.
- Epics 11's and 19's plan.md header text beyond "epic 19: in flight (item 8 of 8)" —
  not re-read in full this session; Item 1 of epic 21 should read both in full before
  writing their closing retros.
- Whether stale worktrees remain under `.claude/worktrees/` from epic 19's items
  (several were listed at this session's start, including one locked on
  `feat/epic-loop-entry-and-live-proof`) — not re-checked after the `dev`→`main`
  collapse. These likely need `git worktree remove` + prune before or during Item 1,
  since the branches they point at either merged already or belonged to now-superseded
  epic 19 item 8.

## Exact next action
Dispatch Item 1 of epic 21 ("Retire the promotion-ladder and daemon-trigger surface") —
read `docs/epics/21-session-scoped-issue-loop/plan.md` Item 1 in full, check
`.claude/worktrees/` for stale epic-11/epic-19 worktrees and clean them up first, then
dispatch a `work-item-executor` on branch `refactor/retire-autonomy-ladder` from `main`.

## Environment state
- No worktrees currently active for epic 21 (nothing dispatched yet this epic).
- A peer interactive session (`claude-skills-5a`, seen via `ListAgents` this session) may
  still be running against this same shared checkout — verify it isn't mid-git-operation
  before the next dispatch.
- No running services, no applied-but-unmerged migrations, no env vars/tunnels set.

## Open questions for Jonathan
- None — the design decisions (replace vs. add, harm-floor definition, issue-filing
  dedup/attribution, integration-testing scope) were all resolved in this session's
  conversation and are captured directly in the plan.
