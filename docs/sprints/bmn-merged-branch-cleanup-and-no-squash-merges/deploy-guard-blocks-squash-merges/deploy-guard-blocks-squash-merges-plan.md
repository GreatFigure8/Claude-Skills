# Plan — deploy-guard-blocks-squash-merges

Story: [story.md](story.md) · Run `bmn-merged-branch-cleanup-and-no-squash-merges` · plugin
`Skills/dev-bother-me-nope/` · Python stdlib only (the hook runs on bare `python3`).

## 1. Approach

1. Add a second rule family, the **merge guard**, beside the deploy rules in
   `assets/bin/deploy-guard.py`. It is checked per Bash segment *before* the
   `BMN_USER_APPROVED_DEPLOY` short-circuit, and per MCP call before the deploy checks. The
   approval prefix stays a deploy-only pass-through (story assumption 2).
2. Every rule returns a `Block(guard, reason)` NamedTuple, not a bare string. `main()`
   picks the message by `guard`. The deploy message text is moved into a constant and stays
   byte-for-byte identical (pinned by a test captured from `dev_base`, see §3, C8).
3. `git merge|pull`: a git parse-options-aware scan (value flags skipped, `--` stops, last
   of `--squash`/`--no-squash` wins, git's unambiguous long-option abbreviations `--sq…`
   honoured: verified locally, `git merge --squ b` squashes).
4. `gh pr merge` / `gh api`: one small pflag-faithful parser (`pflag_items`), written from
   pflag v1.0.10 source (the version gh v2.92.0 pins), so `-sd`, `-s=false`, `--squash=true`,
   `-tvalue` and value flags whose value starts with `-` resolve the same way gh resolves them.
5. MCP: any tool whose name ends in `merge_pull_request` with `merge_method`/`mergeMethod`
   equal to `squash` (case-insensitive) is a merge block. No other MCP decision changes.

Why: the guard's contract ("accident guard, not a sandbox", "anything it cannot parse is
allowed") is kept, and its precision rule is kept too: quoted text, heredocs and lookalikes
never trigger. Skill guidance applied: `python-library-quality:keeping-git-repos-clean` and
`:guarding-destructive-operations` are **not installed in this session** ("Unknown skill"),
so I followed the rules the story and stack.md restate. A destructive or history-losing
operation is refused at the boundary. The refusal names the safe alternative
(`git merge --no-ff`, `gh pr merge <n> --merge --delete-branch`). Merged branches get deleted,
and the branch-cleanup commands themselves are never blocked. Parsing mirrors the real tool, so
the guard neither over-blocks nor under-blocks. Small pure functions, no in-place mutation.

### Verified CLI facts (local `--help`, plus source fetched read-only from GitHub)

- `gh version 2.92.0`. `gh pr merge --help` shows these flags. Bool flags: `--admin`, `--auto`,
  `-d/--delete-branch`, `--disable-auto`, `-m/--merge`, `-r/--rebase`, `-s/--squash`. Value
  flags: `-A/--author-email`, `-b/--body`, `-F/--body-file`, `--match-head-commit`,
  `-t/--subject`, inherited `-R/--repo`. `-h`/`--help` prints help (checked locally).
  `cli/cli@v2.92.0 pkg/cmd/pr/merge/merge.go:174-185` registers exactly these, so all story
  spellings are confirmed. The story omits **`-r`** (short for `--rebase`), and the plan adds it.
- Same source: `--disable-auto` returns before any merge (`merge.go:548`). With `--auto`, gh
  never deletes the remote branch itself (`deleteRemoteBranch` returns early on `autoMerge`,
  `merge.go:456`). `-d` is refused when a merge queue is required (`merge.go:248`).
  `--merge/--rebase/--squash` are mutually exclusive. With no method and no TTY, gh errors
  out (`merge.go:309`).
- `gh api --help` lists these. Value flags: `--cache`, `-F/--field`, `-H/--header`,
  `--hostname`, `--input`, `-q/--jq`, `-X/--method`, `-p/--preview`, `-f/--raw-field`,
  `-t/--template`. Bool flags: `-i/--include`, `--paginate`, `--silent`, `--slurp`,
  `--verbose`.
