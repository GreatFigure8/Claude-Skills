# {Run title} — dev-bother-me-nope report

**Run:** `{run}` · **Finished:** {iso8601} · **Outcome:** ✅ shipped to `dev` / ⛔ blocked
**Stack:** {kind} · skills used: {routed skills}
**Design:** {picked direction} — {Claude Design link} / no UI in this run / Claude Design unavailable, built to existing conventions
**Merged to dev:** {merge shas}

## Deploy checklist — nothing was deployed to Vercel; Supabase MAIN untouched

**Vercel:** `dev` is ready for a Vercel **dev** deploy when you say so —
`vercel deploy --target=<dev env>`. Merges to `dev`, `wip/**` and `{run branch}` pushes
did not build (git.deploymentEnabled). "The first push of `{run branch}` may have built
once — Vercel doesn't document whether a commit's own vercel.json governs its push."

**Supabase**
| # | Migration | DEV | MAIN | Why it matters |
| - | --- | --- | --- | --- |
| 1 | `supabase/migrations/…sql` — {e.g. new table `invoices` + RLS} | ✅ applied / ⏸ held back: {why} | ⏳ waiting | {feature X fails on main until applied} |

MAIN, when you say go:
```bash
supabase link --project-ref <main-ref> && supabase db push --linked
```

**Env vars / secrets to add (names only):** {NAME → dev, main}

## Summary
{3–6 sentences: what was asked, what was built, what state it's in.}

## Stories
| Story | Result | Tests (unit/int/browser) | Review (C/H/M/L) | Notes |
| --- | --- | --- | --- | --- |

**Whole-run review (REVIEW③, max):** {rounds} round(s) · final C/H/M/L {c/h/m/l} ·
`docs/sprints/{run}/review-final.md`

## Assumptions I made instead of asking
{numbered list — every decision taken without Jonathan}

## Fixed along the way
{review findings and test failures that were fixed, one line each}

## Left open
{MEDIUM/LOW findings not fixed, skipped surfaces (e.g. no Docker → DB not validated), blocker if any}

## Git cleanup
**Run branch** `{type}/{run-slug}` · worktree `{path}`: deleted (local + origin) / left — {why,
e.g. "not in dev: merge it, the next bmn start deletes it" or "worktree has uncommitted changes"}
**Deleted:** {n} wip branches (local + origin), {n} worktrees — {list}
**Left:** {ref → why, one per line; "nothing" when clean}

## Evidence
Per-story `review.md`, `validation.md`, run-level `review-final.md`, screenshots under `docs/sprints/{run}/<slug>/evidence/`.
