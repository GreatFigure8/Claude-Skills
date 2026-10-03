# Moving computers

Jonathan sometimes switches machines mid-run. Nothing lives only in one machine's memory,
worktrees, or running agents: everything the other machine needs goes to `origin` as a
committed `handoff.md` per open run, and bmn reads those first when it starts.

## MOVE-OUT — Jonathan says "I'm moving computers" (or "switching machines", "move-computers")

Scope: every `docs/sprints/bmn-*` run in **this repo** whose `bmn.json` `phase` is not
`done`. Do these steps in order, with no questions:

1. **Settle running agents.** Let every in-flight bmn-worker return, because each one
   pushes its branch before it returns. If one has run for a long time with no milestone,
   stop it with `TaskStop`. Record its branch in the handoff as "interrupted: re-dispatch
   <brief> for <slug>", because its unpushed worktree work is lost.
2. **Push everything.** Push the run branch `<type>/<run-slug>` and every
   `wip/<run-slug>/*` story, fix, or test branch that has commits `origin` doesn't, and
   mark each one `pushed: true` in `temp_refs` so CLEANUP later deletes the remote copy.
   Never push `dev` or `main` as part of a move, and never deploy.
3. **Write `docs/sprints/bmn-<run-slug>/handoff.md`** from the template below, one per open
   run. Fill it from `bmn.json` and git, not from memory. Mark anything you didn't check
   against disk as *Claimed, not verified*.
4. **Mark the run moved.** Write `bmn.json` atomically with
   `"handoff": {"status": "open", "at": "<iso8601>", "from_host": "<hostname -s>"}`. Leave
   `phase` alone so the resume picks up exactly where the run stopped.
5. **Commit and push** the run folder on the run branch, in the run worktree, with the
   title `chore(bmn): hand off <run-slug> for a machine move`. Then confirm it landed with
   `git show origin/<type>/<run-slug>:docs/sprints/bmn-<run-slug>/handoff.md | head -3`.
   Then tidy this machine: remove the run worktree and each harness worktree in
   `temp_refs` (`git worktree remove`, no `--force`), and `git branch -D` every local run or
   `wip/` branch whose tip equals its `origin/` copy. Anything dirty or unpushed stays and is
   named in the handoff under *Left on <host>*. The main checkout is never touched.
6. **Other repos.** List any other repo under `~/Source/*` that has an open `bmn-*` run
   (`phase` ≠ `done`) but no open handoff. Don't write handoffs there: another session may
   own that checkout. Name those repos in the closing message so Jonathan can say "moving
   computers" in each of them.
7. **Close** with one short message listing each handed-off run as `<run-slug> — <phase> —
   next: <action>`, the other repos from step 6, and this one line:
   "On the other machine: pull `claude-skills`, update the dev-bother-me-nope plugin, open
   this repo, and start dev-bother-me-nope."

## MOVE-IN — every time dev-bother-me-nope starts

This check runs before INTAKE's resume check, on every invocation.

1. `git fetch --prune origin`.
2. Collect the open handoffs from both of these places:
   - every worktree (`git worktree list`): `docs/sprints/bmn-*/handoff.md`;
   - each remote branch `origin/<type>/<x>` with `<type>` in `feat|fix|hotfix|chore` and
     `<x>` one path segment: `git show origin/<type>/<x>:docs/sprints/bmn-<x>/handoff.md`
     (a branch without that file is a human branch — skip it). Also `origin/bmn/<x>`, for
     runs from before 1.4.0.
   A handoff is open when its `bmn.json` on that same ref has `handoff.status == "open"`.
   Deduplicate by run slug, keeping the newest `at`.
3. **No open handoffs:** continue normally (resume rule, then INTAKE).
4. **One or more open handoffs:** ask Jonathan with `AskUserQuestion`, in one question.
   This is a sanctioned exception to "no questions". Give one option per run, labelled
   `<run-slug>` and described as `<phase> · next: <action> · moved <date> from <host>`.
   Add an option "New story instead" when the objective named a new story, and an option
   "None — just list them". When there are more than three runs, offer the three newest and
   let "Other" take a slug.
5. **On a pick:**
   - Recreate the run worktree, never switching the main checkout:
     `git worktree add --track -b <type>/<run-slug> ../<repo-name>-<run-slug> origin/<type>/<run-slug>`
     (plain `git worktree add <path> <type>/<run-slug>` if the local branch exists). Write
     its path to `bmn.json` `worktree`. Harness worktrees from the other machine don't
     exist here; their `wip/` branches stay on origin until CLEANUP deletes them.
   - Re-ground from disk: verify every *Claimed, not verified* line, and confirm every branch
     the handoff lists exists on origin.
   - Re-dispatch any "interrupted" brief.
   - Write `bmn.json` with `handoff.status = "picked-up"`, `picked_up_at`, `to_host`.
     Rename `handoff.md` to `handoff-<YYYYMMDD-HHMM>.md` so the history stays and it's no
     longer open. Commit, push, and continue the run from `phase`.
   - The runs that weren't picked stay open, so the next start offers them again.
6. **On "New story instead":** start a new run. The open handoffs remain open.

## handoff.md template

```markdown
# Handoff — <run-slug>

**Moved:** <iso8601> from `<host>` · **Repo:** <origin url> · **Phase:** <phase>
**Run branch:** `<type>/<run-slug>` @ <sha> (pushed) · **wip branches on origin:** <list>
**dev_base:** <sha> · **Live:** dev

## Stories
| Story | Status | Branch @ sha | Notes |
| --- | --- | --- | --- |

## In flight when the move happened
- <agent/brief> for <slug> — returned / interrupted: re-dispatch <brief> on <branch>

## Verified (checked against git and disk just now)
- ...

## Claimed, not verified
- ...

## Left on <host>
- <worktree or branch> — <dirty / unpushed>; nothing else was left behind

## Exact next action
- <the step from SKILL.md and the brief to dispatch first>

## Deploy state
- Supabase dev applied: <files> · pending main: <files> · Vercel: nothing deployed

## Other machine needs
- Tooling the run depends on: <docker / supabase CLI / playwright / python version / GPU>
- Local-only state that does not travel: <.env names, local supabase data, model weights>
```