- pflag v1.0.10 (`flag.go` `parseLongArg` :980, `parseSingleShortArg` :1047-1090,
  `bool.go` `strconv.ParseBool`). Long `--f=v` takes the attached value, a bool `--f` takes
  `"true"`, and a value `--f` consumes the next arg. Short clusters read left to right:
  `-x=v` takes `v`, a bool letter takes `"true"` and continues, and a value letter takes the
  rest of the cluster or else the next arg. `--` ends flags, and flags may come after
  positionals. True values are `1 t T TRUE true True`.
- git 2.54.0: `git merge -h` and `git pull -h` show these. `--[no-]squash` is long-only.
  `-s` is `--strategy <strategy>`. Value options are `-m/--message`, `-F/--file`,
  `-s/--strategy`, `-X/--strategy-option`, `--into-name`, `--cleanup`. Pull adds
  `--upload-pack`, `--depth`, `--deepen`, `--shallow-since`, `--shallow-exclude`, `--refmap`,
  `-o/--server-option`, `--negotiation-tip`. Abbreviations `--sq`, `--squ` and `--no-squ`
  are accepted (tested in a scratch repo).
- Baseline at `dev_base`: these 3 commands currently exit 0 in an active repo (the RED
  starting point). `git merge --squash x`, `gh pr merge 1 --squash -d`,
  `gh api -X PUT repos/o/r/pulls/12/merge -f merge_method=squash`.

### Function design (all < 50 lines, tuples, rebinding only, no `.append`/item assignment)

| Function | Contract |
| --- | --- |
| `Block(NamedTuple)` | `guard: str` (`DEPLOY_GUARD="deploy"` / `MERGE_GUARD="merge"`), `reason: str` |
| `is_abbrev(arg, full, shortest)` | `len(arg) >= len(shortest) and full.startswith(arg)` |
| `git_merge_squashes(args)` | args after `merge`/`pull`: skip values of `GIT_MERGE_VALUE_FLAGS`, stop at `--`, fold `--squash`/`--no-squash` (abbrev-aware), last wins |
| `check_git_merge(args)` | `git_subcommand(args)`; `merge`/`pull` + squash → reason string, else `None` |
| `pflag_items(args, shorts, value_names)` | tuple of `(long_name, value)` in order; loop with rebinding; `--` stops |
| `long_flag(body, rest, value_names)` | `((name, value),), rest` per pflag `parseLongArg` |
| `short_cluster(letters, rest, shorts, value_names)` | per pflag `parseSingleShortArg`; unknown letters read as bools |
| `is_true(value)` | `value in PFLAG_TRUE` |
| `check_gh(args)` | `positional(args, {"-R","--repo"})[:2]`: `pr merge` → `check_gh_pr_merge`, `api` → `check_gh_api` |
| `check_gh_pr_merge(args)` | `flags = dict(pflag_items(...))`; help → allow; squash → block; disable-auto → allow; not delete-branch → block |
| `check_gh_api(args)` | any `field`/`raw-field` value where `is_squash_field` → block |
| `is_squash_field(text)` | key in {`merge_method`,`mergemethod`} (case-insensitive) and value `squash` (quotes stripped, case-insensitive), or `GRAPHQL_SQUASH` (`mergeMethod\s*:\s*"?squash\b`, IGNORECASE) matches |
| `merge_reason(prog, args)` | `git` → `check_git_merge`, `gh` → `check_gh`, else `None` |
| `deploy_reason(prog, args, ctx)` | the existing vercel/supabase/psql/git-push dispatch, moved out of `check_segment` unchanged |
| `check_segment(tokens, ctx)` | unwrap; shells `-c` recurse with `{**ctx, "approved": approved or ctx["approved"]}` (approval reaches inner deploys exactly as today); merge rule first → `Block(MERGE…)`; approved → `None, ctx` (unchanged: no `with_link`); else `Block(DEPLOY…)` |
| `check_mcp_merge(tool, tool_input)` | name ends `merge_pull_request` and `merge_method`/`mergeMethod` lower == `squash`; non-dict input → `None` |
| `mcp_deploy_reason(server, tool, tool_input)` | the existing `check_mcp` body, unchanged |
| `check_mcp(tool_name, tool_input)` | merge check first, then deploy; returns `Block` or `None` |
| `block_message(block)` | deploy text byte-identical to today; merge text below |

