# {Run title} — dev-bother-me-nope report

**Run:** `{run}` · **Finished:** {iso8601} · **Outcome:** ✅ shipped to `dev` / ⛔ blocked
**Stack:** {kind} · skills used: {routed skills}
**Merged to dev:** {merge shas}

## Deploy checklist — nothing below has been deployed

> Omit this section only when `deploy_pending` is empty; then write
> "No deploys pending — nothing touches Supabase or needs a Vercel release."

**Supabase — apply to DEV first, verify, then MAIN**
| # | Change | Files | Why it matters |
| - | --- | --- | --- |
| 1 | {e.g. new table `invoices` + RLS} | `supabase/migrations/…sql` | {feature X fails on dev until applied} |

Commands, when you say go (dev, then main):
```bash
supabase link --project-ref <dev-ref> && supabase db push --linked
```

**Env vars / secrets to add (names only):** {NAME → dev, main}
**Vercel:** {project} is ready to deploy when you say so — `{command}`.
**Heads-up:** the push to `dev` may have triggered a Vercel preview build via git integration.

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
