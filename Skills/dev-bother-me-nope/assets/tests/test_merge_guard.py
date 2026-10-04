"""Merge-guard tests for deploy-guard.py: no squash merges, PR merges delete their branch.

Reuses the helpers of test_deploy_guard (pytest's default import mode puts this directory on
sys.path). Run: python3 -m pytest Skills/dev-bother-me-nope/assets/tests -q
"""
import ast
import re
import subprocess

import pytest
from test_deploy_guard import GUARD, bash, guard_in, mcp, new_repo, run_guard, start_run

MERGE_PREFIX = "Blocked by dev-bother-me-nope merge guard:"
DEPLOY_PREFIX = "Blocked by dev-bother-me-nope deploy guard:"
PLUGIN_ROOT = GUARD.parents[2]
DEPLOY_GUARDS_DOC = (PLUGIN_ROOT / "skills" / "dev-bother-me-nope" / "references"
                     / "deploy-guards.md")

BLOCKED_GIT_SQUASH = [
    "git merge --squash feat/x",
    "git -C /tmp/w merge --squash wip/demo/a",
    "git pull --squash origin dev",
    "cd w && git merge --squash x && git commit -m y",
    "env FOO=1 git merge --squash x",
    'bash -c "git merge --squash x"',
    "git merge --no-ff --squash x",
    "git merge --squ feat/x",
]

BLOCKED_GH_SQUASH = [
    "gh pr merge 12 --squash --delete-branch",
    "gh pr merge 12 -s -d",
    "gh pr merge 12 -sd",
    "gh pr merge 12 -ds",
    "gh pr merge --squash",
    "gh pr merge 12 --repo o/r --squash --delete-branch",
    "gh pr merge 12 -R o/r -s -d",
    "gh pr merge 12 --squash=true -d",
]

BLOCKED_PR_KEEPS_BRANCH = [
    "gh pr merge 12 --merge",
    "gh pr merge 12 -m",
    "gh pr merge 12 --rebase",
    "gh pr merge 12 --auto --merge",
    "gh pr merge 12 -m --delete-branch=false",
    "gh pr merge 12",
    "gh pr merge 12 -r",
]

ALLOWED_GH = [
    "gh pr merge 12 --merge --delete-branch",
    "gh pr merge 12 -m -d",
    "gh pr merge 12 -md",
    "gh pr merge 12 --merge --delete-branch --repo o/r",
    "gh pr merge 12 --rebase --delete-branch",
    "gh pr merge 12 --disable-auto",
    "gh pr view 12",
    "gh pr create --fill",
    "gh pr list",
    'gh pr merge 12 -m -d -t "-s fix"',
    "gh pr merge --help",
    'gh pr merge 12 -md -b "-s"',
    "gh pr merge 12 -md -F -",
    "gh pr merge 12 -m -d --squash=false",
]

SQUASH_MUTATION = ('gh api graphql -f query=\'mutation { mergePullRequest(input: '
                   '{pullRequestId: "x", mergeMethod: SQUASH}) { clientMutationId } }\'')
BLOCKED_API_SQUASH = [
    "gh api -X PUT repos/o/r/pulls/12/merge -f merge_method=squash",
    "gh api -X PUT repos/o/r/pulls/12/merge -F merge_method=squash",
    "gh api -X PUT repos/o/r/pulls/12/merge --field merge_method=squash",
    "gh api -X PUT repos/o/r/pulls/12/merge --raw-field merge_method=squash",
    "gh api -X PUT repos/o/r/pulls/12/merge -f merge_method=SQUASH",
    SQUASH_MUTATION,
    "gh api -X PUT repos/o/r/pulls/12/merge --field=merge_method=squash",
    "gh api -X PUT repos/o/r/pulls/12/merge -fmerge_method=squash",
]

ALLOWED_API = [
    "gh api -X PATCH repos/o/r -F allow_squash_merge=false -F delete_branch_on_merge=true",
    "gh api -X PUT repos/o/r/pulls/12/merge -f merge_method=merge",
    "gh api repos/o/r",
    "gh api search/issues -f q='merge_method=squash in:body'",
]

