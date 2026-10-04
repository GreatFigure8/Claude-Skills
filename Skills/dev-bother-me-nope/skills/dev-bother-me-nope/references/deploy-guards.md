# Deploy and merge guards — Vercel, Supabase, git

Jonathan decides every deploy. This file is what "never deploy" means concretely, what the
hook blocks, and how the report hands the decision back to him.

## Never, without Jonathan saying so in chat this session

**Vercel** — every deploy is Jonathan's, dev included ("deploy to dev" = a real Vercel
deployment to the dev environment, e.g. `vercel deploy --target=<dev env>`).
- `vercel` with no subcommand (it deploys), `vercel deploy`, `vercel --prod`, `vercel promote`,
  `vercel rollback`, `vercel redeploy`, `vercel alias`, `vercel env add|rm` (changes a live
  project), `vercel remove`.
- Any Vercel MCP tool whose name contains `deploy`, `promote`, `rollback` or `alias`.
- `git push` to `main`, `master`, `prod`, `production`, `release` — the production branch.

Allowed: `vercel dev`, `vercel build`, `vercel pull`, `vercel env pull`, `vercel ls`,
`vercel inspect`, `vercel logs`, `vercel whoami`, `vercel link`, `vercel --version`.

- A git push that makes Vercel build. The run pushes `dev`, its run branch
  `<type>/<run-slug>` and `wip/<run-slug>/*` often, so INTAKE sets
  `git.deploymentEnabled: {"dev": false, "wip/**": false, "bmn/**": false,
  "<type>/<run-slug>": false}` in every Vercel app's `vercel.json` as the run branch's
  first commit, before its first push. The run branch is keyed by exact name so human
  `feat/*`/`fix/*` branches still get previews; CLEANUP drops that key in its final commit
  to `dev`. `ignoreCommand` is not used: Vercel still creates the deployment and cancels
  it, and cancelled builds count against deployment quotas and build slots. The guard
  can't see Vercel's git integration. This setting is what enforces it.

**Supabase** — there are always two projects, `dev` and `main`.
- **DEV (allowed, migrations only):** `supabase db push` / `migration up` is allowed when
  the target is provably the dev ref. That means the repo's `.claude/bmn.config.json` names
  both `dev_ref` and `main_ref`, they differ, and either the linked ref
  (`supabase/.temp/project-ref`, or a `supabase link --project-ref` earlier in the same
  command) equals `dev_ref`, or `--db-url` contains `dev_ref` and not `main_ref`. Otherwise
  it's blocked. DB-SYNC also holds back migrations that destroy data (a procedure rule, not
  something the guard checks).
- **MAIN (never)** and **both projects** for everything else:
- `supabase db push`, `supabase migration up` against anything but the dev ref, any
  `--linked` / `--db-url` mutation (`db reset --linked`, `migration repair`), `supabase
  functions deploy`, `supabase secrets set|unset`, `supabase config push`,
  `supabase branches create|delete`.
- `psql`/`pg_restore` against a `*.supabase.co` or `*.pooler.supabase.com` host, or via a
  connection variable whose name mentions SUPABASE/PROD/MAIN/REMOTE. (A plain
  `$DATABASE_URL` is assumed local; the briefs keep workers on local DBs.)
- Supabase MCP `apply_migration`, `deploy_edge_function`, `create_branch`, `merge_branch`,
  `reset_branch`, `rebase_branch`, `delete_branch`, `pause_project`, `restore_project`,
  `create_project`, and `execute_sql` unless the statement is read-only
  (`select` / `with … select` / `explain` / `show`).

Allowed: `supabase start|stop|status`, `supabase db reset` (local), `supabase migration new`,
`supabase db diff` (local), `supabase gen types --local`, `supabase test db`,
`supabase link` (records the ref, changes nothing remote).

