"""Text-presence tests for the 1.8.0 speed rules (Jonathan, 2026-10-05).

A bmn run of three small changes took about four hours. 1.8.0 adds fast mode for ASAP and
small runs, scopes every agent's gates so the full suite and the build run once per phase (in
TEST), lets stories whose deps have a planned interface build in the same wave, folds the
integrator and the merger into one agent when one branch is left to merge, and has the
orchestrator state a time estimate and pass a speed request to in-flight agents. These tests
pin where SKILL.md, briefs.md, stack-routing.md, report-template.md, the worker agent and
plugin.json say so. Section lookup is by heading text so the tests survive line shifts.
Offline, standard library plus pytest; nothing here runs a helper script.
"""

import json
import re

import nextjs_doc_helpers as h
import pytest

SKILL_DIR = h.PLUGIN / "skills" / "dev-bother-me-nope"
SKILL = SKILL_DIR / "SKILL.md"
BRIEFS = SKILL_DIR / "references" / "briefs.md"
STACK_ROUTING = SKILL_DIR / "references" / "stack-routing.md"
REPORT_TEMPLATE = SKILL_DIR / "references" / "report-template.md"
WORKER = h.PLUGIN / "agents" / "bmn-worker.md"
PLUGIN_JSON = h.PLUGIN / ".claude-plugin" / "plugin.json"

SCOPED_BRIEFS = ("coder", "planner-coder", "fixer", "integrator", "merger", "integrator-merger")
CLEANUP_HELPER = "python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py"
FULL_SUITE = re.compile(r"full (?:test )?suite", re.IGNORECASE)
NEGATED = re.compile(r"\bnever\b|\bnot\b|\bnone\b|\bonly\b|\bno\b", re.IGNORECASE)


# --- helpers ---------------------------------------------------------------------------


def _flat(text):
    return re.sub(r"\s+", " ", text).strip()


def _assert_has(text, *needles):
    flat = _flat(text)
    missing = [needle for needle in needles if _flat(needle) not in flat]
    assert not missing, f"missing: {missing}"


def _skill():
    return h.read(SKILL)


def _skill_section(heading):
    return h.section(_skill(), heading, prefix=True)


def _brief(name):
    """The code block of the brief headed ``## <name> (…)`` (exact name, so ``coder`` is
    never ``planner-coder``)."""
    body = h.section(h.read(BRIEFS), f"{name} (", prefix=True)
    blocks = h.code_blocks(body)
    assert blocks, f"no code block in the {name} brief"
    return blocks[0][1]


def _sentences(text):
    return re.split(r"(?<=[.;])\s+", _flat(text))


def _bmn_json_schema():
    for block in re.findall(r"```json\n(.*?)```", _skill(), re.DOTALL):
        if '"integration_pushed"' in block:
            return json.loads(block)
    raise AssertionError("bmn.json schema block not found")


# --- fast mode exists -------------------------------------------------------------------


def test_skill_has_a_fast_mode_section_with_its_trigger():
    section = _skill_section("Fast mode")
    _assert_has(
        section,
        "ASAP, urgent or hotfix",
        "≤3 small stories",
        "no UI design is needed",
        "as an assumption",
        'bmn.json.mode: "fast"',
    )


def test_fast_mode_uses_one_planner_coder_per_story_and_no_splitter_or_planner():
    section = _skill_section("Fast mode")
    _assert_has(
        section,
        "There is no separate DESIGN, SPLIT or PLAN, and no separate integrator",
        "One **planner-coder** (opus, `isolation: \"worktree\"`) per story",
        "merges its own branch into the run branch (the integrator brief, folded in)",
        "merged-branch-cleanup.py",
        "Straight to the merger",
    )


def test_fast_mode_skips_test2_and_review2_unless_asked():
    section = _skill_section("Fast mode")
    _assert_has(section, "without TEST② and REVIEW②: those run only if Jonathan asks for them")


