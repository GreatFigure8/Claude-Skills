# Deploy guard: protected deletes ignore the approval prefix, xargs/fish gaps, list parity

**As** Jonathan, **I want** the deploy-guard hook to refuse deleting a protected branch on
origin even when a deploy was approved, to read the wrapped command behind GNU `xargs` long
flags and `fish --command`, and to fail a test whenever its protected-branch list drifts from
the cleanup helper's, **so that** "deploy" never becomes permission to delete `dev`, a squash
merge can't hide behind a wrapper, and the two lists can't silently disagree again.

## Context

Closes REVIEW② items R2-4, R2-5 and R2-6 of `bmn-merged-branch-cleanup-and-no-squash-merges`
(full text, file:line and probes: the REVIEW2 section of
`docs/sprints/bmn-merged-branch-cleanup-and-no-squash-merges/review.md`).

- **R2-4 (LOW).** `assets/bin/deploy-guard.py` puts the protected-branch delete check
  (`deleted_protected_ref`, reached through `check_git` → `deploy_reason`) in the deploy
  family. `check_segment` returns early for an approved segment before `deploy_reason` runs,
  so `BMN_USER_APPROVED_DEPLOY=1 git push origin --delete dev` exits 0 (probed). Stack.md
  assumption 4: deleting a protected branch on origin is never a deploy step, so the approval
  prefix must not lift it.
- **R2-5 (LOW).** `WRAPPER_VALUE_FLAGS["xargs"]` (line ~58) lists GNU xargs's
  optional-value long flags `--replace`, `--max-lines` and `--eof`. GNU getopt only gives
  those a value through `=` (`--replace=R`), so the guard wrongly eats the next token and
  never reads the wrapped program: `xargs --replace git merge --squash x` exits 0.
  `shell_command_string` skips every `--long` flag, so `fish --command='git merge --squash x'`
  (and `fish --command 'git merge --squash x'`) is never read either. Neither gap is in
  `references/deploy-guards.md`'s blind spots.
- **R2-6 (LOW).** `DELETE_PROTECTED` (guard, line ~41) and `PROTECTED`
  (`assets/bin/merged-branch-cleanup.py`, line ~38) name the same eight branches, typed by
  hand in two files, and no test compares them; adding a name to one list only brings back
  the R1-6 disagreement without a failing test. Today they match.

Paths are relative to `Skills/dev-bother-me-nope/` unless they start with `docs/`. The hook
runs on the system Python 3.9.6: no 3.10+ syntax or stdlib.

Build skills: `python-library-quality:guarding-destructive-operations` and
`python-library-quality:keeping-git-repos-clean` are named for this run but are not installed
on this machine; the rules that apply are restated here (a destructive action needs an
explicit, non-bypassable refusal with a reason; an approval for one class of action never
widens to another; parsing follows the real tool's grammar so it neither over- nor
under-blocks; every rule has a reproducing test).

## Acceptance criteria

### R2-4 — protected deletes are not lifted by the approval prefix

1. [unit] **Reproduces R2-4.** Each of these exits 2 through the hook (the tests'
   `bash()` helper, run in progress): `BMN_USER_APPROVED_DEPLOY=1 git push origin --delete dev`,
   `BMN_USER_APPROVED_DEPLOY=1 git push origin :main`,
   `BMN_USER_APPROVED_DEPLOY=1 git push -d origin staging`,
   `BMN_USER_APPROVED_DEPLOY=1 git push origin +:refs/heads/release`,
   `BMN_USER_APPROVED_DEPLOY=1 sh -c 'git push origin --delete dev'`,
   `BMN_USER_APPROVED_DEPLOY=1 sudo -u me bash -lc 'git push origin --delete develop'`,
   `BMN_USER_APPROVED_DEPLOY=1 git -C . push origin --delete DEV`, and an approved delete of
   the remote's default branch (read from `refs/remotes/origin/HEAD`, as the existing
   `repo_with_default_branch` test does). The first fails today.
