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
    "getSession(",
    "sseEvent(",
)
ROUTE_PATH = re.compile(r"^// src/app/api/\S+/route\.ts")
SUBSCRIBE_CALLBACK = re.compile(r"subscribe\(session\.userId, (\w+)\)")
FUNCTIONS_KEYS = re.compile(r'^\s*"([^"$]+)":\s*\{\s*"supportsCancellation"', re.MULTILINE)


@cache
def _text():
    return h.read(SSE_MD)


def _blocks():
    return h.code_blocks(_text(), ("ts", "tsx"))


def _block_at(path):
    """Body of the ts/tsx fence whose first line is ``// <path>``; fails when there is none."""
    for _, body in _blocks():
        if body.startswith(f"// {path}"):
            return body
    raise AssertionError(f"no ts/tsx fence starts with // {path}")


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



# --- FIX① guards (REVIEW① findings; each runtime behaviour was also run under Node) ---------


def test_sse_route_handlers_read_a_nullable_session_not_a_redirecting_one():
    """R1-C1, R1-C9: verifySession() redirects (307 to /login), so a Route Handler's 401 never runs."""
    routes = [body for _, body in _blocks() if ROUTE_PATH.match(body)]
    assert len(routes) >= 2, "expected the SSE GET and chat POST route fences"
    for body in routes:
        first = body.splitlines()[0]
        assert "import { getSession } from '@/lib/dal'" in body, first
        assert "verifySession(" not in body, f"{first} calls the redirecting helper"
        assert "@/lib/auth'" not in body, f"{first} imports the session from a non-canonical path"


def test_sse_route_holds_live_events_until_the_replay_is_written():
    """R1-C2: live events written straight from subscribe() overtake the replay (101 before 99)."""
    route = _block_at("src/app/api/events/route.ts")
    callback = SUBSCRIBE_CALLBACK.search(route)
    assert callback, "the route no longer subscribes with session.userId"
    assert callback.group(1) != "write", "live events go straight to write() while the replay is pending"
    assert ".has(" in route, "live events the replay already sent are not dropped"


def test_sse_vercel_json_keys_use_the_src_prefix():
    """R1-C3: the canonical layout is src/app, and the duration page says src projects prefix /src/."""
    keys = [key for _, body in h.code_blocks(_text(), ("json",)) for key in FUNCTIONS_KEYS.findall(body)]
    assert keys, "no supportsCancellation keys in a json fence"
    assert all(key.startswith("src/app/") for key in keys), keys
    assert "keys for a `src/app` layout" not in h.section(_text(), "Not confirmed by the docs")


def test_sse_route_checks_desired_size_before_enqueueing():
    """R1-C10: a push source that ignores desiredSize queues without bound for a slow client."""
    route = _block_at("src/app/api/events/route.ts")
    assert "controller.desiredSize" in route
    assert "QueuingStrategy" in route, "with the default highWaterMark of 1 the queue is full after one frame"


def test_sse_route_unsubscribes_inside_after():
    """R1-C11: an unsubscribe outside after()/waitUntil is lost when Vercel cancels the function."""
    route = _block_at("src/app/api/events/route.ts")
    assert "import { after } from 'next/server'" in route
    assert "after(() => cleanedUp)" in route
    assert ".finally(markCleanedUp)" in route


def test_sse_hook_keys_resume_id_and_status_by_url():
    """R1-C12: switching rooms must not send the old room's lastEventId or report its status."""
    hook = _block_at("src/shared/hooks/use-event-source.ts")
    assert "lastId.current?.url === url" in hook
    assert "state.url === url ? state.status : 'connecting'" in hook


def test_sse_hook_listens_for_stream_error():
    """R1-C22: without a stream-error listener a persistent failure is a silent reconnect loop."""
    hook = _block_at("src/shared/hooks/use-event-source.ts")
    assert "addEventListener('stream-error'" in hook


def test_sse_fetch_reader_stops_on_a_final_4xx():
    """R1-C13: retrying 401/403/400 forever hides an expired session from the UI."""
    reader = _block_at("src/shared/utils/read-sse.ts")
    assert "error instanceof HttpStatusError && isFinal(error.status)) throw error" in reader


def test_sse_plain_text_ai_stream_has_its_own_reader():
    """R1-C14: toTextStreamResponse() has no data: lines, so readSse drops every chunk."""
    reader = _block_at("src/shared/utils/read-text-stream.ts")
    assert "export async function readTextStream" in reader
    assert "readSse(" not in reader
    assert "as in the previous section" not in h.section(_text(), "Patterns")


def test_sse_fetch_readers_cancel_the_body_on_failure():
    """R1-C20: a throwing onMessage or a non-OK status must not leave the connection open."""
    reader = _block_at("src/shared/utils/read-sse.ts")
    assert "await response.body?.cancel()" in reader
    assert "} finally {\n    await reader.cancel()" in reader
    assert "} finally {\n    await reader.cancel()" in _block_at("src/shared/utils/read-text-stream.ts")


def test_sse_fetch_reader_tracks_id_only_blocks():
    """R1-C21: WHATWG sets the last event ID even for a block with no data."""
    reader = _block_at("src/shared/utils/read-sse.ts")
    assert "if (data.length === 0) return null" not in reader
    assert "if (id !== undefined) onId(id)" in reader


def test_sse_backoff_wait_removes_its_abort_listener():
    """R1-C23: one abort listener per reconnect piles up on a long-lived signal."""
    reader = _block_at("src/shared/utils/read-sse.ts")
    assert "signal.removeEventListener('abort', done)" in reader


def test_sse_frames_to_stream_takes_the_request_signal():
    """R1-C24: the prose pairs framesToStream with request.signal, so the function must accept one."""
    frames = _block_at("src/shared/utils/sse-stream.ts")
    assert "frames: AsyncGenerator<string, void>, signal: AbortSignal" in frames
    assert "signal.addEventListener('abort', onAbort" in frames


def test_sse_not_confirmed_section_exists_and_cites_urls():
    body = h.section(_text(), "Not confirmed by the docs")
    items = (*h.bullet_items(body), *h.numbered_items(body))
    assert items, "nothing is listed"
    uncited = [item[:60] for item in items if not h.all_urls(item)]
    assert not uncited, f"items without the URL that was checked: {uncited}"
