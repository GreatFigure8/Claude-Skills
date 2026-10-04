# Validation — deploy-guard-protected-deletes-and-wrapper-gaps

Surface: unit/integration, TEST1 (after BUILD), against `origin/dev` @ `79dd1b08dbd465c459f252ef6f22cc0b1ae21bc5`.

## Commands and results

| Command | Result |
| --- | --- |
| `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q` (uv default Python) | 596 passed |
| `uv run --quiet --python /usr/bin/python3 --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q` (3.9.6) | 596 passed |
| `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope/assets` | All checks passed |
| suite under `coverage run` with `patch = subprocess`, `include = */assets/bin/*.py` | 596 passed |
| `python3 evidence/smoke.py <checkout>` (hook driven over stdin with an active-run fixture in a tmp clone; no real GitHub) | 188 checks (both stories), 0 failed |

## Coverage (subprocess coverage, default Python)

`assets/bin/deploy-guard.py`: 94% (499 statements, 32 missed). The missed lines are defensive paths
(unparsable shell quoting fallback, `git branch --show-current` and `symbolic-ref` failures, a few
parser `break`/`return` branches, `--all`/`--mirror` message, empty command). None of the new
code (`unliftable_block`, the branch-guard family, the xargs value-flag set, `--command` reading,
`DELETE_PROTECTED`) is among the missed lines (183-184, 208, 249, 342-347, 367, 380-381, 417,
419-422, 444-445, 454-455, 469-470, 480-481, 500-501, 574, 582, 593, 678, 753). Target 80%: met.

## Criteria

| # | Criterion | Result | Evidence |
| --- | --- | --- | --- |
| 1 | approved protected deletes exit 2 (`--delete dev`, `:main`, `-d … staging`, `+:refs/heads/release`, `sh -c`, `sudo -u me bash -lc … develop`, `git -C . … DEV`, remote default branch) | PASS | smoke S2.C1 |
| 2 | branch-guard family, evaluated before the approval return; message starts `Blocked by dev-bother-me-nope branch guard:`, names the refspec, does not offer the approval prefix | PASS | smoke S2.C1/C2 (stderr has no `BMN_USER_APPROVED_DEPLOY`; unapproved delete gives the same family) |
| 3 | approval still passes real deploys (`git push origin main`, `vercel deploy --prod`, via `sh -c`); unapproved push to `main` exits 2 with the deploy prefix | PASS | smoke S2.C3 |
| 4 | allowed cleanup stays allowed with and without the prefix (`--delete wip/…`, approved `--delete feat/run-branch`, `--force-with-lease=<ref>:<sha> --delete wip/x`, `gh pr merge 5 --merge --delete-branch`) | PASS | smoke S2.C4, RUNCTX |
| 5 | `xargs --replace`, `--max-lines`, `--eof`, `--replace=R`, `--max-lines=1 gh pr merge … --squash`, `-I{}` exit 2 with merge prefix; `xargs --replace vercel deploy --prod` with the deploy prefix | PASS | smoke S2.C5 |
| 6 | value-taking xargs flags still consume (`-I {}`, `-L 1`, `-n 1`, `--max-args 1`, `-E EOF`, `--process-slot-var SLOT`); `xargs -I {} git status {}` and `xargs --replace echo squash` allowed | PASS | smoke S2.C6 |
| 7 | fish `--command=…`, `--command '…'`, `-c '…'`, approved fish, `--command` + protected delete exit 2; `fish --command='git status'` and a script argument allowed; `--command` read for sh/bash/zsh/dash/ksh | PASS | smoke S2.C7 |
| 8 | `deploy-guards.md` wrapper bullet names `xargs --replace` and `fish -c` / `fish --command`; blind spots do not list them; `eval`, `doas`, `env -S` still listed | PASS | smoke S2.C8 |
| 9 | parity: `DELETE_PROTECTED == PROTECTED` (eight lowercase names) | PASS | smoke PARITY; `test_protected_branch_parity.py` in the suite |
| 10 | parity check bites: guard copy with `qa` reports exactly `{qa}` guard-only, helper copy exactly `{qa}` helper-only; no `assets/bin` file modified | PASS | smoke PARITY (copies loaded from a tmp dir) |
| 11 | every protected name is in the guard docstring and the doc's protected-delete bullet | PASS | smoke PARITY |
| 12 | doc: protected-delete bullet is a branch-guard block never lifted by the prefix; "approval prefix does not apply" covers protected deletes; list checked by a test; guard docstring says the same | PASS | smoke S2.C12 |
| 13 | gates pass on default Python and 3.9.6; ruff clean; no function in `deploy-guard.py` at or above 50 lines; file under 800 (767) | PASS | commands above; smoke S2.C13 |

Totals: 13 PASS, 0 FAIL.

## Extra probes (beyond the criteria, all as expected)

Blocked: `git push origin :refs/heads/dev`, `git push --delete origin dev`, an approved
`--delete origin Dev`, `--delete refs/heads/main`, a mixed `--delete wip/x dev`, an approved
`env git push … --delete dev`, an approved `xargs --replace git push origin --delete dev`,
`xargs --null|-r|-0 -n1|--max-procs 4|--no-run-if-empty|-t -r --verbose|-i|-l|-e git merge --squash`,
`find . | xargs --replace … --delete dev`, `fish --login --command=…`, `fish -lc …`,
`timeout 5 xargs --replace …`, `sudo -u me fish --command …`, a nested `fish --command='fish --command="…"'`.
Allowed: `xargs --replace git status`, `xargs --max-lines=1 git log`, `fish --command='git log'`,
`echo xargs --replace git merge --squash x`, `git push origin --delete wip/dev|dev-x|feature/dev`,
`git push origin :wip/main/x`.

