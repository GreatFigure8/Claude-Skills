"""repo-merge-policy.py: no squash merges, delete the head branch on merge, via the gh CLI.

Run: uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q
A fake `gh` (conftest.py) is the only gh on PATH; nothing here reaches GitHub.
"""
import json

import pytest

REPO = "--repo=OWNER/NAME"
BOTH_CHANGES = {
    "allow_squash_merge": {"old": True, "new": False},
    "delete_branch_on_merge": {"old": False, "new": True},
}
COMPLIANT = {"allow_squash_merge": False, "delete_branch_on_merge": True}


# --- AC 13-16: what gets changed ----------------------------------------------------------


@pytest.mark.integration
def test_changes_needed_sends_one_typed_patch_and_confirms(fake_gh):
    run = fake_gh.run(REPO)

    assert run.code == 0, run.stderr
    assert run.data == {"repo": "OWNER/NAME", "status": "changed", "changes": BOTH_CHANGES,
                        "reason": None}
    patches = fake_gh.patch_calls()
    assert len(patches) == 1
    assert patches[0]["argv"] == [
        "api", "-X", "PATCH", "repos/OWNER/NAME",
        "-F", "allow_squash_merge=false", "-F", "delete_branch_on_merge=true",
    ]
    assert fake_gh.api_calls() == ["api GET", "api PATCH", "api GET"]


@pytest.mark.integration
def test_already_compliant_sends_no_patch(fake_gh):
    fake_gh.configure(repo=COMPLIANT)

    run = fake_gh.run(REPO)

    assert run.code == 0, run.stderr
    assert run.data == {"repo": "OWNER/NAME", "status": "already-set", "changes": {},
                        "reason": None}
    assert fake_gh.patch_calls() == []


@pytest.mark.integration
def test_already_compliant_takes_precedence_over_missing_admin(fake_gh):
    fake_gh.configure(repo={**COMPLIANT, "permissions": {"admin": False}})

    run = fake_gh.run(REPO)

    assert run.data["status"] == "already-set" and fake_gh.patch_calls() == []


@pytest.mark.integration
@pytest.mark.parametrize("rebase_allowed", [True, False])
def test_merge_commits_turned_on_in_same_patch_rebase_never_sent(fake_gh, rebase_allowed):
    fake_gh.configure(repo={"allow_merge_commit": False, "allow_rebase_merge": rebase_allowed})

    run = fake_gh.run(REPO)

    assert run.code == 0, run.stderr
    assert run.data["status"] == "changed"
    assert run.data["changes"] == {**BOTH_CHANGES,
                                   "allow_merge_commit": {"old": False, "new": True}}
    (patch,) = fake_gh.patch_calls()
    assert "allow_merge_commit=true" in patch["argv"]
    assert not any("allow_rebase_merge" in arg for arg in patch["argv"])


@pytest.mark.integration
def test_no_admin_rights_skips_without_patch(fake_gh):
    fake_gh.configure(repo={"permissions": {"admin": False}})

    run = fake_gh.run(REPO)

    assert run.code == 0, run.stderr
    assert run.data["status"] == "skipped" and run.data["changes"] == {}
    assert "missing admin rights on OWNER/NAME" in run.data["reason"]
    assert fake_gh.patch_calls() == []


# --- AC 17: no usable gh -------------------------------------------------------------------


@pytest.mark.integration
def test_gh_missing_from_path_skips(fake_gh):
    run = fake_gh.run(REPO, gh_on_path=False)

    assert run.code == 0, run.stderr
    assert (run.data["repo"], run.data["status"]) == ("OWNER/NAME", "skipped")
    assert "gh CLI not found" in run.data["reason"]
    assert fake_gh.calls() == []


@pytest.mark.integration
def test_gh_not_authenticated_skips(fake_gh):
    fake_gh.configure(auth_ok=False)

    run = fake_gh.run(REPO)

    assert run.code == 0, run.stderr
    assert run.data["status"] == "skipped"
    assert "not authenticated" in run.data["reason"]
    assert "ghp_" not in run.stdout + run.stderr
    assert [call["argv"][:2] for call in fake_gh.calls()] == [["auth", "status"]]


@pytest.mark.integration
def test_no_github_remote_skips(fake_gh, tmp_path):
    fake_gh.configure(repo_view={"code": 1, "out": "", "err": "no git remotes found\n"})

    run = fake_gh.run("--repo-path", str(tmp_path))

    assert run.code == 0, run.stderr
    assert (run.data["repo"], run.data["status"]) == (None, "skipped")
    assert run.data["reason"].startswith(f"no GitHub repository at {tmp_path}")
    assert fake_gh.patch_calls() == []


@pytest.mark.integration
def test_skip_reasons_are_distinct(fake_gh, tmp_path):
    reasons = [fake_gh.run(REPO, gh_on_path=False).data["reason"]]
    fake_gh.configure(auth_ok=False)
    reasons.append(fake_gh.run(REPO).data["reason"])
    fake_gh.configure(repo_view={"code": 1, "out": "", "err": "no git remotes found"})
    reasons.append(fake_gh.run("--repo-path", str(tmp_path)).data["reason"])
    fake_gh.configure(repo={"permissions": {"admin": False}})
    reasons.append(fake_gh.run(REPO).data["reason"])

    assert len(set(reasons)) == 4 and all(reasons)


# --- AC 18: rejected or not applied --------------------------------------------------------


