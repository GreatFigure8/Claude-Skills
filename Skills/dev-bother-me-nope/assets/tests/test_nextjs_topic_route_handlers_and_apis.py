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
    major,
    missing_terms,
    read,
    rule_items,
    section,
    source_urls,
    uses_any_type,
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
ERROR_SHAPE_DECL_RE = re.compile(r"\b(?:type|interface)\s+ApiErrorBody\b")
HANDLER_EXPORT_RE = re.compile(
    r"export\s+(?:async\s+)?function\s+(?:GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\b"
)
ERROR_STATUS_RE = re.compile(r"status:\s*[45]\d\d")
FENCE_OPENER_RE = re.compile(r"^\s*`{3}(?:ts|tsx)\b", re.MULTILINE)
DO_MARKER = "**Do**"
SIBLING_LINKS = (
    "](sse-and-streaming.md)",
    "](proxy-auth-and-security.md)",
    "](performance-and-vercel.md)",
)


HANDLER_NAME_RE = re.compile(
    r"export\s+(?:async\s+)?(?:function|const)\s+(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\b"
)
SAFE_METHODS = ("GET", "HEAD")
MUTATING_METHODS = ("POST", "PUT", "PATCH", "DELETE")
SIDE_EFFECT_CALL_RE = re.compile(
    r"\b(?:revalidateTag|revalidatePath|updateTag|signOut|logout)\(|\.delete\("
)
SIGNATURE_VERIFY_RE = re.compile(r"\btimingSafeEqual\(|\bverify\w*\(")
SESSION_CALL_RE = re.compile(r"\b(?:getSession|verifySession|auth)\(")
ORIGIN_CHECK_RE = re.compile(r"\brejectCrossSiteRequest\(|headers\.get\(\s*['\"]origin['\"]\s*\)")
NODE_CRYPTO_IMPORT_RE = re.compile(r"""from\s+['"]node:crypto['"]""")
CRYPTO_CALL_RE = re.compile(r"\b(?:createHmac|timingSafeEqual)\(")
LENGTH_COMPARE_RE = re.compile(r"\b(\w+)\.length\s*[!=]==\s*(\w+)\.length\b")
LIST_CALL_RE = re.compile(r"\blist\w*\(")
GET_SESSION_IMPORT_RE = re.compile(r"import\s*\{[^}]*\bgetSession\b[^}]*\}\s*from\s*'([^']+)'")
UNPREFIXED_PATH_COMMENT_RE = re.compile(r"^//\s+(?:app|lib)/\S+\.tsx?\b")
DAL_MODULE = "@/lib/dal"
SAFE_METHOD_URL = "https://developer.mozilla.org/en-US/docs/Glossary/Safe/HTTP"


def _patterns_ts_blocks():
    return code_blocks(section(TEXT, "Patterns"), TS_LANGS)


def _rule_texts():
    return tuple(item for _, item in rule_items(TEXT))


def _good_ts_blocks():
    """Patterns blocks plus the Do half of every anti-pattern: the code a reader may copy."""
    blocks = [body for _, body in _patterns_ts_blocks()]
    for _, item in anti_patterns(TEXT):
        _, after = item.split(DO_MARKER, 1)
        blocks.extend(body for _, body in code_blocks(after, TS_LANGS))
    return blocks


def _first_line(body):
    return body.splitlines()[0]


def _handler_bodies(block):
    """``{method: source}`` for each exported HTTP handler, sliced at the next export."""
    marks = list(HANDLER_NAME_RE.finditer(block))
    bodies = {}
    for index, mark in enumerate(marks):
        end = marks[index + 1].start() if index + 1 < len(marks) else len(block)
        bodies[mark.group(1)] = block[mark.start() : end]
    return bodies


def _has_mutating_handler(block):
    return any(method in MUTATING_METHODS for method in _handler_bodies(block))


def _is_verified_webhook(block):
    return "request.text()" in block and SIGNATURE_VERIFY_RE.search(block) is not None