Known limit, not a defect of this story: when the refspec is an `xargs` placeholder
(`xargs -I{} sh -c 'git push origin --delete {}'`) the branch name is unknown to the guard, so it
cannot refuse it. Accident guard, not a sandbox.

## Assumptions

1. The hook was driven exactly as Claude Code does, a JSON payload on stdin with the active-run fixture
   `docs/sprints/bmn-demo/bmn.json` (phase `build`) in a tmp clone whose `refs/remotes/origin/HEAD` is `trunk`.
2. The same smoke run covers both stories; its story 2 output is `evidence/smoke-story2-out.txt`.

## FIX①

Fixer branch `wip/harden-merged-branch-cleanup-and-merge-guard/deploy-guard-protected-deletes-and-wrapper-gaps-fix`,
cut from `origin/fix/harden-merged-branch-cleanup-and-merge-guard` @ `5c27dfd`. Reproducing tests are in
`Skills/dev-bother-me-nope/assets/tests/test_guard_review1_gaps.py`. Before the fix, 43 of its 62 tests failed (every
one for the stated reason: the hook exited 0 where 2 was expected, or counted 2 parses / N default-branch lookups
where 1 was expected, or a doc string was missing); the rest pin behaviour that already held.

| Id | Result | Evidence |
| --- | --- | --- |
| R1-2 | fixed | `test_heads_slash_name_is_a_protected_delete` (16 cases: eight spellings, with and without the approval prefix), `test_heads_form_of_the_default_branch_is_a_protected_delete`, `test_pushing_to_a_production_branch_through_heads_is_a_deploy_block`; allowed cleanup pinned by `test_heads_form_cleanup_stays_allowed_with_and_without_the_prefix`, including a branch literally named `heads/dev` (`refs/heads/heads/dev`). `ref_destination` now strips one `refs/heads/` or `heads/` prefix (regex `BRANCH_REF_PREFIX`). |
| R1-3 | fixed | `test_blocks_squash_merges_behind_fish_init_commands` (12 cases: `-C S`, `-lC S`, `--init-command S`, `--init-command=S`, before or after `-c`, a second `-C`, with a script file, behind `sudo`, with the approval prefix, and `bash -C -c` still read), `test_fish_init_command_reaches_the_deploy_and_branch_guards`, `test_fish_init_leaves_harmless_commands_and_script_arguments_alone`. `shell_command_string` became `shell_command_strings`: it returns every string the shell runs and `check_segment` checks each. `-C` and `--init-command` are read for fish only (bash's `-C` is noclobber). |
| R1-4 | fixed (documented, not guarded) | `test_doc_blind_spots_name_gh_api_ref_deletes_and_the_github_mcp_branch_tools`: *Known blind spots* now names `gh api -X DELETE repos/<o>/<r>/git/refs/heads/<protected>` and the GitHub MCP server's branch tools. |
| R1-5 | fixed | `test_each_push_segment_is_parsed_once` (spy on `push_parts`: 1 call per `git push` segment, was 2) and `test_the_default_branch_is_looked_up_at_most_once_per_push` (spy on `default_branch`: 1 lookup for `--delete a b c d`, was 4; 0 when a refspec is already a protected name or the push deletes nothing). `check_segment` parses the push once and hands it to `unliftable_block` and `deploy_reason`; `deleted_protected_ref` looks the default branch up lazily, once, keeping first-match order (`test_a_default_branch_match_still_names_the_first_doomed_refspec`). |

Docs touched with the fixes: `references/deploy-guards.md` (wrapper bullet names `fish -C` / `--init-command`; protected-delete
bullet names the `heads/<name>` form; blind spots add `fish --init`, `gh api -X DELETE …/git/refs/heads/<protected>` and the
GitHub MCP branch tools) and the guard's module docstring, each pinned by a test in the new file.

Gates after FIX①: `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q` 658 passed;
the same with `--python /usr/bin/python3` (3.9.6) 658 passed; `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope/assets`
all checks passed. `deploy-guard.py` is 797 lines (limit 800); no function reaches 50 lines.

### Assumptions (FIX①)

1. R1-4 is closed by documenting the two blind spots, not by guarding `gh api -X DELETE`: the story's out-of-scope note
   already leaves the GitHub MCP tools as listed blind spots, and `deploy-guard.py` has 3 lines of headroom under its
   800-line cap. A guard for the REST path is a new goal if Jonathan wants one.
2. fish was not installed on this machine, so its grammar rests on its documented `-C`/`--init-command` text (evaluated
   after the config, before the `-c` command) and the same getopt rules the `--command` support already assumes. Only
   the documented spellings are read; abbreviations (`--init`) are listed as blind spots.
3. `git push <remote> heads/<name>` (no colon) also resolves to the production branch, so the deploy family reads it
   through the same `ref_destination`.
4. The guard keeps plain tuples for the parsed push, as before; a NamedTuple would not fit under the 800-line cap.