Constants: `GIT_MERGE_VALUE_FLAGS`, `GH_PR_MERGE_SHORTS` (`A b F d m r s t R h`),
`GH_PR_MERGE_VALUES`, `GH_API_SHORTS` (`F f H i q X p t h`), `GH_API_VALUES`, `PFLAG_TRUE`,
`GRAPHQL_SQUASH`, `SQUASH_FIELD_KEYS`, `MERGE_GUARD`, `DEPLOY_GUARD`, `ALLOWED_MERGE_FORMS`.

Merge message (no `BMN_USER_APPROVED_DEPLOY` in it):
`Blocked by dev-bother-me-nope merge guard: {reason}. Merge commits only: squash merges
flatten history and are never run inside a bmn run, and a merged PR's source branch is
deleted. Allowed: \`git merge --no-ff <branch>\`, and for a PR \`gh pr merge <n> --merge
--delete-branch\`.` (one line on stderr)

Example reasons: ``"`git merge --squash` folds a branch's commits into one"``,
``"`gh pr merge --squash` folds the PR's commits into one"``,
``"`gh pr merge` without `--delete-branch` leaves the merged source branch on origin"``,
``"`gh api` merge with `merge_method=squash`"``, ``"MCP `merge_pull_request` with merge_method=squash"``.

## 2. Files