def test_fast_mode_keeps_every_hard_line():
    _assert_has(
        _skill_section("Fast mode"),
        "Every hard line, the silence rule, merge commits only, the cleanup helper",
        "the main checkout left untouched",
        "DB-SYNC to Supabase DEV only",
        "no Vercel deploys",
        "nothing pushed to `main`",
    )


def test_pipeline_diagram_shows_the_fast_path():
    diagram = h.code_blocks(_skill())[0][1]
    _assert_has(diagram, "Fast mode", "planner-coder", "REVIEW① ∥ TEST①", "MERGE→dev②")
    fast = diagram.split("Fast mode", 1)[1]
    assert "REVIEW②" not in fast, "the fast path has no REVIEW②"


def test_bmn_json_records_mode_and_estimate():
    schema = _bmn_json_schema()
    assert schema["mode"] == "full|fast"
    assert "estimate" in schema
    assert schema["speed"] == {"requested": False, "skipped_gates": []}


def test_intake_decides_mode_and_estimate():
    item = h.numbered_items(_skill_section("0 · INTAKE"))[6]
    _assert_has(item, "Mode and estimate", "fast_fit", "assumptions", "`mode`", "`estimate`")


def test_resume_rule_knows_fast_runs():
    _assert_has(
        _skill(),
        'A fast run (`mode: "fast"`) resumed at `test1`',
        "A run from before 1.8.0 has no `mode`: treat it as `full`.",
    )


def test_planner_coder_brief_plans_builds_and_integrates():
    brief = _brief("planner-coder")
    _assert_has(
        brief,
        "docs/sprints/{run}/{slug}/story.md",
        "docs/sprints/{run}/{slug}/{slug}-plan.md",
        "strict TDD",
        "confirm they FAIL",
        "the integrator brief, folded in",
        "git merge --no-ff origin/{story_branch}",
        "git push origin HEAD:{integration}",
        "never --force",
        f"{CLEANUP_HELPER} --repo {{run_worktree}} --branch {{story_branch}} "
        "--target origin/{integration}",
    )


def test_planner_coder_heading_names_opus_and_worktree():
    titles = h.headings(h.read(BRIEFS), 2)
    title = next(t for t in titles if t.startswith("planner-coder ("))
    for word in ("fast mode", "opus", "isolation: worktree"):
        assert word in title, word


def test_worker_agent_lists_the_new_briefs():
    head = h.read(WORKER).split("---")[1]
    for name in ("planner-coder", "integrator-merger"):
        assert name in head, name


# --- the code → review → fix → review rule stays consistent -----------------------------


def test_review_rule_says_review2_is_skipped_in_fast_mode_unless_asked():
    rule = _skill_section("Code → review → fix → review → report → done")
    _assert_has(
        rule,
        "In fast mode REVIEW② is skipped unless Jonathan asks for it",
        "code → review → fix → report → done",
        "not re-reviewed after fixing",
        "REVIEW②'s findings are still never fixed",
    )


def test_review2_step_is_optional_in_fast_mode():
    titles = h.headings(_skill(), 3)
    review2 = next(t for t in titles if t.startswith("9 · REVIEW②"))
    assert "fast mode: only if Jonathan asks" in review2
    _assert_has(_skill_section("8 · MERGE→dev ②"), "In fast mode TEST② runs only if Jonathan asked")


def test_report_template_has_mode_and_not_re_reviewed_line():
    text = h.read(REPORT_TEMPLATE)
    _assert_has(text, "**Mode:** full / fast", "estimated {estimate} · actual {actual}")
    stopped = h.section(text, "Stopped for Jonathan", prefix=True)
    _assert_has(
        stopped,
        "Fast mode, REVIEW② skipped",
        "code → review → fix → report",
        "**the FIX① fixes were not re-reviewed after fixing.**",
        "not re-reviewed after fixing",
    )


def test_skill_report_step_names_the_not_re_reviewed_line():
    _assert_has(
        _skill_section("10 · REPORT"),
        "the FIX① fixes were not re-reviewed after fixing",
        "the mode",
        "estimate vs the actual time",
    )


