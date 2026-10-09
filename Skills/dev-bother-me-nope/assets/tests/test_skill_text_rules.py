"""Text-presence tests for the merge rules: merge commits only, every merged branch deleted.

Each test reads the plugin's Markdown/JSON and asserts the named section holds the required
commands and phrases. Section lookup is by heading text so the tests survive line shifts.
Standard library only; nothing here runs, imports or execs either helper script
(`merged-branch-cleanup.py`, `repo-merge-policy.py`), so this file does not depend on the
story that builds them.
"""

import ast
import json
import re
from pathlib import Path

import pytest

PLUGIN = Path(__file__).resolve().parents[2]
SKILL_DIR = PLUGIN / "skills" / "dev-bother-me-nope"
SKILL = SKILL_DIR / "SKILL.md"
BRIEFS = SKILL_DIR / "references" / "briefs.md"
MOVE_COMPUTERS = SKILL_DIR / "references" / "move-computers.md"
REPORT_TEMPLATE = SKILL_DIR / "references" / "report-template.md"
WORKER = PLUGIN / "agents" / "bmn-worker.md"
PLUGIN_JSON = PLUGIN / ".claude-plugin" / "plugin.json"
OWNED_MARKDOWN = (SKILL, BRIEFS, MOVE_COMPUTERS, REPORT_TEMPLATE, WORKER)

HEADING = re.compile(r"^(#{1,6})\s+(.*)$")
NEGATION = re.compile(r"never|no |not|block|forbidden", re.IGNORECASE)
PR_MERGE_FORM = "gh pr merge <n> --merge --delete-branch --repo <owner>/<repo>"
CLEANUP_CALL = (
    "python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py "
    "--repo <path> --branch <branch> --target <ref>"
)
POLICY_CALL = (
    "python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/repo-merge-policy.py "
    "--repo-path {run_worktree}"
)


# --- helpers ----------------------------------------------------------------------


def _read(path):
    return path.read_text(encoding="utf-8")


def _norm(text):
    """Collapse all whitespace so a phrase matches however the prose is wrapped."""
    return re.sub(r"\s+", " ", text).strip()


def _assert_has(text, *needles):
    flat = _norm(text)
    missing = [needle for needle in needles if _norm(needle) not in flat]
    assert not missing, f"missing: {missing}"


def _assert_lacks(text, *needles):
    flat = _norm(text)
    present = [needle for needle in needles if _norm(needle) in flat]
    assert not present, f"must not contain: {present}"


def _headings(lines):
    """Yield (line index, level, title) for every heading outside a code fence."""
    in_fence = False
    for index, line in enumerate(lines):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        match = None if in_fence else HEADING.match(line)
        if match:
            yield index, len(match.group(1)), match.group(2)


def _section(text, title_part):
    """Body of the first heading whose title contains title_part, up to the next
    heading of the same or a higher level."""
    lines = text.splitlines()
    heads = list(_headings(lines))
    for position, (index, level, title) in enumerate(heads):
        if title_part not in title:
            continue
        end = len(lines)
        for next_index, next_level, _ in heads[position + 1 :]:
            if next_level <= level:
                end = next_index
                break
        return "\n".join(lines[index + 1 : end])
    raise AssertionError(f"no heading containing {title_part!r}")


def _brief(name):
    return _section(_read(BRIEFS), f"{name} (")


def _paragraph(text, lead):
    """From the line that starts with lead to the next blank line."""
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if not line.startswith(lead):
            continue
        end = index
        while end < len(lines) and lines[end].strip():
            end += 1
        return "\n".join(lines[index:end])
    raise AssertionError(f"no paragraph starting with {lead!r}")


def _numbered_items(section):
    items, current = [], None
    for line in section.splitlines():
        if re.match(r"\d+\. ", line):
            current = [line]
            items.append(current)
        elif current is not None:
            current.append(line)
    return ["\n".join(item) for item in items]


