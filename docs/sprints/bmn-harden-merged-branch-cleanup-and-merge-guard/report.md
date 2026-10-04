# Harden merged-branch cleanup and merge guard — dev-bother-me-nope report

**Run:** `bmn-harden-merged-branch-cleanup-and-merge-guard` · **Finished:** 2026-10-04 · **Outcome:** ✅ done, merged to `dev`, stopped for you
**Stack:** library · skills used: python-library-quality:keeping-git-repos-clean, :guarding-destructive-operations (not installed; rules restated in the stories)
**Design:** no UI in this run
**Merged to dev:** `79dd1b0` (MERGE①), `7e990c1` (MERGE②), plus the report merge
**Cost:** 17 workflow agents, 2.19M subagent tokens (as reported by the workflow), plus the orchestrator.

## Stopped for Jonathan — the run is done

**Built:**
- **cleanup-helper-local-only-mode-and-wider-caches:**
  - `merged-branch-cleanup.py` has `--local-only` / `--pushed`, so a run branch that was never pushed goes through the helper with every safety check. This fixes the previous run's R2-1.
  - The cache list now covers Next.js and Playwright leftovers (R2-2). `build/`, `dist/` and `.env*` still keep a worktree.
  - The cleaner text no longer runs a repo-wide `git worktree prune` (R2-3).
- **deploy-guard-protected-deletes-and-wrapper-gaps:**
  - Deleting a protected branch on origin is now a separate "branch guard" block, which `BMN_USER_APPROVED_DEPLOY=1` can't lift (R2-4).
  - `xargs --replace/--max-lines/--eof` and `fish --command` are now read (R2-5).
  - A new parity test keeps the guard's and the helper's protected-branch lists equal (R2-6).

**FIX① fixed:** 6 of 6 REVIEW① findings — R1-1…R1-6. There were no TEST① failures.
**FIX① not reproducible / blocked:** none.
**Left open:** REVIEW② C/H/M/L 0/0/0/6, including the one TEST② failure (R2-5). No REVIEW① item is still open.

**Decisions that are yours**
1. Left-open items are all LOW. Make them a new goal or accept them.
2. Release `dev` → `main`: ready.
3. Deploys: none (no Vercel, no Supabase).
4. DB: nothing.

## Deploy checklist — nothing was deployed; no Vercel, no Supabase in this repo
Plugin: another session's Next.js wiring merge took `plugin.json` to **1.7.0** on `dev`, so that version carries these fixes. The orchestrator updates the installed plugin after this report.

## Summary
The run fixed the six LOW/MEDIUM/HIGH items that the previous run's REVIEW② left open. It did that in two parallel stories, one for the cleanup helper and skill text and one for the deploy guard. Both were merged to `dev`, tested on Python 3.13 and 3.9, and reviewed once. All six REVIEW① findings were reproduced and fixed. REVIEW② re-checked them all as fixed and found six new LOW items, listed below.

## Stories
| Story | Result | REVIEW① C/H/M/L | Fixed in FIX① | Left open |
| --- | --- | --- | --- | --- |
| cleanup-helper-local-only-mode-and-wider-caches | ✅ merged | 0/0/1/1 | R1-1, R1-6 | R2-1, R2-3, R2-5, R2-6 |
| deploy-guard-protected-deletes-and-wrapper-gaps | ✅ merged | 0/0/0/4 | R1-2, R1-3, R1-4, R1-5 | R2-2, R2-4 |

**Reviews (`/code-review` high, one pass each):** REVIEW① 0/0/1/5 · REVIEW② re-check 6 fixed · REVIEW② new 0/0/0/6 · `review.md`

## Assumptions I made instead of asking
See `stack.md` (1–6) and the stories' Assumptions sections. Two points matter most here:
- The protected-branch block can't be lifted by the approval prefix.
- `--local-only` reports "origin copy kept", and the cleaner rewrites that to "origin copy not pushed by this run".

Two process deviations:
- SPLIT through REVIEW② ran as one workflow, with `bmn.json` written only before and after it.
- The report merge and CLEANUP were run by the orchestrator directly, not by merger and cleaner agents, to cut cost (Jonathan, 2026-10-04).

## FIX①
- R1-1 (MEDIUM): fixed. The machine-move tidy now goes through the helper.
- R1-2: fixed. `heads/<name>` refspecs are now caught.
- R1-3: fixed. `fish -C`/`--init-command` is now read.
- R1-4: fixed. The blind-spot list now names the `gh api` ref deletes and the MCP branch tools.
- R1-5: fixed. Each push segment is parsed once.
- R1-6: fixed. `--local-only` is applied while planning, not after.

## Left open — not fixed by this run (all LOW)
- **R2-1** `move-computers.md:41`: step 6 records kept items in `handoff.md` after step 5 has already pushed the handoff, and step 6 removes the worktree that holds it.
- **R2-2** `deploy-guard.py:249`: fish `-c'…'` attached to its argument and fish's value flags `-d/-p/-f/-D/--profile` still get past the guard.
- **R2-3** `merged-branch-cleanup.py:314`: under `--local-only`/`--pushed`, a failed fetch is dropped from the JSON and the local branch is still deleted, based on stale refs.
- **R2-4** `deploy-guard.py:415`: a docstring disagrees with the code about when the default branch is read.
- **R2-5** (TEST② failure): criterion 15 pins 1.6.1, but `dev` is on 1.7.0 after another session's merge. This is spec drift.
- **R2-6** `move-computers.md:29`: each per-branch helper call fetches again; fetching once and passing `--no-fetch` would do.

## Git cleanup
_Filled in by CLEANUP._

## Evidence
`review.md`, per-story `validation.md`, `evidence/` under each story folder.
