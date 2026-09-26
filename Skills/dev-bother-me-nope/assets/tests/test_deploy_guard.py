"""Fixtures for deploy-guard.py. Run: python3 -m pytest Skills/dev-bother-me-nope/assets/tests -q"""
import json
import subprocess
import sys
from pathlib import Path

import pytest

GUARD = Path(__file__).resolve().parents[1] / "bin" / "deploy-guard.py"


def run_guard(payload):
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


def test_vercel_mcp_read_tools_allowed():
    assert mcp("mcp__vercel__get_deployment").returncode == 0
    assert mcp("mcp__vercel__list_deployments").returncode == 0
