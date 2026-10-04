# The deploy guard blocks squash merges and PR merges that keep the source branch

**Slug:** `deploy-guard-blocks-squash-merges`
**Run:** `bmn-merged-branch-cleanup-and-no-squash-merges` · plugin `Skills/dev-bother-me-nope/`

## Story

**As** Jonathan ("NO MORE SQUASH MERGING. I want history from here on out"),
**I want** the dev-bother-me-nope PreToolUse guard to refuse every squash merge, and every
PR merge that doesn't delete its source branch, while a bmn run is active,
**so that** no worker, fixer or orchestrator can flatten history or leave a merged head
branch on origin by accident, whatever the skill text says.

## Context

- `Skills/dev-bother-me-nope/assets/bin/deploy-guard.py` (406 lines) is the plugin's
  PreToolUse hook (`hooks/hooks.json`, matcher `Bash|mcp__.*`). It is active only while a
  `docs/sprints/bmn-*/bmn.json` run is unfinished. It tokenizes Bash into segments
  (`split_segments`; quoted text and heredocs never split or trigger), unwraps env/wrapper
  prefixes (`unwrap`), and dispatches per program (`check_segment`: vercel, supabase,
  psql, git push). It has no `gh` handling and no `git merge`/`git pull` handling today.
  `BMN_USER_APPROVED_DEPLOY=1` short-circuits every check in `check_segment`.
- `check_mcp` handles Supabase/Vercel MCP tools. The GitHub MCP `merge_pull_request` tool
  takes a `merge_method` (`merge|squash|rebase`).
- Tests: `assets/tests/test_deploy_guard.py`, 106 passing at `dev_base`. It has
  `BLOCKED_BASH`/`ALLOWED_BASH` parametrized lists, `mcp()` and `bash()` helpers, an
  active-repo fixture and an inactive one. Allowed case line 107:
  `git push origin --delete wip/demo/story-a`.
- `skills/dev-bother-me-nope/references/deploy-guards.md` documents what the guard blocks.
- stack.md assumption 5: bmn never squashes (`git merge --squash`, `gh pr merge --squash`/`-s`,
  `merge_method=squash`). Its merges stay `--no-ff` merge commits, and the guard blocks
  squash merges while a run is active. Rebase merges are left as they are. Assumption 4: any
  PR bmn merges uses `gh pr merge --merge --delete-branch`.

## Acceptance criteria

Unless a criterion says otherwise, every case runs through the existing `bash()`/`mcp()`
helpers against the active-repo fixture. "Blocked" means exit 2 with the reason on stderr.

1. **[unit]** Squash via git is blocked: `git merge --squash feat/x`,
   `git -C /tmp/w merge --squash wip/demo/a`, `git pull --squash origin dev`,
   `cd w && git merge --squash x && git commit -m y`, `env FOO=1 git merge --squash x`,
   `bash -c "git merge --squash x"`, `git merge --no-ff --squash x`.
2. **[unit]** Squash via `gh pr merge` is blocked: `gh pr merge 12 --squash --delete-branch`,
   `gh pr merge 12 -s -d`, `gh pr merge 12 -sd`, `gh pr merge 12 -ds`,
   `gh pr merge --squash`, `gh pr merge 12 --repo o/r --squash --delete-branch`,
   `gh pr merge 12 -R o/r -s -d`, `gh pr merge 12 --squash=true -d`.
   `--subject`/`-t`, `--body`/`-b`, `--body-file`/`-F`, `--author-email`/`-A`,
   `--match-head-commit` and `-R`/`--repo` are parsed as value flags. So
   `gh pr merge 12 -m -d -t "-s fix"` is **allowed**: the value is not a flag.
3. **[unit]** A PR merge that keeps its source branch is blocked: `gh pr merge 12 --merge`,
   `gh pr merge 12 -m`, `gh pr merge 12 --rebase`, `gh pr merge 12 --auto --merge`,
   `gh pr merge 12 -m --delete-branch=false`. Allowed: `gh pr merge 12 --merge --delete-branch`,
   `gh pr merge 12 -m -d`, `gh pr merge 12 -md`,
   `gh pr merge 12 --merge --delete-branch --repo o/r`,
   `gh pr merge 12 --rebase --delete-branch`, `gh pr merge 12 --disable-auto` (merges
   nothing), `gh pr view 12`, `gh pr create --fill`, `gh pr list`.
4. **[unit]** Squash via the GitHub API is blocked: `gh api -X PUT repos/o/r/pulls/12/merge
   -f merge_method=squash`, the same with `-F`, `--field`, `--raw-field` and
   `merge_method=SQUASH`, and `gh api graphql -f query='mutation { mergePullRequest(input:
   {pullRequestId: "x", mergeMethod: SQUASH}) { clientMutationId } }'`. Allowed:
   `gh api -X PATCH repos/o/r -F allow_squash_merge=false -F delete_branch_on_merge=true`
   (what the repo-merge-policy helper sends), `gh api -X PUT repos/o/r/pulls/12/merge -f
   merge_method=merge`, `gh api repos/o/r`.
