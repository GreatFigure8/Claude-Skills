# Validation — cleanup-helper-local-only-mode-and-wider-caches

Surface: unit/integration, TEST1 (after BUILD), against `origin/dev` @ `79dd1b08dbd465c459f252ef6f22cc0b1ae21bc5`.

## Commands and results

| Command | Result |
| --- | --- |
| `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q` (uv default Python) | 596 passed |
| `uv run --quiet --python /usr/bin/python3 --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q` (3.9.6) | 596 passed |
| `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope/assets` | All checks passed |
| suite under `coverage run` with `patch = subprocess`, `include = */assets/bin/*.py` | 596 passed |
| `python3 evidence/smoke.py <checkout>` (tmp dir, local bare origin, PATH git shim that logs argv; no real GitHub) | 188 checks (both stories), 0 failed |

## Coverage (subprocess coverage, default Python)

`assets/bin/merged-branch-cleanup.py`: 94% (248 statements, 15 missed). Every missed line is a
defensive error path that the tests cannot reach without breaking git itself (git timeout and
`OSError` in `run_git`, `status`/`rev-parse` failure, `--repo ""`, a target that stops resolving
between validate and survey, a failing `worktree list`, `fetch` failure reason). None of the new
code (`--local-only` plan, `is_cache`, CACHE constants) is among the missed lines (88, 107-110,
204, 221, 237, 246-247, 256, 259, 309, 370-371). Target 80%: met.

`repo-merge-policy.py` is not touched by this run; its tests run it with a stripped environment, so
subprocess coverage cannot attach to it and it is not measured here.

## Criteria

| # | Criterion | Result | Evidence |
| --- | --- | --- | --- |
| 1 | `--local-only` runs no `git push`, origin SHA unchanged (also for a merged origin copy) | PASS | smoke S1.C1 (shim log has no push; `origin.git` `refs/heads/fix/run` SHA identical, merged and unmerged copy) |
| 2 | exactly one `{"ref":"origin:<b>","why":"origin copy kept: --local-only"}` in `left`, never in `deleted`; no entry when no remote copy | PASS | smoke S1.C2 (merged, unmerged and absent remote copy) |
| 3 | R2-1 repro: ignored `.env` worktree kept, bytes intact, `worktree:<path>` names the ignored file, `local:<b>` in `left` | PASS | smoke S1.C3 (no origin copy, and origin copy present) |
| 4 | clean worktree removed (no `--force`), local branch deleted compare-and-swap, both in `deleted` | PASS | smoke S1.C4 (`update-ref -d <ref> <40-hex sha>`, no `--force` on any git call) |
| 5 | rebase/bisect in progress keeps the local branch with the default mode's reason; unmerged local kept "not merged into" | PASS | smoke S1.C5 (real `rebase -i` stopped at `edit`, real `bisect start`; reasons equal to default mode) |
| 6 | `--local-only --dry-run`: no fetch, no mutating git call, refs and worktrees identical, no `origin:` in `deleted`, kept entry in `left` | PASS | smoke S1.C6 |
| 7 | docstring Contract lists `[--local-only]` and says what it does; `--help` names it; every refusal still applies with the flag | PASS | smoke S1.C7 (protected `main`/`DEV`/`release`, default branch, `-x`, `refs/heads/x`, bad targets all exit 2 and change nothing; `--local-onl` abbreviation refused) |
| 8 | SKILL.md CLEANUP step 2 and cleaner brief step 2 route through `--local-only`; hand-run sequence gone; origin copy reporting text present | PASS | smoke S1.C8 |
| 9 | Leftover sweep passes `--local-only` when `integration_pushed` is false; plugin-root invocation form | PASS | smoke S1.C9 |
| 10 | `is_cache` True for all 19 listed ignored entries | PASS | smoke S1.C10 |
| 11 | `is_cache` False for existing entries and the near-misses; exact, case-sensitive (extra probes: `NEXT-ENV.D.TS`, `.ds_store`, `Test-Results/`, `my-test-results/`, `a.coverage`, `.coveragerc`) | PASS | smoke S1.C11 |
| 12 | cache rules are immutable named constants, no mutable module state, no `global` | PASS | smoke S1.C12 |
| 13 | worktree with only `next-env.d.ts`, `tsconfig.tsbuildinfo`, `test-results/`, `playwright-report/`, `.coverage`, `.DS_Store` removed and branch deleted; plus ignored `.env` kept with `.env` intact; `dist/`, `.env.local` keep it | PASS | smoke S1.C13 (local-only and default mode) |
| 14 | no `worktree prune` in SKILL.md 10b or the cleaner brief except in a "Never run" sentence; helper docstring keeps "prunes other worktrees" | PASS | smoke S1.C14 |
| 15 | plugin.json version 1.6.1 | PASS | smoke S1.C15 |
| 16 | gates pass on default Python and 3.9.6; ruff clean; helper under 400 lines (398), every function under 50 lines | PASS | commands above; smoke S1.C16 |

