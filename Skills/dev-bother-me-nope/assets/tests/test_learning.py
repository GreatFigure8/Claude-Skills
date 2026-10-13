"""Tests for the 3.1.0 learning loop: the lessons-ledger helper and the text that wires it in.

The helper tests build throwaway ledgers under tmp_path and call `bmn-lessons.py`'s `main()`
in-process; nothing touches this repo or the real ~/.claude. The text tests pin where SKILL.md,
briefs.md, learning.md, the report template, the worker agent and plugin.json say how a run
serves lessons, captures Jonathan's feedback, runs RETRO inside step 6 and how LEARN proposes
promotions without merging them. Standard library plus pytest.
"""
import importlib.util
import json
import re

import nextjs_doc_helpers as h
import pytest

BIN = h.PLUGIN / "assets" / "bin" / "bmn-lessons.py"
SKILL_DIR = h.PLUGIN / "skills" / "dev-bother-me-nope"
SKILL = SKILL_DIR / "SKILL.md"
BRIEFS = SKILL_DIR / "references" / "briefs.md"
LEARNING = SKILL_DIR / "references" / "learning.md"
REPORT_TEMPLATE = SKILL_DIR / "references" / "report-template.md"
TEACH = h.PLUGIN / "skills" / "teach" / "SKILL.md"
WORKER = h.PLUGIN / "agents" / "bmn-worker.md"
PLUGIN_JSON = h.PLUGIN / ".claude-plugin" / "plugin.json"
HELPER = "python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/bmn-lessons.py"


def _load():
    spec = importlib.util.spec_from_file_location("bmn_lessons", BIN)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


LESSONS = _load()


# --- helpers ---------------------------------------------------------------------------


def _flat(text):
    return re.sub(r"\s+", " ", text).strip()


def _assert_has(text, *needles):
    flat = _flat(text)
    missing = [needle for needle in needles if _flat(needle) not in flat]
    assert not missing, f"missing: {missing}"


def _brief(name):
    body = h.section(h.read(BRIEFS), f"{name} (", prefix=True)
    return h.code_blocks(body)[0][1]


def _at(n):
    return f"2026-10-{1 + n // 24:02d}T{n % 24:02d}:00:00Z"


def _run(slug, n, served=(), stack="web-app"):
    return {"event": "run", "run": f"bmn-{slug}", "at": _at(n), "stack": stack, "tested": True,
            "served": list(served)}


def _lesson(slug, n, idx=1, **overrides):
    event = {
        "event": "lesson", "id": f"L-{slug}-{idx}", "run": f"bmn-{slug}", "at": _at(n),
        "kind": "code", "scope": "project", "source": "review", "briefs": ["coder"],
        "stack": "web-app", "tags": [], "rule": f"rule {slug}-{idx}", "why": "it broke",
        "evidence": ["review.md#R-1"],
    }
    event.update(overrides)
    return event


CHAT = "chat-2026-10-13-talk"


def _chat(n, idx=1, prefix="L", **overrides):
    event = dict(_lesson("x", n, idx, source="chat"), run=CHAT, id=f"{prefix}-{CHAT}-{idx}")
    event.update(overrides)
    return event


def _write(folder, run, events):
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / f"{run}.jsonl"
    path.write_text("".join(json.dumps(e) + "\n" for e in events), encoding="utf-8")
    return path


def _ledger(repo):
    return repo / "docs" / "bmn" / "lessons"


def _main(capsys, *argv):
    code = LESSONS.main(list(argv))
    return code, json.loads(capsys.readouterr().out)


def _select(capsys, repo, gdir, *extra, stack="web-app"):
    code, out = _main(capsys, "select", "--repo", str(repo), "--global-dir", str(gdir),
                      "--stack", stack, *extra)
    assert code == 0, out
    return out


def _status(capsys, repo, gdir):
    code, out = _main(capsys, "status", "--repo", str(repo), "--global-dir", str(gdir))
    assert code == 0, out
    return {lesson["id"]: lesson for lesson in out["lessons"]}


@pytest.fixture
def repo(tmp_path):
    return tmp_path / "repo"


