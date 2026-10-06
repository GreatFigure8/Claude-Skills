"""Text-presence tests for the 2.0.0 eight-step flow and the speed rules it keeps.

2.0.0 runs every story through eight steps, each once: 1 SPRINT (intake, the UI design pick,
split) → 2 PLAN → 3 CODE → 4 TEST with one code review beside it → 5 FIX → 6 TEST (failures
reported, never fixed) → 7 REPORT → 8 RELEASE? (Jonathan decides). The design pick and the
release decision are the only questions. A yes runs the whole release in a fixed order and
leaves `dev` and `main` on the same commit; nothing is committed after `main` moves. Fast mode,
the planner-coder, the integrator and the second review are gone. The speed rules from 1.8.0
stay: scoped gates, deps by interface, one merger per step with gates run once, an up-front
time estimate and speed on request. These tests pin where SKILL.md, briefs.md,
stack-routing.md, report-template.md, the worker agent and plugin.json say so. Section lookup
is by heading text so the tests survive line shifts. Offline, standard library plus pytest;
nothing here runs a helper script.
"""

import json
import re

import nextjs_doc_helpers as h
import pytest

SKILL_DIR = h.PLUGIN / "skills" / "dev-bother-me-nope"
SKILL = SKILL_DIR / "SKILL.md"
REFERENCES = SKILL_DIR / "references"
BRIEFS = REFERENCES / "briefs.md"
STACK_ROUTING = REFERENCES / "stack-routing.md"
REPORT_TEMPLATE = REFERENCES / "report-template.md"
MOVE_COMPUTERS = REFERENCES / "move-computers.md"
DEPLOY_GUARDS = REFERENCES / "deploy-guards.md"
NEXTJS = REFERENCES / "nextjs.md"
WORKER = h.PLUGIN / "agents" / "bmn-worker.md"
PLUGIN_JSON = h.PLUGIN / ".claude-plugin" / "plugin.json"
FLOW_DOCS = (
    SKILL, BRIEFS, STACK_ROUTING, REPORT_TEMPLATE, MOVE_COMPUTERS, DEPLOY_GUARDS, NEXTJS, WORKER,
    PLUGIN_JSON,
)

STEPS = (
    ("1", "SPRINT"), ("2", "PLAN"), ("3", "CODE"), ("4", "TEST"),
    ("5", "FIX"), ("6", "TEST"), ("7", "REPORT"), ("8", "RELEASE?"),
)
STEP_PHASES = {
    "Step 1 · SPRINT": "(`intake` → `design` → `split`)",
    "Step 2 · PLAN": "(`plan`;",
    "Step 3 · CODE": "(`code`;",
    "Step 4 · TEST① ∥ REVIEW": "(`test1`;",
    "Step 5 · FIX": "(`fix`;",
    "Step 6 · TEST②": "(`test2`;",
    "Step 7 · REPORT": "(`report`;",
    "Step 8 · RELEASE?": "(`decision`)",
}
PHASES = "intake|design|split|plan|code|test1|fix|test2|report|decision|done|blocked"
BRIEF_NAMES = (
    "stack-scout", "designer", "splitter", "planner", "coder", "merger", "db-sync", "tester",
    "reviewer", "fixer", "cleaner", "release-prep",
)
RELEASE_ORDER = (
    "**Preflight", "**Supabase MAIN**", "**Release commit", "**Main and tag**", "**Sync dev**",
    "**Vercel production.**", "**GitHub release**", "**Smoke check", "**Done.**",
)
CHECKLIST_ORDER = (
    "Preflight", "Supabase **main**", "Release commit", "`dev` → `main`", "Sync",
    "Vercel production", "GitHub release", "Smoke check",
)
REMOVED = re.compile(
    r"[Ff]ast mode|planner-coder|\bintegrator|REVIEW[①②]|FIX[①②]|MERGE→dev|\brun branch",
    re.IGNORECASE,
)
SCOPED_BRIEFS = ("coder", "fixer", "merger")
CLEANUP_HELPER = "python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py"
FULL_SUITE = re.compile(r"full (?:test )?suite", re.IGNORECASE)
NEGATED = re.compile(r"\bnever\b|\bnot\b|\bnone\b|\bonly\b|\bno\b", re.IGNORECASE)
COMMITS = re.compile(r"\bgit commit\b|\bCommit `|HEAD:dev\b|\bpush `?dev\b")


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
    """The code block of the brief headed ``## <name> (…)``."""
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


def _diagram():
    return h.code_blocks(_skill())[0][1]


def _release_items():
    return h.numbered_items(_skill_section("RELEASE (after Jonathan's yes"))


