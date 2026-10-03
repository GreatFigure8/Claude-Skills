# Deploy guards — Vercel and Supabase

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
| `deploymentEnabled` commit on the run branch | "The run branch's first push may have built once (Vercel doesn't document whether a commit's own vercel.json governs its push)" |

Supabase is always **dev before main**. The checklist says plainly which migrations the
code on `dev` depends on, and which features will fail on an environment until they're
applied there.

## When approved

Only the named step, only for the named target. Prefix the CLI command with
`BMN_USER_APPROVED_DEPLOY=1` (the guard's pass-through), show the output, confirm it
landed (e.g. `supabase migration list --linked`), tick it off in `report.md`, and commit.
MCP deploy tools stay blocked even then — use the CLI. Approval never carries to the next
step or the next project.
