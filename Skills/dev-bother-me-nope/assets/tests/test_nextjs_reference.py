"""Contract tests for the Next.js + TypeScript reference (``references/nextjs.md`` + topics).

``nextjs.md`` is the entry point: principles, the canonical folder tree, a topic index and the
authoring contract. The nine topic files in ``references/nextjs/`` follow that contract. The
generic topic tests below enforce it for every topic file that is no longer a stub; a stub is
skipped with a reason and nothing else is skipped. Topic stories add their own
``test_nextjs_topic_<x>.py`` that asserts their file is no longer a stub.

Offline, standard library plus pytest. Parsing lives in ``nextjs_doc_helpers``.
"""

import re
from collections import Counter
from functools import cache

import nextjs_doc_helpers as h
import pytest

ALL_FILES = (h.NEXTJS_MD, *h.topic_paths())
TOPIC_NAMES = tuple(h.TOPICS)

STUB_TITLES = {
    "typescript.md": "TypeScript in Next.js",
    "routing-and-metadata.md": "Routing and metadata",
    "rendering-and-caching.md": "Rendering, caching and streaming SSR",
    "data-fetching-and-mutations.md": "Data fetching, Server Actions and forms",
    "route-handlers-and-apis.md": "Route Handlers and API design",
    "sse-and-streaming.md": "Server-Sent Events and streaming responses",
    "proxy-auth-and-security.md": "Proxy, auth and security",
    "performance-and-vercel.md": "Performance and the Vercel platform",
    "testing-and-observability.md": "Testing, errors and observability",
}

# Jonathan's draft tree, one path per entry below the root, in draft order.
DRAFT_PATHS = (
    "src",
    "src/app",
    "src/app/(auth)",
    "src/app/(auth)/login",
    "src/app/(auth)/login/page.tsx",
    "src/app/(auth)/layout.tsx",
    "src/app/(dashboard)",
    "src/app/(dashboard)/dashboard",
    "src/app/(dashboard)/dashboard/page.tsx",
    "src/app/api",
    "src/app/api/webhooks",
    "src/app/api/webhooks/route.ts",
    "src/app/layout.tsx",
    "src/app/page.tsx",
    "src/app/globals.css",
    "src/features",
    "src/features/auth",
    "src/features/auth/components",
    "src/features/auth/hooks",
    "src/features/auth/services",
    "src/features/auth/tests",
    "src/features/billing",
    "src/shared",
    "src/shared/components",
    "src/shared/hooks",
    "src/shared/utils",
    "src/shared/types",
    "src/shared/tests",
    "src/lib",
    "src/lib/prisma.ts",
    "src/lib/actions",
    "src/lib/auth.ts",
    "src/lib/tests",
    "src/tests",
    "public",
    "next.config.ts",
    "tsconfig.json",
)

# The draft's comments, verbatim except "Tests files" -> "Test files".
DRAFT_COMMENTS = {
    "src/app": "NEXT.JS APP ROUTER (Routing Layer only)",
    "src/app/(auth)": "Route Group: Grouping without affecting URL",
    "src/app/(auth)/login/page.tsx": "Route page component",
    "src/app/(auth)/layout.tsx": "Auth-specific shared UI",
    "src/app/api": "API Route Handlers (REST endpoints)",
    "src/app/layout.tsx": "Global Root Layout",
    "src/app/page.tsx": "Homepage",
    "src/app/globals.css": "Global Tailwind/CSS rules",
    "src/features": "FEATURE MODULES (The core of your business logic)",
    "src/features/auth": "Isolated domain logic",
    "src/features/auth/components": "Feature-specific UI components",
    "src/features/auth/hooks": "Feature-specific hooks",
    "src/features/auth/services": "Feature API calls / logic",
    "src/features/auth/tests": "Test files",
    "src/shared": "REUSABLE LAYER (Cross-feature code)",
    "src/shared/components": "Base UI primitives (Button, Input, Modal)",
    "src/shared/hooks": "Global React hooks (useDebounce, useAuth)",
    "src/shared/utils": "Pure utility functions (cn formatting)",
    "src/shared/types": "Shared TypeScript definitions",
    "src/shared/tests": "Test files",
    "src/lib": "THIRD-PARTY CONFIGS / SERVER LAYER",
    "src/lib/prisma.ts": "Database client singletons",
    "src/lib/actions": 'Server Actions ("use server" files)',
    "src/lib/auth.ts": "Auth configurations (e.g., NextAuth/Auth.js)",
    "src/lib/tests": "Test files",
    "src/tests": "Tests for pages/routes/etc.",
    "public": "Static assets (images, fonts, favicons)",
    "next.config.ts": "Next.js configurations",
    "tsconfig.json": "TypeScript configurations",
}