@pytest.mark.integration
@pytest.mark.parametrize("http_code", [403, 422])
def test_rejected_patch_fails_with_first_error_line(fake_gh, http_code):
    err = f"gh: Validation Failed (HTTP {http_code})\nsecond line is detail"
    fake_gh.configure(patch={"code": 1, "err": err, "applies": True})

    run = fake_gh.run(REPO)

    assert run.code == 0, run.stderr
    assert run.data["status"] == "failed" and run.data["changes"] == {}
    assert run.data["reason"] == f"gh: Validation Failed (HTTP {http_code})"
    assert fake_gh.api_calls() == ["api GET", "api PATCH"]


@pytest.mark.integration
def test_read_back_with_old_values_fails(fake_gh):
    fake_gh.configure(patch={"code": 0, "err": "", "applies": False})

    run = fake_gh.run(REPO)

    assert run.code == 0, run.stderr
    assert run.data["status"] == "failed"
    assert "read-back still shows allow_squash_merge=true" in run.data["reason"]
    assert fake_gh.api_calls() == ["api GET", "api PATCH", "api GET"]


SECRET_LINES = {
    "bearer-header": "HTTP 403 Authorization: Bearer ghp_" + "a" * 36 + " was rejected",
    "pat-token": "bad credentials for token github_pat_" + "B" * 30 + " on repos/OWNER/NAME",
    "bare-ghs": "gh: HTTP 401 ghs_" + "c" * 36,
}


@pytest.mark.integration
@pytest.mark.parametrize("line", SECRET_LINES.values(), ids=SECRET_LINES.keys())
def test_failure_reason_never_contains_token_or_auth_header(fake_gh, line):
    fake_gh.configure(patch={"code": 1, "err": line + "\nmore detail", "applies": True})

    run = fake_gh.run(REPO)

    reason = run.data["reason"]
    assert run.data["status"] == "failed" and "[redacted]" in reason
    for secret in ("ghp_", "ghs_", "github_pat_", "Authorization", "Bearer"):
        assert secret not in reason and secret not in run.stdout + run.stderr


# --- AC 19-20: dry run, repo resolution, validation ---------------------------------------


@pytest.mark.unit
def test_dry_run_plans_changes_without_patch(fake_gh):
    run = fake_gh.run(REPO, "--dry-run")

    assert run.code == 0, run.stderr
    assert run.data == {"repo": "OWNER/NAME", "status": "dry-run", "changes": BOTH_CHANGES,
                        "reason": None}
    assert fake_gh.api_calls() == ["api GET"]


MALFORMED_REPOS = ["noslash", "a/b/c", "a/b;x", "a b/c", "../..", "./.", "a/..", ""]


@pytest.mark.unit
@pytest.mark.parametrize("value", MALFORMED_REPOS)
def test_malformed_repo_argument_exits_2(fake_gh, value):
    run = fake_gh.run(f"--repo={value}")

    assert run.code == 2
    assert set(run.data) == {"error"} and run.data["error"]
    assert fake_gh.calls() == []


@pytest.mark.unit
def test_repo_path_that_is_not_a_directory_exits_2(fake_gh, tmp_path):
    run = fake_gh.run("--repo-path", str(tmp_path / "missing"))

    assert run.code == 2 and set(run.data) == {"error"}
    assert fake_gh.calls() == []


@pytest.mark.unit
def test_repo_name_comes_from_gh_repo_view_in_repo_path(fake_gh, tmp_path):
    inside = tmp_path / "project"
    inside.mkdir()

    run = fake_gh.run("--repo-path", str(inside))

    assert run.code == 0, run.stderr
    assert run.data["repo"] == "OWNER/NAME" and run.data["status"] == "changed"
    views = [c for c in fake_gh.calls() if c["argv"][:2] == ["repo", "view"]]
    assert [c["cwd"] for c in views] == [str(inside.resolve())]


@pytest.mark.unit
@pytest.mark.parametrize("output", ["", "null\n", "42\n", "two words\n"],
                         ids=["empty", "null", "42", "two-words"])
def test_invalid_repo_view_output_skips(fake_gh, output):
    fake_gh.configure(repo_view={"code": 0, "out": output, "err": ""})

    run = fake_gh.run()

    assert run.code == 0, run.stderr
    assert (run.data["repo"], run.data["status"]) == (None, "skipped")
    assert "no valid nameWithOwner" in run.data["reason"]
    assert fake_gh.patch_calls() == []


def api_responses(base):
    def without(key):
        return {k: v for k, v in base.items() if k != key}

    return {
        "not-json": "this is not json",
        "list": "[]",
        "no-permissions": json.dumps(without("permissions")),
        "admin-str": json.dumps({**base, "permissions": {"admin": "yes"}}),
        "field-missing": json.dumps(without("allow_squash_merge")),
        "field-string": json.dumps({**base, "delete_branch_on_merge": "false"}),
    }


@pytest.mark.unit
@pytest.mark.parametrize("case", list(api_responses({})))
def test_invalid_api_json_skips_without_traceback(fake_gh, case):
    fake_gh.configure(get={"code": 0, "raw": api_responses(fake_gh.default_repo)[case], "err": ""})

    run = fake_gh.run(REPO)

    assert run.code == 0, run.stderr
    assert "Traceback" not in run.stderr
    assert run.data["status"] == "skipped"
    assert run.data["reason"].startswith("unexpected gh api response")
    assert fake_gh.patch_calls() == []


@pytest.mark.unit
def test_failed_first_read_is_skipped_not_failed(fake_gh):
    fake_gh.configure(get={"code": 1, "raw": None, "err": "gh: Not Found (HTTP 404)"})

    run = fake_gh.run(REPO)

    assert run.code == 0, run.stderr
    assert run.data["status"] == "skipped" and "Not Found" in run.data["reason"]
    assert fake_gh.patch_calls() == []
