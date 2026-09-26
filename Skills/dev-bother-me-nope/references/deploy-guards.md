# Deploy guards — Vercel and Supabase

Jonathan decides every deploy. This file is what "never deploy" means concretely, what the
hook blocks, and how the report hands the decision back to him.

## Never, without Jonathan saying so in chat this session

**Vercel**
- `vercel` with no subcommand (it deploys), `vercel deploy`, `vercel --prod`, `vercel promote`,
  `vercel rollback`, `vercel redeploy`, `vercel alias`, `vercel env add|rm` (changes a live
  project), `vercel remove`.
- Any Vercel MCP tool whose name contains `deploy`, `promote`, `rollback` or `alias`.
- `git push` to `main`, `master`, `prod`, `production`, `release` — the production branch.

Allowed: `vercel dev`, `vercel build`, `vercel pull`, `vercel env pull`, `vercel ls`,
`vercel inspect`, `vercel logs`, `vercel whoami`, `vercel link`, `vercel --version`.

**Supabase** — there are always two projects, `dev` and `main`. Both are remote; both are
off limits.
- `supabase db push`, `supabase migration up` against a linked or remote db, any
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

- Migrations are written to `supabase/migrations/` and applied only to a **local**
  Supabase (`supabase start`, then `supabase db reset`). No Docker → unit/integration tests
  use the repo's test DB fixture, and TEST notes that DB-level validation ran locally-only
  or not at all.
- Browser tests run against the app served locally, not a Vercel URL.
- A push to `dev` may trigger a Vercel **preview** build through the host's git
  integration; the report says so. It is never used as the thing under test.

## Hand-back — the report's Deploy checklist

Whenever a run creates or changes any of the following, add an entry to
`bmn.json.deploy_pending` and to the report's Deploy checklist:

| Change | Entry says |
| --- | --- |
| new/changed file in `supabase/migrations/` | "Apply to Supabase **dev**, verify, then **main**" + file list + `supabase db push --linked` per project (after `supabase link --project-ref <dev-ref>` / `<main-ref>`) |
| RLS policy, function, trigger, extension | same as above, called out separately — these change security behaviour |
| edge function | `supabase functions deploy <name>` per project |
| new env var / secret | the name (never a value) and which project(s) need it |
| app code on a Vercel project | "Ready to deploy when you say so" + `vercel --prod` or the promote command |

Order is always **dev before main** for Supabase. The checklist says plainly: *"Nothing
above has been deployed. The app on dev expects migrations X, Y — until they're applied to
the dev database, features A, B will fail there."*

## When approved

Only the named step, only for the named target. Prefix the CLI command with
`BMN_USER_APPROVED_DEPLOY=1` (the guard's pass-through), show the output, confirm it
landed (e.g. `supabase migration list --linked`), tick it off in `report.md`, and commit.
MCP deploy tools stay blocked even then — use the CLI. Approval never carries to the next
step or the next project.
