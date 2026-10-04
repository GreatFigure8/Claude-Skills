"""Story tests for references/nextjs/routing-and-metadata.md (rule prefix RT).

test_nextjs_reference.py already runs the generic authoring-contract checks on every
non-stub topic file: section order, rule format and citations, floors, Sources, the as-of
line, the 800-line cap, fence tags and relative links. This module adds what only the
routing-and-metadata topic needs: depth, the required concepts, five worked examples, the
Next.js 16 parallel-route `default` rule, the link to the canonical layout in nextjs.md,
version notes for the as-of major, and a reviewer-ready checklist and anti-pattern list.
Standard library and pytest only; nothing here touches the network.
"""

import re

import nextjs_doc_helpers as h
import pytest

TOPIC = h.TOPICS_DIR / "routing-and-metadata.md"
PREFIX = "RT"
MIN_RULES = 15
MIN_ANTI_PATTERNS = 3
MIN_CHECKLIST_ITEMS = 8
TERMS = (
    "layout.tsx", "page.tsx", "loading.tsx", "not-found.tsx", "template.tsx",
    "default.tsx", "[slug]", "[...slug]", "[[...slug]]", "route group",
    "private folder", "parallel route", "intercepting route", "(.)",
    "generateStaticParams", "dynamicParams", "<Link", "prefetch", "useRouter",
    "usePathname", "useSearchParams", "redirect(", "permanentRedirect", "notFound(",
    "generateMetadata", "metadataBase", "generateViewport", "sitemap.ts", "robots.ts",
    "opengraph-image", "ImageResponse", "MetadataRoute",
)
EXAMPLES = {
    "static-params-page": ("generateStaticParams", "params"),
    "typed-generate-metadata": ("generateMetadata", "Metadata"),
    "sitemap": ("MetadataRoute.Sitemap",),
    "not-found-page": ("notFound()",),
    "client-search-params": ("'use client'", "useSearchParams"),
}
ANY_TYPE = re.compile(r"(?::|\bas|<|\|)\s*any\b")
MARKER_LEAD = r"^[ \t]*(?:[-*][ \t]+|#{3,4}[ \t]+)?(?:\*\*)?"
DONT_MARKER = re.compile(MARKER_LEAD + r"Don['’]t\b", re.MULTILINE)
DO_MARKER = re.compile(MARKER_LEAD + r"Do(?=[:*\s])(?![ \t]+not\b)", re.MULTILINE)
FENCE_LINE = re.compile(r"^[ \t]*```", re.MULTILINE)
PARENT_LINK = re.compile(r"\]\(\.\./nextjs\.md(?:#[^)]*)?\)")
SAFE_PATH_GUARD = "function toSafePath"
ORIGIN_COMPARE = re.compile(r"\.origin\s*!==")
PREFIX_ONLY_CHECK = re.compile(r"startsWith\(\s*'//'\s*\)")
SERVER_ACTION = re.compile(r"export async function \w+\([^)]*\)[^{]*\{", re.MULTILINE)
WRITE_CALL = re.compile(r"\b(?:save|insert|update|delete|create)[A-Z]\w*\(")
AUTHZ_CHECK = re.compile(r"\bif \([^)]*\b(?:role|can[A-Z]\w*)\b")
LAYOUT_EXPORT = re.compile(r"export default function \w*Layout\(")
GROUP_IN_ROUTE_LITERAL = re.compile(r"(?:Page|Layout)Props<'[^']*\(")
ROUTER_CALL = re.compile(r"\brouter\.(?:push|replace)\(\s*([^,)]+)")
ROUTE_TYPE_IMPORT = re.compile(r"import type \{[^}]*\bRoute\b[^}]*\} from 'next'")


def _text() -> str:
    return h.read(TOPIC)


def _rule_ids() -> list[str]:
    return [rule_id for rule_id, _ in h.rule_items(_text())]


def test_routing_topic_replaces_the_stub():
    assert not h.is_stub(_text())


def test_routing_topic_has_at_least_fifteen_rt_rules():
    assert len(_rule_ids()) >= MIN_RULES


def test_routing_topic_cites_no_other_topics_rule_ids():
    ids = _rule_ids()
    assert ids and all(rule_id.startswith(f"{PREFIX}-") for rule_id in ids)
    others = "|".join(prefix for prefix, _ in h.TOPICS.values() if prefix != PREFIX)
    assert re.findall(rf"\b(?:{others})-\d+\b", _text()) == []


def test_routing_topic_covers_required_concepts():
    assert h.missing_terms(_text(), TERMS) == []


@pytest.mark.parametrize("needles", list(EXAMPLES.values()), ids=list(EXAMPLES))
def test_routing_topic_has_worked_example(needles):
    assert h.has_block_with(_text(), *needles), needles


def test_routing_topic_examples_never_type_as_any():
    blocks = h.code_blocks(_text(), ("ts", "tsx"))
    assert [body for _, body in blocks if ANY_TYPE.search(body)] == []