def _unauthenticated_mutations(blocks):
    """First lines of mutating-handler blocks with neither a session check nor a verified signature."""
    return [
        _first_line(block)
        for block in blocks
        if _has_mutating_handler(block)
        and not SESSION_CALL_RE.search(block)
        and not _is_verified_webhook(block)
    ]


def _unsafe_gets(blocks):
    """First lines of blocks whose GET or HEAD handler changes state (API-7)."""
    return [
        _first_line(block)
        for block in blocks
        for method, body in _handler_bodies(block).items()
        if method in SAFE_METHODS and SIDE_EFFECT_CALL_RE.search(body)
    ]


def _missing_origin_checks(blocks):
    """First lines of cookie-session mutating blocks that never check Origin (API-17)."""
    return [
        _first_line(block)
        for block in blocks
        if _has_mutating_handler(block)
        and SESSION_CALL_RE.search(block)
        and not ORIGIN_CHECK_RE.search(block)
    ]


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
    offenders = [body.splitlines()[0] for _, body in blocks if uses_any_type(body)]
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
    good = _good_ts_blocks()
    assert any(_has_mutating_handler(block) for block in good), "no mutating handler example"
    unchecked = _unauthenticated_mutations(good)
    assert not unchecked, f"mutating handlers without a session check or a verified signature: {unchecked}"


def test_guard_rejects_a_body_read_that_never_verifies_a_signature():
    unsigned = (
        "export async function POST(request: Request) {\n"
        "  const rawBody = await request.text()\n"
        "  await wipe(rawBody)\n"
        "  return new Response(null, { status: 204 })\n"
        "}"
    )
    signed = unsigned.replace("await wipe", "crypto.timingSafeEqual(a, b)\n  await wipe")
    assert _unauthenticated_mutations([unsigned]) == [_first_line(unsigned)]
    assert _unauthenticated_mutations([signed]) == []


def test_guard_rejects_a_get_that_changes_state():
    mutating_get = (
        "export async function GET() {\n"
        "  revalidateTag('catalog', 'max')\n"
        "  return Response.json({ ok: true })\n"
        "}"
    )
    post_only = mutating_get.replace("GET", "POST")
    mixed = "export async function GET() {\n  return Response.json({})\n}\n" + post_only
    assert _unsafe_gets([mutating_get]) == [_first_line(mutating_get)]
    assert _unsafe_gets([post_only]) == []
    assert _unsafe_gets([mixed]) == []


def test_guard_rejects_a_cookie_session_mutation_without_an_origin_check():
    bare = "export async function POST(request: Request) {\n  const session = await getSession()\n}"
    checked = bare.replace(
        "const session", "const blocked = rejectCrossSiteRequest(request)\n  const session"
    )
    assert _missing_origin_checks([bare]) == [_first_line(bare)]
    assert _missing_origin_checks([checked]) == []


def test_example_get_handlers_change_no_state():
    unsafe = _unsafe_gets(_good_ts_blocks())
    assert not unsafe, f"GET or HEAD handlers that revalidate, sign out or delete: {unsafe}"


def test_cookie_session_mutations_check_origin():
    missing = _missing_origin_checks(_good_ts_blocks())
    assert not missing, f"cookie-authenticated mutating handlers with no Origin check (API-17): {missing}"


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
    assert f"Next.js {major(version)}" in notes
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


# --- webhook verification, listing, session helper and path conventions ---------------------


def _verifying_blocks():
    return [body for body in _good_ts_blocks() if "timingSafeEqual(" in body]


def test_crypto_calls_import_from_node_crypto():
    blocks = [body for _, body in code_blocks(TEXT, TS_LANGS) if CRYPTO_CALL_RE.search(body)]
    assert blocks, "no block calls createHmac or timingSafeEqual"
    bare = [_first_line(body) for body in blocks if not NODE_CRYPTO_IMPORT_RE.search(body)]
    assert not bare, f"blocks that use crypto without importing 'node:crypto' (the global is Web Crypto): {bare}"


