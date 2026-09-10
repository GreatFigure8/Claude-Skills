---
description: Start (or stop, or inspect) the session-scoped autonomous issue loop on one repo — drafts, dispatches, verifies, harm-checks, merges, chains and closes admitted issues with no approval stop, until you say stop
allowed-tools: Bash(git:*), Bash(gh:*), Bash(ls:*), Bash(date:*), Bash(session-loop.sh:*), Read, Write, Edit, Glob, Grep, Task, ScheduleWakeup
argument-hint: [repo path or name, or "stop" / "status" / "preview" — e.g. "~/Source/LODE", "stop"]
---

Run the session-scoped issue loop from the dev-epic-workflow skill. **Read
`references/session-loop.md` before the first action** — it is the contract, this command
is only the entry point. Execute every step yourself; never hand Jonathan a command to run.

**Starting the loop is the grant of full autonomy for this session and this repo.** From
`--start` onward there is no approval stop: the loop drafts, dispatches, verifies, merges,
chains and closes without asking again. The only in-flight brake is the harm floor, and
the driver runs it — do not add a confirmation step the contract does not have, and do not
skip one it does.

`$ARGUMENTS` routes:

- **`stop`** → `session-loop.sh --stop --repo <bound repo>`, then report in one line where
  things stand (last action, active issue, any PR left open for a human) and stop
  scheduling wakeups. Nothing else.
- **`status`** → `session-loop.sh --status --repo <path>` and report it. No actions.
- **`preview`** / **`dry-run`** → `session-loop.sh --next --repo <path> --dry-run` and
  report it verbatim. It is a preview of the shape, not a claim about permission.
- **a repo path or name, or empty** → start the loop on it (below). Empty means the current
  repo; a name that is not a path resolves under `~/Source/`. If it resolves to more than
  one checkout, ask once — a loop bound to the wrong repo merges to the wrong repo.

## Starting

1. `git remote get-url origin` and `gh auth status` — GitHub only; the loop's admission,
   dispatch and close paths are all `gh`. Report what is missing and stop rather than
   half-starting.
2. `session-loop.sh --start --repo <path>`. A refusal here (a loop already bound to
   another checkout) is final — report it and stop. One loop, one repo, one live session.
3. `session-loop.sh --admit --repo <path>` — the admitted and parked issues, with reasons.
4. State in **one line**: repo, how many issues are admitted, and that the loop will merge
   and chain without asking again. This is a statement, not a question — do not wait for
   an answer.
5. Enter the turn cycle.

## The turn cycle — one wakeup, one action

Per turn, and nothing else:

1. `session-loop.sh --next --repo <path>`.
2. Perform exactly the printed `action`, per `references/session-loop.md`:
   `draft` · `dispatch` · `verify` · `merge` · `close` · `poll` · `blocked` · `halt` ·
   `stop`. For anything but `poll` and `stop`, the harm floor already cleared it.
3. `session-loop.sh --record --repo <path> --issue N --state <s> [--item I] [--branch B]
   --detail "<what happened>"`.
4. Call **`ScheduleWakeup`** with the `wake-in` seconds the driver printed, and end the
   turn. Never `sleep` in Bash — a blocking wait cannot be interrupted by Jonathan typing
   stop, and a scheduled wakeup can.

## While it runs

- **Visible text only for**: a `blocked`/`halt` action, something that changes the shape of
  the work, and the **model table** every dispatch owes (one row per agent, Model column
  mandatory). The ledger, the status files and the commit stream are the progress channel.
  A running commentary on a multi-hour loop is re-billed on every remaining turn.
- **Never merge without the driver naming `merge`**, never dispatch a `no-work` or
  `needs-decision` plan, never resolve a `needs-decision`, never auto-close a `no-work`,
  never retry a failed verifier verdict or a blocked executor. Chain past them.
- **A stop, in any phrasing, halts before the next action.** Run `--stop`, report, end.
