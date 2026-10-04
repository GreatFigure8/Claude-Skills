"""Topic tests for ``references/nextjs/typescript.md`` (story typescript-config-and-typing-patterns).

The generic contract tests in ``test_nextjs_reference.py`` already enforce the shape of every topic
file (sections, rule format, floors, sources, hygiene). These tests add what only the TypeScript
topic owes: its own rule ids, the terms and patterns the story promises, and the rules that keep
``params``, ``searchParams``, ``any`` and build errors in check.

Offline, standard library plus pytest. Parsing lives in ``nextjs_doc_helpers``.
"""

import re

import nextjs_doc_helpers as helpers
import pytest

TOPIC = helpers.TOPICS_DIR / "typescript.md"
RULE_PREFIX = "TS"
MIN_RULES = 15
MIN_CHECKLIST_ITEMS = 8
MIN_ANTI_PATTERN_PAIRS = 3

OTHER_TOPIC_ID_RE = re.compile(r"\b(?:RT|RC|DF|API|SSE|SEC|PERF|TEST)-\d+\b")
ANY_TYPE_RE = re.compile(r":\s*any\b|<any>|as any\b")
DONT_MARKER = "**Don't**"
DO_MARKER = "**Do**"
FENCE_OPENER = "```"

# The last term keeps its backticks so that words like "many" cannot satisfy it.
TERMS = (
    '"strict": true',
    "noUncheckedIndexedAccess",
    "next-env.d.ts",
    "next.config.ts",
    "NextConfig",
    "typedRoutes",
    "next typegen",
    "PageProps",
    "LayoutProps",
    "RouteContext",
    "searchParams",
    "Promise<",
    "ignoreBuildErrors",
    "safeParse",
    "unknown",
    "satisfies",
    "server-only",
    "NEXT_PUBLIC_",
    "Metadata",
    "`any`",
)


@pytest.fixture(scope="module")
def text() -> str:
    return helpers.read(TOPIC)


def _section(text: str, heading: str) -> str:
    """Body of an H2 section; a missing section fails with a message instead of a crash."""
    try:
        return helpers.section(text, heading)
    except LookupError:
        pytest.fail(f"typescript.md has no '## {heading}' section")


def _anti_pattern_markers(body: str) -> list[tuple[str, bool]]:
    """``(marker, followed_by_a_fence)`` for each Don't/Do marker line outside a fence."""
    lines = body.splitlines()
    markers = []
    in_fence = False
    for index, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith(FENCE_OPENER):
            in_fence = not in_fence
            continue
        if in_fence or stripped not in (DONT_MARKER, DO_MARKER):
            continue
        following = next((later.strip() for later in lines[index + 1 :] if later.strip()), "")
        markers.append((stripped, following.startswith(FENCE_OPENER)))
    return markers


# --- AC1 and AC2: this topic's own rules, and the stub is gone -----------------------------


def test_typescript_topic_uses_only_ts_rule_ids(text):
    ids = [rule_id for rule_id, _ in helpers.rule_items(text)]

    assert ids, "no rules under ## Rules"
    assert ids == [f"{RULE_PREFIX}-{n}" for n in range(1, len(ids) + 1)]
    assert OTHER_TOPIC_ID_RE.search(text) is None


def test_typescript_topic_is_not_a_stub(text):
    assert helpers.is_stub(text) is False


def test_typescript_topic_has_at_least_15_rules(text):
    assert len(helpers.rule_items(text)) >= MIN_RULES


# --- AC3: the promised terms --------------------------------------------------------------


def test_typescript_topic_mentions_every_required_term(text):
    assert helpers.missing_terms(text, TERMS) == []


# --- AC4: the promised code blocks --------------------------------------------------------


def test_typescript_topic_has_strict_tsconfig_json_block(text):
    assert helpers.has_block_with(text, '"strict": true', langs=("json",))


def test_typescript_topic_has_typed_next_config_block(text):
    assert helpers.has_block_with(text, "NextConfig", "typedRoutes")


def test_typescript_topic_has_page_props_block_awaiting_params(text):
    assert helpers.has_block_with(text, "PageProps<'/", "await")


def test_typescript_topic_has_route_context_handler_block(text):
    assert helpers.has_block_with(text, "RouteContext<'/", "await")


def test_typescript_topic_has_safe_parse_boundary_block(text):
    assert helpers.has_block_with(text, "safeParse")


def test_typescript_topic_examples_never_use_any(text):
    blocks = helpers.code_blocks(_section(text, "Patterns"), ("ts", "tsx"))

    assert blocks, "## Patterns holds no ts or tsx block"
    offenders = [body.splitlines()[0] for _, body in blocks if ANY_TYPE_RE.search(body)]
    assert not offenders, f"Patterns blocks that write any: {offenders}"


# --- AC5: async params and generated route helpers ----------------------------------------


def test_typescript_topic_awaits_search_params_in_tsx(text):
    assert helpers.has_block_with(text, "searchParams", "await", langs=("tsx",))


def test_typescript_rules_say_how_route_helpers_are_generated(text):
    rules = _section(text, "Rules")

    missing = [term for term in ("next typegen", "next dev", "next build", "Promise") if term not in rules]
    assert not missing, f"## Rules never mentions: {missing}"


# --- AC6: build errors and any ------------------------------------------------------------


def test_typescript_rules_forbid_ignore_build_errors_and_ban_any(text):
    rules = _section(text, "Rules")

    missing = [term for term in ("ignoreBuildErrors", "unknown", "`any`") if term not in rules]
    assert not missing, f"## Rules never mentions: {missing}"


# --- AC7: version notes -------------------------------------------------------------------


def test_typescript_version_notes_name_major_and_link_nextjs(text):
    version = helpers.as_of_version(text)
    assert version is not None, "no as-of line right after the H1"
    notes = _section(text, "Version notes")

    assert notes.strip()
    assert f"Next.js {helpers.major(version)}" in notes
    assert "https://nextjs.org/" in notes


# --- AC8: checklist and anti-patterns -----------------------------------------------------


def test_typescript_review_checklist_items_cite_rule_ids(text):
    items = [line for line in text.splitlines() if line.startswith("- [ ]")]

    assert len(items) >= MIN_CHECKLIST_ITEMS
    uncited = [item[:60] for item in items if f"{RULE_PREFIX}-" not in item]
    assert not uncited, f"checklist items without a rule id: {uncited}"


def test_typescript_anti_patterns_pair_each_dont_with_a_do(text):
    markers = _anti_pattern_markers(_section(text, "Anti-patterns"))
    kinds = [marker for marker, _ in markers]
    pairs = len(kinds) // 2

    assert pairs >= MIN_ANTI_PATTERN_PAIRS
    assert kinds == [DONT_MARKER, DO_MARKER] * pairs
    unfenced = [marker for marker, has_fence in markers if not has_fence]
    assert not unfenced, f"{len(unfenced)} marker(s) not followed by a fenced block"
    assert len(helpers.anti_patterns(text)) == pairs, "each ### Don't heading holds one pair"


# --- AC9: every source is used ------------------------------------------------------------


def test_typescript_every_source_is_linked_in_the_body(text):
    body, _, _ = text.rpartition("\n## Sources")

    unused = sorted(set(helpers.source_urls(text)) - set(helpers.all_urls(body)))
    assert not unused, f"Sources entries no rule, pattern or note links to: {unused}"