ALLOWED_LOOKALIKES = [
    'git commit -m "no more git merge --squash"',
    "git log --grep=squash",
    "echo 'gh pr merge --squash'",
    "git commit -F - <<'EOF'\ngit merge --squash x\nEOF",
    "git merge --no-ff feat/x",
    "git merge --no-squash x",
    "git merge -s ours x",
    "git merge --strategy=recursive x",
    "grep -r -- --squash docs/",
    "git merge --squash --no-squash x",
]

ALLOWED_DELETES = [
    "git push origin --delete feat/demo-run",
    "git push origin --delete --force-with-lease=feat/demo-run:0a1b2c3d feat/demo-run",
    "git push --force-with-lease=wip/demo/a:0a1b2c3d origin --delete wip/demo/a",
]

MCP_SQUASH_CALLS = [
    ("mcp__github__merge_pull_request", {"merge_method": "squash"}),
    ("mcp__1a2b3c4d__merge_pull_request", {"mergeMethod": "SQUASH"}),
    ("mcp__github__merge_pull_request", {"merge_method": "Squash"}),
]

ALL_BLOCKED_BASH = (BLOCKED_GIT_SQUASH + BLOCKED_GH_SQUASH + BLOCKED_PR_KEEPS_BRANCH
                    + BLOCKED_API_SQUASH)


def assert_merge_blocked(result, command):
    assert result.returncode == 2, command
    assert result.stderr.startswith(MERGE_PREFIX), command


# ---- AC1-4: Bash squash merges and PR merges that keep their branch ----

@pytest.mark.parametrize("command", BLOCKED_GIT_SQUASH)
def test_blocks_git_squash_merges(command):
    assert_merge_blocked(bash(command), command)


@pytest.mark.parametrize("command", BLOCKED_GH_SQUASH)
def test_blocks_gh_pr_squash_merges(command):
    assert_merge_blocked(bash(command), command)


@pytest.mark.parametrize("command", BLOCKED_PR_KEEPS_BRANCH)
def test_blocks_pr_merges_that_keep_the_source_branch(command):
    assert_merge_blocked(bash(command), command)


@pytest.mark.parametrize("command", ALLOWED_GH)
def test_allows_pr_merges_that_delete_the_branch_and_other_gh(command):
    assert bash(command).returncode == 0, command


@pytest.mark.parametrize("command", BLOCKED_API_SQUASH)
def test_blocks_api_squash_merges(command):
    assert_merge_blocked(bash(command), command)


@pytest.mark.parametrize("command", ALLOWED_API)
def test_allows_api_calls_that_do_not_squash(command):
    assert bash(command).returncode == 0, command


@pytest.mark.parametrize("command", ALLOWED_LOOKALIKES)
def test_merge_lookalikes_are_allowed(command):
    assert bash(command).returncode == 0, command


def test_git_value_flags_are_skipped_not_read_as_options():
    assert_merge_blocked(bash('git merge -m "msg" --squash x'), "value flag then --squash")
    assert bash('git merge -m "--squash" x').returncode == 0
    assert bash("git merge x -- --squash").returncode == 0


# ---- AC5: MCP ----

@pytest.mark.parametrize(("name", "tool_input"), MCP_SQUASH_CALLS)
def test_blocks_mcp_squash_merges(name, tool_input):
    assert_merge_blocked(mcp(name, **tool_input), name)


@pytest.mark.parametrize("tool_input", [{"merge_method": "merge"}, {"merge_method": "rebase"},
                                        {}, {"mergeMethod": "MERGE"}])
def test_allows_mcp_merges_that_do_not_squash(tool_input):
    assert mcp("mcp__github__merge_pull_request", **tool_input).returncode == 0


def test_mcp_squash_on_other_tools_is_ignored():
    assert mcp("mcp__github__create_pull_request", merge_method="squash").returncode == 0


# ---- AC7: the approval prefix is a deploy-only pass-through ----

