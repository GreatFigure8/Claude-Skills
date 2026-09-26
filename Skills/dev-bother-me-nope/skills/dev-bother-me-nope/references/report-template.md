# {Run title} — dev-bother-me-nope report

**Run:** `{run}` · **Finished:** {iso8601} · **Outcome:** ✅ shipped to `dev` / ⛔ blocked
**Stack:** {kind} · skills used: {routed skills}
**Merged to dev:** {merge shas}

## Deploy checklist — nothing was deployed to Vercel; Supabase MAIN untouched

**Vercel:** `dev` is ready for a Vercel **dev** deploy when you say so —
`vercel deploy --target=<dev env>`. Merges to `dev` did not build (git.deploymentEnabled).
{if first run in this repo: "The first push may have built once; also set the rule in
Vercel → Project → Settings → Git."}

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

## Assumptions I made instead of asking
{numbered list — every decision taken without Jonathan}

## Fixed along the way
{review findings and test failures that were fixed, one line each}

## Left open
{MEDIUM/LOW findings not fixed, skipped surfaces (e.g. no Docker → DB not validated), blocker if any}

## Evidence
Per-story `review.md`, `validation.md`, screenshots under `docs/sprints/{run}/<slug>/evidence/`.