def _in_order(text, needles):
    flat = _flat(text)
    positions = [flat.find(_flat(needle)) for needle in needles]
    assert -1 not in positions, [n for n, p in zip(needles, positions) if p == -1]
    return positions == sorted(positions)


# --- the eight steps -------------------------------------------------------------------


def test_diagram_lists_the_eight_steps_in_order():
    rows = [line.split()[:2] for line in _diagram().splitlines() if line.strip()]
    assert [tuple(row) for row in rows] == list(STEPS)


def test_diagram_marks_only_the_design_pick_and_the_decision_as_manual():
    manual = [line for line in _diagram().splitlines() if "[manual:" in line]
    assert len(manual) == 2
    assert manual[0].startswith("1 SPRINT") and "design pick" in manual[0]
    assert manual[1].startswith("8 RELEASE?") and "the decision" in manual[1]


def test_diagram_runs_the_review_beside_the_first_test():
    test1 = next(line for line in _diagram().splitlines() if line.startswith("4 TEST"))
    _assert_has(test1, "full tests ∥ one code review")
    test2 = next(line for line in _diagram().splitlines() if line.startswith("6 TEST"))
    _assert_has(test2, "whatever still fails is reported, not fixed")


def test_procedure_has_one_heading_per_step_in_order_then_release():
    titles = h.headings(h.section(_skill(), "Procedure"), 3)
    steps = [t for t in titles if t.startswith("Step ")]
    assert [s.split(" ")[1] for s in steps] == [number for number, _ in STEPS]
    for title, prefix in zip(steps, STEP_PHASES):
        assert title.startswith(prefix), (title, prefix)
    assert titles[-1].startswith("RELEASE (after Jonathan's yes")
    assert titles.index(steps[-1]) == len(titles) - 2


@pytest.mark.parametrize("heading", STEP_PHASES)
def test_each_step_heading_names_its_phase(heading):
    title = next(t for t in h.headings(_skill(), 3) if t.startswith(heading))
    assert STEP_PHASES[heading] in title, title


def test_bmn_json_phases_follow_the_steps_and_release_is_not_one():
    schema = _bmn_json_schema()
    assert schema["phase"] == PHASES
    assert "release" not in schema["phase"].split("|")
    assert schema["release"]["status"] == "pending|declined|released|failed"


def test_each_step_runs_once():
    _assert_has(
        _skill(),
        "**Each step runs once.** There is one code review (in step 4), one fix round (step 5) "
        "and one re-test (step 6).",
        "Nothing loops \"until clean\", no verifier agent re-checks a finding",
        "nothing step 6 finds is fixed",
    )


def test_resume_never_fixes_again_after_test2_and_maps_old_phases():
    _assert_has(
        _skill(),
        "Phases only move forward in enum order; a run resumed at `test2` or later never fixes "
        "again.",
        "A run from before 2.0.0 maps its old phase first",
    )


def test_briefs_table_maps_every_brief_to_its_step():
    rows = h.table_rows(h.read(BRIEFS).split("## Common preamble")[0])
    table = {row[0]: row[1] for row in rows[1:]}
    assert list(table) == [
        "1 SPRINT", "2 PLAN", "3 CODE", "4 TEST①", "5 FIX", "6 TEST②", "7 REPORT", "8 RELEASE",
    ]
    assert table["4 TEST①"] == "tester, reviewer (same message)"
    named = {name.strip() for cell in table.values() for name in re.split(r",|\(", cell)}
    for brief in BRIEF_NAMES:
        assert brief in named, brief


def test_briefs_file_has_exactly_the_current_briefs():
    titles = [t.split(" (")[0] for t in h.headings(h.read(BRIEFS), 2)]
    assert titles[0] == "Common preamble"
    assert sorted(titles[1:]) == sorted(BRIEF_NAMES)


def test_worker_agent_lists_the_current_briefs():
    head = h.read(WORKER).split("---")[1]
    listed = re.search(r"runs one brief \(([^)]*)\)", head).group(1)
    assert sorted(name.strip() for name in listed.split(",")) == sorted(BRIEF_NAMES)


@pytest.mark.parametrize("path", FLOW_DOCS, ids=lambda path: path.name)
def test_removed_concepts_are_gone(path):
    found = sorted({m.group(0) for m in REMOVED.finditer(_flat(h.read(path)))})
    assert not found, f"{path.name}: {found}"


# --- the two questions --------------------------------------------------------------------


def test_jonathan_is_asked_two_things():
    _assert_has(
        _skill(),
        "**Jonathan is asked two things:** which UI design he wants (step 1, only when the story "
        "touches something a person looks at) and whether to release (step 8).",
        "Every other open question is decided here, written down as an assumption, and shipped.",
        "3. **No questions except the two.**",
    )