@pytest.mark.parametrize("command", [
    "BMN_USER_APPROVED_DEPLOY=1 git merge --squash x",
    "BMN_USER_APPROVED_DEPLOY=1 gh pr merge 1 --squash -d",
    'BMN_USER_APPROVED_DEPLOY=1 bash -c "git merge --squash x"',
])
def test_approval_prefix_does_not_unlock_merge_rules(command):
    assert_merge_blocked(bash(command), command)


def test_approval_still_passes_deploys_through_a_shell():
    assert bash('BMN_USER_APPROVED_DEPLOY=1 bash -c "vercel --prod"').returncode == 0


# ---- AC8: messages ----

MERGE_MESSAGE_CASES = [
    ("git merge --squash x", "`git merge --squash` folds a branch's commits into one"),
    ("gh pr merge 12 --squash -d", "`gh pr merge --squash` folds the PR's commits into one"),
    ("gh pr merge 12 --merge", ("`gh pr merge` without `--delete-branch` leaves the merged "
                                "source branch on origin")),
    ("gh api -X PUT repos/o/r/pulls/12/merge -f merge_method=squash",
     "`gh api` merge with `merge_method=squash`"),
]


@pytest.mark.parametrize(("command", "reason"), MERGE_MESSAGE_CASES)
def test_merge_block_message_names_the_allowed_forms(command, reason):
    assert_merge_message(bash(command), reason)


def test_merge_block_message_for_mcp():
    result = mcp("mcp__github__merge_pull_request", merge_method="squash")
    assert_merge_message(result, "MCP `merge_pull_request` with merge_method=squash")


def assert_merge_message(result, reason):
    assert result.returncode == 2
    assert result.stderr.startswith(f"{MERGE_PREFIX} {reason}.")
    assert "git merge --no-ff" in result.stderr
    assert "gh pr merge <n> --merge --delete-branch" in result.stderr
    assert "BMN_USER_APPROVED_DEPLOY" not in result.stderr
    assert result.stderr.count("\n") == 1


DEPLOY_TAIL = (". Jonathan decides every deploy and every remote database change — add it "
               "to the report's Deploy checklist instead. (Only if he said 'deploy' in chat "
               "this session: prefix the command with BMN_USER_APPROVED_DEPLOY=1.)\n")


def test_deploy_block_message_is_unchanged():
    vercel = bash("vercel --prod")
    assert vercel.stderr == (f"{DEPLOY_PREFIX} `vercel` with no subcommand deploys"
                             f"{DEPLOY_TAIL}")
    migration = mcp("mcp__supabase__apply_migration")
    assert migration.stderr == (f"{DEPLOY_PREFIX} MCP `apply_migration` changes a remote "
                                f"Supabase project{DEPLOY_TAIL}")


# ---- AC9: scope ----

def idle_repo(state):
    if state == "inactive":
        return new_repo(active=False)
    root = new_repo(active=False)
    start_run(root, state)
    return root


@pytest.mark.parametrize("state", ["inactive", "done", "blocked"])
def test_merge_rules_idle_outside_an_active_run(state):
    root = idle_repo(state)
    for command in ALL_BLOCKED_BASH:
        assert guard_in(root, command).returncode == 0, (state, command)
    for name, tool_input in MCP_SQUASH_CALLS:
        payload = {"tool_name": name, "tool_input": tool_input, "cwd": str(root)}
        assert run_guard(payload).returncode == 0, (state, name)


# ---- AC10: branch cleanup is never blocked ----

@pytest.mark.parametrize("command", [
    "git push origin --delete feat/demo-run",
    "git branch -D wip/demo/a",
    "git worktree remove ../x",
    "git worktree prune",
])
def test_branch_cleanup_is_never_blocked(command):
    assert bash(command).returncode == 0, command


@pytest.mark.parametrize("command", ALLOWED_DELETES)
def test_compare_and_delete_of_a_remote_branch_is_allowed(command):
    assert bash(command).returncode == 0, command


def test_push_delete_of_a_protected_branch_stays_blocked():
    result = bash("git push origin --delete main")
    assert result.returncode == 2
    assert "deploy guard:" in result.stderr


# ---- FIX1 R1-5: wrappers that take options or values, and bundled shell -c ----