def _numbered_item(section, needle):
    for item in _numbered_items(section):
        if _norm(needle) in _norm(item):
            return item
    raise AssertionError(f"no numbered item containing {needle!r}")


def _bullets(text):
    bullets, current = [], None
    for line in text.splitlines():
        if line.startswith("- "):
            current = [line]
            bullets.append(current)
        elif current is not None and line.startswith(" ") and line.strip():
            current.append(line)
        else:
            current = None
    return ["\n".join(bullet) for bullet in bullets]


def _bullet(text, needle):
    for bullet in _bullets(text):
        if _norm(needle) in _norm(bullet):
            return bullet
    raise AssertionError(f"no bullet containing {needle!r}")


def _sentences(text):
    return re.split(r"(?<=\.)\s+", _norm(text))


def _skill():
    return _read(SKILL)


def _never_squash_section():
    return _section(_skill(), "never squash")


def _branches_section():
    return _section(_skill(), "Branches and worktrees")


def _part(section, lead, until):
    """From the line that starts with lead up to the line that starts with until."""
    lines = section.splitlines()
    start = next((i for i, line in enumerate(lines) if line.startswith(lead)), None)
    assert start is not None, f"no line starting with {lead!r}"
    end = next(
        (i for i, line in enumerate(lines[start + 1 :], start + 1) if line.startswith(until)), None
    )
    assert end is not None, f"no line starting with {until!r} after {lead!r}"
    return "\n".join(lines[start:end])


def _intake():
    """Step 1's INTAKE part (1a), up to DESIGN (1b)."""
    return _part(_section(_skill(), "Step 1 · SPRINT"), "**1a · INTAKE", "**1b · DESIGN")


def _cleanup():
    """Step 6's CLEANUP part, up to the ALERT."""
    return _part(_section(_skill(), "Step 6 · REPORT"), "**CLEANUP", "**ALERT.**")


def _table_row(section, lead):
    for line in section.splitlines():
        if line.startswith("|") and lead in line:
            return line
    raise AssertionError(f"no table row containing {lead!r}")


def _deleted_cell(row):
    return _norm(row.strip().strip("|").split("|")[-1])


def _bmn_json_schema():
    for block in re.findall(r"```json\n(.*?)```", _skill(), re.DOTALL):
        if '"integration_pushed"' in block:
            return json.loads(block)
    raise AssertionError("bmn.json schema block not found")


# --- AC1: plugin.json -------------------------------------------------------------


def test_plugin_json_is_version_3_0_0():
    data = json.loads(_read(PLUGIN_JSON))
    assert data["version"] == "3.0.0"


def test_plugin_description_names_merge_commits_and_branch_cleanup():
    description = json.loads(_read(PLUGIN_JSON))["description"].lower()
    for phrase in (
        "merge commits only",
        "never squash",
        "every merged branch is deleted",
        "every worktree",
        "locally and on origin",
        "every pr merge deletes its source branch",
    ):
        assert phrase in description, phrase


# --- AC2, AC3: the never-squash section -------------------------------------------


def test_skill_has_never_squash_section_with_forbidden_forms():
    heading = "## Merge commits only — never squash (Jonathan's rule, 2026-10-03)"
    assert heading in _skill().splitlines()
    _assert_has(
        _never_squash_section(),
        "--no-ff",
        "git merge --squash",
        "gh pr merge",
        "merge_method=squash",
        "--delete-branch",
        "deploy guard",
        "2026-10-03",
        "never squash",
        "merge commit",
        "history",
    )


def test_never_squash_section_sits_right_after_merging_never_builds():
    titles = [title for _, _, title in _headings(_skill().splitlines())]
    position = next(i for i, t in enumerate(titles) if "Merging never builds" in t)
    assert "never squash" in titles[position + 1]
    assert "State on disk" in titles[position + 2]


def test_never_squash_section_says_guard_blocks_while_run_active():
    section = _norm(_never_squash_section())
    _assert_has(section, "while a run is active", "deploy guard")
    assert re.search(r"deploy guard blocks[^.]*while a run is active", section)