# --- full suite once per phase, only in TEST --------------------------------------------


@pytest.mark.parametrize("name", SCOPED_BRIEFS)
def test_scoped_briefs_run_scoped_gates_never_the_full_suite(name):
    brief = _brief(name)
    assert "{gates}" in brief
    assert "{full_gates}" not in brief
    for sentence in _sentences(brief):
        if FULL_SUITE.search(sentence):
            assert NEGATED.search(sentence), f"{name}: {sentence}"


@pytest.mark.parametrize("name", SCOPED_BRIEFS)
def test_scoped_briefs_never_run_next_build(name):
    assert "next build" not in _brief(name)


def test_tester_brief_is_the_only_one_running_the_full_suite_and_build():
    brief = _brief("tester")
    _assert_has(
        brief,
        "run {full_gates}: the full suite with coverage",
        "then the build (`next build` for a TypeScript / Next.js repo",
        "The tester is the only agent that runs the full suite and the build",
    )


def test_briefs_define_scoped_and_full_gates():
    intro = h.read(BRIEFS).split("## Common preamble")[0]
    _assert_has(
        intro,
        "`{gates}` = the **scoped gates**",
        "`{gates}` never includes the full test suite or the build",
        "`{full_gates}` = the full suite with coverage, then the build",
        "only the tester runs it, once per TEST phase",
    )


def test_skill_build_and_merge_steps_drop_the_full_suite():
    build = _skill_section("3 · BUILD")
    merge = _skill_section("4 · MERGE→dev ①")
    assert "(lint, type-check, the full test suite)" not in build
    assert "run the full\ngates" not in merge and "run the full gates" not in _flat(merge)
    _assert_has(build, "Coders never run the full suite or the build")
    _assert_has(merge, "run the scoped gates once", "never the full suite or the build")
    _assert_has(
        _skill_section("5 · TEST①"),
        "This is the only place in a phase where the full suite and the build run.",
    )


def test_speed_rules_state_the_full_suite_rule():
    _assert_has(
        _skill_section("Speed rules"),
        "The full suite runs once per phase, in TEST.",
        "None of them runs the full test suite or the build.",
    )


def test_stack_routing_keeps_next_build_in_test_only():
    text = h.read(STACK_ROUTING)
    _assert_has(
        text,
        "`next build` (TEST only: coder, fixer, integrator and merger gates stop after the linter",
        "Only the tester runs `test` (the full suite, with coverage) and `build`",
    )


def test_stack_scout_reports_related_and_build_gates_and_fast_fit():
    _assert_has(
        _brief("stack-scout"),
        "gates{lint,types,related,test,build}",
        "fast_fit{urgent, small, why,",
        "gates.related is the command that runs only the tests related to a list of files",
    )


# --- integrator + merger fold -----------------------------------------------------------


def test_integrator_merger_brief_does_both_merges_and_gates_once():
    brief = _brief("integrator-merger")
    _assert_has(
        brief,
        "There is a single branch to merge",
        "run the gates ONCE",
        "`git merge --no-ff origin/{branch}`",
        "merge origin/dev into {integration}",
        "git merge --no-ff {integration}",
        "git push origin HEAD:dev",
        f"{CLEANUP_HELPER} --repo {{run_worktree}} --branch <branch> --target origin/{{integration}}",
        "Don't delete {integration}: CLEANUP does",
        "never squash",
    )
    assert len(re.findall(r"\bgates\b", brief.split("3. ", 1)[0])) <= 1, "gates run before step 3"


def test_skill_folds_integrator_and_merger_for_one_branch():
    _assert_has(
        _skill_section("Speed rules"),
        "When a step leaves a single branch to merge",
        "one **integrator-merger** merges it into the run branch and then the run branch into `dev`",
        "runs the gates once",
    )
    _assert_has(
        _skill_section("3 · BUILD"),
        "When the last wave is a single story branch, don't dispatch an integrator",
    )
    _assert_has(_skill_section("7 · FIX①"), "When FIX① leaves a single fix branch")


