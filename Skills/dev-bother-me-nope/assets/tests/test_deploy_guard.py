"""Fixtures for deploy-guard.py. Run: python3 -m pytest Skills/dev-bother-me-nope/assets/tests -q"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest

GUARD = Path(__file__).resolve().parents[1] / "bin" / "deploy-guard.py"


def start_run(root, phase="build", worktree=None):
    """Mark `root` as a repo with a dev-bother-me-nope run in progress."""
    run = root / "docs" / "sprints" / "bmn-demo"
    run.mkdir(parents=True, exist_ok=True)
    state = {"run": "bmn-demo", "phase": phase}
    if worktree is not None:
        state["worktree"] = str(worktree)
    (run / "bmn.json").write_text(json.dumps(state))


def new_repo(active=True):
    root = Path(tempfile.mkdtemp())
    subprocess.run(["git", "init", "-q", str(root)], check=True)
    if active:
        start_run(root)
    return root


ACTIVE_REPO = new_repo()


def run_guard(payload):
    payload = {"cwd": str(ACTIVE_REPO), **payload}
    return subprocess.run(
        [sys.executable, str(GUARD)], input=json.dumps(payload), capture_output=True, text=True
    )


def bash(command):
    return run_guard({"tool_name": "Bash", "tool_input": {"command": command}})


def mcp(name, **tool_input):
    return run_guard({"tool_name": name, "tool_input": tool_input})


BLOCKED_BASH = [
    "vercel",
    "vercel --prod",
    "npx vercel deploy",
    "cd app && vercel --prod --yes",
    "vercel promote https://x.vercel.app",
    "vercel rollback",
    "vercel env add FOO production",
    "pnpm dlx vercel@latest deploy --prebuilt",
    "supabase db push",
    "supabase db push --linked",
    "npx supabase migration up --linked",
    "supabase db reset --linked",
    "supabase functions deploy hello",
    "supabase secrets set KEY=v",
    "supabase config push",
    "psql postgresql://postgres:x@db.abc.supabase.co:5432/postgres -f m.sql",
    "psql 'postgres://u@aws-0-us-east-1.pooler.supabase.com:6543/postgres' -c 'drop table t'",
    "git push origin main",
    "git push origin HEAD:main",
    "git push -u origin master",
    "git push origin production",
    "git push --force origin release",
    'bash -c "vercel --prod"',
    "(cd web && vercel --prod)",
    "env vercel --prod",
    "time vercel --prod",
    "$(which vercel) deploy",
    "uv run supabase db push",
    "yarn vercel deploy",
    "pnpm vercel --prod",
    "bun x vercel --prod",
    "vercel --cwd web --prod",
    "git -C web push origin main",
    "git push origin dev:main",
    "supabase --workdir db db push",
    "supabase --project-ref x db push",
    'psql "$SUPABASE_DB_URL" -c "drop table x"',
    "echo ok\nvercel --prod",
]

ALLOWED_BASH = [
    "vercel dev",
    "vercel build",
    "vercel env pull .env.local",
    "vercel --version",
    "vercel whoami",
    "supabase start",
    "supabase db reset",
    "supabase migration new add_invoices",
    "supabase gen types typescript --local",
    "supabase link --project-ref abc",
    "psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c 'select 1'",
    "git push origin dev",
    "git push -u origin bmn/run/story-a",
    "git push -u origin wip/demo/story-a",
    "git push -u origin feat/demo",
    "git push origin HEAD:dev",
    "git push origin --delete wip/demo/story-a",
    "git push origin feat/maintenance-page",
    "pytest -q",
    "grep -r 'vercel --prod' docs/",
    "echo supabase db push is forbidden",
    'git commit -m "note && vercel deploy"',
    'git commit -m "docs: checklist\n\nrun supabase db push later"',
    "cat > report.md <<'EOF'\nvercel --prod\nsupabase db push --linked\nEOF",
    "vercel --cwd web dev",
    "vercel --scope team env pull",
    "vercel -A x.json dev",
    "vercel project ls",
    "vercel domains ls",
    "uv run pytest -q",
]


@pytest.mark.parametrize("command", BLOCKED_BASH)
def test_blocks_deploy_and_remote_db_commands(command):
    result = bash(command)
    assert result.returncode == 2, command
    assert "dev-bother-me-nope" in result.stderr


@pytest.mark.parametrize("command", ALLOWED_BASH)
def test_allows_local_and_readonly_commands(command):
    assert bash(command).returncode == 0, command


def test_user_approved_prefix_lets_a_deploy_through():
    assert bash("BMN_USER_APPROVED_DEPLOY=1 supabase db push --linked").returncode == 0


@pytest.mark.parametrize(
    "name",
    [
        "mcp__supabase__apply_migration",
        "mcp__abc123__deploy_edge_function",
        "mcp__supabase__merge_branch",
        "mcp__vercel__deploy_to_vercel",
        "mcp__vercel__promote_deployment",
        "mcp__vercel__create_deployment",
    ],
)
def test_blocks_mcp_deploy_tools(name):
    assert mcp(name).returncode == 2


def test_blocks_mcp_write_sql_but_allows_reads():
    assert mcp("mcp__supabase__execute_sql", query="insert into t values (1)").returncode == 2
    assert mcp("mcp__supabase__execute_sql", query="  SELECT * from t").returncode == 0
    assert mcp("mcp__supabase__execute_sql", query="with x as (select 1) select * from x").returncode == 0


def test_ignores_unrelated_mcp_tools_and_malformed_input():
    assert mcp("mcp__github__create_issue").returncode == 0
    assert subprocess.run([sys.executable, str(GUARD)], input="not json", text=True).returncode == 0


def test_supabase_sql_detected_by_project_id_on_uuid_named_server():
    assert mcp("mcp__9378f59a__execute_sql", project_id="abc", query="drop table users").returncode == 2
    assert mcp("mcp__9378f59a__execute_sql", query="drop table users").returncode == 0


def test_claude_design_mcp_tools_allowed():
    assert run_guard({"tool_name": "mcp__claude_design__create_project", "tool_input": {"name": "x — bmn-run"}}).returncode == 0
    assert mcp("mcp__claude_design__write_files", project_id="abc", files=[]).returncode == 0
    assert mcp("mcp__claude_design__delete_files", project_id="abc").returncode == 0
    assert mcp("mcp__claude_design__ack_comments", project_id="abc").returncode == 0


def test_vercel_mcp_read_tools_allowed():
    assert mcp("mcp__vercel__get_deployment").returncode == 0
    assert mcp("mcp__vercel__list_deployments").returncode == 0


# ---- Supabase DEV project is writable by the skill; MAIN never is ----

DEV_REF, MAIN_REF = "devref111", "mainref222"


@pytest.fixture
def repo(tmp_path):
    subprocess.run(["git", "init", "-q", str(tmp_path)], check=True)
    start_run(tmp_path)
    (tmp_path / ".claude").mkdir()
    (tmp_path / ".claude" / "bmn.config.json").write_text(
        json.dumps({"supabase": {"dev_ref": DEV_REF, "main_ref": MAIN_REF}}))
    return tmp_path


def bash_in(cwd, command):
    return run_guard({"tool_name": "Bash", "tool_input": {"command": command}, "cwd": str(cwd)})


def link(cwd, ref):
    (cwd / "supabase" / ".temp").mkdir(parents=True, exist_ok=True)
    (cwd / "supabase" / ".temp" / "project-ref").write_text(ref + "\n")


def test_db_push_allowed_when_linked_to_dev(repo):
    link(repo, DEV_REF)
    assert bash_in(repo, "supabase db push --linked").returncode == 0
    assert bash_in(repo, "supabase db push").returncode == 0


def test_db_push_blocked_when_linked_to_main(repo):
    link(repo, MAIN_REF)
    assert bash_in(repo, "supabase db push --linked").returncode == 2


def test_link_in_same_command_decides_the_target(repo):
    link(repo, MAIN_REF)
    assert bash_in(repo, f"supabase link --project-ref {DEV_REF} && supabase db push --linked").returncode == 0
    link(repo, DEV_REF)
    assert bash_in(repo, f"supabase link --project-ref={MAIN_REF} && supabase db push").returncode == 2


def test_db_url_must_name_the_dev_ref(repo):
    dev_url = f"postgresql://postgres.{DEV_REF}:pw@aws-0-us-east-1.pooler.supabase.com:6543/postgres"
    main_url = dev_url.replace(DEV_REF, MAIN_REF)
    assert bash_in(repo, f"supabase db push --db-url '{dev_url}'").returncode == 0
    assert bash_in(repo, f"supabase db push --db-url '{main_url}'").returncode == 2


def test_other_remote_supabase_changes_stay_blocked_even_on_dev(repo):
    link(repo, DEV_REF)
    for command in ("supabase functions deploy x", "supabase secrets set A=b",
                    "supabase db reset --linked", "supabase migration repair 1 --status applied"):
        assert bash_in(repo, command).returncode == 2, command


def test_db_push_blocked_without_config_or_link(repo, tmp_path_factory):
    assert bash_in(repo, "supabase db push").returncode == 2  # config but no link
    bare = tmp_path_factory.mktemp("bare")
    subprocess.run(["git", "init", "-q", str(bare)], check=True)
    start_run(bare)
    link(bare, DEV_REF)
    assert bash_in(bare, "supabase db push").returncode == 2  # link but no config


def test_misconfigured_same_ref_for_dev_and_main_blocks(repo):
    (repo / ".claude" / "bmn.config.json").write_text(
        json.dumps({"supabase": {"dev_ref": DEV_REF, "main_ref": DEV_REF}}))
    link(repo, DEV_REF)
    assert bash_in(repo, "supabase db push").returncode == 2


# ---- the guard only acts while a dev-bother-me-nope run is active in the repo ----

def guard_in(cwd, command):
    return run_guard({"tool_name": "Bash", "tool_input": {"command": command}, "cwd": str(cwd)})


def test_inactive_repo_is_not_guarded():
    idle = new_repo(active=False)
    assert guard_in(idle, "vercel --prod").returncode == 0
    assert run_guard({"tool_name": "mcp__supabase__apply_migration", "cwd": str(idle)}).returncode == 0


@pytest.mark.parametrize("phase", ["done", "blocked"])
def test_finished_run_is_not_guarded(phase):
    root = new_repo(active=False)
    start_run(root, phase)
    assert guard_in(root, "vercel --prod").returncode == 0


@pytest.mark.parametrize("phase", ["intake", "build", "merge1", "test1", "review1", "fix1",
                                   "merge2", "test2", "review2", "report"])
def test_every_unfinished_phase_is_guarded(phase):
    root = new_repo(active=False)
    start_run(root, phase)
    assert guard_in(root, "vercel --prod").returncode == 2


GIT_ENV = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t",
           "GIT_COMMITTER_EMAIL": "t@t", "PATH": "/usr/bin:/bin:/opt/homebrew/bin"}


def add_worktree(root):
    subprocess.run(["git", "-C", str(root), "commit", "-q", "--allow-empty", "-m", "init"],
                   check=True, env=GIT_ENV)
    tree = Path(tempfile.mkdtemp()) / "wt"
    subprocess.run(["git", "-C", str(root), "worktree", "add", "-q", "--detach", str(tree)], check=True)
    return tree


def test_worktree_of_active_repo_is_guarded():
    root = new_repo()
    tree = add_worktree(root)
    assert guard_in(tree, "vercel --prod").returncode == 2


def test_run_living_in_a_sibling_run_worktree_guards_every_worktree():
    root = new_repo(active=False)
    run_tree = add_worktree(root)
    harness_tree = add_worktree(root)
    start_run(run_tree)
    assert guard_in(root, "vercel --prod").returncode == 2  # the human's main checkout
    assert guard_in(harness_tree, "vercel --prod").returncode == 2  # a coder's worktree
    assert guard_in(run_tree, "vercel --prod").returncode == 2


def test_finished_run_in_a_sibling_worktree_is_not_guarded():
    root = new_repo(active=False)
    run_tree = add_worktree(root)
    start_run(run_tree, "done")
    assert guard_in(root, "vercel --prod").returncode == 0


def test_leftover_harness_copy_of_a_finished_run_is_not_guarded():
    root = new_repo(active=False)
    run_tree = add_worktree(root)
    harness_tree = add_worktree(root)
    start_run(run_tree, "done", worktree=run_tree)
    start_run(harness_tree, "build", worktree=run_tree)  # copy inherited from the run branch
    assert guard_in(root, "vercel --prod").returncode == 0
    assert guard_in(harness_tree, "vercel --prod").returncode == 0


def test_state_naming_its_own_worktree_still_guards():
    root = new_repo(active=False)
    run_tree = add_worktree(root)
    start_run(run_tree, "build", worktree=run_tree)
    assert guard_in(root, "vercel --prod").returncode == 2


def test_non_git_dir_is_not_guarded(tmp_path):
    assert guard_in(tmp_path, "vercel --prod").returncode == 0