# Entries this standard adds to the draft tree, each grounded in a file-convention page.
ADDED_SOURCES = {
    "src/proxy.ts": "https://nextjs.org/docs/app/api-reference/file-conventions/proxy",
    "src/instrumentation.ts": (
        "https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation"
    ),
}

TREE_LINE_RE = re.compile(
    r"^(?P<indent>(?:│   |    )*)(?:├── |└── )(?P<name>\S+)(?P<rest>.*)$"
)
CONTRACT_LINE_RE = re.compile(r"^(?:│   |    )*(?:├── |└── )\S")
SPACER_RE = re.compile(r"^[│ ]+$")
TREE_INDENT_WIDTH = 4
INDEX_FILE_CELL_RE = re.compile(r"^\[`(?P<file>[^`]+)`\]\(nextjs/(?P<target>[^)]+)\)$")
TODO_RE = re.compile(r"\b(?:TODO|TBD)\b")
UNNUMBERED_ITEM_RE = re.compile(r"^(?P<number>\d+)\. ")
HEADING_LINE_RE = re.compile(r"^#{3,6} ")
STRAY_RULE_ID_RE = re.compile(r"\*\*[A-Z]+-\d+\*\*")
PLUGIN_ROOT_PATH = (
    "${CLAUDE_PLUGIN_ROOT}/skills/dev-bother-me-nope/references/nextjs.md"
)


# --- helpers ---------------------------------------------------------------------------


@cache
def _text(path):
    return h.read(path)


def _entry():
    return _text(h.NEXTJS_MD)


def _norm(text):
    """Whitespace-collapsed text with ``*`` stripped, for phrase matching."""
    return re.sub(r"\s+", " ", text.replace("*", "")).strip()


def _assert_has_phrases(text, phrases):
    flat = _norm(text).lower()
    missing = [phrase for phrase in phrases if _norm(phrase).lower() not in flat]
    assert not missing, f"missing phrases: {missing}"


def _topic(name):
    """Text of a topic file; skips (with a reason) when it is still a stub."""
    text = _text(h.TOPICS_DIR / name)
    if h.is_stub(text):
        pytest.skip(f"{name} is a stub pending {h.TOPICS[name][1]}")
    return text


def _rule_prefix(name):
    return h.TOPICS[name][0]


def _tree_lines():
    section = h.section(_entry(), "Folder structure")
    blocks = h.code_blocks(section)
    assert len(blocks) == 1, f"expected exactly one fence, found {len(blocks)}"
    lang, body = blocks[0]
    assert lang == "text", f"the tree fence must be tagged text, not {lang!r}"
    return body.splitlines()


def _tree_entries():
    """(path, comment) for every entry below the root, in tree order."""
    stack, entries = [], []
    for line in _tree_lines()[1:]:
        if not line.strip() or SPACER_RE.match(line):
            continue
        match = TREE_LINE_RE.match(line)
        assert match, f"not a tree line: {line!r}"
        depth = len(match.group("indent")) // TREE_INDENT_WIDTH
        stack = [*stack[:depth], match.group("name").rstrip("/")]
        rest = match.group("rest").strip()
        comment = rest.removeprefix("# ") if rest.startswith("# ") else ""
        entries.append(("/".join(stack), comment))
    return tuple(entries)


def _tree_paths():
    return tuple(path for path, _ in _tree_entries())


def _index_rows():
    rows = h.table_rows(h.section(_entry(), "Topic index"))
    assert rows, "the Topic index has no table"
    return rows[0], rows[1:]


# --- AC2: entry point shape ---------------------------------------------------------------


def test_entry_point_h1_is_the_standard_title():
    assert h.h1(_entry()) == h.ENTRY_TITLE
    assert h.headings(_entry(), 1) == (h.ENTRY_TITLE,)