WRAPPED_SQUASH_MERGES = [
    "timeout 60 git merge --squash x",
    "timeout -k 5 60 git merge --squash x",
    "timeout --signal=KILL 60s git merge --squash x",
    "timeout -s KILL 60 git merge --squash x",
    "sudo -u me git merge --squash x",
    "sudo -u me -g wheel git merge --squash x",
    "sudo -E git merge --squash x",
    "nice -n 5 git merge --squash x",
    "nice -5 git merge --squash x",
    "nohup git merge --squash x",
    "env -u FOO git merge --squash x",
    "env -C /tmp/w git merge --squash x",
    "command git merge --squash x",
    "command -p git merge --squash x",
    "xargs -n1 git merge --squash",
    "xargs -I {} git merge --squash {}",
    "xargs -P 4 -n 1 gh pr merge --squash --delete-branch",
    "sh -ec 'git merge --squash x'",
    "bash -lc 'git merge --squash x'",
    "bash -c 'git merge --squash x'",
    "bash -o pipefail -c 'git merge --squash x'",
    "bash --norc -c 'git merge --squash x'",
    "zsh -lc 'git merge --squash x'",
    "sudo timeout 60 sh -c 'git merge --squash x'",
    "sudo -u me bash -lc 'timeout 5 git merge --squash x'",
    "timeout 60 gh pr merge 12 --squash --delete-branch",
    "sudo -u me gh pr merge 12 -s -d",
    "timeout 60 gh pr merge 12 --merge",
]

WRAPPED_DEPLOYS = [
    "timeout 60 git push origin main",
    "timeout -k 5 60 vercel --prod",
    "sudo -u me git push origin main",
    "sudo -u me vercel --prod",
    "nice -n 5 vercel --prod",
    "env -u FOO supabase db push --linked",
    "xargs -n1 vercel deploy",
    "sh -ec 'vercel --prod'",
    "bash -lc 'git push origin HEAD:main'",
    "bash -o pipefail -c 'supabase db push --linked'",
]

WRAPPED_ALLOWED = [
    "timeout 60 git merge --no-ff x",
    "timeout 60 git log --grep=squash",
    "timeout 60 echo 'git merge --squash x'",
    "sudo -u me git merge --no-ff x",
    "sudo -u me git status",
    "nice -n 5 git merge --no-ff x",
    "env -u FOO echo ok",
    "command -v git",
    "xargs -n1 echo git merge --squash",
    "sh -ec 'git merge --no-ff x'",
    "bash -lc 'git status'",
    "bash run.sh -c 'git merge --squash x'",
    "bash -x script.sh",
    "timeout 60 gh pr merge 12 --merge --delete-branch",
    "timeout 60 vercel ls",
    "sudo -u me git push origin wip/demo/a",
]


@pytest.mark.parametrize("command", WRAPPED_SQUASH_MERGES)
def test_blocks_merges_behind_wrappers_that_take_options(command):
    assert_merge_blocked(bash(command), command)


@pytest.mark.parametrize("command", WRAPPED_DEPLOYS)
def test_blocks_deploys_behind_wrappers_that_take_options(command):
    result = bash(command)
    assert result.returncode == 2, command
    assert result.stderr.startswith(DEPLOY_PREFIX), command


@pytest.mark.parametrize("command", WRAPPED_ALLOWED)
def test_allows_wrapped_commands_that_are_not_blocked_unwrapped(command):
    assert bash(command).returncode == 0, command


@pytest.mark.parametrize("command", [
    "BMN_USER_APPROVED_DEPLOY=1 sh -ec 'git merge --squash x'",
    "BMN_USER_APPROVED_DEPLOY=1 timeout 60 git merge --squash x",
    "BMN_USER_APPROVED_DEPLOY=1 sudo -u me git merge --squash x",
])
def test_approval_prefix_does_not_unlock_wrapped_merges(command):
    assert_merge_blocked(bash(command), command)


@pytest.mark.parametrize("command", [
    "BMN_USER_APPROVED_DEPLOY=1 timeout 60 vercel --prod",
    "BMN_USER_APPROVED_DEPLOY=1 sh -ec 'vercel --prod'",
])
def test_approval_still_passes_wrapped_deploys(command):
    assert bash(command).returncode == 0, command