The `BMN_USER_APPROVED_DEPLOY=1` pass-through works on trust: it catches accidents, it does
not stop an agent that decides to type it. Briefs forbid workers from ever using it; only the
orchestrator may, and only after Jonathan's chat instruction.

## Merge commits only — no squash merges, PR merges delete their branch

Jonathan's standing rule: history stays, and a merged PR's source branch goes. While a run is
active the hook's second rule family (the *merge guard*) refuses every squash merge and every
`gh pr merge` that would leave its source branch on origin. A merge-guard refusal begins
`Blocked by dev-bother-me-nope merge guard:` and names the allowed forms.

**Blocked**
- `git merge --squash`, `git pull --squash` (also `git -C <dir> merge --squash`, `--no-ff
  --squash`, and git's abbreviations such as `--squ`; the last of `--squash` / `--no-squash`
  wins).
- `gh pr merge --squash` and `-s`, alone or in a cluster (`-sd`, `-ds`), and `--squash=true`.
- Any `gh pr merge` without `--delete-branch` / `-d`, or with `--delete-branch=false`:
  `gh pr merge 12`, `--merge`, `-m`, `--rebase`, `--auto --merge`.
- `gh api` with a field `merge_method=squash` (`-f`, `-F`, `--field`, `--raw-field`, any case)
  and a GraphQL `mergeMethod: SQUASH`.
- The GitHub MCP tool `merge_pull_request` (any server name) with `merge_method` or
  `mergeMethod` set to `squash`, any case.
- All of the above behind a wrapper, which the guard strips first, flags and values included:
  `timeout [-k 5] 60`, `sudo [-u me]`, `nice [-n 5]`, `nohup`, `env [-u X]`, `command`,
  `xargs [-n1]`, and `sh -c '…'` / `bash -lc '…'` / `sh -ec '…'` / `bash -o pipefail -c '…'`
  (bundled flags, the command string is checked as its own command, nested to any depth).
  `timeout 60 git merge --squash x` and `sudo -u me gh pr merge 12 -s -d` are blocked like
  the bare commands; `bash run.sh -c 'git merge --squash x'` is a script's argument, not a
  shell command string, and is not read.
- Deleting a protected branch on origin: `git push origin --delete dev` (also `develop`,
  `staging`, `main`, `master`, `prod`, `production`, `release`, the remote's default branch
  read from `refs/remotes/<remote>/HEAD`, any case), `git push -d origin dev`, and the
  empty-source refspecs `git push origin :dev` / `+:refs/heads/dev`. This is a deploy-guard
  block, not a merge-guard one. Pushing to `dev` stays allowed.

**Allowed**
- `git merge --no-ff <branch>`, and for a PR `gh pr merge <n> --merge --delete-branch`.
  `gh pr merge <n> --rebase --delete-branch` is not a squash and is allowed.
- `gh pr merge --disable-auto` and `gh pr merge --help` (they merge nothing), `gh pr view`,
  `gh pr create`, `gh pr list`, and `gh api` calls that do not squash, such as
  `gh api -X PATCH repos/o/r -F allow_squash_merge=false -F delete_branch_on_merge=true`.
- Branch cleanup is never blocked: `git push origin --delete <wip or run branch>` (also with
  `--force-with-lease=<ref>:<sha>`, a compare-and-delete), `git branch -D`,
  `git worktree remove`, `git worktree prune`. Deleting a protected branch on origin
  (`main`, `dev`, the default branch, ...) stays blocked, with or without a
  `--force-with-lease`.