def test_entry_point_as_of_line_directly_follows_h1():
    assert h.as_of_line(_entry()) == h.as_of_line_for(h.NEXTJS_VERSION)
    assert h.as_of_version(_entry()) == h.NEXTJS_VERSION


def test_entry_point_h2_sections_in_order():
    assert h.headings(_entry(), 2) == h.ENTRY_SECTIONS


# --- AC3: folder tree kept and cleaned ----------------------------------------------------


def test_folder_tree_is_one_text_fence():
    lines = _tree_lines()
    assert lines[0] == "my-app/"
    assert len(lines) > len(DRAFT_PATHS)


def test_folder_tree_keeps_every_draft_entry_at_its_path():
    missing = [path for path in DRAFT_PATHS if path not in _tree_paths()]
    assert not missing, f"draft entries missing or moved: {missing}"


def test_folder_tree_keeps_draft_order():
    remaining = iter(_tree_paths())
    out_of_order = [path for path in DRAFT_PATHS if path not in remaining]
    assert not out_of_order, f"draft order changed at: {out_of_order[:3]}"


def test_folder_tree_keeps_draft_comments():
    comments = dict(_tree_entries())
    lost = [
        f"{path}: {wanted!r}"
        for path, wanted in DRAFT_COMMENTS.items()
        if wanted.lower() not in comments.get(path, "").lower()
    ]
    assert not lost, f"draft comments changed: {lost}"


def test_folder_tree_uses_box_drawing_lines_only():
    lines = _tree_lines()
    stray = [
        line
        for line in lines[1:]
        if line.strip() and not CONTRACT_LINE_RE.match(line) and not SPACER_RE.match(line)
    ]
    assert not stray, f"lines that are neither tree lines nor spacers: {stray}"
    assert not [line for line in lines if "|" in line], "ASCII | in the tree"


def test_folder_tree_comments_use_space_hash_space():
    for line in _tree_lines()[1:]:
        match = TREE_LINE_RE.match(line)
        if not match:
            continue
        assert "#" not in match.group("name"), line
        assert re.fullmatch(r"(?:\s+# \S.*)?", match.group("rest")), line


def test_folder_tree_additions_are_marked_and_sourced():
    comments = dict(_tree_entries())
    added = [path for path in _tree_paths() if path not in DRAFT_PATHS]
    assert sorted(added) == sorted(ADDED_SOURCES), added
    sources = h.source_urls(_entry())
    for path, url in ADDED_SOURCES.items():
        assert comments[path].startswith("added:"), f"{path} is not marked '# added:'"
        assert url in sources, f"{path}: {url} is not listed in Sources"


def test_placement_rules_follow_the_tree_and_cite_or_tag():
    folder = h.section(_entry(), "Folder structure")
    assert h.headings(folder, 3) == ("Placement rules",)
    assert folder.index("```text") < folder.index("### Placement rules")
    items = h.numbered_items(h.section(folder, "Placement rules"))
    assert len(items) >= 5
    for item in items:
        assert h.cites_source(item), f"placement rule without a link or (convention): {item[:70]}"
        hosts = {h.url_host(url) for url in h.all_urls(item)}
        assert hosts <= h.PRIMARY_SOURCE_HOSTS, f"layout facts are backed by nextjs.org: {hosts}"


def test_placement_rules_scope_the_layout_to_new_projects():
    placement = h.section(_entry(), "Placement rules")
    _assert_has_phrases(
        placement,
        ("canonical for new projects", "an existing repo keeps its established layout"),
    )


# --- AC4: topic index --------------------------------------------------------------------


def test_topic_index_columns():
    header, _ = _index_rows()
    assert header == ("File", "Prefix", "Covers", "Read when")


def test_topic_index_rows_match_topics_in_order():
    _, rows = _index_rows()
    assert [len(row) for row in rows] == [4] * len(h.TOPICS)
    listed = []
    for row in rows:
        match = INDEX_FILE_CELL_RE.match(row[0])
        assert match, f"File cell is not [`<file>`](nextjs/<file>): {row[0]!r}"
        assert match.group("file") == match.group("target")
        assert row[1].startswith("`") and row[1].endswith("`")
        assert row[2] and row[3], f"empty Covers or Read when cell in {row[0]}"
        listed.append((match.group("file"), row[1].strip("`")))
    assert listed == [(name, prefix) for name, (prefix, _) in h.TOPICS.items()]