def test_integrator_merger_brief_follows_the_merger_brief():
    titles = h.headings(h.read(BRIEFS), 2)
    names = [t.split(" (")[0] for t in titles]
    assert names.index("integrator-merger") > names.index("merger")
    assert names.index("planner-coder") > names.index("coder")


# --- deps by interface -------------------------------------------------------------------


def test_speed_rules_build_deps_against_planned_interfaces():
    _assert_has(
        _skill_section("Speed rules"),
        "**Deps by interface.**",
        "When every dep of a story has a planned, stated interface, that story builds in the "
        "**same wave**",
        "its coder stubs or mocks it",
        "the integrator merges deps first",
        "Only a dep whose interface is truly unplannable (`plannable: false`)",
    )


def test_splitter_and_planner_state_the_interface():
    _assert_has(
        _brief("splitter"),
        "state the interface this story consumes from it",
        '"unplannable: <why>"',
        "both stories build in the same wave",
        "interfaces[{dep, contract, plannable}]",
    )
    _assert_has(
        _brief("planner"),
        "7. Interfaces provided",
        "the exact contract it consumes",
        "same wave",
        "interfaces[{consumer, contract, plannable}]",
    )


def test_coder_and_integrator_honour_the_interface():
    _assert_has(
        _brief("coder"),
        "build against the contract in the dep's plan",
        "stub or mock it in your tests",
        "The integrator merges deps first.",
    )
    _assert_has(_brief("integrator"), "deps before the stories that consume them")


def test_build_readiness_is_by_interface_not_by_merged_deps_only():
    _assert_has(
        _skill_section("3 · BUILD"),
        "A story is ready when each of its deps is merged into the run branch or has a planned "
        "interface (`plannable: true`)",
        "only an unplannable dep holds a story for the next wave",
    )
    _assert_has(
        _skill_section("Orchestrator discipline"),
        "A story is ready when every one of its `deps` is merged or has a planned, stated interface",
    )
    story = _bmn_json_schema()["stories"][0]
    assert story["interfaces"] == [
        {"dep": "<slug>", "contract": "<what this story consumes>", "plannable": True}
    ]


def test_orchestrator_no_longer_waits_on_every_unmet_dep():
    assert "Stories without unmet `deps` build in" not in _skill()


# --- time estimate and speed on request --------------------------------------------------


def test_first_phase_line_states_a_time_estimate():
    _assert_has(
        _skill_section("Silence"),
        "the first one states the mode and an up-front time estimate",
        "a one-line acknowledgement when Jonathan asks for speed",
    )
    _assert_has(
        _skill_section("Speed rules"),
        "**Up-front time estimate.**",
        "first phase line states the mode and a rough wall-clock estimate",
        "`bmn.json.estimate`",
    )


def test_speed_on_request_messages_in_flight_agents():
    _assert_has(
        _skill_section("Speed rules"),
        "**Speed on request.**",
        "sends every in-flight agent a message (load `SendMessage` with ToolSearch)",
        "skip non-essential gates",
        "Never skipped: the agent's own red → green tests, the type-check, the TEST phase's "
        "full suite, and every hard line.",
    )
    preamble = h.code_blocks(h.section(h.read(BRIEFS), "Common preamble"))[0][1]
    _assert_has(
        preamble,
        "Jonathan asked for speed, skip the non-essential gates it names",
        "Never skip your own red → green tests, the type-check, or any rule above.",
    )


# --- plugin.json ---------------------------------------------------------------------------


def test_plugin_description_mentions_fast_mode():
    description = json.loads(h.read(PLUGIN_JSON))["description"]
    _assert_has(
        description,
        "Fast mode for ASAP, hotfix or small runs",
        "the re-review only if Jonathan asks",
        "the full suite and the build run once, in TEST",
    )