Totals: 16 PASS, 0 FAIL.

## Observation (not a failure)

A worktree stopped in the middle of a `rebase` has a detached HEAD, so the helper does not see it as
a holder of the branch and leaves it in place; the branch is kept by the rebase/bisect check. No
data is lost.

## Assumptions

1. The smoke ran the code under test (this checkout at the sha above), not the installed 1.6.0
   plugin copy, because 1.6.0 has no `--local-only`.
2. The fixture's remote default branch is `trunk`; the target is `origin/dev`, as in a real run.
3. Evidence: `evidence/smoke.py` (the script) and `evidence/smoke-story1-out.txt` (its story 1 output).

## FIX①

Branch `wip/harden-merged-branch-cleanup-and-merge-guard/cleanup-helper-local-only-mode-and-wider-caches-fix`
from `origin/fix/harden-merged-branch-cleanup-and-merge-guard`. Each item was reproduced by a test that failed
first (25 new tests failed, then passed). Gates after the fix: pytest 622 passed on the default Python and on
/usr/bin/python3 (3.9.6); `ruff check` clean; the helper is 399 lines (limit 399), every function under 50.

- **R1-1** → fixed. Reproduction: `test_pushed_keeps_a_worktree_holding_an_ignored_env` (a pushed, unmerged
  branch whose worktree holds an ignored `.env`), plus the text tests
  `test_move_out_tidy_runs_the_helper_for_every_branch_it_removes`,
  `test_move_out_tidy_says_which_files_keep_a_worktree` and
  `test_move_computers_never_hand_runs_worktree_remove_or_branch_delete`. They failed because MOVE-OUT step 5
  hand-ran `git worktree remove` and `git branch -D`. Fix: `move-computers.md` MOVE-OUT now has a separate step 6
  that runs `merged-branch-cleanup.py` per branch. The helper has a new flag, `--pushed` (implies `--local-only`),
  whose only valid `--target` is the branch's own `<remote>/<branch>`; the proof is "pushed", not "merged", so a
  machine move can tidy a pushed, unmerged branch without any hand-run delete. Every existing check still runs
  (dirty/ignored files, locked, main, rebase/bisect, compare-and-swap delete) and the origin copy is never touched.
  Own-branch targets are still refused without `--pushed` (existing tests, unchanged), so a typo in a CLEANUP call
  cannot lift the merge proof. Harness branches use `--local-only --target origin/<type>/<run-slug>`.
- **R1-6** → fixed. Reproduction: `test_local_only_plan_*` (9 cases) build a `--local-only` Survey and expect
  `plan_remote` and `plan_unmerged` to decide the origin copy themselves; they failed because `Survey` had no
  `local_only` and `plan_cleanup` post-filtered by ref string. Fix: `Survey.local_only` (default False) is read in
  `plan_remote`, which reports `origin:<branch>` once ("origin copy kept: --local-only") whatever the copy's
  state or a fetch error; `plan_unmerged` takes that entry from `plan_remote`; `plan_cleanup(s)` no longer filters.

### FIX① assumptions

1. `--pushed` is a separate flag rather than letting `--local-only` accept an own-branch target: criterion 7 pins
   own-target as refused with `--local-only`, and a separate flag keeps that refusal for every CLEANUP call.
2. Harness branches in the move tidy are proven against `origin/<type>/<run-slug>` (the pushed run branch) rather
   than by the old "no unique commits" rev-list rule; a harness branch with its own commits is kept and listed.
3. The "Left on <host>" handoff section is committed at step 5, before the tidy; the tidy's kept items also go in the
   closing message (step 8). The ordering predates this fix.

## TEST2 (after FIX①)

Surface: unit/integration, against `origin/dev` @ `7e990c1abc9de8fc71b51277eb83150e160e8119` (FIX① merged, 1114 tests).