# ---- FIX1 R1-6: protected branches are never deleted on origin ----

BLOCKED_PROTECTED_DELETES = [
    "git push origin --delete dev",
    "git push origin --delete develop",
    "git push origin --delete staging",
    "git push origin --delete DEV",
    "git push origin :dev",
    "git push origin :refs/heads/dev",
    "git push origin --delete refs/heads/dev",
    "git push origin +:dev",
    "git push -d origin dev",
    "git push origin --de dev",
    "git push origin --delete wip/demo/a dev",
    "git push --force-with-lease=dev:0a1b2c3d origin --delete dev",
    "git -C /tmp/w push origin --delete dev",
    "timeout 60 git push origin --delete dev",
    "sudo -u me git push origin --delete dev",
    "sh -ec 'git push origin --delete dev'",
    "git push origin --delete production",
    "git push origin --delete master",
    "git push origin :main",
    "git push origin --delete release",
]

ALLOWED_BRANCH_PUSHES = [
    "git push origin --delete wip/merged-branch-cleanup/deploy-guard-fix",
    "git push origin --delete feat/merged-branch-cleanup",
    "git push origin --delete feat/dev",
    "git push origin --delete dev-tools",
    "git push origin --delete devops",
    "git push origin :wip/demo/a",
    "git push origin --delete --force-with-lease=wip/demo/a:0a1b2c3d wip/demo/a",
    "git push --force-with-lease=feat/demo-run:0a1b2c3d origin --delete feat/demo-run",
    "git push origin dev",
    "git push -u origin wip/demo/a",
    "git push --dry-run origin dev",
    "git push origin wip/demo/a:dev",
]


@pytest.mark.parametrize("command", BLOCKED_PROTECTED_DELETES)
def test_blocks_deleting_protected_branches_on_origin(command):
    result = bash(command)
    assert result.returncode == 2, command
    assert result.stderr.startswith(DEPLOY_PREFIX), command


@pytest.mark.parametrize("command", ALLOWED_BRANCH_PUSHES)
def test_allows_deleting_wip_and_run_branches_and_pushing_dev(command):
    assert bash(command).returncode == 0, command


def test_protected_delete_message_names_the_branch_spec():
    result = bash("git push origin --delete dev")
    assert result.stderr.startswith(
        f"{DEPLOY_PREFIX} `git push … dev` deletes a protected branch. ")


def repo_with_default_branch(name):
    root = new_repo()
    subprocess.run(["git", "-C", str(root), "symbolic-ref", "refs/remotes/origin/HEAD",
                    f"refs/remotes/origin/{name}"], check=True)
    return root


@pytest.mark.parametrize("command", [
    "git push origin --delete trunk",
    "git push origin :trunk",
    "git push origin --delete Trunk",
    "git push origin --delete wip/x trunk",
])
def test_blocks_deleting_the_default_branch(command):
    root = repo_with_default_branch("trunk")
    result = guard_in(root, command)
    assert result.returncode == 2, command
    assert result.stderr.startswith(DEPLOY_PREFIX), command


@pytest.mark.parametrize("command", [
    "git push origin --delete wip/x",
    "git push origin --delete trunky",
    "git push origin trunk",
])
def test_default_branch_rule_leaves_other_pushes_alone(command):
    root = repo_with_default_branch("trunk")
    assert guard_in(root, command).returncode == 0, command


def test_a_repo_without_a_default_branch_ref_still_guards_the_named_ones():
    root = new_repo()
    assert guard_in(root, "git push origin --delete dev").returncode == 2
    assert guard_in(root, "git push origin --delete trunk").returncode == 0


# ---- AC11: docs ----

DOC_REQUIRED = [
    "git merge --squash", "git pull --squash", "gh pr merge --squash", "-s",
    "--delete-branch", "--delete-branch=false", "merge_method=squash", "mergeMethod: SQUASH",
    "merge_pull_request", "git merge --no-ff", "gh pr merge <n> --merge --delete-branch",
    "BMN_USER_APPROVED_DEPLOY", "allow_squash_merge=false", "delete_branch_on_merge=true",
]


