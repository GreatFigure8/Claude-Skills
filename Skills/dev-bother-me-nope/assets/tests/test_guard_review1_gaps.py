"""FIX① tests for the REVIEW① findings R1-2..R1-5 on deploy-guard.py.

R1-2  a protected branch deleted (or pushed) as `heads/<name>`, which git resolves to refs/heads/<name>.
R1-3  fish's `-C` / `--init-command` strings, which fish runs before its `-c` command.
R1-4  the doc's blind spots name `gh api -X DELETE …/git/refs/heads/<protected>` and the GitHub MCP.
R1-5  a `git push` segment is parsed once and the remote's default branch is looked up once.

Reuses the helpers of test_deploy_guard and test_merge_guard (pytest's default import mode puts
this directory on sys.path). Run: python3 -m pytest Skills/dev-bother-me-nope/assets/tests -q
"""
import ast

import pytest
from test_deploy_guard import ACTIVE_REPO, GUARD, bash
from test_merge_guard import (
    APPROVED,
    BRANCH_PREFIX,
    DEPLOY_GUARDS_DOC,
    DEPLOY_PREFIX,
    assert_merge_blocked,
    blind_spots,
    guard_in,
    list_item,
    merge_section,
    normalised,
    repo_with_default_branch,
)

# ---- R1-2: `heads/<name>` is `refs/heads/<name>` to git ----

HEADS_FORM_DELETES = [
    "git push origin --delete heads/dev",
    "git push origin --delete heads/main",
    "git push origin :heads/main",
    "git push origin +:heads/release",
    "git push -d origin heads/staging",
    "git push origin --delete wip/demo/a heads/develop",
    "git -C . push origin --delete heads/production",
    "git push origin --delete heads/DEV",
]

HEADS_FORM_CLEANUP = [
    "git push origin --delete heads/wip/demo/a",
    "git push origin :heads/feat/run-branch",
    "git push origin --delete heads/dev-tools",
    "git push origin --delete refs/heads/heads/dev",
    "git push origin heads/feat/demo",
]


@pytest.mark.parametrize("command", HEADS_FORM_DELETES)
@pytest.mark.parametrize("prefix", ["", f"{APPROVED} "])
def test_heads_slash_name_is_a_protected_delete(prefix, command):
    result = bash(prefix + command)
    assert result.returncode == 2, prefix + command
    assert result.stderr.startswith(BRANCH_PREFIX), prefix + command
    assert "BMN_USER_APPROVED_DEPLOY" not in result.stderr, prefix + command


@pytest.mark.parametrize("prefix", ["", f"{APPROVED} "])
def test_heads_form_of_the_default_branch_is_a_protected_delete(prefix):
    root = repo_with_default_branch("trunk")
    result = guard_in(root, f"{prefix}git push origin --delete heads/trunk")
    assert result.returncode == 2
    assert result.stderr.startswith(BRANCH_PREFIX)
    assert guard_in(root, f"{prefix}git push origin --delete heads/trunky").returncode == 0


@pytest.mark.parametrize("command", HEADS_FORM_CLEANUP)
def test_heads_form_cleanup_stays_allowed_with_and_without_the_prefix(command):
    assert bash(command).returncode == 0, command
    assert bash(f"{APPROVED} {command}").returncode == 0, command


@pytest.mark.parametrize("command", ["git push origin HEAD:heads/main", "git push origin heads/main"])
def test_pushing_to_a_production_branch_through_heads_is_a_deploy_block(command):
    result = bash(command)
    assert result.returncode == 2, command
    assert result.stderr.startswith(DEPLOY_PREFIX), command
    assert bash(f"{APPROVED} {command}").returncode == 0, command


# ---- R1-3: fish `-C` / `--init-command` run before the `-c` command ----

FISH_INIT_SQUASHES = [
    "fish -C 'git merge --squash x' -c true",
    "fish --init-command='git merge --squash x' -c true",
    "fish --init-command 'git merge --squash x' -c true",
    "fish -lC 'git merge --squash x' -c true",
    "fish -c true -C 'git merge --squash x'",
    "fish -C 'git merge --squash x'",
    "fish --init-command='git merge --squash x' script.fish",
    "fish -C 'git status' -C 'git merge --squash x' -c true",
    "sudo -u me fish -C 'git merge --squash x' -c true",
    f"{APPROVED} fish -C 'git merge --squash x' -c true",
    f"{APPROVED} fish --init-command='git merge --squash x' -c true",
    "bash -C -c 'git merge --squash x'",
]