def test_pr_merge_form_in_skill_and_merger_brief():
    _assert_has(_skill(), PR_MERGE_FORM)
    _assert_has(_brief("merger"), PR_MERGE_FORM)


def test_skill_explains_repo_form_keeps_local_checkouts():
    _assert_has(
        _never_squash_section(),
        "deletes only the remote head branch",
        "leaves every local checkout alone",
        "merged-branch-cleanup.py",
    )


# --- AC4: Branches and worktrees --------------------------------------------------


def test_branches_section_names_cleanup_script_and_every_worktree():
    _assert_has(
        _branches_section(),
        "merged-branch-cleanup.py",
        "git worktree list --porcelain",
        "every worktree",
        "main checkout",
        "--force",
    )


def test_branches_table_deleted_column_timing():
    section = _branches_section()
    temp_cell = _deleted_cell(_table_row(section, "Story, fix and test branches"))
    sprint_cell = _deleted_cell(_table_row(section, "**Sprint branch**"))
    _assert_has(
        temp_cell,
        "as soon as the merger has merged it — local, origin and every worktree on it",
    )
    _assert_has(
        sprint_cell,
        "at CLEANUP (step 6), after its last merge to `dev` — not after step 3, "
        "because FIX still branches from it",
    )


def test_sprint_branch_is_cut_from_origin_dev():
    section = _branches_section()
    _assert_has(_table_row(section, "**Sprint branch**"), "`sprint/<run-slug>`, cut from `origin/dev`")
    _assert_has(
        _intake(),
        "git worktree add --no-track -b sprint/<run-slug> ../<repo-name>-<run-slug> origin/dev",
    )
    assert _bmn_json_schema()["integration"] == "sprint/<run-slug>"


def test_cleanup_scope_sentence_covers_every_worktree():
    section = _branches_section()
    _assert_has(
        section,
        "Cleanup only ever touches those refs, plus every worktree that has one of "
        "them checked out (from `git worktree list --porcelain`), even one bmn "
        "didn't create; the main checkout is never removed or switched.",
    )
    _assert_lacks(section, "Cleanup only ever touches those.")


def test_force_only_appears_in_never_sentences_in_branches_section():
    sentences = [s for s in _sentences(_branches_section()) if "--force" in s]
    assert sentences, "the section must mention --force in a never sentence"
    for sentence in sentences:
        assert re.search(r"never|without|no ", sentence, re.IGNORECASE), sentence


# --- AC5: Cleanup is a step -------------------------------------------------------


def test_cleanup_is_a_step_runs_script_and_records_json():
    paragraph = _paragraph(_branches_section(), "**Cleanup is a step")
    _assert_has(
        paragraph,
        CLEANUP_CALL,
        "deleted",
        "left",
        "bmn.json.cleanup",
        "Git cleanup",
        "exit 2",
        "why",
    )


def test_cleanup_is_a_step_drops_hand_written_delete_sequence():
    paragraph = _paragraph(_branches_section(), "**Cleanup is a step")
    _assert_lacks(paragraph, "git branch -D", "git push origin --delete")


# --- AC6, AC7, AC8: briefs and CLEANUP --------------------------------------------


def test_merger_brief_runs_cleanup_script_per_merged_branch():
    _assert_has(
        _brief("merger"),
        "merged-branch-cleanup.py",
        "--target origin/{integration}",
        "--repo {run_worktree}",
        "For each branch you merged",
    )


def test_merger_brief_keeps_harness_rule_and_return_shape():
    _assert_has(
        _brief("merger"),
        "git rev-list <harness> --not --exclude=refs/heads/<harness> --branches --remotes",
        "deleted[]",
        "left[{ref, why}]",
    )


def test_cleaner_brief_uses_script_with_both_targets():
    _assert_has(
        _brief("cleaner"),
        "merged-branch-cleanup.py",
        "--repo {repo_path}",
        "--target origin/{integration}",
        "--target origin/dev",
        "integration_pushed",
    )