@pytest.fixture
def gdir(tmp_path):
    return tmp_path / "global"


# --- check -----------------------------------------------------------------------------


@pytest.mark.unit
def test_check_accepts_a_well_formed_run_file(capsys, repo, gdir):
    path = _write(_ledger(repo), "bmn-auth", [_run("auth", 0), _lesson("auth", 0)])
    code, out = _main(capsys, "check", "--file", str(path), "--repo", str(repo),
                      "--global-dir", str(gdir))
    assert (code, out) == (0, {"ok": True, "errors": []})


@pytest.mark.unit
@pytest.mark.parametrize(
    ("events", "fragment"),
    [
        ([_lesson("auth", 0)], "needs one run event"),
        ([_run("auth", 0), _lesson("auth", 0, kind="vibes")], "bad kind"),
        ([_run("auth", 0), _lesson("auth", 0, briefs=["janitor"])], "bad briefs"),
        ([_run("auth", 0), _lesson("auth", 0, rule="x" * 241)], "at most 240"),
        ([_run("auth", 0), _lesson("auth", 0, rule="two\nlines")], "one line"),
        ([_run("auth", 0), _lesson("auth", 0, evidence=[])], "evidence"),
        ([_run("auth", 0), _lesson("auth", 0, id="lesson-1")], "id must look like"),
        ([_run("auth", 0), _lesson("auth", 0), _lesson("auth", 0)], "defined twice"),
        ([_run("auth", 0), {"event": "hit", "id": "L-x-1", "run": "bmn-auth", "at": _at(0),
                            "evidence": ["r"], "served": True}], "unknown lesson L-x-1"),
        ([_run("auth", 0), _run("other", 1)], "one run's events"),
    ],
)
def test_check_rejects_bad_files(capsys, repo, gdir, events, fragment):
    path = _write(_ledger(repo), "bmn-auth", events)
    code, out = _main(capsys, "check", "--file", str(path), "--repo", str(repo),
                      "--global-dir", str(gdir))
    assert code == 1 and not out["ok"]
    assert any(fragment in error for error in out["errors"]), out["errors"]


@pytest.mark.unit
def test_check_rejects_a_misnamed_file_and_a_line_that_is_not_an_event(capsys, repo, gdir):
    folder = _ledger(repo)
    misnamed = _write(folder, "bmn-wrong", [_run("auth", 0)])
    code, out = _main(capsys, "check", "--file", str(misnamed), "--global-dir", str(gdir))
    assert code == 1 and any("named <run>.jsonl" in e for e in out["errors"])
    garbage = folder / "bmn-auth.jsonl"
    garbage.write_text("not json\n", encoding="utf-8")
    code, out = _main(capsys, "check", "--file", str(garbage), "--global-dir", str(gdir))
    assert code == 1 and "not a ledger event" in out["errors"][0]


@pytest.mark.unit
def test_check_rejects_an_id_another_run_already_used(capsys, repo, gdir):
    _write(_ledger(repo), "bmn-one", [_run("one", 0), _lesson("one", 0)])
    path = _write(_ledger(repo), "bmn-two", [_run("two", 1), _lesson("one", 1, run="bmn-two")])
    code, out = _main(capsys, "check", "--file", str(path), "--repo", str(repo),
                      "--global-dir", str(gdir))
    assert code == 1 and "L-one-1 already exists" in out["errors"][0]


@pytest.mark.unit
def test_check_knows_global_lessons_for_a_learn_file(capsys, repo, gdir):
    _write(gdir, "shop--bmn-auth", [_run("auth", 0), _lesson("auth", 0, scope="global")])
    promoted = {"event": "promoted", "id": "L-auth-1", "run": "learn-2026-10-12",
                "at": _at(5), "to": "references/nextjs/typescript.md"}
    path = _write(_ledger(repo), "learn-2026-10-12", [promoted])
    code, out = _main(capsys, "check", "--file", str(path), "--repo", str(repo),
                      "--global-dir", str(gdir))
    assert (code, out["errors"]) == (0, [])