def test_signature_mismatch_answers_401_with_the_envelope():
    blocks = _verifying_blocks()
    assert len(blocks) >= 2, "expected the webhook pattern and the Do half of the webhook anti-pattern"
    wrong = [
        _first_line(body)
        for body in blocks
        if "invalid_signature" not in body or "status: 401" not in body or "throw new Error" in body
    ]
    assert not wrong, f"signature checks that do not answer 401 invalid_signature: {wrong}"


def test_signature_length_check_compares_buffer_byte_lengths():
    blocks = _verifying_blocks()
    assert blocks, "no block calls timingSafeEqual"
    for body in blocks:
        compares = LENGTH_COMPARE_RE.findall(body)
        assert compares, f"{_first_line(body)!r} calls timingSafeEqual without a length comparison"
        for names in compares:
            for name in names:
                assert re.search(rf"\b{name}\s*=\s*Buffer\.from\(", body), (
                    f"{_first_line(body)!r} compares {name}.length but {name} is not a Buffer: "
                    "a string length counts UTF-16 units and timingSafeEqual needs equal byte lengths"
                )


def test_webhook_marks_an_event_processed_only_after_its_work_succeeds():
    blocks = [body for body in _verifying_blocks() if "handleVercelEvent(" in body]
    assert len(blocks) == 1, "expected one webhook pattern that runs handleVercelEvent"
    block = blocks[0]
    assert "markEventReceived" not in block, "the event is marked received before its work ran"
    work = re.search(r"\bhandleVercelEvent\(", block)
    mark = re.search(r"\bmark\w*\(", block)
    assert mark, "the webhook pattern never records the event id"
    assert work.start() < mark.start(), "the event id is recorded before handleVercelEvent runs"


def test_webhook_rule_records_the_event_after_success_and_names_the_durable_job():
    matches = [
        item
        for _, item in rule_items(TEXT)
        if all(term in item for term in ("webhook", "after()", "processed", "durable"))
    ]
    assert matches, "no rule says to mark a webhook event processed after success and to use a durable job"


def test_pattern_handlers_that_list_are_bounded_by_limit_and_cursor():
    listing = [
        body
        for _, body in _patterns_ts_blocks()
        if HANDLER_EXPORT_RE.search(body) and LIST_CALL_RE.search(body)
    ]
    assert len(listing) >= 2, "expected the projects list and the catalog list"
    unbounded = [_first_line(body) for body in listing if "limit" not in body or "cursor" not in body]
    assert not unbounded, f"list handlers with no limit and cursor (API-20): {unbounded}"


def test_session_helper_is_imported_from_the_dal():
    assert "@/lib/auth/session" not in TEXT
    modules = [
        module
        for _, body in code_blocks(TEXT, TS_LANGS)
        for module in GET_SESSION_IMPORT_RE.findall(body)
    ]
    assert modules, "no block imports getSession"
    assert set(modules) == {DAL_MODULE}, f"getSession must come from {DAL_MODULE}, found {sorted(set(modules))}"


def test_snippet_path_comments_use_the_src_layout():
    blocks = [body for _, body in code_blocks(TEXT, TS_LANGS)]
    bare = [_first_line(body) for body in blocks if UNPREFIXED_PATH_COMMENT_RE.match(_first_line(body))]
    assert not bare, f"path comments without the src/ prefix: {bare}"
    assert any(_first_line(body).startswith("// src/") for body in blocks), "no snippet names a src/ path"


def test_rule_keeps_get_free_of_side_effects_and_cites_mdn():
    matches = [
        item
        for item in _rule_texts()
        if "GET" in item and "side effect" in item and SAFE_METHOD_URL in item
    ]
    assert matches, "no rule keeps GET free of side effects with the MDN Safe page"
    assert SAFE_METHOD_URL in source_urls(TEXT)