def test_topic_index_links_point_into_nextjs_dir():
    links = h.relative_links(h.section(_entry(), "Topic index"))
    assert links and all(link.startswith("nextjs/") for link in links), links


def test_every_topic_file_on_disk_has_an_index_row():
    on_disk = {path.name for path in h.TOPICS_DIR.glob("*.md")}
    _, rows = _index_rows()
    indexed = {INDEX_FILE_CELL_RE.match(row[0]).group("file") for row in rows}
    assert on_disk - indexed == set(), f"orphan topic files: {sorted(on_disk - indexed)}"


def test_every_indexed_topic_file_exists():
    _, rows = _index_rows()
    for row in rows:
        name = INDEX_FILE_CELL_RE.match(row[0]).group("file")
        assert (h.TOPICS_DIR / name).is_file(), f"indexed file does not exist: {name}"


# --- AC5: stubs ----------------------------------------------------------------------------


def test_stubs_have_h1_as_of_marker_and_version_source():
    problems = []
    for name in TOPIC_NAMES:
        text = _text(h.TOPICS_DIR / name)
        if not h.is_stub(text):
            continue
        slug = h.TOPICS[name][1]
        if h.h1(text) != STUB_TITLES[name]:
            problems.append(f"{name}: H1 is {h.h1(text)!r}")
        if h.as_of_line(text) != h.as_of_line(_entry()):
            problems.append(f"{name}: as-of line differs from nextjs.md")
        if h.stub_marker_for(slug) not in text.splitlines():
            problems.append(f"{name}: marker line missing")
        if h.VERSION_SOURCE_URL not in h.source_urls(text):
            problems.append(f"{name}: version source missing from Sources")
    assert not problems, problems


@pytest.mark.parametrize("name", TOPIC_NAMES)
def test_stub_marker_names_the_owning_story(name):
    assert h.stub_slug(_text(h.TOPICS_DIR / name)) in (None, h.TOPICS[name][1])


# --- AC6: authoring contract, enforced on every non-stub topic ---------------------------------


@pytest.mark.parametrize("name", TOPIC_NAMES)
def test_topic_sections_follow_the_contract(name):
    text = _topic(name)
    required = tuple(s for s in h.TOPIC_SECTIONS if s != h.OPTIONAL_TOPIC_SECTION)
    assert h.headings(text, 2) in (required, h.TOPIC_SECTIONS)
    assert h.headings(text, 1) == (h.h1(text),)


@pytest.mark.parametrize("name", TOPIC_NAMES)
def test_topic_rules_are_well_formed_and_numbered(name):
    text = _topic(name)
    prefix = _rule_prefix(name)
    rules = h.rule_items(text)
    assert rules, "no numbered rules under ## Rules"
    numbered = h.numbered_items(h.section(text, "Rules"))
    assert len(rules) == len(numbered), "rule_items and numbered_items disagree on the rule count"
    for position, ((rule_id, item), raw) in enumerate(zip(rules, numbered), start=1):
        match = h.RULE_RE.match(item)
        assert match, f"not '**{prefix}-n** …': {item[:60]!r}"
        assert match.group("prefix") == prefix, f"{rule_id} is not a {prefix} id"
        assert match.group("n") == str(position), f"{rule_id} should be {prefix}-{position}"
        assert UNNUMBERED_ITEM_RE.match(raw).group("number") == str(position), raw[:30]
        first_word = match.group("body").split()[0]
        assert first_word not in h.SUBJECT_WORDS, f"{rule_id} starts with {first_word!r}"
    stray = [
        line
        for line in h.prose(h.section(text, "Rules")).splitlines()
        if line.strip() and not line[0].isspace()
        and not UNNUMBERED_ITEM_RE.match(line) and not HEADING_LINE_RE.match(line)
    ]
    assert not stray, f"only list items belong in ## Rules: {stray[:2]}"


@pytest.mark.parametrize("name", TOPIC_NAMES)
def test_topic_rules_cite_a_source_or_convention(name):
    uncited = [
        rule_id for rule_id, item in h.rule_items(_topic(name)) if not h.cites_source(item)
    ]
    assert not uncited, f"rules with neither an allowed-host link nor (convention): {uncited}"


