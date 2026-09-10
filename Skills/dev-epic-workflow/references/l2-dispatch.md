# L2 dispatch — retired

**Retired (epic 21 item 1, 2026-09-10).** This file documented `bin/dispatch.sh`'s
`dispatch_repo`: a headless cycle that cut a worktree, pushed it, invoked
`claude -p --agent work-item-executor` unattended and opened the resulting pull request
whenever a repo's autonomy-ladder level resolved to the exact rung `L2`. Epics 11 and 19
are both closed, with a retro pointing here — see their plans for the full history of what
was built and why.

`dispatch_repo` now always refuses. Nothing in `dispatch.sh` spawns a subprocess or opens a
pull request unattended any more. Epic 21's Outcome replaces it with a session-scoped loop
(item 3) that only ever runs inside a live, already-authenticated interactive session —
dispatching each work item through the same orchestrated `work-item-executor` path an
attended session already uses, not through a headless `claude -p` invocation.

## What survives in `dispatch.sh`, and why

Several functions had no dependency on the retired ladder and are still called by other
live files, so they were kept rather than deleted with the daemon path:

| Function | Still called by |
|---|---|
| `dispatch_brief`, `dispatch_allowed_tools` | `phase-session.sh`'s drafting utility, `verify-item.sh` |
| `dispatch_read_executor_status` | `epic-loop.sh`, `verify-item.sh` |
| `dispatch_check_diff`, `dispatch_gate_brief` | reusable denylist/size-ceiling and gate-set preview, available to epic 21 item 2's harm floor |
| `dispatch_work_items`, `dispatch_select`, `dispatch_plan_state`, `dispatch_plan_source` | this file's own read-only CLI |

## Reading it without a session

The CLI is unchanged and remains entirely read-only — there was never a `--dispatch` flag,
and there still isn't:

```bash
bin/dispatch.sh --check --repo <path> --slug <owner/name>
bin/dispatch.sh --plan <plan.md>
bin/dispatch.sh --select --repo <path> --slug <owner/name> --epics-dir <dir>
bin/dispatch.sh --deny --repo <path> --slug <o/n> --worktree <wt> --base <ref>
```

## What comes next

See `docs/epics/21-session-scoped-issue-loop/plan.md` — item 2 defines the harm floor that
replaces the ladder's role as an in-flight brake, and item 3 is the session-scoped driver
that dispatches work items from inside a live session.