def test_skill_asks_with_ask_user_question_only_at_the_design_pick_and_the_decision():
    text = _skill()
    assert text.count("AskUserQuestion") == 2
    assert "AskUserQuestion" in _skill_section("Step 1 · SPRINT").split("**1c · SPLIT")[0]
    assert "AskUserQuestion" in _skill_section("Step 8 · RELEASE?")


def test_design_freeze_asks_nothing_until_step_8():
    _assert_has(
        _skill_section("Step 1 · SPRINT"),
        "**From here on the design is fixed and Jonathan is not asked anything until step 8.**",
    )


def test_release_question_has_two_options_and_no_recommendation():
    step = _skill_section("Step 8 · RELEASE?")
    _assert_has(
        step,
        "ask **one** `AskUserQuestion`: \"Release v<next>?\". Two options:",
        "- **Release** —",
        "- **Not now** —",
        "Never mark either option as recommended.",
        "A blocked run (`phase: blocked`) is not asked",
    )


def test_not_now_ends_the_run_and_jonathan_decides_whats_next():
    step = _skill_section("Step 8 · RELEASE?")
    _assert_has(
        step,
        "`release.status: \"declined\"` and `phase: done`",
        "Then **stop**: dispatch nothing, start nothing.",
        "it's Jonathan deciding what's next",
    )
    _assert_has(_skill(), "Any further work is a **new goal, and only Jonathan decides whether there is one**.")


# --- step 4: one review beside the tests; step 5 fixes; step 6 only reports ---------------


def test_step_4_dispatches_testers_and_reviewer_together():
    step = _skill_section("Step 4 · TEST① ∥ REVIEW")
    _assert_has(
        step,
        "then dispatch the testers and the reviewer together",
        "Run `/code-review` at `high` on the whole run's diff",
        "`git diff {dev_base}...{test1_sha}`",
    )
    _assert_has(_skill_section("Speed rules"), "**Review beside test.**")


def test_reviewer_brief_is_the_one_review():
    _assert_has(
        _brief("reviewer"),
        "This is the run's ONE code review",
        "no verifier agent re-checks you and no second review follows",
        "Run /code-review at high effort, never max or ultra",
    )


def test_step_5_fixes_findings_and_test1_failures_reproduced_first():
    _assert_has(
        _skill_section("Step 5 · FIX"),
        "Input: every review finding, every severity, plus every TEST① failure",
        "reproduces each item as a failing test",
        "One attempt per fixer, no retry loop.",
    )


def test_clean_review_and_green_test1_skip_fix_and_retest():
    _assert_has(
        _skill_section("Step 4 · TEST① ∥ REVIEW"),
        "When the review found nothing and TEST① was green, skip steps 5 and 6: set "
        "`phase: report`.",
    )


def test_step_6_failures_go_to_the_report_and_are_never_fixed():
    _assert_has(
        _skill_section("Step 6 · TEST②"),
        "**Nothing TEST② finds is fixed.**",
        "goes straight to the report under *Left open*",
    )
    _assert_has(_brief("tester"), "TEST2 adds no tests and fixes nothing.")
    _assert_has(h.read(REPORT_TEMPLATE), "## Left open — not fixed by this run")


# --- the release ------------------------------------------------------------------------


def test_release_runs_its_steps_in_order():
    items = _release_items()
    assert len(items) == len(RELEASE_ORDER)
    for item, lead in zip(items, RELEASE_ORDER):
        assert _flat(item).split(" ", 1)[1].startswith(lead), (lead, item[:60])


def test_release_migrates_supabase_main_before_main_moves():
    _assert_has(
        _skill_section("RELEASE (after Jonathan's yes"),
        "nothing reaches `main` until the database is ready for it",
    )
    supabase = _release_items()[1]
    _assert_has(supabase, "`main` is untouched", "every migration on dev is on main")


def test_release_preflight_checks_main_and_the_tested_sha():
    preflight = _release_items()[0]
    _assert_has(
        preflight,
        "`git log --oneline origin/dev..origin/main` is empty",
        "`dev`'s code is what TEST② tested",
        "`gh auth status`, `vercel whoami`",
        "`vercel env ls production`",
        "the tag `v<next>` doesn't exist yet",
        "Any problem stops the release before anything changes",
    )


def test_release_commit_is_the_last_commit_and_marks_the_run_done():
    commit = _release_items()[2]
    _assert_has(
        commit,
        "write `bmn.json` with `phase: done` and `release: {status: \"released\"",
        "Commit `release: v<next>` and push `HEAD:dev`",
    )