@pytest.mark.parametrize("name", TOPIC_NAMES)
def test_topic_meets_the_floors(name):
    text = _topic(name)
    assert len(h.rule_items(text)) >= h.MIN_RULES
    assert len(h.code_blocks(text, ("ts", "tsx"))) >= h.MIN_TS_FENCES
    antis = h.anti_patterns(text)
    assert len(antis) >= h.MIN_ANTI_PATTERNS
    bare = [title for title, body in antis if not h.code_blocks(body)]
    assert not bare, f"Don't items without a fenced block: {bare}"
    assert len(h.checklist_items(text)) >= h.MIN_CHECKLIST_ITEMS


@pytest.mark.parametrize("name", TOPIC_NAMES)
def test_topic_cites_only_its_own_rule_ids(name):
    prefix = _rule_prefix(name)
    foreign = sorted({i for i in h.rule_ids_cited(_topic(name)) if i.split("-")[0] != prefix})
    assert not foreign, f"link to the other topic file instead of citing its ids: {foreign}"


@pytest.mark.parametrize("name", TOPIC_NAMES)
def test_topic_version_notes_name_the_major(name):
    major = h.major(h.as_of_version(_entry()))
    assert f"Next.js {major}" in h.section(_topic(name), "Version notes")


@pytest.mark.parametrize("name", TOPIC_NAMES)
def test_topic_not_confirmed_section_lists_urls_and_no_rules(name):
    text = _topic(name)
    if h.OPTIONAL_TOPIC_SECTION not in h.headings(text, 2):
        return
    body = h.section(text, h.OPTIONAL_TOPIC_SECTION)
    items = (*h.bullet_items(body), *h.numbered_items(body))
    assert items, "the section lists nothing"
    bare = [item[:60] for item in items if not h.all_urls(item)]
    assert not bare, f"items without the URL that was checked: {bare}"
    assert not STRAY_RULE_ID_RE.search(body), "nothing in this section is stated as a rule"


def test_rule_ids_are_unique_across_topic_files():
    ids = [
        rule_id
        for name in TOPIC_NAMES
        if not h.is_stub(_text(h.TOPICS_DIR / name))
        for rule_id, _ in h.rule_items(_text(h.TOPICS_DIR / name))
    ]
    duplicates = sorted(i for i, count in Counter(ids).items() if count > 1)
    assert not duplicates, f"duplicate rule ids: {duplicates}"


def test_authoring_contract_states_the_contract():
    body = h.section(_entry(), "Authoring contract")
    phrases = (
        *h.TOPIC_SECTIONS,
        "N. **<PREFIX>-<n>**",
        h.CONVENTION_TAG,
        f"at least {h.MIN_RULES} rules",
        f"at least {h.MIN_TS_FENCES}",
        f"at least {h.MIN_ANTI_PATTERNS}",
        f"at least {h.MIN_CHECKLIST_ITEMS}",
        f"{h.MAX_LINES} lines",
        "Stub: pending story",
        *sorted(h.ALLOWED_SOURCE_HOSTS),
        "only nextjs.org or vercel.com",
        "Not confirmed by the docs",
        "### Don't",
        "- [ ]",
    )
    _assert_has_phrases(body, phrases)


# --- AC7: sources and grounding -------------------------------------------------------------


@pytest.mark.parametrize("path", ALL_FILES, ids=lambda path: path.name)
def test_sources_is_a_bullet_list_of_unique_https_urls(path):
    text = _text(path)
    assert h.malformed_source_lines(text) == ()
    urls = h.source_urls(text)
    assert urls, "## Sources lists no URL"
    assert len(set(urls)) == len(urls), f"duplicate Sources URLs: {sorted(set(urls))}"
    assert all(url.startswith("https://") for url in urls)


@pytest.mark.parametrize("path", ALL_FILES, ids=lambda path: path.name)
def test_every_url_host_is_allowed(path):
    text = _text(path)
    hosts = {h.url_host(url) for url in (*h.all_urls(text), *h.source_urls(text))}
    assert hosts <= h.ALLOWED_SOURCE_HOSTS, sorted(hosts - h.ALLOWED_SOURCE_HOSTS)


@pytest.mark.parametrize("path", ALL_FILES, ids=lambda path: path.name)
def test_every_prose_url_is_listed_in_sources(path):
    text = _text(path)
    unlisted = sorted(set(h.all_urls(text)) - set(h.source_urls(text)))
    assert not unlisted, f"URLs in prose but not in ## Sources: {unlisted}"


