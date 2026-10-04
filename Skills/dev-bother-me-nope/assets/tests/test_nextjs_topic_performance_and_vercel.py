"""Topic tests for ``references/nextjs/performance-and-vercel.md`` (rule prefix ``PERF``).

The generic contract (section order, rule format, citations, floors, Sources, hygiene) is
enforced for every non-stub topic by ``test_nextjs_reference.py``. This file adds what only this
topic owes: it is no longer a stub, it is deep enough, it names the required concepts, it carries
the five required TypeScript examples, every Vercel number sits next to a vercel.com or nextjs.org
link, the runtime-choice rule links vercel.com, the version notes and checklist are
reviewer-ready, and the file never tells an agent to run a Vercel deploy command.

Offline, standard library plus pytest. Parsing lives in ``nextjs_doc_helpers``.
"""

import re
from functools import cache

import nextjs_doc_helpers as h
import pytest

TOPIC = h.TOPICS_DIR / "performance-and-vercel.md"
PREFIX = "PERF"
MIN_RULES = 15
MIN_ANTI_PATTERNS = 3
MIN_FENCES_PER_ANTI_PATTERN = 2

TERMS = (
    "next/image",
    "sizes",
    "remotePatterns",
    "preload",
    "priority",
    "next/font",
    "next/script",
    "strategy",
    "next/dynamic",
    "optimizePackageImports",
    "serverExternalPackages",
    "bundle-analyzer",
    "Turbopack",
    "reactCompiler",
    "Fluid compute",
    "maxDuration",
    "region",
    "runtime",
    "Edge",
    "Node.js",
    "vercel.json",
    "request body",
)

# Needles that one ts/tsx fence must contain together, per required example.
EXAMPLES = {
    "responsive-image": ("next/image", "sizes"),
    "self-hosted-font": ("next/font",),
    "remote-allow-list": ("NextConfig", "remotePatterns"),
    "third-party-script": ("next/script", "strategy"),
    "route-duration": ("maxDuration",),
}

UNIT_TOKENS = ("MB", " GB", "seconds", "minutes")
PLATFORM_LINK = re.compile(r"https://(?:vercel\.com|nextjs\.org)/")
DEPLOY_COMMAND = re.compile(
    r"\bvercel\s+(?:deploy|--prod|promote|rollback|redeploy|alias|remove|--regions"
    r"|env\s+(?:add|rm))\b"
)
ANY_TYPE = re.compile(r":\s*any\b|<any>|\bas any\b")
DO_LINE = re.compile(r"^\*\*Do\*\*", re.MULTILINE)
PERF_ID = re.compile(r"\bPERF-\d+\b")
FENCE_MARK = "```"
ITEM_START = re.compile(r"^(?:[-*]|\d+\.)\s")

# Each pattern is an API the Next.js 16 docs deprecate or remove; none may appear in a Pattern.
DEPRECATED_IN_PATTERNS = (
    re.compile(r"(?<![A-Za-z])priority(?![A-Za-z])"),
    re.compile(r"runtime\s*=\s*['\"]edge['\"]"),
    re.compile(r"preferredRegion"),
    re.compile(r"\bdomains\s*:"),
    re.compile(r"next/legacy/image"),
    re.compile(r"experimental\s*:\s*\{\s*turbopack"),
)


@cache
def _text() -> str:
    return h.read(TOPIC)


def _prose_lines(text: str) -> tuple[str, ...]:
    """Lines outside fenced code blocks."""
    kept = []
    in_fence = False
    for line in text.splitlines():
        if line.lstrip().startswith(FENCE_MARK):
            in_fence = not in_fence
        elif not in_fence:
            kept.append(line)
    return tuple(kept)


def _item_groups(lines: tuple[str, ...]) -> tuple[tuple[str, ...], ...]:
    """Group prose lines: a column-0 list item with its indented lines, or a line on its own."""
    groups: list[list[str]] = []
    for line in lines:
        indented = line[:1].isspace()
        if indented and groups and groups[-1][0] and ITEM_START.match(groups[-1][0]):
            groups[-1].append(line)
        else:
            groups.append([line])
    return tuple(tuple(group) for group in groups)


def _unlinked_unit_lines(text: str) -> tuple[str, ...]:
    """Prose lines carrying a unit token whose line and list item hold no platform link."""
    found = []
    for group in _item_groups(_prose_lines(text)):
        has_link = any(PLATFORM_LINK.search(line) for line in group)
        found.extend(
            line for line in group if any(token in line for token in UNIT_TOKENS) and not has_link
        )
    return tuple(found)


def _ts_bodies(text: str) -> tuple[str, ...]:
    return tuple(body for _, body in h.code_blocks(text, ("ts", "tsx")))


# --- AC2: not a stub, deep enough -----------------------------------------------------------


def test_performance_topic_is_not_a_stub():
    assert not h.is_stub(_text())


