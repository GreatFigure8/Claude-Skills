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


# --- FIX①: REVIEW① findings R1-C7, R1-C9, R1-C18, R1-C19, R1-C29, R1-C30, R1-C31 --------------------


def _rule(rule_id: str) -> str:
    for found_id, item in h.rule_items(_text()):
        if found_id == rule_id:
            return item
    raise AssertionError(f"{rule_id} is not in ## Rules")


def _block(*needles: str) -> str:
    """The first ts/tsx fence that holds every needle."""
    for _, body in _ts_blocks():
        if all(needle in body for needle in needles):
            return body
    raise AssertionError(f"no ts/tsx block holds {needles}")


def test_vitest_coverage_excludes_what_test_2_and_test_10_keep_off_the_unit_surface():
    # R1-C7: include src/** with an 80% floor counted async pages, layouts, instrumentation and
    # 'use server' files at 0%, so a typical App Router story could never pass TEST-37.
    config = _block("defineConfig", "jsdom")
    assert "exclude:" in config, "the coverage config has no exclude list"
    excluded = config[config.index("exclude:") :].split("]", 1)[0]
    for needle in ("page", "layout", "instrumentation", "lib/actions", "*.d.ts", "generated"):
        assert needle in excluded, f"coverage.exclude does not cover {needle!r}"
    assert "coverage.exclude" in _rule("TEST-7")


def test_playwright_config_gives_each_checkout_its_own_port():
    # R1-C18: a shared default port (3100) defeated TEST-13 in every worktree.
    configs = [
        body for _, body in _ts_blocks() if "webServer" in body and "npm run dev" not in body
    ]
    assert configs, "no Playwright config examples"
    for body in configs:
        shared = re.findall(r"\?\?\s*\d{4}|-p\s+\d{4}|localhost:\d{4}", body)
        assert not shared, f"a Playwright config hard-codes a port: {shared}"
    main = _block("defineConfig", "webServer", "E2E_PORT")
    assert "process.cwd()" in main, "no per-checkout fallback port"
    assert "E2E_PORT" in _rule("TEST-13")


def test_playwright_reuses_an_existing_server_only_on_request():
    # R1-C18: reuseExistingServer: !process.env.CI attaches to another checkout or a stale build.
    for _, body in _ts_blocks():
        assert not re.search(r"reuseExistingServer:\s*!process\.env\.CI\s*[,}]", body)
    assert "E2E_REUSE_SERVER" in _block("defineConfig", "webServer", "E2E_PORT")
    assert "E2E_REUSE_SERVER" in _rule("TEST-13")


def test_on_request_error_example_redacts_the_message_and_guards_the_reporter():
    # R1-C19: the pattern posted raw err.message and awaited fetch with no try/catch or timeout.
    block = _block("onRequestError", "register")
    assert ".message" not in block, "the reporter must not send err.message"
    assert "request.headers" not in block and "request.path" not in block
    assert "try {" in block and "catch" in block, "the reporter call is not in a try/catch"
    assert "AbortSignal.timeout" in block, "the reporter call has no timeout"
    rule = _rule("TEST-28")
    assert "err.message" in rule and "try/catch" in rule and "timeout" in rule


def test_unstable_rethrow_example_renders_the_post_it_loaded():
    # R1-C29: the awaited result was discarded, so success rendered "unavailable" too.
    block = _block("unstable_rethrow", "export default async function Page")
    assert re.search(r"=\s*await\s+load\w+\(\)", block), "the loaded value is discarded"
    unavailable = [line for line in block.splitlines() if "unavailable" in line]
    assert unavailable and all("if (" in line for line in unavailable), (
        "'unavailable' must render only when the load failed"
    )


def test_log_error_spreads_caller_fields_before_the_reserved_keys():
    # R1-C30: ...fields came last, so a caller could overwrite errorId and level.
    block = _block("logError", "console.error")
    spread = block.index("...fields")
    for reserved in ("level: 'error'", "message,", "errorId,", "errorType:"):
        assert spread < block.index(reserved), f"...fields must come before {reserved!r}"


def test_web_vitals_reporter_is_owned_by_perf_26_and_not_copied():
    # R1-C31: the WebVitals component and rule lived here and in performance-and-vercel.md.
    assert not [body for _, body in _ts_blocks() if "useReportWebVitals" in body]
    assert "WebVitals component" not in h.section(_text(), "Patterns")
    rule = _rule("TEST-32")
    assert "(performance-and-vercel.md)" in rule and "`PERF-26`" in rule
    assert "useReportWebVitals" in rule


def test_snippets_and_rules_use_the_canonical_src_layout():
    # R1-C9: the nextjs.md layout puts routes under src/app and Server Actions under src/lib/actions.
    text = _text()
    assert not re.search(r"`app/[\w\[(@.-]", text), "a path drops the src/ prefix"
    assert not re.search(r"^### app/", text, re.MULTILINE)
    assert "'../app/" not in text
    actions = [body for _, body in _ts_blocks() if "'use server'" in body.splitlines()[:2]]
    assert actions, "no 'use server' examples"
    assert all(body.startswith("// src/lib/actions/") for body in actions)
    assert "src/lib/actions/" in _rule("TEST-10")
