"""Topic tests for ``references/nextjs/testing-and-observability.md`` (rule prefix ``TEST``).

The generic contract (section order, rule format, citations, floors, Sources, line cap) is
enforced for every non-stub topic by ``test_nextjs_reference.py``. These tests assert what only
this topic owes: it is no longer a stub, it is deep enough, it carries the required concepts and
examples, and its error-handling and test-surface rules say what the Next.js docs say.

Offline, standard library plus pytest. Parsing lives in ``nextjs_doc_helpers``.
"""

import re
from functools import cache

import nextjs_doc_helpers as h

TOPIC = h.TOPICS_DIR / "testing-and-observability.md"

MIN_RULES = 15
MIN_CHECKLIST_ITEMS = 8
MIN_ANTI_PATTERNS = 3
MIN_DO_BLOCKS_PER_ANTI_PATTERN = 2

TERMS = (
    "vitest",
    "@vitejs/plugin-react",
    "jsdom",
    "async Server Components",
    "next/jest",
    "playwright",
    "webServer",
    "next build",
    "next start",
    "instrumentation.ts",
    "register",
    "onRequestError",
    "@vercel/otel",
    "instrumentation-client",
    "error.tsx",
    "global-error.tsx",
    "not-found.tsx",
    "'use client'",
    "expected errors",
    "useReportWebVitals",
    "logging",
)

# The gate commands stack-routing.md's TypeScript row names; this file must state the same ones.
GATE_COMMANDS = ("tsc --noEmit", "eslint .", "next build")

OTHER_TOPIC_RULE_TOKEN_RE = re.compile(r"\*\*(?:TS|RT|RC|DF|API|SSE|SEC|PERF)-\d+\*\*")
OWN_RULE_ID_RE = re.compile(r"^TEST-\d+$")
ANY_TYPE_RE = re.compile(r":\s*any\b|<any>|\bas any\b|any\[\]")
TESTING_GUIDE_LINK_RE = re.compile(r"https://nextjs\.org/docs/app/guides/testing")
DO_LINE_RE = re.compile(r"^\*\*Do:\*\*", re.MULTILINE)
TS_LANGS = ("ts", "tsx")


@cache
def _text():
    return h.read(TOPIC)


def _rules_section():
    return h.section(_text(), "Rules")


def _ts_blocks():
    return h.code_blocks(_text(), TS_LANGS)


# --- AC2: not a stub, deep enough --------------------------------------------------------------


def test_topic_file_is_not_a_stub():
    assert h.is_stub(_text()) is False


def test_topic_file_has_at_least_15_test_rules():
    assert len(h.rule_items(_text())) >= MIN_RULES


# --- AC1: only this topic's rule ids ---------------------------------------------------------


def test_rule_ids_use_only_the_test_prefix():
    ids = [rule_id for rule_id, _ in h.rule_items(_text())]
    assert ids, "no rules to check"
    bad = [rule_id for rule_id in ids if not OWN_RULE_ID_RE.match(rule_id)]
    assert not bad, f"rule ids outside the TEST prefix: {bad}"
    assert OTHER_TOPIC_RULE_TOKEN_RE.search(_text()) is None


# --- AC3: required concepts ---------------------------------------------------------------------


def test_required_terms_are_present():
    assert h.missing_terms(_text(), TERMS) == []


# --- AC4: examples ------------------------------------------------------------------------------


def test_has_vitest_config_example():
    assert h.has_block_with(_text(), "defineConfig", "jsdom")


def test_has_playwright_config_example():
    assert h.has_block_with(_text(), "defineConfig", "webServer")


def test_has_instrumentation_example():
    assert h.has_block_with(_text(), "register", "onRequestError")


def test_has_global_error_example():
    assert h.has_block_with(_text(), "'use client'", "<html", "<body")


def test_has_segment_error_boundary_example():
    # The global-error block also holds 'use client' and digest, so it is excluded by <html.
    segment = [
        body
        for _, body in _ts_blocks()
        if "'use client'" in body and "digest" in body and "retry" in body and "<html" not in body
    ]
    assert segment, "no error.tsx example typed with error.digest and retry"


def test_typescript_examples_never_use_any():
    assert _ts_blocks(), "no ts/tsx examples to check"
    offenders = [body.splitlines()[0] for _, body in _ts_blocks() if ANY_TYPE_RE.search(body)]
    assert not offenders, f"ts/tsx blocks that use any: {offenders}"


# --- AC5: test surfaces and the async Server Component limit ---------------------------------------


def test_rules_state_async_server_component_limit_with_testing_guide_link():
    rules = _rules_section()
    assert "async Server Components" in rules
    assert TESTING_GUIDE_LINK_RE.search(rules), "no link to the nextjs.org testing guides"


def test_rules_map_onto_bmn_test_surfaces():
    rules = _rules_section()
    assert "../stack-routing.md" in rules
    assert "unit" in rules and "browser" in rules
    playwright_rules = [item for _, item in h.rule_items(_text()) if "Playwright" in item]
    assert any("async Server Components" in item for item in playwright_rules), (
        "a Playwright rule must say it covers async Server Components"
    )


def test_gate_commands_agree_with_stack_routing():
    stack_routing = h.read(h.REFERENCES_DIR / "stack-routing.md")
    for command in GATE_COMMANDS:
        assert command in stack_routing, f"stack-routing.md no longer names {command!r}"
        assert command in _rules_section(), f"## Rules does not state the gate {command!r}"


# --- AC6: expected errors versus error boundaries ----------------------------------------------


def test_rules_separate_expected_errors_from_global_error():
    rules = _rules_section()
    assert "expected errors" in rules
    assert "global-error" in rules
    assert "<html>" in rules and "<body>" in rules, "global-error must be said to render both"


# --- AC7: version notes -------------------------------------------------------------------------


def test_version_notes_name_the_major_and_link_nextjs():
    major = h.major(h.as_of_version(_text()))
    notes = h.section(_text(), "Version notes")
    assert notes.strip(), "## Version notes is empty"
    assert f"Next.js {major}" in notes
    assert "https://nextjs.org/" in notes


# --- AC8: reviewer-ready ---------------------------------------------------------------------------


def test_every_review_checklist_item_names_a_rule():
    lines = h.section(_text(), "Review checklist").splitlines()
    items = [line for line in lines if line.lstrip().startswith("- [ ]")]
    assert len(items) >= MIN_CHECKLIST_ITEMS
    unnamed = [line[:70] for line in items if "TEST-" not in line]
    assert not unnamed, f"checklist items without a TEST-<n> rule: {unnamed}"


def test_every_anti_pattern_pairs_dont_with_do():
    antis = h.anti_patterns(_text())
    assert len(antis) >= MIN_ANTI_PATTERNS
    for title, body in antis:
        assert DO_LINE_RE.search(body), f"{title!r} has no **Do:** line"
        blocks = h.code_blocks(body)
        assert len(blocks) >= MIN_DO_BLOCKS_PER_ANTI_PATTERN, (
            f"{title!r} needs a Don't block and a Do block, found {len(blocks)}"
        )


def test_gate_scripts_example_uses_eslint_never_next_lint():
    gate_blocks = [body for lang, body in h.code_blocks(_text(), ("json",)) if '"e2e"' in body]
    assert gate_blocks, "no json block with the gate scripts"
    assert any('"lint": "eslint ."' in body for body in gate_blocks)
    assert not any("next lint" in body for body in gate_blocks)