def test_performance_topic_has_at_least_15_perf_rules():
    rules = h.rule_items(_text())
    assert len(rules) >= MIN_RULES
    assert all(rule_id.startswith(f"{PREFIX}-") for rule_id, _ in rules)


# --- AC3: required concepts ------------------------------------------------------------------


def test_performance_topic_names_every_required_concept():
    assert h.missing_terms(_text(), TERMS) == []


# --- AC4: required TypeScript examples ---------------------------------------------------------


@pytest.mark.parametrize("needles", EXAMPLES.values(), ids=EXAMPLES.keys())
def test_performance_topic_has_required_typescript_example(needles):
    assert h.has_block_with(_text(), *needles)


def test_typescript_examples_use_no_any_type():
    offenders = [body for body in _ts_bodies(_text()) if ANY_TYPE.search(body)]
    assert not offenders, f"{len(offenders)} ts/tsx block(s) use the any type"


# --- AC5: every Vercel number carries a platform link ------------------------------------------


def test_every_vercel_number_line_carries_a_platform_link():
    assert _unlinked_unit_lines(_text()) == ()


def test_unit_line_check_flags_a_number_without_a_link():
    assert _unlinked_unit_lines("- Max 4.5 MB per body\n") == ("- Max 4.5 MB per body",)


def test_unit_line_check_accepts_a_link_elsewhere_in_the_list_item():
    sample = (
        "1. **PERF-1** Keep payloads small ([limits](https://vercel.com/docs/functions/limitations)).\n"
        "   The cap is 4.5 MB.\n"
        "\n"
        "```text\n"
        "- 99 MB inside a fence is ignored\n"
        "```\n"
    )
    assert _unlinked_unit_lines(sample) == ()


def test_unit_line_check_counts_nested_bullets_as_part_of_the_item():
    sample = (
        "- Image changes ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16)):\n"
        "  - the cache lifetime is now 4 hours\n"
    )
    assert _unlinked_unit_lines(sample) == ()


def test_unit_line_check_does_not_let_one_item_vouch_for_the_next():
    sample = (
        "- Linked item ([doc](https://vercel.com/docs/limits))\n"
        "- A plain item with 30 minutes\n"
    )
    assert _unlinked_unit_lines(sample) == ("- A plain item with 30 minutes",)


# --- AC6: runtime choice -------------------------------------------------------------------


def test_runtime_choice_rule_names_edge_with_a_vercel_link():
    rules = h.section(_text(), "Rules")
    assert "Edge" in rules
    assert "https://vercel.com/" in rules
    both = [
        rule_id
        for rule_id, item in h.rule_items(_text())
        if "Edge" in item and "https://vercel.com/" in item
    ]
    assert both, "no single rule names Edge and links vercel.com"


# --- AC7: version notes -----------------------------------------------------------------------


def test_version_notes_name_the_major_and_link_nextjs():
    major = h.major(h.as_of_version(_text()))
    notes = h.section(_text(), "Version notes")
    assert notes.strip()
    assert f"Next.js {major}" in notes
    assert "https://nextjs.org/" in notes


# --- AC8: reviewer-ready ------------------------------------------------------------------------


def test_every_checklist_item_names_a_perf_rule():
    lines = [line for line in _text().splitlines() if "- [ ]" in line]
    assert lines, "no checklist items"
    missing = [line for line in lines if f"{PREFIX}-" not in line]
    assert not missing, missing


def test_checklist_rule_ids_exist_in_rules():
    known = {rule_id for rule_id, _ in h.rule_items(_text())}
    cited = set(PERF_ID.findall(h.section(_text(), "Review checklist")))
    assert cited, "the checklist cites no rule"
    assert cited <= known, f"checklist cites unknown rules: {sorted(cited - known)}"


def test_anti_patterns_pair_each_dont_with_a_do():
    antis = h.anti_patterns(_text())
    assert len(antis) >= MIN_ANTI_PATTERNS
    for title, body in antis:
        assert DO_LINE.search(body), f"{title!r} has no **Do** line"
        fences = len(h.code_blocks(body))
        assert fences >= MIN_FENCES_PER_ANTI_PATTERN, f"{title!r} has {fences} fence(s)"


# --- drift guard and the bmn hard line -----------------------------------------------------------


def test_patterns_code_uses_no_deprecated_api():
    patterns = h.section(_text(), "Patterns")
    hits = [
        (regex.pattern, body)
        for _, body in h.code_blocks(patterns, ("ts", "tsx"))
        for regex in DEPRECATED_IN_PATTERNS
        if regex.search(body)
    ]
    assert not hits, f"deprecated APIs in Patterns: {[pattern for pattern, _ in hits]}"


def test_topic_never_instructs_a_vercel_deploy():
    assert DEPLOY_COMMAND.search(_text()) is None
