"""Text-presence tests for how the Next.js reference is wired into the bmn skill.

The reference (``references/nextjs.md``) is read with the Read tool by the planner, coder,
reviewer and fixer of a TypeScript / Next.js story. These tests pin the four places that say so
(``stack-routing.md``, ``SKILL.md``, ``briefs.md`` and the ``plugin.json`` invariants) and that
nothing else in them moved. Section lookup is by heading text so the tests survive line shifts.
Offline, standard library plus pytest.
"""

import hashlib
import json
import re

import nextjs_doc_helpers as h
import pytest

SKILL_DIR = h.PLUGIN / "skills" / "dev-bother-me-nope"
SKILL = SKILL_DIR / "SKILL.md"
BRIEFS = SKILL_DIR / "references" / "briefs.md"
STACK_ROUTING = SKILL_DIR / "references" / "stack-routing.md"
PLUGIN_JSON = h.PLUGIN / ".claude-plugin" / "plugin.json"

NEXTJS_PATH = "${CLAUDE_PLUGIN_ROOT}/skills/dev-bother-me-nope/references/nextjs.md"
SKILL_DESCRIPTION_SHA256 = "ff1c4ebd1232745ee8c4de5a117cc7ee74eb1036ec898fadd708d999a617697c"
PLUGIN_DESCRIPTION_SHA256 = "bbda88acb08a513c0f17ac9243d946ce7c996af61abd86f248a7a903c7358860"
EDITED_BRIEFS = ("planner", "coder", "reviewer", "fixer")
OTHER_BRIEFS = (
    "stack-scout",
    "designer",
    "splitter",
    "integrator",
    "merger",
    "cleaner",
    "db-sync",
    "tester",
)
TYPESCRIPT_ROW = "TypeScript / Next.js repo"


# --- helpers ---------------------------------------------------------------------------


def _flat(text):
    return re.sub(r"\s+", " ", text).strip()


def _assert_has(text, *needles):
    flat = _flat(text)
    missing = [needle for needle in needles if _flat(needle) not in flat]
    assert not missing, f"missing: {missing}"


def _brief(name):
    """Text of the brief's section in briefs.md (heading ``## <name> (…)``)."""
    return h.section(h.read(BRIEFS), f"{name} (", prefix=True)


def _brief_block(name):
    blocks = h.code_blocks(_brief(name))
    assert blocks, f"no code block in the {name} brief"
    return blocks[0][1]


def _table_row(section_text, first_cell):
    rows = [row for row in h.table_rows(section_text) if row[0].startswith(first_cell)]
    assert len(rows) == 1, f"expected one row starting {first_cell!r}, found {len(rows)}"
    return rows[0]


def _frontmatter_description(text):
    head = text.split("---\n")[1]
    line = next(line for line in head.splitlines() if line.startswith("description:"))
    return line.removeprefix("description:").strip()


# --- AC11: stack-routing.md -----------------------------------------------------------------


def test_stack_routing_typescript_row_names_the_reference_in_both_cells():
    row = _table_row(h.section(h.read(STACK_ROUTING), "Route"), TYPESCRIPT_ROW)
    assert len(row) == 3
    assert "references/nextjs.md" in row[1], "Build with cell"
    assert "references/nextjs.md" in row[2], "review lens cell"


def test_stack_routing_keeps_fullstack_standards_when_available():
    row = _table_row(h.section(h.read(STACK_ROUTING), "Route"), TYPESCRIPT_ROW)
    for cell in row[1:]:
        _assert_has(cell, "nextjs-fullstack-standards", "when the session has it")


def test_stack_routing_says_references_are_read_not_loaded():
    route = h.section(h.read(STACK_ROUTING), "Route")
    _assert_has(
        route,
        "read with the Read tool, not loaded with `Skill(...)`",
        "They ship inside this plugin, so they are always available.",
        f"`{NEXTJS_PATH}`",
    )


def test_stack_routing_intro_covers_reference_files():
    intro = h.read(STACK_ROUTING).split("## Classify")[0]
    _assert_has(
        intro,
        'via `Skill({skill: "<name>"})` — and reads every reference file routed here, '
        "**before** writing or judging code.",
    )


def test_stack_routing_never_approximate_sentence_unchanged():
    _assert_has(
        h.read(STACK_ROUTING),
        "If a routed skill isn't in the session's skill list, say so in `stack.md` and continue "
        "with the rest — never approximate a skill from memory.",
    )