2. [unit] The protected-delete block belongs to a rule family the approval prefix never
   lifts, evaluated before the approval early-return in `check_segment` (and for an inner
   `sh -c` string, whose approval is inherited). Its stderr message starts with
   `Blocked by dev-bother-me-nope branch guard:`, names the refspec (as today:
   `` `git push … dev` deletes a protected branch``) and gives advice that does NOT tell the
   reader to use `BMN_USER_APPROVED_DEPLOY=1` (it says a protected branch is never deleted
   inside a run; Jonathan deletes it himself). The existing tests that assert the deploy
   prefix for protected deletes (`test_push_delete_of_a_protected_branch_stays_blocked`,
   `test_blocks_deleting_protected_branches_on_origin`,
   `test_protected_delete_message_names_the_branch_spec`) are updated to the new prefix, not
   deleted.
3. [unit] The approval prefix still lets real deploys through, unchanged:
   `BMN_USER_APPROVED_DEPLOY=1 git push origin main`, an approved `vercel deploy --prod`, and
   the existing `test_user_approved_prefix_lets_a_deploy_through` /
   `test_approval_still_passes_deploys_through_a_shell` /
   `test_approval_still_passes_wrapped_deploys` all pass. Unapproved
   `git push origin main` still exits 2 with the deploy-guard prefix.
4. [unit] Allowed cleanup stays allowed with and without the prefix:
   `git push origin --delete wip/demo/a`,
   `BMN_USER_APPROVED_DEPLOY=1 git push origin --delete feat/run-branch`,
   `git push origin --force-with-lease=refs/heads/wip/x:<sha> --delete wip/x`, and every
   existing `ALLOWED_DELETES` / `ALLOWED_BRANCH_PUSHES` case exit 0.

### R2-5 — xargs GNU long flags and fish --command

5. [unit] **Reproduces R2-5 (xargs).** Each exits 2 with the merge-guard prefix:
   `xargs --replace git merge --squash x`, `xargs --max-lines git merge --squash x`,
   `xargs --eof git merge --squash x`, `xargs --replace=R git merge --squash R`,
   `xargs --max-lines=1 gh pr merge 12 --squash --delete-branch`, and with a deploy:
   `xargs --replace vercel deploy --prod` exits 2 with the deploy-guard prefix. The first
   fails today.
6. [unit] xargs flags that do take a separate value still consume it: `xargs -I {} git
   merge --squash {}`, `xargs -L 1 git merge --squash x`, `xargs -n 1 git merge --squash x`,
   `xargs --max-args 1 git merge --squash x`, `xargs -E EOF git merge --squash x`,
   `xargs --process-slot-var SLOT git merge --squash x` all exit 2, and
   `xargs -I {} git status {}` / `xargs --replace echo squash` exit 0.
7. [unit] **Reproduces R2-5 (fish).** Each exits 2: `fish --command='git merge --squash x'`,
   `fish --command 'git merge --squash x'`, `fish -c 'git merge --squash x'`,
   `fish --command='git push origin --delete dev'` (branch guard),
   `BMN_USER_APPROVED_DEPLOY=1 fish --command 'git merge --squash x'` (merge rules ignore
   the prefix). `fish --command='git status'` and `fish script.fish --command 'git merge --squash x'`
   (an argument of a script, not a command string) exit 0. `--command` / `--command=` is read
   for every shell in `SHELLS`; no other long flag changes meaning.
8. [unit] `references/deploy-guards.md` wrapper bullet names `xargs --replace` (GNU long
   flags whose value only follows `=`) and `fish -c` / `fish --command`; the *Known blind
   spots* paragraph does not list them. Existing doc tests
   (`test_doc_blind_spots_no_longer_claim_covered_shell_wrappers` and friends) still pass;
   `eval`, `doas` and `env -S` stay listed as blind spots.

