"""Topic test for references/nextjs/route-handlers-and-apis.md.

The generic contract (as-of line, section order, rule format, floors, Sources, hygiene) is
enforced for every topic by ``test_nextjs_reference.py``. This module pins what is specific to
Route Handlers and API design: the rule count, the required concepts, the typed examples, the one
error envelope, auth on every mutating handler, the Route Handler versus Server Action choice and
the reviewer-ready sections. Offline, standard library plus pytest. Parsing is in
``nextjs_doc_helpers``.
"""

import re

from nextjs_doc_helpers import (
    TOPICS,
    TOPICS_DIR,
    anti_patterns,
    as_of_version,
    checklist_items,
    code_blocks,
    has_block_with,
    is_stub,
    missing_terms,
    read,
    rule_items,
    section,
)

TOPIC = TOPICS_DIR / "route-handlers-and-apis.md"
TEXT = read(TOPIC)

OWN_PREFIX = TOPICS["route-handlers-and-apis.md"][0]
MIN_API_RULES = 18
MIN_CHECKLIST_ITEMS = 8
MIN_ANTI_PATTERNS = 3
TS_LANGS = ("ts", "tsx")
BACKEND_FOR_FRONTEND_URL = "https://nextjs.org/docs/app/guides/backend-for-frontend"

TERMS = (
    "route.ts", "GET", "POST", "NextRequest", "NextResponse", "Response.json", "RouteContext",
    "OPTIONS", "Access-Control-Allow-Origin", "request.text()", "signature", "webhook",
    "safeParse", "400", "401", "403", "404", "runtime", "maxDuration", "after(", "cookies()",
    "headers()", "Server Action", "page.tsx",
)

OWN_RULE_ID_RE = re.compile(rf"^{OWN_PREFIX}-\d+$")
FOREIGN_PREFIXES = tuple(prefix for prefix, _ in TOPICS.values() if prefix != OWN_PREFIX)
FOREIGN_RULE_ID_RE = re.compile(r"\b(?:" + "|".join(FOREIGN_PREFIXES) + r")-\d+\b")
API_ID_RE = re.compile(rf"\b{OWN_PREFIX}-\d+\b")
RULE_ITEM_ID_RE = re.compile(rf"\*\*({OWN_PREFIX}-\d+)\*\*")
ANY_RE = re.compile(r":\s*any\b|\bas\s+any\b|<any>|\bany\[\]")
ERROR_SHAPE_DECL_RE = re.compile(r"\b(?:type|interface)\s+ApiErrorBody\b")
HANDLER_EXPORT_RE = re.compile(
    r"export\s+(?:async\s+)?function\s+(?:GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\b"
)
MUTATING_EXPORT_RE = re.compile(
    r"export\s+(?:async\s+)?function\s+(?:POST|PUT|PATCH|DELETE)\b"
    r"|export\s+const\s+(?:POST|PUT|PATCH|DELETE)\b"
)
ERROR_STATUS_RE = re.compile(r"status:\s*[45]\d\d")
AUTH_CALL_RE = re.compile(r"(?i)(session|auth)\w*\(")
FENCE_OPENER_RE = re.compile(r"^\s*`{3}(?:ts|tsx)\b", re.MULTILINE)
DO_MARKER = "**Do**"
SIBLING_LINKS = (
    "](sse-and-streaming.md)",
    "](proxy-auth-and-security.md)",
    "](performance-and-vercel.md)",
)


def _patterns_ts_blocks():
    return code_blocks(section(TEXT, "Patterns"), TS_LANGS)


def _rule_texts():
    return tuple(item for _, item in rule_items(TEXT))


# --- AC1: only API rule ids -----------------------------------------------------------------


def test_topic_uses_only_api_rule_ids():
    ids = [rule_id for rule_id, _ in rule_items(TEXT)]
    assert ids, "no rules found under ## Rules"
    bad = [rule_id for rule_id in ids if not OWN_RULE_ID_RE.match(rule_id)]
    assert not bad, f"rule ids that are not {OWN_PREFIX}-n: {bad}"
    foreign = sorted(set(FOREIGN_RULE_ID_RE.findall(TEXT)))
    assert not foreign, f"another topic's rule ids appear in the file: {foreign}"


# --- AC2: not a stub, deep enough -------------------------------------------------------------


def test_topic_is_not_a_stub():
    assert not is_stub(TEXT)


def test_topic_has_at_least_18_api_rules():
    assert len(rule_items(TEXT)) >= MIN_API_RULES


# --- AC3: required concepts ---------------------------------------------------------------------


def test_topic_covers_required_terms():
    assert missing_terms(TEXT, TERMS) == []


# --- AC4: examples ------------------------------------------------------------------------------


def test_validated_post_example_returns_error_shape():
    assert has_block_with(TEXT, "export async function POST", "safeParse", ".json(", "status:")


def test_dynamic_segment_example_uses_typed_route_context():
    assert has_block_with(TEXT, "RouteContext<'/", "await")


def test_webhook_example_verifies_signature_on_raw_body():
    assert has_block_with(TEXT, "request.text()", "signature", "timingSafeEqual")


def test_cors_example_answers_preflight():
    assert has_block_with(TEXT, "OPTIONS", "Access-Control-Allow-Origin")