@pytest.mark.parametrize("path", ALL_FILES, ids=lambda path: path.name)
def test_primary_source_floor(path):
    text = _text(path)
    required = 0 if h.is_stub(text) else h.MIN_PRIMARY_SOURCES
    primary = [u for u in h.source_urls(text) if h.url_host(u) in h.PRIMARY_SOURCE_HOSTS]
    assert len(primary) >= required, f"{len(primary)} nextjs.org/vercel.com sources, need {required}"


# --- AC8: as-of consistency ------------------------------------------------------------------


@pytest.mark.parametrize("name", TOPIC_NAMES)
def test_topic_as_of_matches_the_entry_point(name):
    text = _text(h.TOPICS_DIR / name)
    version = h.as_of_version(text)
    assert version is not None, "no as-of line right after the H1"
    assert version == h.as_of_version(_entry())
    assert h.as_of_line(text) == h.as_of_line_for(version)


# --- AC9: file hygiene -----------------------------------------------------------------------


@pytest.mark.parametrize("path", ALL_FILES, ids=lambda path: path.name)
def test_file_is_at_most_800_lines(path):
    assert len(_text(path).splitlines()) <= h.MAX_LINES


@pytest.mark.parametrize("path", ALL_FILES, ids=lambda path: path.name)
def test_no_bare_code_fences(path):
    assert h.bare_fence_lines(_text(path)) == ()


@pytest.mark.parametrize("path", ALL_FILES, ids=lambda path: path.name)
def test_relative_links_resolve(path):
    broken = [link for link in h.relative_links(_text(path)) if not (path.parent / link).exists()]
    assert not broken, f"links to files that do not exist: {broken}"


@pytest.mark.parametrize("path", ALL_FILES, ids=lambda path: path.name)
def test_no_todo_or_tbd(path):
    assert TODO_RE.search(_text(path)) is None


# --- AC10: entry point content ---------------------------------------------------------------


def test_non_negotiables_are_few_linked_and_cited():
    items = h.numbered_items(h.section(_entry(), "Non-negotiables"))
    assert 1 <= len(items) <= h.MAX_NON_NEGOTIABLES
    for item in items:
        topics = [link for link in h.relative_links(item) if link.startswith("nextjs/")]
        assert topics, f"no nextjs/<file> link: {item[:70]}"
        unknown = [link for link in topics if link.removeprefix("nextjs/") not in h.TOPICS]
        assert not unknown, f"links to a file that is not a topic: {unknown}"
        assert h.cites_source(item), f"no allowed-host link or (convention): {item[:70]}"


def test_how_agents_use_this_covers_every_agent():
    body = h.section(_entry(), "How bmn agents use this")
    _assert_has_phrases(
        body,
        (
            "Planner reads `nextjs.md` plus the topic files the Topic index routes the story to",
            "always includes `typescript.md` and `testing-and-observability.md`",
            "lists the rule ids it applies in the plan",
            "Coder follows those rules",
            "Reviewer cites the violated rule id in each finding",
            "Fixer names the rule id its fix restores",
            PLUGIN_ROOT_PATH,
        ),
    )


def test_how_agents_use_this_states_precedence():
    body = h.section(_entry(), "How bmn agents use this")
    _assert_has_phrases(
        body,
        (
            "`nextjs.md` wins over `nextjs-fullstack-standards`",
            "an existing repo's established conventions win",
        ),
    )


def test_entry_version_notes_cite_and_point_to_topics():
    body = h.section(_entry(), "Version notes")
    assert f"Next.js {h.major(h.NEXTJS_VERSION)}" in body
    items = h.bullet_items(body)
    assert len(items) >= 5
    for item in items:
        primary = [u for u in h.all_urls(item) if h.url_host(u) in h.PRIMARY_SOURCE_HOSTS]
        assert primary, f"no nextjs.org/vercel.com source: {item[:70]}"
        owners = [link for link in h.relative_links(item) if link.startswith("nextjs/")]
        assert owners, f"does not point to the topic file that owns it: {item[:70]}"
        assert all(link.removeprefix("nextjs/") in h.TOPICS for link in owners), owners