| Command | Result |
| --- | --- |
| `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q` (uv default Python) | 1114 passed |
| `uv run --quiet --python /usr/bin/python3 --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q` (3.9.6) | 1114 passed |
| `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope/assets` | All checks passed |
| suite under subprocess coverage (venv with a `.pth` that starts coverage with a fixed rcfile, so the helper's stripped-env subprocesses are measured too; `include = */assets/bin/*.py`) | 1114 passed |
| `evidence/test2-smoke-cleanup.py <checkout>` (tmp dir, local bare origin, PATH git shim logging argv) | 18 checks, 0 failed |
| `evidence/test2-smoke-fix1.py <checkout>` (R1-1 `--pushed`, R1-2/R1-3 guard, R1-4 doc, R1-6) | 27 checks, 0 failed |
| `evidence/smoke.py <checkout>` (the TEST1 smoke, rerun unchanged against this sha; output `evidence/test2-smoke-full-out.txt`) | 187 pass, 1 fail (S1.C15, below) |

### Coverage (subprocess coverage, default Python)

`assets/bin/merged-branch-cleanup.py`: 94% (249 statements, 15 missed: 91, 110-113, 210, 227, 243, 252-253, 262, 265, 317, 372-373).
Every missed line is a defensive error path (git timeout / `OSError`, `status` or `rev-parse` failure, `--repo ""`, a target
that stops resolving, a failing `worktree list`, a fetch-failure reason, a worktree that `worktree remove` cannot remove). None
of the `--local-only`, `--pushed`, `is_cache` or `plan_remote` code is missed. Target 80%: met.

### Criteria

Criteria 1-14 and 16: PASS, re-proved on the post-FIX① sha by `evidence/test2-smoke-cleanup.py` and
`evidence/smoke.py` (output `evidence/test2-smoke-cleanup-out.txt`, `evidence/test2-smoke-full-out.txt`):
no `git push` run and origin SHA unchanged under `--local-only` (merged origin copy, unmerged origin copy, absent copy);
exactly one `origin:fix/run` entry, reason `origin copy kept: --local-only`; the R2-1 repro (ignored `.env`, `.env` bytes
intact, worktree and local branch kept and named in `left`); clean worktree removed and local branch deleted; rebase in
progress keeps the local branch; `--local-only --dry-run` runs no fetch/push and changes nothing; refusals (`dev`, `main`,
`trunk` default branch, `STAGING`, bad target) exit 2 with the flag; `--help` and the docstring name the flag; SKILL.md CLEANUP,
the cleaner brief and the Leftover sweep route through `--local-only` and carry none of the old hand-run text;
`is_cache` True for all 19 regenerable entries and False for `.env`, near-misses, untracked and modified entries and case variants;
a worktree whose only ignored content is `next-env.d.ts`, `tsconfig.tsbuildinfo`, `test-results/`, `playwright-report/`,
`.coverage`, `.DS_Store` is removed while the same plus `.env` is kept; no `worktree prune` instruction in the cleaner text;
helper at 399 lines (< 400), every function under 50 lines.

| # | Criterion | Result | Evidence |
| --- | --- | --- | --- |
| 15 | `plugin.json` version is `1.6.1` | **FAIL (spec drift, not a defect)** | `plugin.json` says `1.7.0`. `origin/dev` was bumped to 1.7.0 by the Next.js wiring merge (`66eeb2b`) after this story was written; the FIX① merge kept 1.7.0 and `test_plugin_json_is_version_1_7_0` pins it. 1.7.0 is not installed yet (the plugin cache is 1.6.0), so the hardening ships inside 1.7.0. Downgrading to 1.6.1 would be wrong; the story text is stale. |

Totals (post-FIX①): 15 PASS, 1 FAIL (criterion 15, spec drift).

### FIX① items re-proved here (R1-1, R1-6)

`evidence/test2-smoke-fix1.py` (27 checks, all pass):
- R1-1: `--pushed --target origin/<branch>` on a pushed branch whose worktree holds an ignored `.env` keeps the worktree, `.env`
  and branch, runs no `git push` and leaves the origin SHA unchanged; with only `.DS_Store` the worktree is removed and the
  local branch deleted (origin copy kept and reported as `origin:<branch>`); an unpushed commit keeps the local branch;
  `--pushed` with a target other than `<remote>/<branch>` and an own-branch target without `--pushed` both exit 2;
  `move-computers.md` MOVE-OUT step 6 runs the helper (`--pushed` / `--local-only`), step 5 has no hand-run `worktree remove`
  or `branch -D`, and step 6 mentions them only in a "Never run" sentence.
- R1-6: `--local-only` reports the origin copy exactly once (unmerged case, `test2-smoke-cleanup.py`) and at most once with an unreachable origin (`--no-fetch`, spot check).

### Assumptions (TEST2)

1. Criterion 15 is reported as a FAIL because the criterion text is literal; the orchestrator decides whether to treat it as
   superseded by 1.7.0. No code defect was found.
2. The coverage run uses a venv `.pth` instead of `coverage run`'s `patch = subprocess` because the helper tests launch the
   scripts with a stripped environment (`COVERAGE_PROCESS_START` would not survive), so the rcfile path is fixed in the `.pth`.
3. Evidence: `evidence/test2-smoke-cleanup.py`, `evidence/test2-smoke-fix1.py` and their `*-out.txt` files.