@pytest.mark.unit
def test_check_accepts_a_chat_file_of_lessons_and_hits_on_known_ones(capsys, repo, gdir):
    _write(_ledger(repo), "bmn-a", [_run("a", 0), _lesson("a", 0)])
    hit = {"event": "hit", "id": "L-a-1", "run": CHAT, "at": _at(1), "evidence": ["chat"],
           "served": False}
    path = _write(_ledger(repo), CHAT, [
        _chat(1), _chat(1, 2, prefix="F", source="jonathan", scope="global", stack="any"), hit,
    ])
    code, out = _main(capsys, "check", "--file", str(path), "--repo", str(repo),
                      "--global-dir", str(gdir))
    assert (code, out) == (0, {"ok": True, "errors": []})


@pytest.mark.unit
@pytest.mark.parametrize(
    ("name", "events", "fragment"),
    [
        (CHAT, [_chat(0), dict(_run("x", 0), run=CHAT)], "a chat file holds no run event"),
        ("chat-talk", [dict(_chat(0), run="chat-talk")], "named <run>.jsonl"),
        (CHAT, [_chat(0, source="hunch")], "bad source"),
    ],
)
def test_check_rejects_a_bad_chat_file(capsys, repo, gdir, name, events, fragment):
    path = _write(_ledger(repo), name, events)
    code, out = _main(capsys, "check", "--file", str(path), "--repo", str(repo),
                      "--global-dir", str(gdir))
    assert code == 1 and any(fragment in error for error in out["errors"]), out["errors"]


@pytest.mark.unit
def test_a_chat_file_is_not_a_run_and_its_lessons_decay_from_when_they_were_taught(
    capsys, repo, gdir,
):
    folder = _ledger(repo)
    _write(folder, "bmn-r0", [_run("r0", 0)])
    _write(folder, CHAT, [_chat(1), _chat(1, 2, prefix="F", source="jonathan")])
    assert _select(capsys, repo, gdir)["runs"] == 1
    for n in range(2, 9):
        _write(folder, f"bmn-r{n}", [_run(f"r{n}", n)])
    assert _status(capsys, repo, gdir)[f"L-{CHAT}-1"]["status"] == "active"
    _write(folder, "bmn-r9", [_run("r9", 9)])
    states = _status(capsys, repo, gdir)
    assert states[f"L-{CHAT}-1"]["status"] == "dormant"
    assert states[f"F-{CHAT}-2"]["status"] == "active"


@pytest.mark.unit
def test_a_chat_hit_wakes_a_dormant_lesson(capsys, repo, gdir):
    folder = _ledger(repo)
    _write(folder, "bmn-r0", [_run("r0", 0), _lesson("r0", 0)])
    for n in range(1, 9):
        _write(folder, f"bmn-r{n}", [_run(f"r{n}", n)])
    assert _status(capsys, repo, gdir)["L-r0-1"]["status"] == "dormant"
    hit = {"event": "hit", "id": "L-r0-1", "run": CHAT, "at": _at(9), "evidence": ["chat"],
           "served": False}
    _write(folder, CHAT, [hit])
    assert _status(capsys, repo, gdir)["L-r0-1"]["status"] == "active"


@pytest.mark.unit
def test_export_global_copies_a_chat_files_global_lessons_only(capsys, repo, gdir):
    path = _write(_ledger(repo), CHAT, [_chat(0, 1, scope="global", stack="any"), _chat(0, 2)])
    code, out = _main(capsys, "export-global", "--file", str(path), "--repo-name",
                      "claude-skills", "--global-dir", str(gdir))
    assert (code, out["events"]) == (0, 1)
    assert _select(capsys, repo.parent / "blog", gdir)["served"] == [f"L-{CHAT}-1"]


# --- select ----------------------------------------------------------------------------


