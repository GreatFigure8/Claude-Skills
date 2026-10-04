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
