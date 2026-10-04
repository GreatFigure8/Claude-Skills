# Plan — deploy-guard-protected-deletes-and-wrapper-gaps

Story: `story.md` (closes R2-4, R2-5, R2-6). Paths are relative to `Skills/dev-bother-me-nope/`
unless they start with `docs/`. Hook runs on Python 3.9.6: no `match`, no `X | Y` annotations,
no 3.10+ stdlib (`str.removeprefix` is 3.9 and already used).

## 1. Approach

- **R2-4 — a third rule family, the branch guard.** Move the protected-delete check out of the
  deploy family (`check_git` → `deploy_reason`) into `branch_reason`, and evaluate it with the
  merge guard in one helper, `unliftable_block`, that `check_segment` calls *before* the
  `approved` early-return. An inner `sh -c` / `fish --command` string recurses through
  `check_bash` → `check_segment`, so the inherited approval never lifts it either. Refusals read
  `Blocked by dev-bother-me-nope branch guard: <reason>. <BRANCH_ADVICE>`; the advice never names
  `BMN_USER_APPROVED_DEPLOY` (guarding-destructive-operations: a destructive action gets an
  explicit, non-bypassable refusal with a reason, and an approval for one class never widens to
  another).
- **R2-5 — follow the real grammars.** Drop `--replace`, `--max-lines`, `--eof` from
  `WRAPPER_VALUE_FLAGS["xargs"]` (GNU `optional_argument`: value only via `=`); `-I`, `-L`, `-E`,
  `--max-args`, `--process-slot-var` etc. keep eating their value. In `shell_command_string`,
  read `--command <s>` / `--command=<s>` as the command string itself (fish's grammar), for every
  shell in `SHELLS`; every other `--long` flag is still skipped unchanged.
- **R2-6 — parity by value, not by regex.** A new test file loads both live modules with
  `load_script` and compares `DELETE_PROTECTED` with `PROTECTED` as lowercase sets; it proves the
  check bites on `tmp_path` copies, and pins both documented lists to the constant
  (keeping-git-repos-clean: one source of truth for protected names, enforced by a test).

## 2. Files

| File | Change |
| --- | --- |
| `assets/bin/deploy-guard.py` | Docstring rewritten (branch guard, never lifted, parity test, xargs/fish). New `BRANCH_GUARD = "branch"`, `BRANCH_ADVICE`, `GUARD_ADVICE` (MappingProxyType guard→advice). New `push_parts(args)` → `(push_args, remote, refspecs)` or `None` (shared by `check_git` and `branch_reason`). New `branch_reason(prog, args, cwd)` → `deleted_protected_ref` text `` `git push … {spec}` deletes a protected branch``. New `unliftable_block(prog, args, ctx)` → merge Block, else branch Block, else None. `check_git` loses the delete check (keeps `--all/--mirror`, bare push from a production branch, production refspec). `check_segment` calls `unliftable_block` before the approval return. `block_message` becomes one f-string over `GUARD_ADVICE` (deploy text byte-identical). xargs set loses three names. `shell_command_string` reads `--command` / `--command=`. Section comment above the merge guard updated to name both unliftable families. Target ≤ ~770 lines, every function < 50. |
| `assets/tests/test_merge_guard.py` | `BRANCH_PREFIX` constant; four protected-delete tests switched to it; new R2-4, R2-5 and doc tests (§3); `MERGE_RULE_FUNCTIONS` gains `push_parts`, `branch_reason`, `unliftable_block` (no-mutation check). Stays < 800 lines (~720). |
| `assets/tests/test_deploy_guard.py` | AC3: approved real deploys pass; unapproved production push keeps the deploy prefix. |
| `assets/tests/test_protected_branch_parity.py` (new) | AC9–AC12 parity, drift-bites, documented-list checks. |
| `skills/dev-bother-me-nope/references/deploy-guards.md` | Protected-delete bullet rewritten (all eight names backticked, branch-guard block the prefix never lifts, refusal prefix, Jonathan deletes it himself, parity test named). *Approval prefix does not apply* paragraph covers protected deletes. Merge-section intro names the third family. Wrapper bullet names `xargs --replace` (`--max-lines`, `--eof`: value only after `=`) and `fish -c` / `fish --command '…'` / `--command='…'`. Blind spots gain `git push --prune <refspec>` and abbreviated long options (`xargs --max-a 1`, `fish --comm '…'`); `eval`, `doas`, `env -S` stay. *When approved*: "never applies to the merge rules or the branch guard". |

Out of scope (other story / untouched): `merged-branch-cleanup.py`, `SKILL.md`, `briefs.md`,
`test_skill_text_rules.py`, `test_merged_branch_cleanup.py`, `test_helper_script_quality.py`,
`plugin.json`.

## 3. Test plan (write first, watch the R2 reproductions fail, then implement)

All `[unit]`, driven through the real hook with the existing `bash()` / `guard_in()` helpers
(subprocess, active run in a temp repo) unless noted. `BRANCH_PREFIX = "Blocked by
dev-bother-me-nope branch guard:"`.

| AC | Test (file) | Cases |
| --- | --- | --- |
| 1 | `test_approval_prefix_does_not_lift_protected_deletes` (merge_guard, param) | the 7 Bash commands of AC1 (`--delete dev`, `:main`, `-d origin staging`, `+:refs/heads/release`, `sh -c '…dev'`, `sudo -u me bash -lc '…develop'`, `git -C . push … DEV`) → 2 + `BRANCH_PREFIX`. First case fails today (exit 0). |
| 1 | `test_approved_delete_of_the_default_branch_stays_blocked` (merge_guard) | `repo_with_default_branch("trunk")` + `guard_in(root, "BMN_USER_APPROVED_DEPLOY=1 git push origin --delete trunk")` → 2, `BRANCH_PREFIX`. |
| 2 | updated `test_push_delete_of_a_protected_branch_stays_blocked`, `test_blocks_deleting_protected_branches_on_origin`, `test_blocks_deleting_the_default_branch` (merge_guard) | assert `BRANCH_PREFIX` instead of deploy prefix; lists unchanged. |
| 2 | updated `test_protected_delete_message_names_the_branch_spec` (merge_guard) | stderr starts `` f"{BRANCH_PREFIX} `git push … dev` deletes a protected branch. " ``; contains "never deleted inside a bmn run" and "Jonathan deletes it himself"; `"BMN_USER_APPROVED_DEPLOY" not in stderr`. |
| 3 | `test_approval_prefix_passes_real_deploys` (deploy_guard, param) | `BMN_USER_APPROVED_DEPLOY=1 git push origin main`, `BMN_USER_APPROVED_DEPLOY=1 vercel deploy --prod` → 0. Existing `test_user_approved_prefix_lets_a_deploy_through`, `test_approval_still_passes_deploys_through_a_shell`, `test_approval_still_passes_wrapped_deploys`, `test_deploy_block_message_is_unchanged` stay green. |
| 3 | `test_unapproved_production_push_hits_the_deploy_guard` (deploy_guard) | `git push origin main` → 2, stderr starts `Blocked by dev-bother-me-nope deploy guard:`. |
| 4 | `test_cleanup_deletes_stay_allowed_with_and_without_the_prefix` (merge_guard, param) | each of `git push origin --delete wip/demo/a`, `git push origin --delete feat/run-branch`, `git push origin --force-with-lease=refs/heads/wip/x:0a1b2c3d --delete wip/x`, plus every `ALLOWED_DELETES` + `ALLOWED_BRANCH_PUSHES` entry, run bare and with the prefix → 0. |
| 5 | `test_blocks_merges_behind_gnu_xargs_long_flags` (merge_guard, param) | `xargs --replace git merge --squash x`, `--max-lines …`, `--eof …`, `--replace=R … R`, `xargs --max-lines=1 gh pr merge 12 --squash --delete-branch` → 2 + merge prefix. First fails today. |
| 5 | `test_blocks_deploys_behind_gnu_xargs_long_flags` (merge_guard) | `xargs --replace vercel deploy --prod` → 2 + deploy prefix. |
| 6 | `test_xargs_value_flags_still_consume_their_value` (merge_guard, param) | `-I {}`, `-L 1`, `-n 1`, `--max-args 1`, `-E EOF`, `--process-slot-var SLOT` before `git merge --squash …` → 2. |
| 6 | `test_xargs_value_flags_leave_harmless_commands_alone` (merge_guard, param) | `xargs -I {} git status {}`, `xargs --replace echo squash` → 0. |
| 7 | `test_blocks_squash_merges_behind_fish_command` (merge_guard, param) | `fish --command='git merge --squash x'` (fails today), `fish --command '…'`, `fish -c '…'`, `BMN_USER_APPROVED_DEPLOY=1 fish --command '…'` → 2 + merge prefix. |
| 7 | `test_fish_command_reaches_the_branch_guard` (merge_guard) | `fish --command='git push origin --delete dev'` → 2 + `BRANCH_PREFIX`. |
| 7 | `test_fish_allows_harmless_strings_and_script_arguments` (merge_guard, param) | `fish --command='git status'`, `fish script.fish --command 'git merge --squash x'` → 0. |
| 7 | `test_command_long_flag_is_read_for_every_shell` (merge_guard, param over `sh bash zsh dash ksh fish`) | `<shell> --command 'git merge --squash x'` → 2; plus `bash --norc --login -c '…'` still 2 (no other long flag changes meaning). |
| 8 | `test_doc_names_xargs_long_flags_and_fish_command` (merge_guard) | wrapper bullet of `merge_section` contains `xargs --replace`, `fish -c`, `fish --command`. |
| 8 | `test_doc_blind_spots_omit_covered_xargs_and_fish_forms` (merge_guard) | `blind_spots(doc)` lacks `xargs --replace`, `fish -c`, `fish --command`; contains `git push --prune`. Existing `test_doc_blind_spots_no_longer_claim_covered_shell_wrappers` (eval/doas/env -S) unchanged. |
| 9 | `test_guard_and_cleanup_protect_the_same_branches` (parity) | `drift(guard, helper) == (frozenset(), frozenset())` via `load_script("deploy-guard")`, `load_script("merged-branch-cleanup")`. Passes today. |
| 10 | `test_parity_reports_a_name_only_the_guard_protects` (parity) | copy of `deploy-guard.py` in `tmp_path` with `DELETE_PROTECTED = DELETE_PROTECTED \| frozenset({"qa"})` appended, loaded with `importlib` under a unique name (`monkeypatch.setitem(sys.modules, …)`); `drift == ({"qa"}, set())`; bytes of both `assets/bin` scripts identical before/after. |
| 10 | `test_parity_reports_a_name_only_the_cleanup_protects` (parity) | symmetric helper copy with `PROTECTED = frozenset(PROTECTED) \| {"qa"}` → `(set(), {"qa"})`; bin bytes unchanged. |
| 10 | `test_parity_compares_lowercase_names` (parity) | helper copy adding `"DEV"` → no drift. |
| 11 | `test_every_protected_name_is_in_the_guard_docstring` (parity) | whitespace-normalised module docstring; the parenthetical after "protected branch (" holds every `DELETE_PROTECTED` name as a word. |
| 11 | `test_every_protected_name_is_in_the_doc_bullet` (parity) | the bullet from `- Deleting a protected branch on origin` to the next `\n- ` / `\n\n` contains `` `name` `` for every name. |
| 12 | `test_doc_says_the_list_is_checked_against_the_cleanup_helper` (parity) | bullet names `merged-branch-cleanup.py` and `test_protected_branch_parity.py`. |
| 12 | `test_doc_calls_protected_deletes_a_branch_guard_block` (merge_guard) | bullet contains `branch-guard block`, `BMN_USER_APPROVED_DEPLOY=1`, `never lifts`, `Blocked by dev-bother-me-nope branch guard:`; lacks `deploy-guard block`. Existing `test_doc_lists_the_protected_branch_deletes` stays green (`--force-with-lease` lives in the cleanup bullet). |
| 12 | `test_doc_approval_paragraph_covers_protected_deletes` (merge_guard) | paragraph from `**The approval prefix does not apply.**` to `\n\n` mentions `protected` and `branch guard`; *When approved* section mentions `branch guard`. |
| 12 | `test_guard_docstring_says_the_prefix_never_lifts_protected_deletes` (merge_guard) | docstring contains `branch guard`, `never lifts`, `merged-branch-cleanup.py`, `test_protected_branch_parity.py`, `xargs --replace`, `fish --command`. |
| 13 | gates + existing `test_guard_stays_under_800_lines`, `test_every_guard_function_is_under_50_lines`, `test_merge_rule_functions_do_not_mutate` (extended list) | — |

Totals: 25 new test functions + 4 updated = 29. No browser criteria (library; no Playwright).

## 4. Data

None — no models, migrations or RLS.

## 5. Config / env vars / deploy_pending

No new env vars (`BMN_USER_APPROVED_DEPLOY` exists). `deploy_pending: []`. The hook ships in the
plugin; the version bump to 1.6.1 is owned by the sibling story (`plugin.json`).

## 6. Risks and gates

- **Message change for production-name deletes.** `git push origin --delete main` / `:main` now
  report the branch guard ("deletes a protected branch") instead of the deploy guard ("pushes a
  production branch") because the branch check runs first. Intended; covered by updated tests.
- **Sibling story edits `merged-branch-cleanup.py`.** The parity test imports it live; a broken
  import there fails this story's parity tests after integration. `PROTECTED` is not changed by
  that story, so parity holds.
- **Line budget.** deploy-guard.py 724 → ~765; keep `check_segment`, `shell_command_string`
  short (both well under 50).
- **fish grammar unverified locally** (`fish` not installed): only exact `--command` /
  `--command=` and `-c` are read; abbreviations are documented as a blind spot.
- **Python 3.9.6**: run the second gate; no new syntax.

Gates (from the run worktree root):
1. `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`
2. `uv run --quiet --python /usr/bin/python3 --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`
3. `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope/assets`

## Assumptions

1. Build skills `python-library-quality:guarding-destructive-operations` and
   `python-library-quality:keeping-git-repos-clean` are not installed in this session; the plan
   follows the rules restated in `story.md` and `stack.md`.
2. The branch guard and the merge guard share one pre-approval helper (`unliftable_block`) so
   "the prefix never lifts it" lives in one place and `check_segment` stays short.
3. `test_blocks_deleting_the_default_branch` also asserts the deploy prefix for a delete, so it
   is updated with the three tests AC2 names (lists unchanged, nothing deleted).
4. `BRANCH_ADVICE` = "A protected branch is never deleted inside a bmn run, approved deploy or
   not; if it should go, Jonathan deletes it himself."
5. Only exact `--command` / `--command=` are read (AC7 wording). Abbreviated long options
   (`fish --comm`, `xargs --max-a 1`) are listed as blind spots rather than guarded: fish is not
   installed here to verify its abbreviation grammar, and the story does not ask for them.
6. The drift copies append a module-level reassignment instead of regex-editing the literal, so
   they work however the constant is built (story assumption 5).
7. `git push --prune <refspec>` goes into the blind spots, not the guard (story assumption 2).
8. Plan file is left uncommitted; the integrator commits all plans (run instruction).
