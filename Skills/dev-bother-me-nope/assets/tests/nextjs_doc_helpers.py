"""Shared parsing helpers and contract constants for the Next.js reference tests.

This module is non-collected (its name does not start with ``test_``), stdlib only, and is
imported by ``test_nextjs_*.py``. The reference it describes is ``references/nextjs.md`` plus
the nine topic files in ``references/nextjs/``; ``## Authoring contract`` in ``nextjs.md``
states the contract these helpers and the generic tests enforce.

Conventions: every function is pure and returns an immutable value (tuple, frozenset, str,
None, bool), except ``missing_terms``, which returns a ``list``. A function that looks up a
named section raises ``LookupError`` (``section``) or, for the list-returning section readers
(``source_urls``, ``malformed_source_lines``, ``rule_items``, ``checklist_items``,
``anti_patterns``), returns ``()`` when the section is absent, so the contract test for the
missing section reports it instead of an unrelated crash. The contract readers look up their
section at H2 only, and ``section`` picks the shallowest matching heading. Headings, URLs and
list markers inside fenced code blocks (backtick or tilde fences) are never structure.
"""

from __future__ import annotations

import re
from pathlib import Path
from types import MappingProxyType
from urllib.parse import urlsplit

# --- paths ------------------------------------------------------------------------------

PLUGIN = Path(__file__).resolve().parents[2]
REFERENCES_DIR = PLUGIN / "skills" / "dev-bother-me-nope" / "references"
NEXTJS_MD = REFERENCES_DIR / "nextjs.md"
TOPICS_DIR = REFERENCES_DIR / "nextjs"

# --- contract constants ----------------------------------------------------------------

_TOPIC_ROWS = (
    ("typescript.md", ("TS", "typescript-config-and-typing-patterns")),
    ("routing-and-metadata.md", ("RT", "app-router-routing-and-metadata")),
    ("rendering-and-caching.md", ("RC", "rendering-caching-and-streaming-ssr")),
    ("data-fetching-and-mutations.md", ("DF", "data-fetching-server-actions-and-forms")),
    ("route-handlers-and-apis.md", ("API", "route-handlers-and-api-design")),
    ("sse-and-streaming.md", ("SSE", "server-sent-events-and-streaming-responses")),
    ("proxy-auth-and-security.md", ("SEC", "proxy-auth-and-security")),
    ("performance-and-vercel.md", ("PERF", "performance-and-vercel-platform")),
    ("testing-and-observability.md", ("TEST", "testing-errors-and-observability")),
)
TOPICS = MappingProxyType(dict(_TOPIC_ROWS))

ALLOWED_SOURCE_HOSTS = frozenset(
    (
        "nextjs.org",
        "vercel.com",
        "react.dev",
        "typescriptlang.org",
        "www.typescriptlang.org",
        "developer.mozilla.org",
        "html.spec.whatwg.org",
        "zod.dev",
        "vitest.dev",
        "playwright.dev",
    )
)
PRIMARY_SOURCE_HOSTS = frozenset(("nextjs.org", "vercel.com"))

AS_OF_DATE = "2026-10-04"
NEXTJS_VERSION = "16.3.8"
VERSION_SOURCE_URL = "https://nextjs.org/blog/september-2026-security-release"

ENTRY_TITLE = "Next.js + TypeScript standard"
ENTRY_SECTIONS = (
    "How bmn agents use this",
    "Non-negotiables",
    "Folder structure",
    "Topic index",
    "Authoring contract",
    "Version notes",
    "Sources",
)
TOPIC_SECTIONS = (
    "Scope",
    "Rules",
    "Patterns",
    "Anti-patterns",
    "Version notes",
    "Review checklist",
    "Not confirmed by the docs",
    "Sources",
)
OPTIONAL_TOPIC_SECTION = "Not confirmed by the docs"
SUBJECT_WORDS = frozenset(("The", "This", "It", "You", "We", "There", "A", "An"))
CONVENTION_TAG = "(convention)"

MAX_LINES = 800
MIN_RULES = 12
MIN_TS_FENCES = 4
MIN_ANTI_PATTERNS = 3
MIN_CHECKLIST_ITEMS = 8
MIN_PRIMARY_SOURCES = 3
MAX_NON_NEGOTIABLES = 15