def test_cleaner_brief_record_step_unchanged():
    _assert_has(
        _brief("cleaner"),
        "worktree add --detach",
        "git.deploymentEnabled",
        "phase: blocked",
        "chore(bmn): record git cleanup for {run_slug}",
    )


def test_skill_cleanup_step_and_leftover_sweep_name_script_and_targets():
    _assert_has(
        _cleanup(),
        "merged-branch-cleanup.py",
        "--target origin/{integration}",
        "--target origin/dev",
        "integration_pushed",
        "git rev-list",
    )
    sweep = _paragraph(_skill(), "**Leftover sweep")
    _assert_has(sweep, "merged-branch-cleanup.py", "--target origin/dev")
    _assert_lacks(_paragraph(_skill(), "**Resume rule"), "Leftover sweep")


def test_merger_brief_merges_no_ff_and_never_squashes():
    brief = _brief("merger")
    _assert_has(brief, "git merge --no-ff", "never squash")
    for line in brief.splitlines():
        if "--squash" in line:
            assert NEGATION.search(line), line


def test_merger_brief_leaves_sprint_branch_to_cleanup():
    _assert_has(_brief("merger"), "Don't delete {integration}: CLEANUP does")


def test_common_preamble_states_merge_rule():
    _assert_has(
        _section(_read(BRIEFS), "Common preamble"),
        "git merge --no-ff",
        "never squash",
        "gh pr merge <n> --merge --delete-branch",
    )


# --- AC9: INTAKE runs the repo merge policy ---------------------------------------


def _intake_policy_item():
    section = _intake()
    return section, _numbered_item(section, "repo-merge-policy.py")


def test_intake_runs_repo_merge_policy_once():
    section, item = _intake_policy_item()
    assert re.match(r"5\. ", item)
    _assert_has(item, POLICY_CALL, "already set")
    assert "design.needed" in _numbered_items(section)[5]


def test_intake_records_policy_as_assumption_never_blocker():
    _, item = _intake_policy_item()
    _assert_has(item, "bmn.json.repo_policy", "skipped", "failed", "assumptions")
    assert re.search(r"never[^.]*blocker", _norm(item)), "never ... blocker"


def test_bmn_json_schema_has_repo_policy_key():
    keys = list(_bmn_json_schema())
    assert "repo_policy" in keys
    assert _bmn_json_schema()["repo_policy"] is None
    assert keys.index("repo_policy") == keys.index("cleanup") + 1


def test_intake_names_enforced_settings_and_standing_instruction():
    _, item = _intake_policy_item()
    _assert_has(
        item,
        "allow_squash_merge=false",
        "delete_branch_on_merge=true",
        "standing instruction",
        "2026-10-03",
    )


# --- AC10: report template --------------------------------------------------------


def test_report_template_has_repo_merge_settings():
    text = _read(REPORT_TEMPLATE)
    assert "## Repo merge settings" in text.splitlines()
    _assert_has(
        _section(text, "Repo merge settings"),
        "repo_policy",
        "allow_squash_merge",
        "delete_branch_on_merge",
        "→",
        "unchanged: {reason}",
    )


def test_report_git_cleanup_lists_worktrees_per_branch_and_left_reasons():
    _assert_has(
        _section(_read(REPORT_TEMPLATE), "Git cleanup"),
        "per branch",
        "worktree",
        "didn't create",
        "Left",
        "why",
    )


# --- AC11: move-computers ---------------------------------------------------------


def test_move_computers_drops_stale_wip_sentence():
    _assert_lacks(_read(MOVE_COMPUTERS), "stay on origin until CLEANUP")


def test_move_computers_says_merged_wip_branches_already_deleted():
    _assert_has(
        _read(MOVE_COMPUTERS),
        "already deleted",
        "when the merger merged them",
        "only unmerged",
    )


# --- FIX1 R1-1: the machine-move tidy goes through the helper -----------------------