def test_examples_contain_no_any():
    blocks = code_blocks(TEXT, TS_LANGS)
    assert blocks, "the file has no ts or tsx example"
    offenders = [body.splitlines()[0] for _, body in blocks if ANY_RE.search(body)]
    assert not offenders, f"ts blocks that use any: {offenders}"


# --- AC5: one error shape ---------------------------------------------------------------------


def test_error_shape_declared_once_under_patterns_as_convention():
    patterns = section(TEXT, "Patterns")
    declaring = [body for _, body in code_blocks(patterns, TS_LANGS) if ERROR_SHAPE_DECL_RE.search(body)]
    assert len(declaring) == 1, f"expected one declaring block under Patterns, found {len(declaring)}"
    assert len(ERROR_SHAPE_DECL_RE.findall(TEXT)) == 1, "ApiErrorBody is declared more than once"
    assert "(convention)" in patterns


def test_post_example_references_error_shape():
    assert has_block_with(
        TEXT, "export async function POST", "safeParse", ".json(", "status:", "ApiErrorBody"
    )


def test_pattern_handlers_returning_errors_use_error_shape():
    checked = [
        body
        for _, body in _patterns_ts_blocks()
        if HANDLER_EXPORT_RE.search(body) and ERROR_STATUS_RE.search(body)
    ]
    assert checked, "no Patterns handler returns an error status"
    missing = [body.splitlines()[0] for body in checked if "ApiErrorBody" not in body]
    assert not missing, f"handlers that return an error without ApiErrorBody: {missing}"


# --- AC6: auth on every mutating handler -----------------------------------------------------


def test_mutating_handler_examples_check_session_or_auth():
    mutating = [body for _, body in code_blocks(TEXT, TS_LANGS) if MUTATING_EXPORT_RE.search(body)]
    assert mutating, "no mutating handler example in the file"
    unchecked = [
        body.splitlines()[0]
        for body in mutating
        if "request.text()" not in body and not AUTH_CALL_RE.search(body)
    ]
    assert not unchecked, f"mutating handlers without a session or auth check: {unchecked}"


# --- AC7: Route Handler versus Server Action ------------------------------------------------


def test_rules_frame_route_handler_versus_server_action():
    matches = [
        item
        for item in _rule_texts()
        if all(term in item for term in ("Route Handler", "Server Action", "webhook", "third-party"))
    ]
    assert matches, "no rule frames Route Handler versus Server Action"
    assert any(BACKEND_FOR_FRONTEND_URL in item for item in matches)


def test_rules_forbid_server_component_fetching_own_route_handler():
    matches = [
        item
        for item in _rule_texts()
        if "Server Component" in item and "Route Handler" in item and "fetch" in item.lower()
    ]
    assert matches, "no rule forbids a Server Component fetching its own Route Handler"
    assert any(BACKEND_FOR_FRONTEND_URL in item for item in matches)


# --- AC8: version notes -------------------------------------------------------------------------


def test_version_notes_name_major_and_link_nextjs():
    version = as_of_version(TEXT)
    assert version, "no as-of version"
    notes = section(TEXT, "Version notes")
    assert notes.strip(), "## Version notes is empty"
    assert f"Next.js {version.split('.')[0]}" in notes
    assert "https://nextjs.org/" in notes


# --- AC9: reviewer-ready ------------------------------------------------------------------------


def test_review_checklist_items_name_existing_api_rules():
    items = checklist_items(TEXT)
    assert len(items) >= MIN_CHECKLIST_ITEMS
    rule_ids = {rule_id for rule_id, _ in rule_items(TEXT)}
    unnamed = [item[:60] for item in items if not API_ID_RE.search(item)]
    assert not unnamed, f"checklist items that name no {OWN_PREFIX}- rule: {unnamed}"
    unknown = sorted({found for item in items for found in API_ID_RE.findall(item)} - rule_ids)
    assert not unknown, f"checklist items cite rules that do not exist: {unknown}"


def test_anti_patterns_pair_dont_with_do():
    items = anti_patterns(TEXT)
    assert len(items) >= MIN_ANTI_PATTERNS
    for title, body in items:
        assert DO_MARKER in body, f"{title!r} has no {DO_MARKER} counterpart"
        before, after = body.split(DO_MARKER, 1)
        assert FENCE_OPENER_RE.search(before), f"{title!r} has no Don't code block"
        assert FENCE_OPENER_RE.search(after), f"{title!r} has no Do code block"


# --- scope and contract depth ----------------------------------------------------------------


def test_links_sibling_topics_instead_of_duplicating():
    missing = [link for link in SIBLING_LINKS if link not in TEXT]
    assert not missing, f"missing sibling links: {missing}"


def test_not_confirmed_section_states_no_rules():
    body = section(TEXT, "Not confirmed by the docs")
    assert body.strip()
    assert RULE_ITEM_ID_RE.search(body) is None
    assert "https://" in body


def test_runtime_rule_flags_edge_as_deprecated():
    matches = [
        item
        for item in _rule_texts()
        if all(term in item.lower() for term in ("runtime", "edge", "deprecated"))
    ]
    assert matches, "no rule flags the Edge runtime as deprecated"


def test_pattern_examples_never_call_update_tag():
    offenders = [body.splitlines()[0] for _, body in _patterns_ts_blocks() if "updateTag(" in body]
    assert not offenders, f"Patterns blocks that call updateTag: {offenders}"