def test_rules_state_the_parallel_route_default_requirement():
    text = _text()
    assert "default" in h.section(text, "Rules")
    assert any(
        "default.tsx" in item and "@" in item and "build" in item
        for _, item in h.rule_items(text)
    )


def test_canonical_layout_is_linked_from_the_topic():
    assert PARENT_LINK.search(_text())


def test_version_notes_name_the_major_and_link_nextjs_org():
    text = _text()
    notes = h.section(text, "Version notes")
    major = h.as_of_version(text).split(".")[0]
    assert notes.strip()
    assert f"Next.js {major}" in notes
    assert "https://nextjs.org/" in notes


def test_every_checklist_item_names_an_rt_rule():
    items = h.checklist_items(_text())
    assert len(items) >= MIN_CHECKLIST_ITEMS
    assert [line for line in items if f"{PREFIX}-" not in line] == []


def _anti_pattern_chunks(section: str) -> list[str]:
    starts = [match.start() for match in DONT_MARKER.finditer(section)]
    ends = starts[1:] + [len(section)]
    return [section[begin:end] for begin, end in zip(starts, ends)]


def test_every_anti_pattern_pairs_a_dont_with_a_do():
    chunks = _anti_pattern_chunks(h.section(_text(), "Anti-patterns"))
    assert len(chunks) >= MIN_ANTI_PATTERNS
    for chunk in chunks:
        assert DO_MARKER.search(chunk), chunk[:120]
        assert len(FENCE_LINE.findall(chunk)) >= 4, chunk[:120]
        assert f"{PREFIX}-" in chunk, chunk[:120]


def test_not_confirmed_section_lists_the_urls_checked():
    section = h.section(_text(), "Not confirmed by the docs")
    assert "https://nextjs.org/" in section


# --- FIX1 regression guards (REVIEW1 R1-A1, R1-A10, R1-A11, R1-A12, R1-A17) ------------------


def _ts_blocks() -> list[str]:
    return [body for _, body in h.code_blocks(_text(), ("ts", "tsx"))]


def test_safe_path_guard_resolves_the_url_and_compares_origins():
    """R1-A1: a prefix check lets ?next=/%09/evil.com through; the URL parser drops the tab."""
    guards = [body for body in _ts_blocks() if SAFE_PATH_GUARD in body]
    assert guards, "no example defines the toSafePath redirect guard"
    for body in guards:
        assert "new URL(" in body, "the guard must parse the value with new URL(value, base)"
        assert ORIGIN_COMPARE.search(body), "the guard must compare the parsed origin"
        assert not PREFIX_ONLY_CHECK.search(body), "a '//' prefix check is not a same-origin check"


def _server_action_bodies() -> list[str]:
    bodies = []
    for block in _ts_blocks():
        if "'use server'" not in block:
            continue
        starts = [match.end() for match in SERVER_ACTION.finditer(block)]
        bodies += [block[begin:end] for begin, end in zip(starts, starts[1:] + [len(block)], strict=True)]
    return bodies


def test_every_server_action_authenticates_and_authorizes_before_writing():
    """R1-A10: a Server Action is a public POST endpoint; verifySession() and a role check come first."""
    bodies = _server_action_bodies()
    assert bodies, "no 'use server' example found"
    for body in bodies:
        write = WRITE_CALL.search(body)
        assert write, body[:120]
        auth = body.find("await verifySession()")
        authz = AUTHZ_CHECK.search(body)
        assert 0 <= auth < write.start(), f"verifySession() must precede the write: {body[:120]}"
        assert authz and auth < authz.start() < write.start(), f"authorize before the write: {body[:120]}"


def test_layout_examples_use_layout_props_with_group_free_literals():
    """R1-A11: layouts use LayoutProps, and route literals drop (group) folders."""
    layouts = [body for body in _ts_blocks() if LAYOUT_EXPORT.search(body)]
    assert layouts
    for body in layouts:
        assert "LayoutProps<'/" in body, body[:120]
        assert "children: React.ReactNode" not in body, body[:120]
    assert GROUP_IN_ROUTE_LITERAL.findall(_text()) == []
    not_confirmed = h.section(_text(), "Not confirmed by the docs")
    assert "route literals" not in not_confirmed.lower()


def test_router_calls_type_non_literal_hrefs_as_route():
    """R1-A12: with typedRoutes on, a non-literal router.push/replace argument must be a Route."""
    calls = 0
    for body in _ts_blocks():
        for match in ROUTER_CALL.finditer(body):
            calls += 1
            arg = match.group(1).strip()
            if arg[0] in "'\"" or "as Route" in arg:
                continue
            assert ROUTE_TYPE_IMPORT.search(body), f"{arg!r} is not typed as Route: {body[:120]}"
    assert calls


def test_sources_list_the_as_of_version_source():
    """R1-A17: the as-of version 16.3.8 needs its own source in ## Sources."""
    assert h.VERSION_SOURCE_URL in h.source_urls(_text())