HELPER_PATH = "python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py"
MOVE_PUSHED_CALL = (
    f"{HELPER_PATH} --repo <main checkout> --branch <branch> --target origin/<branch> --pushed"
)
MOVE_HARNESS_CALL = (
    f"{HELPER_PATH} --repo <main checkout> --branch <harness branch> "
    "--target origin/<integration> --local-only"
)
HAND_RUN_REMOVAL = re.compile(r"git worktree (?:remove|prune)|git branch -[dD]")
NEVER = re.compile(r"\bnever\b", re.IGNORECASE)


def _move_out_tidy():
    return _numbered_item(_section(_read(MOVE_COMPUTERS), "MOVE-OUT"), "Tidy this machine")


def test_move_out_tidy_runs_the_helper_for_every_branch_it_removes():
    _assert_has(
        _move_out_tidy(),
        MOVE_PUSHED_CALL,
        MOVE_HARNESS_CALL,
        "main checkout",
        "Left on <host>",
        "origin:<branch>",
    )


def test_move_out_tidy_says_which_files_keep_a_worktree():
    _assert_has(_move_out_tidy(), "ignored", ".env", "regenerable build output", "no --force")


def test_move_computers_never_hand_runs_worktree_remove_or_branch_delete():
    unforbidden = [
        sentence
        for sentence in _sentences(_read(MOVE_COMPUTERS))
        if HAND_RUN_REMOVAL.search(sentence) and not NEVER.search(sentence)
    ]
    assert not unforbidden, unforbidden


# --- AC12: the worker agent -------------------------------------------------------


def test_worker_agent_has_merge_commits_only_bullet():
    _assert_has(
        _bullet(_read(WORKER), "merge commits only"),
        "merge commits only",
        "--no-ff",
        "never squash",
        "gh pr merge <n> --merge --delete-branch",
    )


def test_worker_agent_deletion_bullet_covers_every_worktree():
    _assert_has(
        _bullet(_read(WORKER), "every worktree"),
        "every worktree",
        "checked out",
    )


# --- orchestrator fills the plugin root -------------------------------------------


def test_orchestrator_fills_plugin_root_for_workers():
    bullet = _bullet(_section(_skill(), "Orchestrator discipline"), "${CLAUDE_PLUGIN_ROOT}")
    _assert_has(bullet, "${CLAUDE_PLUGIN_ROOT}", "{skill_dir}/../..", "absolute")


# --- AC13: squash is only ever forbidden ------------------------------------------


@pytest.mark.parametrize("path", OWNED_MARKDOWN, ids=lambda path: path.name)
def test_squash_is_only_ever_forbidden(path):
    offenders = []
    for number, line in enumerate(_read(path).splitlines(), start=1):
        stripped = re.sub("allow_squash_merge", "", line, flags=re.IGNORECASE)
        if re.search("squash", stripped, re.IGNORECASE) and not NEGATION.search(stripped):
            offenders.append(f"{path.name}:{number}: {line.strip()}")
    assert not offenders, "\n".join(offenders)


# --- FIX1 R1-7: an unpushed sprint branch is still cleaned locally ----------------


def _sprint_branch_steps():
    """CLEANUP's "Sprint branch" step as the skill and as the cleaner brief word it."""
    return {
        "SKILL.md CLEANUP": _numbered_item(_cleanup(), "Sprint branch"),
        "cleaner brief": _numbered_item(_brief("cleaner"), "Sprint branch"),
    }


def _record_steps():
    return {
        "SKILL.md CLEANUP": _numbered_item(_cleanup(), "**Record.**"),
        "cleaner brief": _numbered_item(_brief("cleaner"), "If step 2 deleted the branch"),
    }


@pytest.mark.parametrize("where", ["SKILL.md CLEANUP", "cleaner brief"])
def test_unpushed_sprint_branch_is_still_deleted_locally(where):
    step = _sprint_branch_steps()[where]
    _assert_lacks(step, "skip the helper", "leave the branch")
    _assert_has(
        step,
        "integration_pushed",
        "origin copy not pushed by this run",
        "local branch",
        "every worktree",
    )