def test_main_gets_a_no_ff_merge_and_a_tag():
    main = _release_items()[3]
    _assert_has(
        main,
        "git merge --no-ff origin/dev -m \"release: v<next>\"",
        "git tag -a v<next>",
        "BMN_USER_APPROVED_DEPLOY=1 git push origin HEAD:main v<next>",
        "never a squash or a fast-forward of `main`",
    )


def test_dev_is_fast_forwarded_onto_main_and_checked():
    sync = _release_items()[4]
    _assert_has(
        sync,
        "git push origin origin/main:dev",
        "it never forces",
        "`git rev-parse origin/dev origin/main` prints the same sha twice",
        "**`dev` and `main` are now the same commit; nothing is committed to either after this.**",
    )


def test_nothing_is_committed_after_main_moves():
    _assert_has(
        _skill_section("RELEASE (after Jonathan's yes"),
        "nothing is committed to either branch after `main` moves, so `dev` and `main` end on "
        "the same commit",
    )
    for item in _release_items()[3:]:
        assert not COMMITS.search(_flat(item).replace("git merge --no-ff origin/dev -m", "")), item
    _assert_has(_release_items()[-1], "never in a new commit, so `dev` and `main` stay in sync")


def test_release_deploy_commands_carry_the_approval_prefix():
    release = _skill_section("RELEASE (after Jonathan's yes")
    _assert_has(
        release,
        "Each deploy command is prefixed with `BMN_USER_APPROVED_DEPLOY=1`.",
        "BMN_USER_APPROVED_DEPLOY=1 supabase link --project-ref <main_ref> && "
        "BMN_USER_APPROVED_DEPLOY=1 supabase db push --linked",
        "BMN_USER_APPROVED_DEPLOY=1 vercel deploy --prod",
        "A Vercel MCP deploy tool is never used.",
    )
    for match in re.finditer(r"vercel deploy --prod|supabase db push|HEAD:main", _flat(release)):
        before = _flat(release)[max(0, match.start() - 120) : match.start()]
        assert "BMN_USER_APPROVED_DEPLOY=1" in before, before


def test_release_approval_covers_this_release_only():
    _assert_has(
        _skill_section("RELEASE (after Jonathan's yes"),
        "Jonathan's yes in chat is the approval for every step on the checklist, for this "
        "release only.",
        "the approval doesn't carry over to a later release or another run",
        "A failure after step 4 is reported, never rolled back or retried on its own",
    )


def test_report_checklist_follows_the_release_order():
    checklist = h.section(h.read(REPORT_TEMPLATE), "Release checklist", prefix=True)
    checklist = checklist.split("**Manual items")[0]
    rows = [row for row in h.table_rows(checklist) if row[0].strip().isdigit()]
    assert [row[1] for row in rows] == list(CHECKLIST_ORDER)
    step7 = _skill_section("Step 7 · REPORT")
    assert _in_order(
        step7,
        (
            "the preflight", "the Supabase migrations that will go to **main**",
            "the release commit", "the `dev` → `main` merge and tag",
            "`dev` fast-forwarded onto `main`", "the Vercel production deploy",
            "the GitHub release", "the smoke check",
        ),
    )


def test_release_prep_brief_never_deploys():
    _assert_has(
        _brief("release-prep"),
        "Mode: {mode} (preflight | commit | verify)",
        "You never deploy, never push main, never tag and never touch Supabase MAIN",
    )
    assert "BMN_USER_APPROVED_DEPLOY" not in _brief("release-prep")


# --- full suite once per test step, only by the tester ---------------------------------


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
    _assert_has(
        _brief("tester"),
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
        "only the tester (and the release preflight, when code changed after TEST②) runs it",
    )


def test_speed_rules_state_the_full_suite_rule():
    _assert_has(
        _skill_section("Speed rules"),
        "**The full suite runs once per test step.**",
        "None of them runs the full test suite or the build.",
        "run only in TEST① and TEST②, by the tester (`{full_gates}`)",
    )


def test_code_and_fix_steps_use_the_scoped_gates():
    _assert_has(_skill_section("Step 3 · CODE"), "run the scoped gates")
    _assert_has(_skill_section("Step 5 · FIX"), "runs the scoped gates", "gates once")
    _assert_has(
        _skill_section("Step 4 · TEST① ∥ REVIEW"),
        "the full `pytest` (or `vitest`/`jest`) run, plus coverage, plus the build",
    )