# --- patterns --------------------------------------------------------------------------

URL_RE = re.compile(r"""https?://[^\s<>()\[\]"'`|]+""")
AS_OF_RE = re.compile(
    r"^> As of Next\.js (?P<version>\d+\.\d+\.\d+), verified (?P<date>\d{4}-\d{2}-\d{2})\.$"
)
STUB_RE = re.compile(r"^> Stub: pending story `(?P<slug>[a-z0-9-]+)`\.$")
RULE_RE = re.compile(r"^\*\*(?P<id>(?P<prefix>[A-Z]+)-(?P<n>\d+))\*\*\s+(?P<body>.+)")
RULE_ID_RE = re.compile(
    r"\b(?:" + "|".join(re.escape(prefix) for prefix, _ in TOPICS.values()) + r")-\d+\b"
)

_HEADING_RE = re.compile(r"^ {0,3}(?P<hashes>#{1,6})\s+(?P<title>.+?)\s*$")
_H1_RE = re.compile(r"^#\s+(?P<title>.+?)\s*$")
_FENCE_OPEN_RE = re.compile(r"^(?P<fence>`{3,}|~{3,})(?P<info>.*)$")
_INLINE_CODE_RE = re.compile(r"(?<!`)(`+)(?!`).+?(?<!`)\1(?!`)")
_NUMBER_MARKER_RE = re.compile(r"^\d+\.\s+")
_NUMBERED_START_RE = re.compile(r"^\d+\. ")
_BULLET_START_RE = re.compile(r"^- ")
_LINK_TARGET_RE = re.compile(r"""\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)""")
_SCHEME_RE = re.compile(r"^[A-Za-z][A-Za-z0-9+.\-]*:")
_SEPARATOR_CELL_RE = re.compile(r":?-+:?")
_DONT_RE = re.compile(r"^Don['’]t")
_ITEM_OR_HEADING_RE = re.compile(r"^(?:\d+\. |#{3,6} )")
_LINE_COMMENT_RE = re.compile(r"(?:^|(?<=\s))//.*$", re.MULTILINE)
_BLOCK_COMMENT_RE = re.compile(r"/\*.*?\*/", re.DOTALL)
ANY_TYPE_RE = re.compile(
    r":\s*any\b"  # annotation: x: any
    r"|\bas\s+any\b"  # assertion: value as any
    r"|<\s*any\s*[,>]"  # first type argument: <any>, Array<any>
    r"|,\s*any\s*[,>\]]"  # later type argument or tuple member: Record<string, any>
    r"|\bany\s*\[\]"  # array: any[]
    r"|[|&]\s*any\b|\bany\s*[|&]"  # union or intersection member
    r"|=\s*any\s*(?:;|$)",  # alias: type X = any
    re.MULTILINE,
)
_TRAILING_PUNCTUATION = ".,;:!?"

# --- small builders --------------------------------------------------------------------


def read(path: Path) -> str:
    """UTF-8 text of a file."""
    return Path(path).read_text(encoding="utf-8")


def topic_paths() -> tuple[Path, ...]:
    """The nine topic files, in ``TOPICS`` order."""
    return tuple(TOPICS_DIR / name for name in TOPICS)


def as_of_line_for(version: str) -> str:
    return f"> As of Next.js {version}, verified {AS_OF_DATE}."


def stub_marker_for(slug: str) -> str:
    return f"> Stub: pending story `{slug}`."


def major(version: str) -> str:
    """``"16.3.8"`` -> ``"16"``."""
    return version.split(".")[0]


# --- fences ----------------------------------------------------------------------------


def _closes_fence(stripped: str, fence: str) -> bool:
    """True for a line made only of ``fence``'s character, at least as long as ``fence``."""
    run = stripped.rstrip()
    return len(run) >= len(fence) and set(run) == {fence[0]}