def test_stack_routing_test_surfaces_names_typescript_tooling():
    surfaces = h.section(h.read(STACK_ROUTING), "Test surfaces", prefix=True)
    row = _table_row(surfaces, TYPESCRIPT_ROW)
    assert len(row) == 3
    _assert_has(
        row[2],
        "Vitest or Jest",
        "with coverage",
        "Playwright (`@playwright/test`)",
        "`next build && next start`",
        "`fetch`",
        "`tsc --noEmit`",
        "`eslint .`",
        "`next lint` was removed in Next.js 16",
        "`next build`",
        "[nextjs/testing-and-observability.md](nextjs/testing-and-observability.md)",
    )
    for surface in ("unit + integration", "browser", "HTTP black-box", "gates"):
        assert surface in row[1], f"{surface!r} missing from the Surface cell"


def test_stack_routing_test_surfaces_keeps_the_python_rows():
    surfaces = h.section(h.read(STACK_ROUTING), "Test surfaces", prefix=True)
    _assert_has(
        surfaces,
        "`pytest` (+ `pytest-cov`), or the repo's runner",
        "`pytest-playwright`, headless Chromium, app started locally",
        "`httpx` against the running server",
    )


# --- AC12: SKILL.md ---------------------------------------------------------------------------


def test_skill_intake_links_the_nextjs_reference():
    intake = h.section(h.read(SKILL), "0 · INTAKE", prefix=True)
    _assert_has(
        intake,
        "For a TypeScript / Next.js repo the routing also names "
        "[references/nextjs.md](references/nextjs.md), the plugin's dated Next.js + TypeScript "
        "standard. The planner, coder, reviewer and fixer read it with the Read tool "
        "([references/stack-routing.md](references/stack-routing.md)).",
    )


def test_skill_review1_links_the_reference_next_to_fullstack_standards():
    review = h.section(h.read(SKILL), "6 · REVIEW", prefix=True)
    _assert_has(
        review,
        "and for TypeScript `nextjs-fullstack-standards` (when the session has it) plus "
        "[references/nextjs.md](references/nextjs.md), each finding citing the rule id it breaks.",
    )


def test_skill_frontmatter_description_unchanged():
    description = _frontmatter_description(h.read(SKILL))
    assert hashlib.sha256(description.encode()).hexdigest() == SKILL_DESCRIPTION_SHA256


# --- AC13: briefs.md --------------------------------------------------------------------------


@pytest.mark.parametrize("name", EDITED_BRIEFS)
def test_brief_reads_the_nextjs_reference_for_typescript(name):
    block = _brief_block(name)
    assert NEXTJS_PATH in block
    assert "TypeScript/Next.js" in block


@pytest.mark.parametrize("name", ("planner", "reviewer"))
def test_planner_and_reviewer_briefs_ask_for_rule_ids(name):
    assert "rule id" in _brief_block(name)


def test_brief_lines_say_what_each_agent_does_with_the_rule_ids():
    _assert_has(
        _brief_block("planner"),
        f"TypeScript/Next.js story: also read {NEXTJS_PATH} and the topic files its Topic index "
        "routes this story to; list every rule id you apply in the plan's Approach.",
    )
    _assert_has(
        _brief_block("coder"),
        f"TypeScript/Next.js story: follow the rule ids the plan lists from {NEXTJS_PATH} and "
        "its topic files.",
    )
    _assert_has(
        _brief_block("reviewer"),
        f"For TypeScript/Next.js code also read {NEXTJS_PATH} and the topic files it routes the "
        "diff to; a finding that breaks one of its rules cites that rule id (e.g. SEC-3) in its "
        "summary.",
    )
    _assert_has(
        _brief_block("fixer"),
        f"For a TypeScript/Next.js finding, name in validation.md the rule id from {NEXTJS_PATH} "
        "that the fix restores.",
    )


def test_reviewer_brief_keeps_fullstack_standards():
    _assert_has(
        _brief_block("reviewer"),
        "(add nextjs-fullstack-standards for any TypeScript in the diff)",
    )


def test_reviewer_return_json_shape_is_unchanged():
    _assert_has(
        _brief_block("reviewer"),
        "Return JSON: {pass, area, critical:n, high:n, medium:n, low:n, "
        "findings:[{id, sev, file, line, owner, summary}], recheck:[{id, status}] (pass 2 only)}.",
    )


@pytest.mark.parametrize("name", OTHER_BRIEFS)
def test_other_briefs_do_not_mention_the_reference(name):
    assert "nextjs.md" not in _brief(name)


# --- AC14: plugin.json invariants ---------------------------------------------------------------


def test_plugin_json_only_the_version_moved():
    data = json.loads(h.read(PLUGIN_JSON))
    assert set(data) == {"author", "description", "name", "version"}
    assert data["name"] == "dev-bother-me-nope"
    assert data["author"] == {"name": "Jonathan Stevenson"}
    assert hashlib.sha256(data["description"].encode()).hexdigest() == PLUGIN_DESCRIPTION_SHA256