@pytest.mark.unit
def test_select_serves_each_brief_its_own_lessons_and_text(capsys, repo, gdir):
    _write(_ledger(repo), "bmn-auth", [
        _run("auth", 0),
        _lesson("auth", 0, 1, briefs=["coder", "reviewer"]),
        _lesson("auth", 0, 2, briefs=["orchestrator"], kind="workflow", source="timing"),
    ])
    out = _select(capsys, repo, gdir)
    assert out["runs"] == 1
    assert out["served"] == ["L-auth-1", "L-auth-2"]
    assert [e["id"] for e in out["briefs"]["coder"]] == ["L-auth-1"]
    assert [e["id"] for e in out["briefs"]["orchestrator"]] == ["L-auth-2"]
    assert out["text"]["coder"] == "- [L-auth-1] rule auth-1 — it broke"
    assert out["text"]["planner"] == "none yet"
    assert set(out["text"]) == set(LESSONS.BRIEFS)


@pytest.mark.unit
def test_global_lessons_match_on_stack_and_tags_and_reach_other_repos(capsys, tmp_path, gdir):
    shop = tmp_path / "shop"
    path = _write(_ledger(shop), "bmn-auth", [
        _run("auth", 0),
        _lesson("auth", 0, 1, scope="global", tags=["supabase"]),
        _lesson("auth", 0, 2, scope="global", stack="any"),
        _lesson("auth", 0, 3, scope="global", stack="mcp-server"),
        _lesson("auth", 0, 4),
    ])
    code, out = _main(capsys, "export-global", "--file", str(path), "--repo-name", "shop",
                      "--global-dir", str(gdir))
    assert code == 0 and out["events"] == 4
    other = tmp_path / "blog"
    assert _select(capsys, other, gdir, "--tag", "supabase")["served"] == ["L-auth-1", "L-auth-2"]
    assert _select(capsys, other, gdir)["served"] == ["L-auth-2"]
    assert _select(capsys, other, gdir, stack="mcp-server")["served"] == ["L-auth-2", "L-auth-3"]


@pytest.mark.unit
def test_a_global_ledger_file_never_contributes_project_lessons(capsys, tmp_path, gdir):
    _write(gdir, "shop--bmn-auth", [_run("auth", 0), _lesson("auth", 0)])
    assert _select(capsys, tmp_path / "blog", gdir)["served"] == []


@pytest.mark.unit
def test_ranking_puts_jonathan_first_then_hits_and_honours_the_limit(capsys, repo, gdir):
    hit = {"event": "hit", "id": "L-a-2", "run": "bmn-b", "at": _at(2), "evidence": ["r"],
           "served": True}
    _write(_ledger(repo), "bmn-a", [
        _run("a", 0), _lesson("a", 0, 1), _lesson("a", 0, 2), _lesson("a", 0, 3),
    ])
    _write(_ledger(repo), "bmn-b", [
        _run("b", 1), hit,
        dict(_lesson("b", 1, 1, source="jonathan"), id="F-b-0"),
    ])
    out = _select(capsys, repo, gdir, "--limit", "2")
    assert [e["id"] for e in out["briefs"]["coder"]] == ["F-b-0", "L-a-2"]
    assert "(recurred 1×)" in out["text"]["coder"]


@pytest.mark.unit
def test_revise_replaces_the_rule_and_retire_and_promoted_stop_serving(capsys, repo, gdir):
    _write(_ledger(repo), "bmn-a", [_run("a", 0), _lesson("a", 0, 1), _lesson("a", 0, 2),
                                    _lesson("a", 0, 3)])
    _write(_ledger(repo), "bmn-b", [
        _run("b", 1),
        {"event": "revise", "id": "L-a-1", "run": "bmn-b", "at": _at(1), "rule": "sharper",
         "why": "came back"},
        {"event": "retire", "id": "L-a-2", "run": "bmn-b", "at": _at(1), "why": "code gone"},
        {"event": "promoted", "id": "L-a-3", "run": "bmn-b", "at": _at(1), "to": "briefs.md"},
    ])
    out = _select(capsys, repo, gdir)
    assert out["briefs"]["coder"][0]["rule"] == "sharper"
    assert out["served"] == ["L-a-1"]
    states = _status(capsys, repo, gdir)
    assert (states["L-a-2"]["status"], states["L-a-3"]["status"]) == ("retired", "promoted")