def _fence_spans(lines: list[str]) -> tuple[tuple[int, int, str, bool], ...]:
    """(first line, last line, lang, closed) of each fence, 0-based and inclusive.

    An opener starts (left-stripped) with three or more backticks or three or more tildes. It
    closes on a left-stripped line made only of the same character, in an equal or longer
    run. An unclosed fence runs to the end of the text.
    """
    spans = []
    start = fence = None
    lang = ""
    for index, line in enumerate(lines):
        stripped = line.lstrip()
        if start is None:
            opener = _FENCE_OPEN_RE.match(stripped)
            if opener:
                info = opener.group("info").strip()
                lang = info.split()[0] if info else ""
                start, fence = index, opener.group("fence")
        elif _closes_fence(stripped, fence):
            spans.append((start, index, lang, True))
            start = None
    if start is not None:
        spans.append((start, len(lines) - 1, lang, False))
    return tuple(spans)


def _fenced_indexes(lines: list[str]) -> frozenset[int]:
    """Indexes of every line inside a fence, delimiter lines included."""
    return frozenset(i for start, end, _, _ in _fence_spans(lines) for i in range(start, end + 1))


def code_blocks(
    text: str, langs: tuple[str, ...] | None = None
) -> tuple[tuple[str, str], ...]:
    """``(lang, body)`` for each fence; ``lang`` is ``""`` for a bare fence."""
    lines = text.splitlines()
    blocks = []
    for start, end, lang, closed in _fence_spans(lines):
        if langs is not None and lang not in langs:
            continue
        body_end = end if closed else end + 1
        blocks.append((lang, "\n".join(lines[start + 1 : body_end])))
    return tuple(blocks)


def bare_fence_lines(text: str) -> tuple[int, ...]:
    """1-based line numbers of fence openers that carry no language tag."""
    return tuple(start + 1 for start, _, lang, _ in _fence_spans(text.splitlines()) if not lang)


def has_block_with(text: str, *needles: str, langs: tuple[str, ...] = ("ts", "tsx")) -> bool:
    """True when one fence of ``langs`` contains every needle (exact substring)."""
    return any(all(needle in body for needle in needles) for _, body in code_blocks(text, langs))


def is_stub(text: str) -> bool:
    return stub_slug(text) is not None


def stub_slug(text: str) -> str | None:
    """The owning story slug from a stub marker line outside fences, else None."""
    lines = text.splitlines()
    fenced = _fenced_indexes(lines)
    for index, line in enumerate(lines):
        match = None if index in fenced else STUB_RE.match(line.rstrip())
        if match:
            return match.group("slug")
    return None


# --- headings and sections ---------------------------------------------------------------


def _heads(lines: list[str]) -> tuple[tuple[int, int, str], ...]:
    """(line index, level, title) of every heading outside fences."""
    fenced = _fenced_indexes(lines)
    found = []
    for index, line in enumerate(lines):
        match = None if index in fenced else _HEADING_RE.match(line)
        if match:
            found.append((index, len(match.group("hashes")), match.group("title")))
    return tuple(found)


def _body_of(lines: list[str], heads: tuple[tuple[int, int, str], ...], position: int) -> str:
    index, level, _ = heads[position]
    end = len(lines)
    for next_index, next_level, _ in heads[position + 1 :]:
        if next_level <= level:
            end = next_index
            break
    return "\n".join(lines[index + 1 : end])


def headings(text: str, level: int) -> tuple[str, ...]:
    """Titles of the ``#``-x-``level`` headings outside fences, in order."""
    return tuple(title for _, found, title in _heads(text.splitlines()) if found == level)


def section(text: str, heading: str, *, prefix: bool = False, level: int | None = None) -> str:
    """Body of the heading titled ``heading`` (or starting with it when ``prefix``).

    Only headings of ``level`` match when it is given. Otherwise the shallowest matching
    heading wins, and the first of those, so a ``### Sources`` inside ``## Patterns`` never
    shadows ``## Sources``. The body runs to the next heading of the same or a higher level.
    Raises ``LookupError`` when no heading matches.
    """
    lines = text.splitlines()
    heads = _heads(lines)
    matches = tuple(
        (found, position)
        for position, (_, found, title) in enumerate(heads)
        if (title == heading or (prefix and title.startswith(heading)))
        and (level is None or found == level)
    )
    if not matches:
        raise LookupError(f"no heading {heading!r}")
    return _body_of(lines, heads, min(matches)[1])


def _section_or_empty(text: str, heading: str) -> str:
    """Body of the H2 ``heading`` (a contract section), or ``""`` when there is none."""
    try:
        return section(text, heading, level=2)
    except LookupError:
        return ""