def merge_section(doc):
    headings = list(re.finditer(r"^## .*$", doc, re.MULTILINE))
    for i, heading in enumerate(headings):
        if "Merge commits only" in heading.group():
            end = headings[i + 1].start() if i + 1 < len(headings) else len(doc)
            return doc[heading.start():end]
    return ""


def test_deploy_guards_doc_lists_merge_rules():
    section = merge_section(DEPLOY_GUARDS_DOC.read_text())
    assert section, "no `## ... Merge commits only ...` section in deploy-guards.md"
    missing = [text for text in DOC_REQUIRED if text not in section]
    assert not missing, missing


def guard_tree():
    return ast.parse(GUARD.read_text())


def test_guard_docstring_mentions_merge_rules():
    docstring = ast.get_docstring(guard_tree())
    assert "squash" in docstring
    assert "--delete-branch" in docstring


# ---- AC12: shape of the code ----

MERGE_RULE_FUNCTIONS = [
    "skip_wrapper_args", "shell_command_string", "push_deletes", "ref_destination",
    "is_abbrev", "git_merge_squashes", "check_git_merge", "pflag_items", "long_flag",
    "short_cluster", "is_true", "check_gh", "check_gh_pr_merge", "check_gh_api",
    "is_squash_field", "merge_reason", "check_mcp_merge", "block_message",
]
MUTATING_CALLS = frozenset({"append", "extend", "insert", "pop", "remove", "sort", "clear",
                            "update"})


def test_guard_stays_under_800_lines():
    assert len(GUARD.read_text().splitlines()) < 800


def test_every_guard_function_is_under_50_lines():
    long_ones = [f"{node.name}:{node.end_lineno - node.lineno + 1}"
                 for node in ast.walk(guard_tree())
                 if isinstance(node, ast.FunctionDef)
                 and node.end_lineno - node.lineno + 1 >= 50]
    assert not long_ones, long_ones


def mutations_in(function):
    found = []
    for node in ast.walk(function):
        is_mutating_call = (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                            and node.func.attr in MUTATING_CALLS)
        targets = getattr(node, "targets", None) or [getattr(node, "target", None)]
        is_item_assignment = (isinstance(node, (ast.Assign, ast.AugAssign, ast.Delete))
                              and any(isinstance(t, ast.Subscript) for t in targets))
        if is_mutating_call or is_item_assignment:
            found = [*found, node.lineno]
    return found


def test_merge_rule_functions_do_not_mutate():
    functions = {node.name: node for node in ast.walk(guard_tree())
                 if isinstance(node, ast.FunctionDef)}
    missing = [name for name in MERGE_RULE_FUNCTIONS if name not in functions]
    assert not missing, f"missing functions: {missing}"
    mutating = {name: mutations_in(functions[name]) for name in MERGE_RULE_FUNCTIONS
                if mutations_in(functions[name])}
    assert not mutating, mutating


# ---- FIX1: the doc says what is and is not covered ----

def blind_spots(doc):
    start = doc.index("**Known blind spots**")
    return doc[start:doc.index("\n\n", start)]


def test_doc_names_the_unwrapped_wrappers():
    section = merge_section(DEPLOY_GUARDS_DOC.read_text())
    missing = [name for name in ("timeout", "sudo", "nice", "nohup", "env", "command", "xargs",
                                 "sh -c", "bash -lc") if name not in section]
    assert not missing, missing


def test_doc_blind_spots_no_longer_claim_covered_shell_wrappers():
    spots = blind_spots(DEPLOY_GUARDS_DOC.read_text())
    assert "`bash -lc`" not in spots
    for still_open in ("eval", "doas", "env -S"):
        assert still_open in spots, still_open


def test_doc_lists_the_protected_branch_deletes():
    section = merge_section(DEPLOY_GUARDS_DOC.read_text())
    for text in ("git push origin --delete dev", ":dev", "default branch", "--force-with-lease"):
        assert text in section, text