| File | Change | Purpose |
| --- | --- | --- |
| `Skills/dev-bother-me-nope/assets/bin/deploy-guard.py` | change | merge guard (functions above), `Block`, `block_message`, docstring paragraph on merge rules. Fixes the 12 pre-existing ruff findings in this file and the test file (`re.S`→`re.DOTALL`, `re.I`→`re.IGNORECASE`, `min(...)` for `sorted(...)[0]`, explicit `check=False`, collapsed nested `if`; for RUF007 use `{tuple(words[i:i + 2]) for i in range(len(words) - 1)}`, **not** `itertools.pairwise`, which is 3.10+, while the hook must run on macOS `/usr/bin/python3` 3.9.6). ~406 → ~560 lines |
| `Skills/dev-bother-me-nope/assets/tests/test_merge_guard.py` | **new** | every merge-guard test (§3). It imports `bash`, `mcp`, `run_guard`, `new_repo`, `start_run`, `guard_in`, `GUARD` from `test_deploy_guard` (pytest's default prepend import mode puts the test dir on `sys.path`). ~230 lines |
| `Skills/dev-bother-me-nope/assets/tests/test_deploy_guard.py` | change (lint only) | add `check=False` to its two `subprocess.run` calls (PLW1510). No test is added, removed or edited |
| `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/deploy-guards.md` | change | new `## Merge commits only — no squash merges, PR merges delete their branch` section (blocked forms, allowed forms, approval prefix does not apply, repo setting backstop, known blind spots); title becomes `# Deploy and merge guards — Vercel, Supabase, git`; one-line pointer in "When approved" |

4 files (1 new, 3 changed). `hooks/hooks.json` is not touched (matcher `Bash|mcp__.*`).

## 3. Test plan (written first, RED against `dev_base`)

All are **unit** tests in `Skills/dev-bother-me-nope/assets/tests/test_merge_guard.py`, run
through `bash()`/`mcp()` against the active `ACTIVE_REPO` unless noted. Blocked means
`returncode == 2` and stderr starts with `Blocked by dev-bother-me-nope merge guard:`. No
browser, API or MCP-server surface, so there are no Playwright tests.

| AC | Test (parametrized list) | Cases |
| --- | --- | --- |
| 1 | `test_blocks_git_squash_merges` over `BLOCKED_GIT_SQUASH` | the story's 7, plus `git merge --squ feat/x` (git abbreviation) |
| 2 | `test_blocks_gh_pr_squash_merges` over `BLOCKED_GH_SQUASH` | the story's 8 |
| 3 | `test_blocks_pr_merges_that_keep_the_source_branch` over `BLOCKED_PR_KEEPS_BRANCH` | the story's 5, plus `gh pr merge 12` and `gh pr merge 12 -r` |
| 2, 3 | `test_allows_pr_merges_that_delete_the_branch_and_other_gh` over `ALLOWED_GH` | the story's 9 allowed, plus `gh pr merge 12 -m -d -t "-s fix"` (AC2), `gh pr merge --help`, `gh pr merge 12 -md -b "-s"`, `gh pr merge 12 -md -F -`, `gh pr merge 12 -m -d --squash=false` |
| 4 | `test_blocks_api_squash_merges` over `BLOCKED_API_SQUASH` | the story's 6 (`-f`, `-F`, `--field`, `--raw-field`, `SQUASH`, graphql `mergeMethod: SQUASH`), plus `--field=merge_method=squash` and `-fmerge_method=squash` |
| 4 | `test_allows_api_calls_that_do_not_squash` over `ALLOWED_API` | the story's 3, plus `gh api search/issues -f q='merge_method=squash in:body'` |
| 5 | `test_blocks_mcp_squash_merges` | `mcp__github__merge_pull_request` merge_method=`squash`; `mcp__1a2b3c4d__merge_pull_request` mergeMethod=`SQUASH`; `mcp__github__merge_pull_request` merge_method=`Squash` |
| 5 | `test_allows_mcp_merges_that_do_not_squash` | merge_method `merge`, `rebase`, none, mergeMethod `MERGE`. The existing MCP tests in `test_deploy_guard.py` pass unchanged |
| 6 | `test_merge_lookalikes_are_allowed` over `ALLOWED_LOOKALIKES` | the story's 9, plus `git merge --squash --no-squash x` (last wins) |
| 7 | `test_approval_prefix_does_not_unlock_merge_rules` | the story's 2, plus `BMN_USER_APPROVED_DEPLOY=1 bash -c "git merge --squash x"` |
| 7 | `test_approval_still_passes_deploys_through_a_shell` | `BMN_USER_APPROVED_DEPLOY=1 bash -c "vercel --prod"` → 0 (pins today's behaviour). The existing `test_user_approved_prefix_lets_a_deploy_through` passes unchanged |
| 8 | `test_merge_block_message_names_the_allowed_forms` | one git, one `gh pr merge` no-delete, one `gh api`, one MCP case. Asserts the prefix, `git merge --no-ff`, `gh pr merge <n> --merge --delete-branch`, and that `BMN_USER_APPROVED_DEPLOY` is absent |
| 8 | `test_deploy_block_message_is_unchanged` | exact stderr for `vercel --prod` and for MCP `mcp__supabase__apply_migration`, as captured at `dev_base` (below) |
| 9 | `test_merge_rules_idle_outside_an_active_run` [inactive, done, blocked] | every Bash command from ACs 1-4 plus the MCP squash calls → 0, in `new_repo(active=False)` and in runs at `done`/`blocked`, via `guard_in`/`run_guard(cwd=…)` |
| 10 | `test_branch_cleanup_is_never_blocked` | `git push origin --delete feat/demo-run`, `git branch -D wip/demo/a`, `git worktree remove ../x`, `git worktree prune` |
| 10 | `test_push_delete_of_a_protected_branch_stays_blocked` | `git push origin --delete main` → 2, stderr contains `deploy guard:` |
| 10 | the existing suite | all 106 tests in `test_deploy_guard.py` pass, line 107's case included |
| 11 | `test_deploy_guards_doc_lists_merge_rules` | the section under a heading containing `Merge commits only` contains `git merge --squash`, `git pull --squash`, `gh pr merge --squash`, `-s`, `--delete-branch`, `--delete-branch=false`, `merge_method=squash`, `mergeMethod: SQUASH`, `merge_pull_request`, `git merge --no-ff`, `gh pr merge <n> --merge --delete-branch`, `BMN_USER_APPROVED_DEPLOY`, `allow_squash_merge=false`, `delete_branch_on_merge=true` |
| 11 | `test_guard_docstring_mentions_merge_rules` | `ast.get_docstring` of `deploy-guard.py` contains `squash` and `--delete-branch` |
| 12 | `test_guard_stays_under_800_lines` | line count < 800 |
| 12 | `test_every_guard_function_is_under_50_lines` | every `FunctionDef` in the module: `end_lineno - lineno + 1 < 50` |
| 12 | `test_merge_rule_functions_do_not_mutate` | the named merge-rule functions exist, and none of them calls `append/extend/insert/pop/remove/sort/clear/update` or assigns to a subscript |
| 12 | gates (§6) | ruff clean on both files; full suite passes |

Expected deploy stderr (byte-exact, plus a trailing `\n`):
`` Blocked by dev-bother-me-nope deploy guard: `vercel` with no subcommand deploys. Jonathan decides every deploy and every remote database change — add it to the report's Deploy checklist instead. (Only if he said 'deploy' in chat this session: prefix the command with BMN_USER_APPROVED_DEPLOY=1.) ``
and the same with reason `` MCP `apply_migration` changes a remote Supabase project `` for the MCP case.

Count: 89 new test cases (8+8+7+14+8+4+3+4+10+3+1+4+2+3+4+1+1+1+1+1+1). The suite goes
from 106 to **195**.

## 4. Data

None. No models, no migrations, no RLS, no Supabase.

## 5. Config / env / deploy_pending

- Env vars: none new. `BMN_USER_APPROVED_DEPLOY` keeps its deploy-only meaning, and the merge
  guard ignores it.
- `deploy_pending`: **[]**. The hook ships with the plugin; nothing goes to Vercel or Supabase.
  The plugin version bump belongs to the `skill-text-…` story (`plugin.json` is out of scope
  here).

## 6. Risks and gates

Risks:
- **Locking out a legitimate merge.** Inside a run, `gh pr merge` without `-d` is refused,
  and gh refuses `-d` on merge-queue branches. A merge-queue PR therefore can't be merged by
  bmn mid-run. bmn merges with `git merge --no-ff` and has no merge queue, so this is
  accepted and recorded in the doc.
- **`--auto … -d` deletes nothing itself** (gh source). The guard allows it. GitHub deletes
  the branch when the auto-merge lands only if `delete_branch_on_merge=true`, which INTAKE
  sets. The doc says so.
- **Blind spots** (accident guard, recorded in the doc): `gh api --input` and `-F key=@file`
  bodies, GraphQL variables not named `mergeMethod`, `curl` to the REST API, git aliases,
  `branch.<name>.mergeOptions=--squash`, `eval`/`bash -lc`.
- **Python 3.9.** The hook runs on bare `python3`, and without Homebrew that is
  `/usr/bin/python3` 3.9.6. So no `itertools.pairwise`, no `match`, no runtime `X | Y`. A 3.9
  gate run guards this (the baseline passes on 3.9: 106 passed).
- **Refactor regressions** in `check_segment`/`check_mcp`/`main`. All 106 existing tests
  plus the byte-exact message tests pin them. An approved segment still returns the
  unchanged `ctx` (no `with_link`).
- **Shared worktree.** Three stories run in parallel, on disjoint files. This plan touches no
  file the other two own.

Gates (run in the run worktree; `git branch --show-current` sits in the same command as any
commit):
```
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q
uv run --quiet --no-project --python /usr/bin/python3 --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q -p no:cacheprovider
uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope/assets/bin/deploy-guard.py Skills/dev-bother-me-nope/assets/tests/test_deploy_guard.py Skills/dev-bother-me-nope/assets/tests/test_merge_guard.py
wc -l Skills/dev-bother-me-nope/assets/bin/deploy-guard.py   # < 800
```

## Assumptions

- The two python-library-quality skills the brief names aren't installed ("Unknown skill").
  The plan follows the rules the story and stack.md restate.
- Research-and-reuse: the hook must be stdlib-only because it runs on bare `python3`, so no
  PyPI dependency is possible. `argparse` was considered and rejected because it does not
  match pflag. It refuses `-t "-s"` (a value that looks like a flag), while pflag always
  consumes it, and it has no `-x=v` short form. So a ~35-line pflag port, cited to source
  lines, is the reuse.
- `-r` (short for `--rebase`) is treated like `--rebase`. The story listed only the long
  form, and gh's source registers both.
- `gh pr merge --help`/`-h` merges nothing and is allowed. A squash flag combined with
  `--disable-auto` is still blocked (squash is checked first; the combination has no use).
- `gh pr merge 12 -d` with no method is allowed. It either errors without a TTY or goes to a
  merge queue, and it never squashes.
- `--auto --merge -d` is allowed (see the risks above).
- git long-option abbreviations (`--sq`… for `--squash`, `--no-sq`… for `--no-squash`) are
  honoured, because git 2.54 accepts them. Short git value flags are matched as exact tokens
  only (`-m`, `-s`, …). A bundled `-qm --squash` would be a false block, which is accepted.
- New tests live in `test_merge_guard.py` (small focused files) and import the existing
  helpers rather than duplicate them. `test_deploy_guard.py` only gets the two lint fixes.
- The doc's title is widened to cover merges; its existing sections are left as they are.