def _subsections(section_text: str, level: int) -> tuple[tuple[str, str], ...]:
    lines = section_text.splitlines()
    heads = _heads(lines)
    return tuple(
        (title, _body_of(lines, heads, position))
        for position, (_, found, title) in enumerate(heads)
        if found == level
    )


def h1(text: str) -> str | None:
    """The title when the first non-blank line is ``# Title``, else None."""
    for line in text.splitlines():
        if line.strip():
            match = _H1_RE.match(line)
            return match.group("title") if match else None
    return None


def as_of_line(text: str) -> str | None:
    """The first non-blank line after the H1 line, or None when there is no H1 first."""
    if h1(text) is None:
        return None
    lines = iter(text.splitlines())
    for line in lines:
        if line.strip():
            break
    return next((line.rstrip() for line in lines if line.strip()), None)


def as_of_version(text: str) -> str | None:
    """The Next.js version in the as-of line right after the H1, else None."""
    line = as_of_line(text)
    match = AS_OF_RE.match(line) if line is not None else None
    return match.group("version") if match else None


# --- prose, urls, links ---------------------------------------------------------------------


def prose(text: str) -> str:
    """Text with fenced blocks and inline code spans removed."""
    lines = text.splitlines()
    fenced = _fenced_indexes(lines)
    kept = (_INLINE_CODE_RE.sub("", line) for i, line in enumerate(lines) if i not in fenced)
    return "\n".join(kept)


def normalize_url(url: str) -> str:
    """Strip trailing ``.,;:!?`` and the ``#fragment``."""
    return url.rstrip(_TRAILING_PUNCTUATION).split("#")[0].rstrip(_TRAILING_PUNCTUATION)


def url_host(url: str) -> str:
    return urlsplit(url).hostname or ""


def all_urls(text: str) -> tuple[str, ...]:
    """Normalised URLs in prose (outside fences and inline code), in order."""
    return tuple(normalize_url(url) for url in URL_RE.findall(prose(text)))


def relative_links(text: str) -> tuple[str, ...]:
    """Prose ``](target)`` targets with no scheme and no leading ``#``, anchor dropped."""
    found = []
    for target in _LINK_TARGET_RE.findall(prose(text)):
        path = target.split("#")[0]
        if path and not _SCHEME_RE.match(target):
            found.append(path)
    return tuple(found)


def missing_terms(text: str, terms) -> list[str]:
    """Terms not found, case-insensitively, anywhere in ``text`` (code included)."""
    haystack = text.lower()
    return [term for term in terms if term.lower() not in haystack]


# --- sources -----------------------------------------------------------------------------


def source_urls(text: str) -> tuple[str, ...]:
    """Normalised first URL of each bullet in ``## Sources``; duplicates kept."""
    found = []
    for bullet in bullet_items(_section_or_empty(text, "Sources")):
        urls = URL_RE.findall(bullet)
        if urls:
            found.append(normalize_url(urls[0]))
    return tuple(found)


def malformed_source_lines(text: str) -> tuple[str, ...]:
    """Non-blank ``## Sources`` lines that are not ``- `` bullets holding one https URL."""
    bad = []
    for line in _section_or_empty(text, "Sources").splitlines():
        urls = URL_RE.findall(line)
        well_formed = line.startswith("- ") and len(urls) == 1 and urls[0].startswith("https://")
        if line.strip() and not well_formed:
            bad.append(line.rstrip())
    return tuple(bad)


def cites_source(item_text: str) -> bool:
    """True when the item carries the convention tag or a link to an allowed host, in prose.

    A tag or URL inside inline code or a fence is an example, not a citation.
    """
    if CONVENTION_TAG in prose(item_text):
        return True
    return any(url_host(url) in ALLOWED_SOURCE_HOSTS for url in all_urls(item_text))


# --- lists, rules, tables ------------------------------------------------------------------


def _items(section_text: str, start_re: re.Pattern[str]) -> tuple[str, ...]:
    lines = section_text.splitlines()
    fenced = _fenced_indexes(lines)
    items: list[list[str]] = []
    for index, line in enumerate(lines):
        if index not in fenced and start_re.match(line):
            items.append([line])
        elif items:
            items[-1].append(line)
    return tuple("\n".join(item).strip() for item in items)