LOCAL_ONLY_CALLS = {
    "SKILL.md CLEANUP": "--repo <main checkout> --branch <integration> --target origin/dev --local-only",
    "cleaner brief": "--repo {repo_path} --branch {integration} --target origin/dev --local-only",
}
HAND_RUN_REMNANTS = (
    "worktree remove <path>",
    "update-ref -d",
    'merge-base --is-ancestor "$sha"',
    "sha=$(",
    "the helper has no flag",
    "git branch -D",
)


@pytest.mark.parametrize("where", ["SKILL.md CLEANUP", "cleaner brief"])
def test_unpushed_sprint_branch_names_the_local_only_steps(where):
    step = _sprint_branch_steps()[where]
    _assert_has(
        step,
        "python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py " + LOCAL_ONLY_CALLS[where],
        "--local-only",
        "origin:",
    )
    _assert_lacks(step, *HAND_RUN_REMNANTS)


def test_leftover_sweep_passes_local_only_when_the_run_did_not_push():
    sweep = _paragraph(_skill(), "**Leftover sweep")
    _assert_has(sweep, "--local-only", "integration_pushed", "--target origin/dev")
    assert re.search(r"--local-only[^.]*integration_pushed[^.]*false", _norm(sweep))


@pytest.mark.parametrize("where", ["SKILL.md CLEANUP", "cleaner brief"])
def test_cleanup_text_never_runs_a_repo_wide_worktree_prune(where):
    section = _cleanup() if where == "SKILL.md CLEANUP" else _brief("cleaner")
    pruning = [item for item in _sentences(section) if re.search(r"worktree\s+prune", item)]
    unforbidden = [item for item in pruning if not re.search(r"\bnever\b", item, re.IGNORECASE)]
    assert not unforbidden, unforbidden


@pytest.mark.parametrize("where", ["SKILL.md CLEANUP", "cleaner brief"])
def test_vercel_key_stays_while_the_origin_copy_stays(where):
    _assert_has(_record_steps()[where], "only when the origin copy was deleted too")


# --- FIX1 R1-10: every helper call uses the plugin-root form ----------------------

HELPER_SCRIPTS = ("merged-branch-cleanup", "repo-merge-policy", "deploy-guard")
HELPER_CALL = re.compile(
    rf"(?P<runner>python3 )?(?P<path>\S*?)\b(?:{'|'.join(HELPER_SCRIPTS)})\.py\s+--"
)
CALL_PATHS = ("${CLAUDE_PLUGIN_ROOT}/assets/bin/", "{skill_dir}/../../assets/bin/")


def _helper_calls(text):
    """Every `<helper>.py --…` invocation (a bare mention of the file name is not one)."""
    return list(HELPER_CALL.finditer(_norm(text)))


def test_the_skill_and_briefs_do_invoke_the_helpers():
    assert len(_helper_calls(_read(SKILL))) >= 5
    assert len(_helper_calls(_read(BRIEFS))) >= 3


@pytest.mark.parametrize("path", OWNED_MARKDOWN, ids=lambda path: path.name)
def test_every_helper_invocation_uses_the_plugin_root_form(path):
    bare = [
        match.group(0)
        for match in _helper_calls(_read(path))
        if not (match.group("runner") and match.group("path") in CALL_PATHS)
    ]
    assert not bare, f"bare helper invocation (the script is not on PATH): {bare}"


# --- AC14: this file never runs the helper scripts --------------------------------


def test_rules_file_never_runs_helper_scripts():
    tree = ast.parse(Path(__file__).read_text(encoding="utf-8"))
    imported = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imported.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            imported.add(node.module.split(".")[0])
    called = {
        node.func.id
        for node in ast.walk(tree)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
    }
    assert not imported & {"subprocess", "runpy", "importlib"}
    assert not called & {"exec", "eval", "__import__"}