FISH_INIT_HARMLESS = [
    "fish -C 'git status' -c true",
    "fish --init-command='git log' -c 'echo hi'",
    "fish script.fish -C 'git merge --squash x'",
    "fish -c 'echo hi' arg -C 'git merge --squash x'",
    "bash -c 'echo hi' -C 'git merge --squash x'",
    "bash -C script.sh",
    "fish -C",
]


@pytest.mark.parametrize("command", FISH_INIT_SQUASHES)
def test_blocks_squash_merges_behind_fish_init_commands(command):
    assert_merge_blocked(bash(command), command)


@pytest.mark.parametrize("command", FISH_INIT_HARMLESS)
def test_fish_init_leaves_harmless_commands_and_script_arguments_alone(command):
    assert bash(command).returncode == 0, command


def test_fish_init_command_reaches_the_deploy_and_branch_guards():
    deploy = bash("fish -C 'vercel --prod' -c true")
    assert deploy.returncode == 2
    assert deploy.stderr.startswith(DEPLOY_PREFIX)
    assert bash(f"{APPROVED} fish -C 'vercel --prod' -c true").returncode == 0
    branch = bash(f"{APPROVED} fish --init-command='git push origin --delete dev' -c true")
    assert branch.returncode == 2
    assert branch.stderr.startswith(BRANCH_PREFIX)


# ---- R1-5: parse a push once, look the default branch up once ----

@pytest.fixture
def guard(load_script):
    return load_script("deploy-guard")


def spy_on(monkeypatch, module, name, returns=None):
    """Wrap module.<name> so every call is recorded; `returns` replaces its result when given."""
    calls = []
    real = getattr(module, name)

    def wrapper(*args):
        calls.append(args)
        return real(*args) if returns is None else returns

    monkeypatch.setattr(module, name, wrapper)
    return calls


@pytest.mark.parametrize("command", [
    "git push origin wip/x",
    "git push origin --delete wip/x",
    f"{APPROVED} git push origin --delete wip/x",
    "git push -u origin HEAD:refs/heads/feat/y",
    "git push origin --delete dev",
])
def test_each_push_segment_is_parsed_once(monkeypatch, guard, command):
    parses = spy_on(monkeypatch, guard, "push_parts")
    guard.check_bash(command, guard.load_context(str(ACTIVE_REPO)))
    assert len(parses) == 1, command


@pytest.mark.parametrize(("command", "lookups"), [
    ("git push origin --delete a b c d", 1),
    ("git push origin :a :b :c", 1),
    ("git push origin --delete dev a b", 0),
    ("git push origin a b c", 0),
    ("git push --delete origin", 0),
    (f"{APPROVED} git push origin --delete a b c d", 1),
])
def test_the_default_branch_is_looked_up_at_most_once_per_push(monkeypatch, guard, command,
                                                               lookups):
    seen = spy_on(monkeypatch, guard, "default_branch", returns="")
    guard.check_bash(command, guard.load_context(str(ACTIVE_REPO)))
    assert len(seen) == lookups, command


def test_a_default_branch_match_still_names_the_first_doomed_refspec():
    root = repo_with_default_branch("trunk")
    result = guard_in(root, "git push origin --delete wip/x trunk dev")
    assert result.returncode == 2
    assert result.stderr.startswith(f"{BRANCH_PREFIX} `git push … trunk` deletes a protected")


# ---- R1-3 / R1-4 docs ----

def test_doc_names_fish_init_commands_among_the_read_wrappers():
    wrapper = list_item(merge_section(DEPLOY_GUARDS_DOC.read_text()),
                        "- All of the above behind a wrapper")
    for text in ("fish -C", "--init-command"):
        assert text in wrapper, text
    assert "fish -C" not in blind_spots(DEPLOY_GUARDS_DOC.read_text())


def test_doc_blind_spots_name_gh_api_ref_deletes_and_the_github_mcp_branch_tools():
    spots = normalised(blind_spots(DEPLOY_GUARDS_DOC.read_text()))
    for text in ("gh api -X DELETE", "git/refs/heads/", "GitHub MCP"):
        assert text in spots, text


def test_doc_blind_spots_list_abbreviated_fish_init_command():
    assert "fish --init" in blind_spots(DEPLOY_GUARDS_DOC.read_text())


def test_doc_protected_delete_bullet_names_the_heads_form():
    bullet = list_item(DEPLOY_GUARDS_DOC.read_text(), "- Deleting a protected branch on origin")
    assert "--delete heads/dev" in bullet


def test_guard_docstring_names_the_heads_form_and_fish_init():
    docstring = normalised(ast.get_docstring(ast.parse(GUARD.read_text())))
    for text in ("heads/", "fish -C"):
        assert text in docstring, text