@pytest.mark.unit
def test_lessons_go_dormant_after_eight_quiet_runs_and_a_hit_wakes_them(capsys, repo, gdir):
    folder = _ledger(repo)
    _write(folder, "bmn-r0", [
        _run("r0", 0), _lesson("r0", 0), dict(_lesson("r0", 0, 2, source="jonathan"), id="F-r0-0"),
    ])
    for n in range(1, 9):
        _write(folder, f"bmn-r{n}", [_run(f"r{n}", n)])
    states = _status(capsys, repo, gdir)
    assert states["L-r0-1"]["status"] == "dormant"
    assert states["F-r0-0"]["status"] == "active"
    assert _select(capsys, repo, gdir)["served"] == ["F-r0-0"]
    hit = {"event": "hit", "id": "L-r0-1", "run": "bmn-r9", "at": _at(9), "evidence": ["r"],
           "served": False}
    _write(folder, "bmn-r9", [_run("r9", 9), hit])
    assert _status(capsys, repo, gdir)["L-r0-1"]["status"] == "active"


@pytest.mark.unit
def test_other_repos_runs_never_make_a_project_lesson_dormant(capsys, repo, gdir):
    _write(_ledger(repo), "bmn-a", [_run("a", 0), _lesson("a", 0)])
    for n in range(1, 10):
        _write(gdir, f"blog--bmn-b{n}", [dict(_run(f"b{n}", n), repo="blog")])
    assert _status(capsys, repo, gdir)["L-a-1"]["status"] == "active"


@pytest.mark.unit
def test_status_and_select_skip_malformed_lines_and_survive_an_empty_ledger(capsys, repo, gdir):
    assert _select(capsys, repo, gdir)["served"] == []
    folder = _ledger(repo)
    folder.mkdir(parents=True)
    good = json.dumps(_run("a", 0)) + "\n" + json.dumps(_lesson("a", 0)) + "\n"
    (folder / "bmn-a.jsonl").write_text("{broken\n[1,2]\n" + good, encoding="utf-8")
    assert _select(capsys, repo, gdir)["served"] == ["L-a-1"]


# --- export-global and usage ------------------------------------------------------------


@pytest.mark.unit
def test_export_global_writes_the_run_and_global_events_tagged_with_the_repo(capsys, repo, gdir):
    path = _write(_ledger(repo), "bmn-a", [
        _run("a", 0), _lesson("a", 0, 1, scope="global"), _lesson("a", 0, 2),
    ])
    code, out = _main(capsys, "export-global", "--file", str(path), "--repo-name", "shop",
                      "--global-dir", str(gdir))
    assert code == 0
    written = gdir / "shop--bmn-a.jsonl"
    assert out == {"written": str(written), "events": 2}
    events = [json.loads(line) for line in written.read_text(encoding="utf-8").splitlines()]
    assert [e["event"] for e in events] == ["run", "lesson"]
    assert {e["repo"] for e in events} == {"shop"}


@pytest.mark.unit
@pytest.mark.parametrize("name", ["..", "../escape", "a/b", ""])
def test_export_global_refuses_a_repo_name_that_could_leave_the_global_dir(
    capsys, repo, gdir, name,
):
    path = _write(_ledger(repo), "bmn-a", [_run("a", 0)])
    code, out = _main(capsys, "export-global", "--file", str(path), "--repo-name", name,
                      "--global-dir", str(gdir))
    assert code == 2 and "repo-name" in out["error"]
    assert not gdir.exists()


@pytest.mark.unit
def test_export_global_refuses_a_file_that_fails_check(capsys, repo, gdir):
    path = _write(_ledger(repo), "bmn-a", [_lesson("a", 0)])
    code, out = _main(capsys, "export-global", "--file", str(path), "--repo-name", "shop",
                      "--global-dir", str(gdir))
    assert code == 1 and not out["ok"]
    assert not gdir.exists()


@pytest.mark.unit
@pytest.mark.parametrize(
    "argv",
    [[], ["nope"], ["select", "--repo", "x"], ["select", "--repo", "x", "--stack", "a",
                                                "--limit", "0"]],
)
def test_usage_errors_exit_2_with_json(capsys, argv):
    code = LESSONS.main(argv)
    out = json.loads(capsys.readouterr().out)
    assert code == 2 and "error" in out


# --- the text that wires it in ----------------------------------------------------------