The guard reads each command the way the tool does, so it neither over- nor under-blocks. git
value flags (`-m`, `-F`, `-s <strategy>`, `-X`) are skipped, so `git merge -s ours x` and
`git merge -m "--squash" x` are allowed (`-s` is git's strategy flag, not squash). `gh` flags
follow spf13/pflag v1.0.10, the parser inside gh: `-t "-s fix"` is a value, not a flag, and
`-md`, `-s=false`, `-tvalue` resolve as gh resolves them. Quoted text, heredocs and lookalikes
(`echo 'gh pr merge --squash'`, `git log --grep=squash`) never trigger it.

**The approval prefix does not apply.** `BMN_USER_APPROVED_DEPLOY=1` is a deploy pass-through
only: the merge rules still run with it, also inside `bash -c`. "No more squash merging" has no
in-run exception. If Jonathan ever wants a squash, he runs it himself.

**Outside a run, and the repo setting.** The hook acts only while a run is unfinished (phase
not `done` or `blocked`). Merges made outside a run, in the GitHub UI or in other sessions, are
covered by the repo settings INTAKE sets: `allow_squash_merge=false` and
`delete_branch_on_merge=true` (old and new values are recorded in `bmn.json` and the report).

**Known blind spots** (an accident guard, not a sandbox): `gh api --input <file>` and
`-F key=@file` bodies, GraphQL variables not named `mergeMethod`, `curl` against the REST API,
git aliases, `branch.<name>.mergeOptions=--squash`, `eval`, wrappers outside the list above
(`doas`, `ionice`, `stdbuf`, `setsid`, `caffeinate`, `watch`, `script -c`, `env -S '<string>'`),
value flags of the runners `uv run`, `poetry run`, `pnpm exec` and `npx -y`, bundled git short
flags such as `-qm`, and a protected branch deleted with `git branch -D` locally (only the
origin delete is guarded; `merged-branch-cleanup.py` refuses protected names itself). Two consequences are accepted. `gh` refuses `--delete-branch` on a
merge-queue branch, so a run cannot merge such a PR (bmn merges with `git merge --no-ff` and
has no merge queue). `gh pr merge --auto … -d` deletes nothing itself; GitHub deletes the
branch when the auto-merge lands only if `delete_branch_on_merge=true`.

## How the work stays testable without deploying

- Migrations are written to `supabase/migrations/` and tested on a **local** Supabase
  (`supabase start`, then `supabase db reset`). DB-SYNC then applies them to the dev
  project. Tests never run against the dev database. Without Docker, unit and integration
  tests use the repo's test DB fixture, and TEST notes that DB-level validation didn't run.
- Browser tests run against the app served locally, never a Vercel URL.

## Hand-back — the report's Deploy checklist

Whenever a run creates or changes any of the following, add an entry to
`bmn.json.deploy_pending` and to the report's Deploy checklist:

| Change | Entry says |
| --- | --- |
| new/changed file in `supabase/migrations/` | "✅ applied to **dev**" (or "⏸ held back from dev: <why>") + "⏳ waiting for **main**" + file list + `supabase link --project-ref <main-ref> && supabase db push --linked` |
| RLS policy, function, trigger, extension | same as above, called out separately — these change security behaviour |
| edge function | `supabase functions deploy <name>` per project |
| new env var / secret | the name (never a value) and which project(s) need it |
| app code on a Vercel project | "`dev` is ready for a Vercel **dev** deploy when you say so" + `vercel deploy --target=<dev env>`; prod listed separately |
| `deploymentEnabled` commit on the run branch or `dev` | "The run branch's first push, and the first `dev` push carrying `deploymentEnabled`, may each have built once (Vercel doesn't document whether a commit's own vercel.json governs its push); set the rule in Vercel → Project → Settings → Git" |

Supabase is always **dev before main**. The checklist says plainly which migrations the
code on `dev` depends on, and which features will fail on an environment until they're
applied there.

## When approved

Only the named step, only for the named target. Prefix the CLI command with
`BMN_USER_APPROVED_DEPLOY=1` (the guard's pass-through), show the output, confirm it
landed (e.g. `supabase migration list --linked`), tick it off in `report.md`, and commit.
MCP deploy tools stay blocked even then — use the CLI. Approval never carries to the next
step or the next project. The prefix never applies to the merge rules — see *Merge commits
only* above.
