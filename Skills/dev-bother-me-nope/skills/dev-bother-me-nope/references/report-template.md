# {Run title} — dev-bother-me-nope report

**Run:** `{run}` · **Finished:** {iso8601} · **Outcome:** ✅ done, merged to `dev`, stopped for you / ⛔ blocked
**Mode:** full / fast — {why: ASAP, urgent, hotfix, or ≤3 small stories with no UI design} · **Time:** estimated {estimate} · actual {actual}
**Stack:** {kind} · skills used: {routed skills}
**Design:** {picked direction} — {Claude Design link} / no UI in this run / Claude Design unavailable, built to existing conventions
**Merged to dev:** {merge shas}

## Stopped for Jonathan — the run is done

code → review → fix → review → report. The run did REVIEW①, one fix round (FIX①) and
REVIEW②, then stopped. Nothing REVIEW② found was fixed. Nothing was released, promoted to
`main` or deployed, and no further round was started. Anything below is a **new goal, and
only you decide whether there is one**.

*Fast mode, REVIEW② skipped (use this paragraph instead of the one above):* code → review →
fix → report. The run did REVIEW① (with TEST① beside it) and one fix round (FIX①), then
stopped. REVIEW② and TEST② were skipped because this was a fast-mode run and you didn't ask
for them: **the FIX① fixes were not re-reviewed after fixing.** Nothing was released,
promoted to `main` or deployed. Asking for REVIEW② now is a new goal you start.

**Built:** {one line per story: what works now}
**FIX① fixed:** {n} of {n} REVIEW① findings + {n} TEST① failures — {ids}
**FIX① not reproducible / blocked:** {id → evidence or reason; "none"}
**Left open:** REVIEW② C/H/M/L {c/h/m/l} + {n} TEST② failures + {n} REVIEW① items still open
or regressed. All of them are listed under *Left open* below, HIGH first. Fast mode without
REVIEW②: "not re-reviewed after fixing — {n} FIX① fixes merged on the fixer's own reproducing
test only".
**Speed:** {"not requested" / requested at {phase}; gates skipped: {list}}
**Decisions that are yours**
1. Left-open items: a new goal for them, or accept them as they are.
2. Release / promotion `dev` → `main`: {ready / held back by …}.
3. Deploys: Vercel dev {ready}; Supabase MAIN {n} migrations waiting (*Deploy checklist*).
4. DB: {held-back migrations, data fixes, anything destructive; "nothing"}.

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
| Story | Result | Tests (unit/int/browser) | REVIEW① C/H/M/L | Fixed in FIX① | Left open | Notes |
| --- | --- | --- | --- | --- | --- | --- |

**Reviews (`/code-review` high, one pass each):** REVIEW① C/H/M/L {c/h/m/l} · REVIEW②
re-check {fixed/still-open/regressed/not-reproducible} · REVIEW② new C/H/M/L {c/h/m/l} ·
`docs/sprints/{run}/review.md` (fast mode without REVIEW②: "REVIEW② skipped (fast mode) —
not re-reviewed after fixing")

## Assumptions I made instead of asking
{numbered list — every decision taken without Jonathan}

## FIX① — what the fix round did
{one line per item: id → fixed (test name) / not reproducible (evidence) / blocked (reason)}

## Left open — not fixed by this run
{every REVIEW② finding and TEST② failure, HIGH first, with id, file:line and scenario; REVIEW①
items still open or regressed; skipped surfaces (e.g. no Docker → DB not validated); blocker if
any. Fixing any of it is a new goal you start.}

## Repo merge settings
From `bmn.json.repo_policy` (INTAKE ran `repo-merge-policy.py`): `allow_squash_merge`
{old} → {new}, `delete_branch_on_merge` {old} → {new}; or `unchanged: {reason}` (already set,
skipped or failed, with the helper's `reason`). Jonathan's standing instruction of 2026-10-03:
no squash merges, and every merged PR deletes its source branch. Rebase merges are untouched.

## Git cleanup
**Run branch** `{type}/{run-slug}` · worktree `{path}`: deleted (local + origin) / left — {why,
e.g. "not in dev: merge it, the next bmn start deletes it" or "worktree has uncommitted changes"}
**Deleted, per branch:** {branch → local + origin deleted; worktrees removed: {paths}} — every
worktree that had the branch checked out, including ones bmn didn't create
**Left:** {every `left` entry as ref → why, one per line (dirty or locked worktree, not
merged, …); "nothing" when clean}

## Evidence
Run-level `review.md` (REVIEW① and REVIEW②), per-story `validation.md` (tests and FIX①), screenshots under `docs/sprints/{run}/<slug>/evidence/`.
