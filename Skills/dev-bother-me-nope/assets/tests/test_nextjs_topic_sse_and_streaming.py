"""Topic tests for ``references/nextjs/sse-and-streaming.md`` (rule prefix ``SSE``).

The generic contract tests in ``test_nextjs_reference.py`` run on this file once it is no longer
a stub. These tests pin what only this topic owes: it is written (not a stub), deep enough, names
every concept the story requires, carries the complete SSE Route Handler and client examples,
sets ``maxDuration`` against a vercel.com source, grounds the client facts in MDN or WHATWG, and
keeps its checklist and anti-patterns tied to its own rule ids. Offline, standard library plus
pytest. Parsing lives in ``nextjs_doc_helpers``.
"""

import re
from functools import cache
from urllib.parse import urlsplit

import nextjs_doc_helpers as h

SSE_MD = h.TOPICS_DIR / "sse-and-streaming.md"
MIN_RULES = 15
MIN_DONT_ITEMS = 3
SSE_RULE_ID = re.compile(r"SSE-\d+")
SSE_RULE_ID_ONLY = re.compile(r"^SSE-\d+$")
ANY_TYPE = re.compile(r":\s*any\b|<any>|\bas any\b|\bany\[\]")
WEB_PLATFORM_HOSTS = frozenset(("developer.mozilla.org", "html.spec.whatwg.org"))
DO_MARKER = "**Do**"
LF_PAIR = "\\n\\n"  # the two characters backslash-n, twice, as written in the TypeScript source

TERMS = (
    "text/event-stream",
    "ReadableStream",
    "TextEncoder",
    "controller.enqueue",
    "controller.close",
    "request.signal",
    "abort",
    "cancel(",
    "data:",
    "event:",
    "id:",
    "retry:",
    "heartbeat",
    "Cache-Control",
    "EventSource",
    "Last-Event-ID",
    "withCredentials",
    "getReader(",
    "reconnect",
    "backpressure",
    "maxDuration",
    "Fluid compute",
    "useEffect",
    ".close()",
)

ROUTE_HANDLER_NEEDLES = (
    "export async function GET",
    "abort",
    "cancel(",
    "clearInterval",
    "text/event-stream",
    "Cache-Control",
    "verifySession",
    "sseEvent(",
)


@cache
def _text():
    return h.read(SSE_MD)


def _blocks():
    return h.code_blocks(_text(), ("ts", "tsx"))


# --- not a stub, and deep enough -----------------------------------------------------------


def test_sse_topic_is_no_longer_a_stub():
    assert h.is_stub(_text()) is False


def test_sse_topic_has_at_least_15_rules():
    assert len(h.rule_items(_text())) >= MIN_RULES


def test_sse_topic_uses_only_sse_rule_ids():
    ids = [rule_id for rule_id, _ in h.rule_items(_text())]
    assert ids, "no rules under ## Rules"
    bad = [rule_id for rule_id in ids if not SSE_RULE_ID_ONLY.match(rule_id)]
    assert not bad, f"rule ids that are not SSE-<n>: {bad}"


# --- required concepts ---------------------------------------------------------------------


def test_sse_topic_names_every_required_concept():
    assert h.missing_terms(_text(), TERMS) == []


# --- examples ------------------------------------------------------------------------------


def test_sse_topic_has_route_handler_example():
    assert h.has_block_with(_text(), "text/event-stream", "ReadableStream", "request.signal")


def test_sse_topic_has_frame_encoding_example():
    assert h.has_block_with(_text(), "controller.enqueue", "TextEncoder")


def test_sse_topic_has_heartbeat_cleared_example():
    assert h.has_block_with(_text(), "setInterval", "clearInterval")


def test_sse_topic_has_last_event_id_resume_example():
    assert h.has_block_with(_text(), "Last-Event-ID")


def test_sse_topic_has_client_event_source_hook_example():
    assert h.has_block_with(_text(), "'use client'", "EventSource", "useEffect", ".close()")


def test_sse_topic_has_fetch_reader_example():
    assert h.has_block_with(_text(), "getReader(")


def test_sse_examples_never_use_any():
    blocks = _blocks()
    assert blocks, "no ts/tsx examples to check"
    offenders = [body.splitlines()[0] for _, body in blocks if ANY_TYPE.search(body)]
    assert not offenders, f"ts/tsx blocks that use the any type: {offenders}"


def test_sse_route_handler_example_releases_on_abort_and_cancel():
    assert h.has_block_with(_text(), *ROUTE_HANDLER_NEEDLES)


def test_sse_route_handler_example_closes_before_max_duration():
    assert h.has_block_with(_text(), "export const maxDuration", "controller.close()", "setTimeout")


def test_sse_frame_encoder_writes_id_event_data_and_blank_line():
    assert h.has_block_with(_text(), "id: ", "event: ", "data: ", LF_PAIR)


# --- Vercel and client facts ---------------------------------------------------------------


def test_sse_rules_set_max_duration_with_vercel_link():
    rules = h.section(_text(), "Rules")
    assert "maxDuration" in rules
    assert "https://vercel.com/" in rules


def test_sse_rules_state_event_source_client_facts():
    rules = h.section(_text(), "Rules")
    for needle in ("Last-Event-ID", "retry:", "withCredentials", "getReader("):
        assert needle in rules, f"## Rules never mentions {needle}"


def test_sse_sources_include_mdn_or_whatwg():
    hosts = {urlsplit(url).hostname for url in h.source_urls(_text())}
    assert hosts & WEB_PLATFORM_HOSTS, sorted(hosts)


# --- version notes -------------------------------------------------------------------------


def test_sse_version_notes_name_the_major_and_link_nextjs():
    major = h.major(h.as_of_version(_text()))
    notes = h.section(_text(), "Version notes")
    assert notes.strip()
    assert f"Next.js {major}" in notes
    assert "https://nextjs.org/" in notes


# --- reviewer-ready ------------------------------------------------------------------------


def test_sse_review_checklist_items_each_name_an_sse_rule():
    items = h.checklist_items(_text())
    assert items, "no - [ ] items under ## Review checklist"
    bare = [item[:60] for item in items if "SSE-" not in item]
    assert not bare, f"checklist items that name no SSE rule: {bare}"


def test_sse_checklist_and_anti_patterns_cite_only_defined_rules():
    defined = {rule_id for rule_id, _ in h.rule_items(_text())}
    cited = set()
    for heading in ("Review checklist", "Anti-patterns"):
        cited.update(SSE_RULE_ID.findall(h.section(_text(), heading)))
    assert cited, "neither section cites a rule"
    assert cited <= defined, f"cited ids with no rule: {sorted(cited - defined)}"


def test_sse_anti_patterns_pair_every_dont_with_a_do():
    items = h.anti_patterns(_text())
    assert len(items) >= MIN_DONT_ITEMS
    for title, body in items:
        assert SSE_RULE_ID.search(title), f"Don't item names no SSE rule: {title}"
        assert DO_MARKER in body, f"Don't item has no {DO_MARKER} counterpart: {title}"
        assert len(h.code_blocks(body)) >= 2, f"needs a bad and a good block: {title}"


def test_sse_not_confirmed_section_exists_and_cites_urls():
    body = h.section(_text(), "Not confirmed by the docs")
    items = (*h.bullet_items(body), *h.numbered_items(body))
    assert items, "nothing is listed"
    uncited = [item[:60] for item in items if not h.all_urls(item)]
    assert not uncited, f"items without the URL that was checked: {uncited}"