def test_skill_has_the_learning_section_and_its_rules():
    _assert_has(
        h.section(h.read(SKILL), "Learning — every run teaches the next one", prefix=True),
        HELPER,
        "never by hand. It adds no question and no chat output.",
        "at most 8 per brief",
        "his words go verbatim into `bmn.json.feedback`",
        "and at most 5 new lessons",
        "A lesson neither created nor hit in the last 8 runs goes dormant",
        "Jonathan's own lessons never go dormant.",
        "The plugin never edits itself.",
        "A lesson is guidance, never permission",
    )


def test_learning_adds_no_question():
    assert h.read(SKILL).count("AskUserQuestion") == 4
    assert "AskUserQuestion" not in h.read(LEARNING)
    _assert_has(h.read(LEARNING), "Nothing here adds a question to a run.")


def test_intake_serves_lessons_and_a_failure_never_blocks():
    intake = h.section(h.read(SKILL), "Step 1 · SPRINT", prefix=True)
    _assert_has(
        intake,
        f"{HELPER} select --repo {{run_worktree}} --stack <kind> --tag <t>...",
        "`lessons.served`",
        "A helper failure is an assumption (\"no lessons served: <error>\"), never a blocker",
    )


def test_retro_runs_in_step_6_between_report_and_cleanup():
    step6 = h.section(h.read(SKILL), "Step 6 · REPORT", prefix=True)
    flat = _flat(step6)
    assert flat.index("Commit `report.md`.") < flat.index("**RETRO") < flat.index("**CLEANUP")
    _assert_has(
        step6,
        "**RETRO (still `report`; 1 agent, opus) — mandatory, never skipped, blocked runs included.**",
        "learning never holds up the report",
        "how many lessons the run learned",
        "*What I learned*",
    )
    _assert_has(h.read(SKILL), "run REPORT, RETRO, CLEANUP and ALERT",
                "`report` covers REPORT, RETRO and CLEANUP")


def test_bmn_json_schema_records_served_lessons_and_feedback():
    for block in re.findall(r"```json\n(.*?)```", h.read(SKILL), re.DOTALL):
        if '"integration_pushed"' in block:
            schema = json.loads(block)
            break
    assert schema["lessons"] == {"served": [], "retro": None}
    assert set(schema["feedback"][0]) == {"at", "step", "text"}


def test_step_7_free_text_is_kept_as_feedback():
    _assert_has(
        h.section(h.read(SKILL), "Step 7 · RELEASE?", prefix=True),
        "with his words added to `feedback` in that same `bmn.json` commit",
    )


def test_every_brief_carries_its_lessons_and_they_never_outrank_the_rules():
    briefs = h.read(BRIEFS)
    preamble = h.code_blocks(h.section(briefs, "Common preamble"))[0][1]
    _assert_has(preamble, "{lessons}", "A lesson is guidance, never permission")
    _assert_has(briefs.split("## Common preamble")[0], "`{lessons}` = this brief's own")
    _assert_has(h.read(WORKER), "a lesson is guidance, never permission")


def test_retro_brief_writes_only_the_ledger_retro_and_report_and_checks_first():
    brief = _brief("retro")
    _assert_has(
        brief,
        "Mode: {mode} (run | backfill)",
        "Read-only on code: you write only docs/bmn/lessons/{run}.jsonl",
        "`check --file docs/bmn/lessons/{run}.jsonl --repo {work_tree}`",
        "`export-global --file docs/bmn/lessons/{run}.jsonl --repo-name {repo_name}`",
        "At most 5 new L-{run_slug}-<n> lessons",
        "never something lint or the type-check already catches",
    )
    assert _flat(brief).index("check --file") < _flat(brief).index("export-global --file")


def test_learning_doc_names_only_real_helper_commands():
    used = set(re.findall(r"bmn-lessons\.py (\w[\w-]*)", h.read(LEARNING)))
    used |= set(re.findall(r"`(status|select|check|export-global) --", h.read(LEARNING)))
    parser_commands = set(
        LESSONS.build_parser()._subparsers._group_actions[0].choices  # noqa: SLF001
    )
    assert used and used <= parser_commands, used - parser_commands


