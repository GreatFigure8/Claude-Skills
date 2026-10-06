# {Run title} — dev-bother-me-nope report

**Run:** `{run}` · **Finished:** {iso8601} · **Outcome:** ✅ merged to `dev`, waiting for your release decision / ⛔ blocked
**Time:** estimated {estimate} · actual {actual}
**Stack:** {kind} · skills used: {routed skills}
**Design:** {picked direction} — {Claude Design link} / no UI in this run / Claude Design unavailable, built to existing conventions
**Merged to dev:** {merge shas}

## Your decision: release?

1 sprint → 2 plan → 3 code → 4 test + review → 5 fix → 6 test → 7 report. The run did each
step once and stopped here. Nothing was released, merged to `main` or deployed. Step 8 is
yours: **release v{next}** (the checklist below runs as one unit), or **not now**, and you
decide what's next.

**Built:** {one line per story: what works now}
**FIX fixed:** {n} of {n} review findings + {n} TEST① failures — {ids}
**FIX not reproducible / blocked:** {id → evidence or reason; "none"}
**TEST②:** {pass}/{total} green · {n} failures left open (listed under *Left open*, HIGH first)
**Left open:** {n} TEST② failures + {n} review findings FIX didn't close. Releasing ships them
as they are; fixing them is a new goal you start.
**Speed:** {"not requested" / requested at {step}; gates skipped: {list}}

## Release checklist — runs only when you say "release"

**Version:** `{current}` → `{next}` ({bump}: {why, e.g. "2 new features, no breaking change"})
· tag `{tag}` · changelog entry below.

| # | Step | What happens | Ready? |
| - | --- | --- | --- |
| 1 | Preflight | `main` has nothing `dev` lacks; `dev` is what TEST② tested; gh / Vercel / Supabase signed in; production env vars exist; tag is free | {✅ / ⚠ what's missing} |
| 2 | Supabase **main** | `supabase db push` of {n} migrations already on dev: {files} | {✅ / none / ⚠ held back: {file → why}} |
| 3 | Release commit | version bump + changelog on `dev` | ✅ |
| 4 | `dev` → `main` | `--no-ff` merge + tag `{tag}`, pushed | ✅ |
| 5 | Sync | `dev` fast-forwarded onto `main`: both on the same commit | ✅ |
| 6 | Vercel production | {git-triggered by the push to `main` / `vercel deploy --prod` for {project}} | {✅ / none / ⚠} |
| 7 | GitHub release | `gh release create {tag}` with the changelog entry | {✅ / no GitHub} |
| 8 | Smoke check | {prod_url}{health_route} answers 200; deployment READY | ✅ |

**Manual items the release won't do** (each needs your own action): {destructive migrations
held back from dev → why; env vars or secrets to add, names only; edge functions; "none"}

**Supabase**
| # | Migration | DEV | MAIN | Why it matters |
| - | --- | --- | --- | --- |
| 1 | `supabase/migrations/…sql` — {e.g. new table `invoices` + RLS} | ✅ applied / ⏸ held back: {why} | ⏳ goes in the release | {feature X fails on main until applied} |

**Vercel during the run:** merges to `dev`, `wip/**` and `{sprint branch}` pushes did not
build (git.deploymentEnabled). "The first push of `{sprint branch}` may have built once —
Vercel doesn't document whether a commit's own vercel.json governs its push."

**Changelog entry**
```markdown
## {next} — {date}
{one line per story, user-facing}
```

## Summary
{3–6 sentences: what was asked, what was built, what state it's in.}

## Stories
| Story | Result | Tests (unit/int/browser) | Review C/H/M/L | Fixed in FIX | TEST② | Left open | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |

**Review (`/code-review` high, one pass, beside TEST①):** C/H/M/L {c/h/m/l} ·
`docs/sprints/{run}/review.md`

## Assumptions I made instead of asking
{numbered list — every decision taken without Jonathan}

## FIX — what the fix round did
{one line per item: id → fixed (test name) / not reproducible (evidence) / blocked (reason)}

## Left open — not fixed by this run
{every TEST② failure, HIGH first, with the criterion, error and repro; review findings FIX
marked blocked or not-reproducible whose TEST② re-run still fails; skipped surfaces (e.g. no
Docker → DB not validated); blocker if any. Fixing any of it is a new goal you start.}

## Repo merge settings
From `bmn.json.repo_policy` (INTAKE ran `repo-merge-policy.py`): `allow_squash_merge`
{old} → {new}, `delete_branch_on_merge` {old} → {new}; or `unchanged: {reason}` (already set,
skipped or failed, with the helper's `reason`). Jonathan's standing instruction of 2026-10-03:
no squash merges, and every merged PR deletes its source branch. Rebase merges are untouched.

## Git cleanup
**Sprint branch** `sprint/{run-slug}` · worktree `{path}`: deleted (local + origin) / left — {why,
e.g. "not in dev: merge it, the next bmn start deletes it" or "worktree has uncommitted changes"}
**Deleted, per branch:** {branch → local + origin deleted; worktrees removed: {paths}} — every
worktree that had the branch checked out, including ones bmn didn't create
**Left:** {every `left` entry as ref → why, one per line (dirty or locked worktree, not
merged, …); "nothing" when clean}

## Evidence
Run-level `review.md`, per-story `validation.md` (TEST①, FIX and TEST②), screenshots under `docs/sprints/{run}/<slug>/evidence/`.
