# Moving computers

Jonathan sometimes switches machines mid-run. Nothing lives only in one machine's memory,
worktrees, or running agents: everything the other machine needs goes to `origin` as a
committed `handoff.md` per open run, and bmn reads those first when it starts.

## MOVE-OUT — Jonathan says "I'm moving computers" (or "switching machines", "move-computers")

Scope: every `docs/sprints/bmn-*` run in **this repo** whose `bmn.json` `phase` is not
`done`, `blocked` or `decision` (a run waiting for the release decision has nothing in flight:
its state is already on `dev`, and the next start asks the question again). Do these steps in order, with no questions:

1. **Settle running agents.** Let every in-flight bmn-worker return, because each one
   pushes its branch before it returns. If one has run for a long time with no milestone,
   stop it with `TaskStop`. Record its branch in the handoff as "interrupted: re-dispatch
   <brief> for <slug>", because its unpushed worktree work is lost.
2. **Push everything.** Push the sprint branch (`integration` in `bmn.json`, `sprint/<run-slug>`;
   `<type>/<run-slug>` for a run from before 2.0.0) and every
   `wip/<run-slug>/*` story, fix, or test branch that has commits `origin` doesn't, and
   mark each one `pushed: true` in `temp_refs` so CLEANUP later deletes the remote copy.
   Never push `dev` or `main` as part of a move, and never deploy.
3. **Write `docs/sprints/bmn-<run-slug>/handoff.md`** from the template below, one per open
   run. Fill it from `bmn.json` and git, not from memory. Mark anything you didn't check
   against disk as *Claimed, not verified*.
4. **Mark the run moved.** Write `bmn.json` atomically with
   `"handoff": {"status": "open", "at": "<iso8601>", "from_host": "<hostname -s>"}`. Leave
   `phase` alone so the resume picks up exactly where the run stopped.
5. **Commit and push** the run folder on the sprint branch, in the run worktree, with the
   title `chore(bmn): hand off <run-slug> for a machine move`. Then confirm it landed with
   `git show origin/<integration>:docs/sprints/bmn-<run-slug>/handoff.md | head -3`.
6. **Tidy this machine** with the helper, run from the main checkout (`--repo <main checkout>`,
   never from a worktree it may remove), once per branch. It never touches the origin copy,
   which the other machine and CLEANUP still need:
   - the sprint branch `<integration>` and every local `wip/<run-slug>/*` branch pushed in
     step 2: `python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py --repo <main checkout> --branch <branch> --target origin/<branch> --pushed`
   - each `temp_refs` harness branch: `python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py --repo <main checkout> --branch <harness branch> --target origin/<integration> --local-only`

   The helper removes every worktree on the branch (the run worktree and each harness
   worktree included, no --force), then deletes the local branch, but only once git proves
   its tip is on origin (`--pushed`) or in the pushed sprint branch (harness). It keeps a worktree
   with uncommitted or untracked files, a locked one, and one holding any ignored file other
   than regenerable build output (a `.env` stays); it keeps a branch whose rebase or bisect is
   running; each is listed in `left` with its reason. Name every kept item and its reason in
   the handoff under *Left on <host>* and in the closing message; `origin:<branch>` entries are
   the origin copies it kept on purpose, not work left behind. A refused call (exit 2) counts as
   kept, with the error as the reason. Never run `git worktree remove`, `git branch -D` or
   `git worktree prune` by hand for this tidy: git deletes ignored files such as `.env`
   without warning. The main checkout is never touched.
7. **Other repos.** List any other repo under `~/Source/*` that has an open `bmn-*` run
   (`phase` not `done`, `blocked` or `decision`) but no open handoff. Don't write handoffs there: another session may
   own that checkout. Name those repos in the closing message so Jonathan can say "moving
   computers" in each of them.
8. **Close** with one short message listing each handed-off run as `<run-slug> — <phase> —
   next: <action>`, what step 6 kept on this machine, the other repos from step 7, and this one line:
   "On the other machine: pull `claude-skills`, update the dev-bother-me-nope plugin, open
   this repo, and start dev-bother-me-nope."

## MOVE-IN — every time dev-bother-me-nope starts

This check runs before INTAKE's resume check, on every invocation.

1. `git fetch --prune origin`.
2. Collect the open handoffs from both of these places:
   - every worktree (`git worktree list`): `docs/sprints/bmn-*/handoff.md`;
   - each remote branch `origin/sprint/<x>` with `<x>` one path segment:
     `git show origin/sprint/<x>:docs/sprints/bmn-<x>/handoff.md` (a branch without that file
     is a human sprint branch — skip it). Also `origin/<type>/<x>` with `<type>` in
     `feat|fix|hotfix|chore`, for runs from 1.4.0 to before 2.0.0, and `origin/bmn/<x>`, for
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
     `git worktree add --track -b <integration> ../<repo-name>-<run-slug> origin/<integration>`
     (plain `git worktree add <path> <integration>` if the local branch exists). Write
     its path to `bmn.json` `worktree`. Harness worktrees from the other machine don't
     exist here, and merged `wip/` branches are already deleted (local, origin and worktrees)
     when the merger merged them; only unmerged ones remain on origin.
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
**Sprint branch:** `<integration>` @ <sha> (pushed) · **wip branches on origin:** <list>
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
- Supabase dev applied: <files> · waiting for the release (main): <files> · Vercel: nothing deployed

## Other machine needs
- Tooling the run depends on: <docker / supabase CLI / playwright / python version / GPU>
- Local-only state that does not travel: <.env names, local supabase data, model weights>
```
