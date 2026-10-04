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


# --- FIX①: REVIEW① findings R1-B2, R1-B3, R1-B9, R1-B10, R1-B14, R1-B15 ---------------------

INVALIDATE_RE = re.compile(r"\b(?:revalidateTag|revalidatePath)\(")
VERIFY_TOKENS = ("timingSafeEqual(", "readSignedBody(")
ERROR_STATUS_RE = re.compile(r"status:\s*[45]\d\d")
PATH_COMMENT_RE = re.compile(r"^// (\S+\.tsx?)\b")
ROOT_CONFIG_FILES = ("next.config.ts",)


def _rule(text, rule_id):
    return next(item for found, item in h.rule_items(text) if found == rule_id)


def _do_blocks(text):
    """``(title, body)`` of each ts/tsx fence after an anti-pattern's ``**Do:**`` marker."""
    pairs = []
    for title, body in h.anti_patterns(text):
        _, _, after = body.partition(DO_MARKER)
        pairs.extend((title, block) for _, block in h.code_blocks(after, ("ts", "tsx")))
    return tuple(pairs)


def _good_blocks(text):
    """Every ts/tsx fence the reader is told to copy: Patterns fences plus Do fences."""
    patterns = h.code_blocks(h.section(text, "Patterns"), ("ts", "tsx"))
    return tuple(block for _, block in patterns) + tuple(block for _, block in _do_blocks(text))


def _route_handlers(text):
    return tuple(b for b in _good_blocks(text) if re.search(r"export async function (POST|GET)", b))


def test_rc30_states_the_persistence_difference_before_migrating(topic_text):
    rule = _rule(topic_text, "RC-30")
    assert "only in repos without Cache Components" not in rule
    for needle in ("unstable_cache", "fetch", "'use cache: remote'", "across deployments", "instances"):
        assert needle in rule, f"RC-30 does not name {needle!r}"
    assert "persist across deploys" in rule, "RC-30 does not say when to keep the persistent caches"


def test_migration_table_keeps_persistent_caches_for_cross_deploy_data(topic_text):
    tables = _tables(h.section(topic_text, "Patterns"))
    table = next(t for t in tables if "unstable_cache" in t and "force-dynamic" in t)
    rows = [row for row in h.table_rows(table) if "unstable_cache(" in row[0] or "force-cache" in row[0]]
    assert len(rows) == 2, rows
    for row in rows:
        assert "deploy" in row[1] and "RC-30" in row[1], f"no persistence caveat: {row}"


def test_not_confirmed_no_longer_doubts_remote_cache_deploy_persistence(topic_text):
    doubts = h.section(topic_text, "Not confirmed by the docs")
    assert "survive a redeploy" not in doubts


def test_rc28_matches_cachetag_documented_limits(topic_text):
    rule = _rule(topic_text, "RC-28")
    assert "per entry" not in rule
    assert "A single `cacheTag()` call accepts up to 128 tags" in rule
    assert "each with a maximum length of 256 characters" in rule
    assert "console warning" in rule


def test_rc40_sends_cache_components_repos_to_proxy(topic_text):
    rule = _rule(topic_text, "RC-40")
    assert "previous model" in rule
    assert "Cache Components" in rule and "Proxy" in rule
    assert "RC-15" in rule or "RC-16" in rule


def test_top_level_param_awaits_in_copyable_pages_are_labelled_previous_model(topic_text):
    offenders = [
        block.splitlines()[0]
        for block in _good_blocks(topic_text)
        if "export default async function" in block
        and "await params" in block
        and "WITHOUT cacheComponents" not in block
    ]
    assert not offenders, f"top-level await params with no previous-model label: {offenders}"


def test_status_code_pattern_points_cache_components_to_proxy(topic_text):
    patterns = h.section(topic_text, "Patterns")
    pattern = h.section(patterns, "Return a real 404 before streaming starts", prefix=True)
    assert "previous model" in pattern
    assert "Proxy" in pattern
    assert "file-conventions/loading" in pattern


def test_route_handlers_verify_the_caller_before_invalidating(topic_text):
    handlers = [b for b in _route_handlers(topic_text) if INVALIDATE_RE.search(b)]
    assert len(handlers) >= 2, "expected the webhook pattern and the RC-32/RC-33 Do block"
    for block in handlers:
        invalidate_at = INVALIDATE_RE.search(block).start()
        verified = [block.find(token) for token in VERIFY_TOKENS if token in block]
        assert verified and min(verified) < invalidate_at, f"unverified: {block.splitlines()[0]}"


def test_signed_body_helper_compares_in_constant_time(topic_text):
    helpers = [b for b in _good_blocks(topic_text) if "export async function readSignedBody" in b]
    assert len(helpers) == 1
    assert "timingSafeEqual(" in helpers[0] and ".length ===" in helpers[0]
    assert "await request.text()" in helpers[0]


def test_route_handler_errors_use_the_api_error_envelope(topic_text):
    for block in _route_handlers(topic_text):
        assert "revalidated: false" not in block
        if ERROR_STATUS_RE.search(block):
            assert "ApiErrorBody" in block, f"ad-hoc error body: {block.splitlines()[0]}"


def test_revalidation_tag_comes_from_a_validated_signed_body(topic_text):
    for block in _route_handlers(topic_text):
        assert "searchParams.get('tag')" not in block
        if re.search(r"revalidateTag\((?!')", block):
            assert ".safeParse(" in block, f"tag not validated: {block.splitlines()[0]}"


def test_server_actions_validate_form_data_before_writing(topic_text):
    actions = [b for b in _good_blocks(topic_text) if "'use server'" in b and "formData.get(" in b]
    assert actions, "no Server Action reads formData"
    for block in actions:
        assert "String(formData.get(" not in block
        assert ".safeParse(" in block


def test_snippets_use_the_shared_session_helpers(topic_text):
    for _, block in h.code_blocks(topic_text, ("ts", "tsx")):
        assert "await auth()" not in block and "'@/lib/auth'" not in block
    actions = [b for b in _good_blocks(topic_text) if b.lstrip("/ \n").find("'use server'") >= 0]
    assert actions
    for block in actions:
        assert "verifySession()" in block and "from '@/lib/dal'" in block


def test_snippet_path_comments_use_src_and_lib_actions(topic_text):
    for block in _good_blocks(topic_text):
        match = PATH_COMMENT_RE.match(block.splitlines()[0])
        if not match or match.group(1) in ROOT_CONFIG_FILES:
            continue
        path = match.group(1)
        assert path.startswith("src/"), f"snippet path not under src/: {path}"
        if "'use server'" in block.splitlines()[1:3]:
            assert path.startswith("src/lib/actions/"), f"Server Action file outside lib/actions: {path}"