5. **[unit]** Squash via MCP is blocked: any MCP tool whose name ends in `merge_pull_request`
   (e.g. `mcp__github__merge_pull_request`, `mcp__<uuid>__merge_pull_request`) with
   `merge_method` or `mergeMethod` equal to `squash`, case-insensitively. The same tool with
   `merge`, `rebase` or no method is allowed. No other MCP decision changes, and all existing
   MCP tests pass unchanged.
6. **[unit]** Text and lookalikes never trip it. Allowed:
   `git commit -m "no more git merge --squash"`, `git log --grep=squash`,
   `echo 'gh pr merge --squash'`, `git commit -F - <<'EOF'\ngit merge --squash x\nEOF`,
   `git merge --no-ff feat/x`, `git merge --no-squash x`,
   `git merge -s ours x` (`-s` is git's *strategy* flag, not squash),
   `git merge --strategy=recursive x`, `grep -r -- --squash docs/`.
7. **[unit]** The approval prefix doesn't unlock merge rules:
   `BMN_USER_APPROVED_DEPLOY=1 git merge --squash x` and
   `BMN_USER_APPROVED_DEPLOY=1 gh pr merge 1 --squash -d` stay blocked.
   `test_user_approved_prefix_lets_a_deploy_through` still passes unchanged.
8. **[unit]** Messages: a merge-rule block's stderr starts with
   `Blocked by dev-bother-me-nope merge guard:`. It names the reason and the allowed forms,
   `git merge --no-ff` and `gh pr merge <n> --merge --delete-branch`, and it does **not**
   mention `BMN_USER_APPROVED_DEPLOY`. Deploy blocks keep their current message byte for
   byte.
9. **[unit]** Scope: with no run in progress (inactive fixture), or with a run in `done` or
   `blocked`, every command in criteria 1-5 is allowed. The guard stays an accident guard for
   bmn runs, not a global policy.
10. **[unit]** Branch cleanup is never blocked: `git push origin --delete feat/demo-run`,
    `git branch -D wip/demo/a`, `git worktree remove ../x` and `git worktree prune` are
    allowed. `git push origin --delete main` stays blocked by the existing protected-branch
    rule. All 106 pre-existing tests pass, including line 107's case.
11. **[unit]** Docs: `references/deploy-guards.md` gains a section whose heading contains
    "Merge commits only". It lists every blocked form from criteria 1-5, the allowed forms,
    that the approval prefix does not apply, and that the GitHub repo setting
    (`allow_squash_merge=false`, `delete_branch_on_merge=true`, set at INTAKE) covers merges
    made outside a run. The `deploy-guard.py` module docstring mentions the merge rules. A
    test asserts the heading and each blocked form string are present in the doc.
12. **[unit]** Gates: ruff is clean on `deploy-guard.py` and the test file. `deploy-guard.py`
    stays under 800 lines. New logic lives in small functions (`check_git_merge`,
    `check_gh`, MCP merge check) under 50 lines each, in the existing immutable style (no
    in-place mutation of token lists). The full suite
    `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`
    passes.

## Out of scope

- SKILL.md, briefs.md, bmn-worker.md, report-template.md, move-computers.md and `plugin.json`
  (story `skill-text-merged-branch-cleanup-and-merge-commits-only`).
- The cleanup and repo-policy scripts (story
  `merged-branch-cleanup-and-repo-merge-policy-scripts`).
- Blocking rebase merges (stack.md assumption 5), and blocking `gh repo edit` /
  `gh api PATCH` calls that would turn squash back on (YAGNI: the repo setting is the
  backstop and Jonathan owns it).
- `gh api --input <file>` bodies. The guard can't see file contents, which is consistent
  with its "accident guard, not a sandbox" contract.
- `hooks/hooks.json`: the matcher `Bash|mcp__.*` already covers both surfaces.

## Deps

None.

## Assumptions

- The python-library-quality skills named in the run brief weren't installed in the
  splitter's session. The planner and coder load them if available.
- `BMN_USER_APPROVED_DEPLOY=1` is a deploy pass-through only. "NO MORE SQUASH MERGING" is a
  standing rule with no in-run exception, so merge-rule checks run even when the prefix is
  present. If Jonathan ever wants a squash, he runs it himself.
- A PR merge without `--delete-branch` is blocked as well as squash. That enforces stack.md
  assumption 4 for bmn's own merges. `--disable-auto` is not a merge and stays allowed.
- Combined short flags (`-sd`, `-md`) follow cobra's bool-shorthand rules. A single-dash token
  of letters only is read as a flag cluster, unless it's the value of a known value flag.
- The guard is deliberately ignorant of which repository a `gh` command targets. Inside an
  active run every squash is blocked.