def numbered_items(section_text: str) -> tuple[str, ...]:
    """Items starting ``N. `` at column 0, marker kept; each runs to the next item."""
    return _items(section_text, _NUMBERED_START_RE)


def bullet_items(section_text: str) -> tuple[str, ...]:
    """Items starting ``- `` at column 0 (``- [ ]`` included), marker kept."""
    return _items(section_text, _BULLET_START_RE)


def rule_items(text: str) -> tuple[tuple[str, str], ...]:
    """``(rule_id, item_text)`` for each numbered item in ``## Rules``.

    ``item_text`` is the item without its ``N. `` marker, so ``RULE_RE`` matches it directly;
    ``rule_id`` is ``""`` when it does not match.
    """
    pairs = []
    for item in numbered_items(_section_or_empty(text, "Rules")):
        body = _NUMBER_MARKER_RE.sub("", item, count=1)
        match = RULE_RE.match(body)
        pairs.append((match.group("id") if match else "", body))
    return tuple(pairs)


def _indented_fence_indexes(lines: list[str]) -> frozenset[int]:
    """Indexes of every line inside a fence whose opener is indented (a list item's fence)."""
    return frozenset(
        i
        for start, end, _, _ in _fence_spans(lines)
        if lines[start][:1].isspace()
        for i in range(start, end + 1)
    )


def stray_rule_lines(text: str) -> tuple[str, ...]:
    """Lines under ``## Rules`` that are not part of a numbered item or an H3+ heading.

    A line belongs to an item when it is indented, or inside a fence an indented item line
    opened. Everything else at column 0 is stray: prose, and a fence opened at column 0 with
    its body and closer.
    """
    lines = _section_or_empty(text, "Rules").splitlines()
    owned = _indented_fence_indexes(lines)
    return tuple(
        line.rstrip()
        for index, line in enumerate(lines)
        if index not in owned
        and line.strip()
        and not line[0].isspace()
        and not _ITEM_OR_HEADING_RE.match(line)
    )


def uses_any_type(code: str) -> bool:
    """True when TypeScript ``code`` uses the ``any`` type outside comments."""
    bare = _LINE_COMMENT_RE.sub("", _BLOCK_COMMENT_RE.sub("", code))
    return ANY_TYPE_RE.search(bare) is not None


def rule_ids_cited(text: str) -> tuple[str, ...]:
    """Rule ids (any topic prefix) written in prose, in order."""
    return tuple(RULE_ID_RE.findall(prose(text)))


def anti_patterns(text: str) -> tuple[tuple[str, str], ...]:
    """``(title, body)`` for each ``### Don't…`` H3 inside ``## Anti-patterns``."""
    body = _section_or_empty(text, "Anti-patterns")
    return tuple((title, sub) for title, sub in _subsections(body, 3) if _DONT_RE.match(title))


def checklist_items(text: str) -> tuple[str, ...]:
    """The ``- [ ] `` items in ``## Review checklist``."""
    body = _section_or_empty(text, "Review checklist")
    return tuple(item for item in bullet_items(body) if item.startswith("- [ ] "))


def _split_cells(line: str) -> tuple[str, ...]:
    inner = line.strip().removeprefix("|")
    if not inner.endswith("\\|"):
        inner = inner.removesuffix("|")
    cells, buffer, in_code, index = [], [], False, 0
    while index < len(inner):
        char = inner[index]
        if char == "\\" and inner[index + 1 : index + 2] == "|":
            buffer.append("|")
            index += 2
            continue
        in_code = in_code != (char == "`")
        if char == "|" and not in_code:
            cells.append("".join(buffer).strip())
            buffer = []
        else:
            buffer.append(char)
        index += 1
    cells.append("".join(buffer).strip())
    return tuple(cells)


def table_rows(section_text: str) -> tuple[tuple[str, ...], ...]:
    """Pipe-table rows, header first, separator row skipped, cells stripped."""
    rows = (_split_cells(line) for line in section_text.splitlines() if line.strip().startswith("|"))
    return tuple(
        cells for cells in rows if not all(_SEPARATOR_CELL_RE.fullmatch(cell) for cell in cells)
    )