### R2-6 — protected-branch list parity

9. [unit] A new test file `assets/tests/test_protected_branch_parity.py` loads both scripts
   with the `load_script` fixture and asserts `deploy_guard.DELETE_PROTECTED ==
   merged_branch_cleanup.PROTECTED` (as sets of lowercase names). It passes today.
10. [unit] **Reproduces R2-6.** The same file proves the check bites: it writes a copy of
    `deploy-guard.py` into `tmp_path` with one extra name (e.g. `qa`) added to
    `DELETE_PROTECTED`, loads it, and asserts the parity comparison reports exactly `{"qa"}`
    as guard-only; and symmetrically for a helper copy with an extra name reported as
    helper-only. No file in `assets/bin/` is modified by the test.
11. [unit] The parity file also asserts every name in `DELETE_PROTECTED` appears in the
    guard's module docstring and in the protected-delete bullet of
    `references/deploy-guards.md`, so the documented list can't drift either.
12. [unit] `references/deploy-guards.md`: the protected-delete bullet says it is a
    branch-guard block that `BMN_USER_APPROVED_DEPLOY=1` never lifts (replacing "This is a
    deploy-guard block, not a merge-guard one"); the *approval prefix does not apply*
    paragraph covers protected deletes as well as merges; and the doc says the list is checked
    against `merged-branch-cleanup.py`'s by a test. The guard's module docstring says the
    same. `test_doc_lists_the_protected_branch_deletes` still passes.
13. [unit] Gates pass: `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`,
    the same with `--python /usr/bin/python3` (3.9.6), and
    `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope/assets`. No function in
    `deploy-guard.py` grows past 50 lines; the file stays under 800.

## Out of scope

- `assets/bin/merged-branch-cleanup.py` and its `PROTECTED` set (owned by story
  `cleanup-helper-local-only-mode-and-wider-caches`; this story only reads it), `SKILL.md`,
  `references/briefs.md`, `test_skill_text_rules.py`, `test_merged_branch_cleanup.py`,
  `test_helper_script_quality.py` and `plugin.json`.
- `git push --all` / `--mirror`: they stay in the deploy family (pushing production branches
  is something Jonathan can approve).
- Guarding local `git branch -D <protected>` (the helper refuses protected names itself) and
  the GitHub MCP's branch tools — listed blind spots stay as they are.

## Files owned

`assets/bin/deploy-guard.py`, `assets/tests/test_deploy_guard.py`,
`assets/tests/test_merge_guard.py`, `assets/tests/test_protected_branch_parity.py` (new),
`skills/dev-bother-me-nope/references/deploy-guards.md`.

## Deps

None. Builds in parallel with `cleanup-helper-local-only-mode-and-wider-caches` (disjoint
files; that story does not change `PROTECTED`, so the parity test sees the same list).

## Assumptions

1. Protected deletes get their own family, "branch guard", rather than joining the merge
   guard: the merge-guard advice ("merge commits only …") would mislead, and the deploy-guard
   advice offers the approval prefix, which must not apply. Like the merge family, the prefix
   never lifts it.
2. `--mirror` and `--all` are not moved: they are blocked as production pushes, which an
   approved deploy may legitimately need. `git push --prune <refspec>` deleting remote
   branches is noted in the blind spots, not guarded (outside REVIEW②).
3. GNU `xargs --replace`, `--max-lines` and `--eof` are `optional_argument` options, so a
   value only ever attaches with `=`; BSD xargs has no long flags. Their short forms with
   required values (`-I`, `-L`, `-E`) keep consuming the next token.
4. `--command` is read for every shell in `SHELLS` (only fish defines it; for the others git
   never runs, so reading it can't wrongly block a working command).
5. The parity test compares the live module constants (not regex over source), so a list
   built by union, like `DELETE_PROTECTED = PROTECTED_BRANCHES | {...}`, is compared by value.
