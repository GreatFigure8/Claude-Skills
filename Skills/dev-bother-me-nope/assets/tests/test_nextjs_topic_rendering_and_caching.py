"""Topic tests for ``references/nextjs/rendering-and-caching.md`` (rule prefix ``RC``).

The generic contract tests in ``test_nextjs_reference.py`` run on this file once it is no longer
a stub. These tests add what this story owns: the file is real and deep, it names every required
concept, it carries the five required examples, it tells the reader to detect the caching model
first, it has the post-write invalidation decision table, and its checklist and anti-patterns
are reviewer-ready. Offline, standard library plus pytest; parsing lives in
``nextjs_doc_helpers``.
"""

import re
from functools import cache

import nextjs_doc_helpers as h
import pytest

TOPIC = h.TOPICS_DIR / "rendering-and-caching.md"
PREFIX = "RC"
MIN_RULES = 18
MIN_ANTI_PATTERNS = 8
MIN_TS_BLOCKS = 12
DO_MARKER = "**Do:**"

TERMS = (
    "'use client'",
    "Server Component",
    "Client Component",
    "children",
    "serializable",
    "'use cache'",
    "cacheComponents",
    "cacheLife",
    "cacheTag",
    "revalidateTag",
    "updateTag",
    "revalidatePath",
    "refresh",
    "Partial Prerendering",
    "<Suspense",
    "loading.tsx",
    "connection()",
    "cookies()",
    "headers()",
    "searchParams",
    "streaming",
    "provider",
)

REQUIRED_EXAMPLES = {
    "enable-cache-components": ("NextConfig", "cacheComponents"),
    "cached-with-lifetime": ("'use cache'", "cacheLife("),
    "tagged-cache": ("cacheTag(",),
    "suspense-streaming": ("<Suspense", "fallback"),
    "client-wrapper-children": ("'use client'", "children"),
}

INVALIDATION_APIS = ("revalidateTag", "updateTag", "revalidatePath", "refresh")
ANY_TYPE_RE = re.compile(r":\s*any\b|<any>|as any\b")
RC_ID_RE = re.compile(r"\bRC-(\d+)\b")
ANY_RULE_ID_RE = re.compile(r"\*\*([A-Z]+)-\d+\*\*")
FENCE_OPEN_RE = re.compile(r"^\s*`{3,}\S")
FENCE_CLOSE_RE = re.compile(r"^\s*`{3,}\s*$")


# --- helpers -----------------------------------------------------------------------------


@cache
def _text():
    return h.read(TOPIC)


@pytest.fixture(scope="module")
def topic_text():
    return _text()


def _tables(section_text):
    """Contiguous pipe-table chunks (header, separator, rows) outside fences."""
    chunks, current, in_fence = [], [], False
    for line in section_text.splitlines():
        if FENCE_OPEN_RE.match(line) and not in_fence:
            in_fence = True
        elif FENCE_CLOSE_RE.match(line) and in_fence:
            in_fence = False
        if not in_fence and line.strip().startswith("|"):
            current.append(line)
            continue
        if current:
            chunks.append("\n".join(current))
            current = []
    if current:
        chunks.append("\n".join(current))
    return tuple(chunk for chunk in chunks if len(chunk.splitlines()) >= 3)


def _events(body):
    """Ordered ``fence`` and ``do`` markers in an anti-pattern body, fences kept whole."""
    events, in_fence = [], False
    for line in body.splitlines():
        if in_fence:
            in_fence = not FENCE_CLOSE_RE.match(line)
        elif FENCE_OPEN_RE.match(line):
            in_fence = True
            events.append("fence")
        elif line.strip().startswith(DO_MARKER):
            events.append("do")
    return tuple(events)


# --- AC1, AC2: not a stub, only RC ids, deep enough ----------------------------------------


def test_rendering_topic_is_not_a_stub(topic_text):
    assert h.is_stub(topic_text) is False


def test_rendering_topic_uses_only_rc_rule_ids(topic_text):
    rules = h.rule_items(topic_text)
    assert rules, "no rules under ## Rules"
    assert all(rule_id.startswith(f"{PREFIX}-") for rule_id, _ in rules)
    assert set(ANY_RULE_ID_RE.findall(topic_text)) == {PREFIX}


def test_rendering_topic_has_at_least_18_rc_rules(topic_text):
    assert len(h.rule_items(topic_text)) >= MIN_RULES


# --- AC3: required concepts -----------------------------------------------------------------


def test_rendering_topic_names_every_required_concept(topic_text):
    assert h.missing_terms(topic_text, TERMS) == []


# --- AC4: examples ---------------------------------------------------------------------------


@pytest.mark.parametrize("needles", REQUIRED_EXAMPLES.values(), ids=REQUIRED_EXAMPLES.keys())
def test_rendering_topic_has_required_example(topic_text, needles):
    assert h.has_block_with(topic_text, *needles), f"no ts/tsx block with {needles}"


def test_rendering_topic_examples_have_no_any(topic_text):
    blocks = h.code_blocks(topic_text, ("ts", "tsx"))
    assert len(blocks) >= MIN_TS_BLOCKS
    offenders = [body.splitlines()[0] for _, body in blocks if ANY_TYPE_RE.search(body)]
    assert not offenders, f"ts/tsx blocks that use any: {offenders}"