def test_stack_routing_keeps_next_build_in_test_only():
    _assert_has(
        h.read(STACK_ROUTING),
        "`next build` (TEST only: coder, fixer and merger gates stop after the linter",
        "Only the tester runs `test` (the full suite, with coverage) and `build`",
    )


def test_stack_scout_reports_related_and_build_gates():
    _assert_has(
        _brief("stack-scout"),
        "gates{lint,types,related,test,build}",
        "gates.related is the command that runs only the tests related to a list of files",
    )


# --- one merger per step, gates once ---------------------------------------------------


def test_speed_rules_have_one_merger_per_step_with_gates_once():
    _assert_has(
        _skill_section("Speed rules"),
        "**One merge agent per step, gates once.** Steps 3 and 5 each end with a single merger.",
        "runs the scoped gates **once** over the combined change",
        "reverts branch by branch to find the one that broke them",
    )


def test_merger_brief_merges_into_the_sprint_branch_then_dev_with_gates_once():
    brief = _brief("merger")
    _assert_has(
        brief,
        "Merge these branches into {integration}, then {integration} into dev, running the gates "
        "ONCE.",
        "Branches, deps first: {branches}",
        "`git merge --no-ff origin/<branch>`",
        "merge origin/dev into {integration}",
        "git merge --no-ff {integration}",
        "git push origin HEAD:dev",
        f"{CLEANUP_HELPER} --repo {{run_worktree}} --branch <branch> --target origin/{{integration}}",
        "Don't delete {integration}: CLEANUP does",
        "never squash",
    )
    assert len(re.findall(r"\bgates\b", brief.split("3. ", 1)[0])) <= 2, "gates run before step 3"


# --- deps by interface -------------------------------------------------------------------


def test_speed_rules_build_deps_against_planned_interfaces():
    _assert_has(
        _skill_section("Speed rules"),
        "**Deps by interface.**",
        "When every dep of a story has a planned, stated interface, that story builds in the "
        "**same wave**",
        "its coder stubs or mocks it",
        "the merger merges deps first",
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


def test_coder_builds_against_the_interface():
    _assert_has(
        _brief("coder"),
        "build against the contract in the dep's plan",
        "stub or mock it in your tests",
        "The merger merges deps first.",
    )


def test_build_readiness_is_by_interface_not_by_merged_deps_only():
    _assert_has(
        _skill_section("Orchestrator discipline"),
        "A story is ready when every one of its `deps` is merged or has a planned, stated interface",
    )
    story = _bmn_json_schema()["stories"][0]
    assert story["interfaces"] == [
        {"dep": "<slug>", "contract": "<what this story consumes>", "plannable": True}
    ]


# --- time estimate and speed on request --------------------------------------------------


def test_bmn_json_records_estimate_and_speed_but_no_mode():
    schema = _bmn_json_schema()
    assert "estimate" in schema
    assert "mode" not in schema
    assert schema["speed"] == {"requested": False, "skipped_gates": []}


def test_first_step_line_states_a_time_estimate():
    _assert_has(
        _skill_section("Silence"),
        "the first one states the story count, the waves and a time estimate",
        "a one-line acknowledgement when Jonathan asks for speed",
    )
    _assert_has(
        _skill_section("Speed rules"),
        "**Up-front time estimate.**",
        "first step line states the story count, the waves and a rough wall-clock estimate",
        "`bmn.json.estimate`",
    )
    _assert_has(h.read(REPORT_TEMPLATE), "**Time:** estimated {estimate} · actual {actual}")


def test_speed_on_request_messages_in_flight_agents():
    _assert_has(
        _skill_section("Speed rules"),
        "**Speed on request.**",
        "sends every in-flight agent a message (load `SendMessage` with ToolSearch)",
        "skip non-essential gates",
        "Never skipped: the agent's own red → green tests, the type-check, the test steps' full "
        "suite, and every hard line.",
    )
    preamble = h.code_blocks(h.section(h.read(BRIEFS), "Common preamble"))[0][1]
    _assert_has(
        preamble,
        "Jonathan asked for speed, skip the non-essential gates it names",
        "Never skip your own red → green tests, the type-check, or any rule above.",
    )


# --- plugin.json ---------------------------------------------------------------------------


def test_plugin_description_names_the_eight_steps_and_the_release():
    description = json.loads(h.read(PLUGIN_JSON))["description"]
    _assert_has(
        description,
        "Eight-step build pipeline",
        "4 test (full suite plus headless Playwright) with one code review beside it",
        "6 test again (whatever still fails is reported, never fixed)",
        "8 Jonathan decides: release?",
        "dev fast-forwarded so dev and main are the same commit",
        "The design pick and the release decision are the only questions.",
        "the full suite and the build run only in the test steps",
    )
