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