# --- AC5: caching model detection ------------------------------------------------------------


def test_rules_section_labels_the_caching_model(topic_text):
    rules = h.section(topic_text, "Rules")
    assert "cacheComponents" in rules
    lowered = rules.lower()
    assert "without" in lowered or "previous model" in lowered


def test_first_rule_tells_the_reader_to_detect_the_caching_model(topic_text):
    (rule_id, item), *_ = h.rule_items(topic_text)
    assert rule_id == "RC-1"
    assert item.split()[1].lower() == "detect"
    assert "cacheComponents" in item


def test_every_rule_carries_a_caching_model_label(topic_text):
    labels = ("*(Cache Components)*", "*(previous model)*", "*(both models)*")
    rules = h.rule_items(topic_text)
    assert rules, "no rules under ## Rules"
    unlabeled = [rid for rid, item in rules if not any(label in item for label in labels)]
    assert not unlabeled, f"rules without a model label: {unlabeled}"


def test_scope_explains_the_model_labels(topic_text):
    scope = h.section(topic_text, "Scope")
    for label in ("Cache Components", "previous model", "both models"):
        assert label in scope, f"## Scope does not explain the {label!r} label"


# --- AC6: post-write invalidation decision table ------------------------------------------------


def test_patterns_has_revalidation_decision_table(topic_text):
    tables = _tables(h.section(topic_text, "Patterns"))
    named = [t for t in tables if all(api in t for api in INVALIDATION_APIS)]
    assert named, "no ## Patterns table names revalidateTag, updateTag, revalidatePath and refresh"


def test_decision_table_says_where_each_api_may_be_called_and_what_the_user_sees(topic_text):
    tables = _tables(h.section(topic_text, "Patterns"))
    table = next(t for t in tables if all(api in t for api in INVALIDATION_APIS))
    header, *rows = h.table_rows(table)
    lowered = [cell.lower() for cell in header]
    assert any("call from" in cell for cell in lowered), header
    assert any("user sees" in cell for cell in lowered), header
    assert len(rows) >= len(INVALIDATION_APIS)
    assert all(all(cell for cell in row) for row in rows), "empty cell in the decision table"


def test_patterns_has_rendering_strategies_and_migration_tables(topic_text):
    tables = _tables(h.section(topic_text, "Patterns"))
    assert len(tables) >= 3, f"expected at least 3 tables in ## Patterns, found {len(tables)}"
    assert any("Partial Prerendering" in t and "Previous model" in t for t in tables)
    assert any("unstable_cache" in t and "force-dynamic" in t for t in tables)


def test_patterns_tells_the_reader_how_to_detect_the_model(topic_text):
    patterns = h.section(topic_text, "Patterns")
    assert any("cacheComponents" in body for _, body in h.code_blocks(patterns, ("bash",)))


# --- AC7: version notes --------------------------------------------------------------------------


def test_version_notes_name_the_major_and_link_nextjs(topic_text):
    major = h.major(h.as_of_version(topic_text))
    notes = h.section(topic_text, "Version notes")
    assert notes.strip()
    assert f"Next.js {major}" in notes
    assert "https://nextjs.org/" in notes


def test_version_notes_give_every_item_a_link(topic_text):
    items = h.bullet_items(h.section(topic_text, "Version notes"))
    assert len(items) >= 10
    unlinked = [item[:60] for item in items if not h.all_urls(item)]
    assert not unlinked, f"version notes without a link: {unlinked}"


# --- AC8: reviewer-ready ----------------------------------------------------------------------------


def test_every_review_checklist_item_names_an_existing_rc_rule(topic_text):
    existing = {rule_id for rule_id, _ in h.rule_items(topic_text)}
    items = h.checklist_items(topic_text)
    assert items, "no checklist items"
    for item in items:
        named = {f"RC-{n}" for n in RC_ID_RE.findall(item)}
        assert named, f"checklist item names no RC rule: {item[:70]}"
        assert named <= existing, f"checklist names a missing rule {sorted(named - existing)}"


def test_every_checklist_line_in_the_section_is_a_checkbox_item(topic_text):
    body = h.section(topic_text, "Review checklist")
    bullets = [line for line in body.splitlines() if line.startswith("- ")]
    assert bullets and all(line.startswith("- [ ] ") and "RC-" in line for line in bullets)


def test_every_anti_pattern_pairs_dont_with_do(topic_text):
    antis = h.anti_patterns(topic_text)
    assert len(antis) >= MIN_ANTI_PATTERNS
    for title, body in antis:
        events = _events(body)
        assert events[:3] == ("fence", "do", "fence"), f"{title}: Don't block, {DO_MARKER}, Do block"
        assert events.count("do") == 1, f"{title}: exactly one {DO_MARKER} marker"
        assert RC_ID_RE.search(title), f"{title}: heading names no RC rule"


def test_anti_patterns_name_existing_rules(topic_text):
    existing = {rule_id for rule_id, _ in h.rule_items(topic_text)}
    antis = h.anti_patterns(topic_text)
    assert antis, "no ### Don't headings under ## Anti-patterns"
    for title, _ in antis:
        named = {f"RC-{n}" for n in RC_ID_RE.findall(title)}
        assert named <= existing, f"{title}: names a missing rule"