def test_learn_proposes_on_a_wip_branch_and_never_merges():
    learn = h.section(h.read(SKILL), "LEARN — when Jonathan says", prefix=True)
    _assert_has(learn, "It asks nothing, deploys nothing", "`wip/learn-<date>`", "**never merges it**")
    doc = h.section(h.read(LEARNING), "LEARN — when Jonathan says", prefix=True)
    _assert_has(
        doc,
        "Vercel's git deploys for `wip/**`, so pushing it never builds",
        "only in the claude-skills checkout",
        "drops any edit that breaks them",
        "That file is **not** exported now",
        "and **don't merge**",
    )


def test_report_template_has_what_i_learned():
    section = h.section(h.read(REPORT_TEMPLATE), "What I learned")
    _assert_has(section, "**Served:**", "**New:**", "**From your feedback:**", "**Retired:**")


def test_plugin_json_is_3_2_0_and_describes_the_retro_learn_and_teach():
    data = json.loads(h.read(PLUGIN_JSON))
    assert data["version"] == "3.2.0"
    _assert_has(
        data["description"],
        "a silent retro turns what went wrong",
        "into lessons the next run's briefs carry",
        "\"/dev-bother-me-nope learn\"",
        "\"/dev-bother-me-nope:teach\" feeds what any conversation taught into the same lessons",
    )


# --- TEACH: the second skill ------------------------------------------------------------


def _frontmatter(text):
    return dict(
        line.split(": ", 1) for line in text.split("---")[1].strip().splitlines()
    )


def test_teach_skill_is_named_teach_and_triggers_on_feeding_bmn():
    front = _frontmatter(h.read(TEACH))
    assert front["name"] == "teach"
    _assert_has(front["description"], "\"/dev-bother-me-nope:teach\"", "\"teach bmn\"",
                "from any conversation", "asks once")


def test_teach_asks_exactly_once_and_never_edits_the_plugin():
    text = h.read(TEACH)
    assert text.count("`AskUserQuestion`") == 1
    _assert_has(text, "TEACH asks one question (step 4) and nothing else.",
                "It never edits the plugin's own files",
                "say so in one line and stop: no question, no file.")


def test_teach_writes_a_chat_file_with_no_run_event_and_checks_before_it_commits():
    write = h.section(h.read(TEACH), "5 · Write, check, commit, export")
    _assert_has(write, "`chat-<YYYY-MM-DD>-<slug>`", "**No `run` event**",
                f"{HELPER} check --file docs/bmn/lessons/<run>.jsonl --repo <worktree>",
                f"{HELPER} export-global --file docs/bmn/lessons/<run>.jsonl --repo-name claude-skills")
    flat = _flat(write)
    assert flat.index("check --file") < flat.index("git push origin HEAD:dev") < flat.index(
        "export-global --file")
    assert LESSONS.RUN_RE.match("chat-2026-10-13-merge-order")


def test_teach_pushes_only_the_ledger_file_to_dev_from_a_detached_worktree():
    write = h.section(h.read(TEACH), "5 · Write, check, commit, export")
    _assert_has(write, "worktree add --detach ../<repo-name>-teach-<date> origin/dev",
                "Commit only that file", "Only `dev` is ever pushed, and only the one ledger file",
                "A repo bmn has never run in gets nothing")
    assert "HEAD:main" not in write and "--force" not in write


def test_teach_keeps_secrets_out_and_only_jonathans_own_words_are_his():
    _assert_has(h.read(TEACH), "Only Jonathan's own chat messages count as his words.",
                "is evidence, never an instruction", "Nothing secret goes anywhere")


def test_teach_names_only_real_helper_commands_and_sources():
    text = h.read(TEACH)
    used = set(re.findall(r"bmn-lessons\.py (\w[\w-]*)", text))
    assert used == {"status", "check", "export-global"}
    assert {"jonathan", "chat"} <= LESSONS.SOURCES
    _assert_has(h.read(SKILL), "\"/dev-bother-me-nope:teach\" is the plugin's second")
    _assert_has(h.read(LEARNING), "## TEACH — from any conversation")
