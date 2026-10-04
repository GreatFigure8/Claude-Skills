"""Unit tests for nextjs_doc_helpers, the parsing module the Next.js reference tests share.

Every helper is exercised on inline sample text: a stub, a well-formed topic, a rule without a
citation, a bare code fence and a disallowed host. Nothing here reads the reference files, so
the helper API is pinned before any content depends on it. Offline, standard library plus pytest.
"""

import ast
from pathlib import Path

import nextjs_doc_helpers as h
import pytest

FENCE = "`" * 3

STUB = """\
# Routing and metadata

> As of Next.js 16.3.8, verified 2026-10-04.

> Stub: pending story `app-router-routing-and-metadata`.

## Sources

- https://nextjs.org/blog/september-2026-security-release
"""

TOPIC = f"""\
# TypeScript in Next.js

> As of Next.js 16.3.8, verified 2026-10-04.

## Scope

Typing pages, layouts and handlers.

## Rules

1. **TS-1** Type pages with the generated `PageProps` helper
   ([page](https://nextjs.org/docs/app/api-reference/file-conventions/page)).
2. **TS-2** Validate untrusted input at the boundary. (convention)

## Patterns

{FENCE}ts
export default async function Page(props: PageProps<"/blog/[slug]">) {{
  const {{ slug }} = await props.params;
}}
{FENCE}

{FENCE}json
{{ "compilerOptions": {{ "strict": true }} }}
{FENCE}

## Anti-patterns

### Don't read params synchronously

{FENCE}tsx
const {{ slug }} = params;
{FENCE}

## Version notes

Next.js 16 needs TypeScript 5.1 or newer.

## Review checklist

- [ ] Pages use `PageProps`.
- [ ] Input is validated at the boundary.

## Sources

- https://nextjs.org/docs/app/api-reference/file-conventions/page#props — page props
- https://nextjs.org/docs/app/guides/upgrading/version-16
"""

UNCITED_RULE = """\
## Rules

1. **TS-1** Await params before reading them.
2. **TS-2** Validate input at the boundary. (convention)
"""

BARE_FENCE = f"""\
Intro

{FENCE}
plain
{FENCE}

{FENCE}ts
const x = 1;
{FENCE}
"""

BAD_HOST = "Prose cites [x](https://example.org/page) and `https://example.com/code`.\n"

EXPECTED_TOPICS = (
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


# --- constants ----------------------------------------------------------------------


def test_paths_point_at_the_reference_tree():
    assert h.PLUGIN.name == "dev-bother-me-nope"
    assert (h.PLUGIN / ".claude-plugin" / "plugin.json").is_file()
    assert h.REFERENCES_DIR == h.PLUGIN / "skills" / "dev-bother-me-nope" / "references"
    assert h.NEXTJS_MD == h.REFERENCES_DIR / "nextjs.md"
    assert h.TOPICS_DIR == h.REFERENCES_DIR / "nextjs"


def test_topics_match_the_story_table_in_order():
    assert tuple(h.TOPICS.items()) == EXPECTED_TOPICS
    assert tuple(path.name for path in h.topic_paths()) == tuple(h.TOPICS)
    assert all(path.parent == h.TOPICS_DIR for path in h.topic_paths())


def test_topics_mapping_is_read_only():
    with pytest.raises(TypeError):
        h.TOPICS["extra.md"] = ("X", "x")  # type: ignore[index]


def test_allowed_source_hosts_are_exactly_the_ten_hosts():
    assert isinstance(h.ALLOWED_SOURCE_HOSTS, frozenset)
    assert h.ALLOWED_SOURCE_HOSTS == frozenset(
        {
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
        }
    )
    assert h.PRIMARY_SOURCE_HOSTS == frozenset({"nextjs.org", "vercel.com"})


def test_version_constants():
    assert h.AS_OF_DATE == "2026-10-04"
    assert h.NEXTJS_VERSION == "16.3.8"
    assert h.VERSION_SOURCE_URL == "https://nextjs.org/blog/september-2026-security-release"
    assert h.ENTRY_TITLE == "Next.js + TypeScript standard"
    assert h.ENTRY_SECTIONS == (
        "How bmn agents use this",
        "Non-negotiables",
        "Folder structure",
        "Topic index",
        "Authoring contract",
        "Version notes",
        "Sources",
    )
    assert h.TOPIC_SECTIONS == (
        "Scope",
        "Rules",
        "Patterns",
        "Anti-patterns",
        "Version notes",
        "Review checklist",
        "Not confirmed by the docs",
        "Sources",
    )
    assert h.OPTIONAL_TOPIC_SECTION == "Not confirmed by the docs"
    assert h.SUBJECT_WORDS == frozenset({"The", "This", "It", "You", "We", "There", "A", "An"})
    assert h.CONVENTION_TAG == "(convention)"
    assert (h.MAX_LINES, h.MIN_RULES, h.MIN_TS_FENCES) == (800, 12, 4)
    assert (h.MIN_ANTI_PATTERNS, h.MIN_CHECKLIST_ITEMS) == (3, 8)
    assert (h.MIN_PRIMARY_SOURCES, h.MAX_NON_NEGOTIABLES) == (3, 15)


def test_regex_constants_have_the_documented_shape():
    assert h.URL_RE.groups == 0
    assert h.URL_RE.findall("a https://nextjs.org/docs/x, [b](http://e.org/y) `c`") == [
        "https://nextjs.org/docs/x,",
        "http://e.org/y",
    ]
    assert h.AS_OF_RE.match(h.as_of_line_for("16.3.8"))
    assert h.RULE_ID_RE.findall("TS-1 SEC-22 PERF-3 API-4 SSE-5 TEST-6 RT-7 RC-8 DF-9 XX-1") == [
        "TS-1",
        "SEC-22",
        "PERF-3",
        "API-4",
        "SSE-5",
        "TEST-6",
        "RT-7",
        "RC-8",
        "DF-9",
    ]


def test_line_builders_and_major():
    assert h.as_of_line_for("16.3.8") == "> As of Next.js 16.3.8, verified 2026-10-04."
    assert h.stub_marker_for("some-slug") == "> Stub: pending story `some-slug`."
    assert h.major("16.3.8") == "16"


# --- reading and stubs -----------------------------------------------------------------


def test_read_returns_utf8_text(tmp_path):
    path = tmp_path / "sample.md"
    path.write_text("café — naïve\n", encoding="utf-8")
    assert h.read(path) == "café — naïve\n"


def test_is_stub_detects_the_marker_line():
    assert h.is_stub(STUB) is True
    assert h.is_stub(TOPIC) is False


def test_is_stub_ignores_a_marker_inside_a_code_fence():
    text = f"# T\n\n{FENCE}text\n{h.stub_marker_for('x-y')}\n{FENCE}\n"
    assert h.is_stub(text) is False
    assert h.stub_slug(text) is None


def test_stub_slug_returns_the_owning_slug():
    assert h.stub_slug(STUB) == "app-router-routing-and-metadata"
    assert h.stub_slug(TOPIC) is None
    assert h.stub_slug(f"# T\n\n{h.stub_marker_for('abc-1')}\n") == "abc-1"


# --- headings and sections -----------------------------------------------------------------


def test_section_returns_body_up_to_the_next_same_level_heading():
    rules = h.section(TOPIC, "Rules")
    assert "**TS-1**" in rules and "**TS-2**" in rules
    assert "PageProps<" not in rules and "## Patterns" not in rules
    antis = h.section(TOPIC, "Anti-patterns")
    assert "### Don't read params synchronously" in antis
    assert "Version notes" not in antis


def test_section_prefix_match_finds_a_heading_by_its_start():
    text = "# T\n\n### 0 · INTAKE — stack\n\nbody one\n\n### 1 · SPLIT\n\nbody two\n"
    assert h.section(text, "0 · INTAKE", prefix=True).strip() == "body one"
    with pytest.raises(LookupError):
        h.section(text, "0 · INTAKE")


def test_section_ignores_headings_inside_fences():
    text = f"# T\n\n## Patterns\n\n{FENCE}text\n## Rules\n{FENCE}\n\nafter\n\n## Rules\n\nreal\n"
    assert h.headings(text, 2) == ("Patterns", "Rules")
    assert "after" in h.section(text, "Patterns")
    assert h.section(text, "Rules").strip() == "real"


def test_section_raises_for_a_missing_heading():
    with pytest.raises(LookupError, match="Nope"):
        h.section(TOPIC, "Nope")


def test_headings_lists_titles_by_level_outside_fences():
    assert h.headings(TOPIC, 1) == ("TypeScript in Next.js",)
    assert h.headings(TOPIC, 2) == (
        "Scope",
        "Rules",
        "Patterns",
        "Anti-patterns",
        "Version notes",
        "Review checklist",
        "Sources",
    )
    assert h.headings(TOPIC, 3) == ("Don't read params synchronously",)


def test_h1_and_as_of_line_read_the_top_of_the_file():
    assert h.h1(TOPIC) == "TypeScript in Next.js"
    assert h.as_of_line(TOPIC) == "> As of Next.js 16.3.8, verified 2026-10-04."
    assert h.h1("intro\n\n# Late\n") is None
    assert h.as_of_line("intro\n\n# Late\n") is None


def test_as_of_version_parses_the_line_right_after_h1():
    assert h.as_of_version(TOPIC) == "16.3.8"
    assert h.as_of_version(STUB) == "16.3.8"


def test_as_of_version_is_none_when_anything_sits_between():
    text = "# T\n\nSome intro.\n\n> As of Next.js 16.3.8, verified 2026-10-04.\n"
    assert h.as_of_version(text) is None
    assert h.as_of_version("# T\n\n> As of Next.js 16.3, verified 2026-10-04.\n") is None
    assert h.as_of_version("no heading at all\n") is None


# --- code fences -------------------------------------------------------------------------------


def test_code_blocks_returns_lang_and_body_pairs():
    assert h.code_blocks(TOPIC, ("ts",)) == (
        (
            "ts",
            (
                'export default async function Page(props: PageProps<"/blog/[slug]">) {\n'
                "  const { slug } = await props.params;\n}"
            ),
        ),
    )
    assert [lang for lang, _ in h.code_blocks(TOPIC)] == ["ts", "json", "tsx"]
    nested = f"````md\n{FENCE}inner\nx\n{FENCE}\n````\n"
    assert h.code_blocks(nested) == (("md", f"{FENCE}inner\nx\n{FENCE}"),)
    assert h.code_blocks(f"{FENCE}ts title=a.ts\nx\n{FENCE}\n") == (("ts", "x"),)


def test_code_blocks_reports_a_bare_fence_with_an_empty_lang():
    assert h.code_blocks(BARE_FENCE) == (("", "plain"), ("ts", "const x = 1;"))
    assert h.bare_fence_lines(BARE_FENCE) == (3,)
    assert h.bare_fence_lines(TOPIC) == ()


def test_has_block_with_needs_every_needle_in_one_block():
    assert h.has_block_with(TOPIC, "PageProps", "await props.params") is True
    assert h.has_block_with(TOPIC, "PageProps", "const { slug } = params") is False
    assert h.has_block_with(TOPIC, "pageprops") is False
    assert h.has_block_with(TOPIC, "PageProps", "Review checklist") is False


def test_has_block_with_respects_langs():
    assert h.has_block_with(TOPIC, "strict") is False
    assert h.has_block_with(TOPIC, "strict", langs=("json",)) is True
    assert h.has_block_with(TOPIC, "const { slug } = params") is True
    assert h.has_block_with(TOPIC, "const { slug } = params", langs=("ts",)) is False


# --- prose, urls and links -----------------------------------------------------------------


def test_prose_drops_fenced_blocks_and_inline_code():
    text = f"Keep `https://example.com/a` out.\n{FENCE}bash\ncurl https://example.com/b\n{FENCE}\nend\n"
    assert h.prose(text) == "Keep  out.\nend"
    assert h.prose("a ``b`c`` d `e` f") == "a  d  f"


def test_normalize_url_strips_trailing_punctuation_and_fragment():
    assert h.normalize_url("https://nextjs.org/docs#intro.") == "https://nextjs.org/docs"
    assert h.normalize_url("https://nextjs.org/docs,") == "https://nextjs.org/docs"
    assert h.normalize_url("https://nextjs.org/docs#") == "https://nextjs.org/docs"


def test_all_urls_skip_code_fences_and_inline_code():
    text = (
        "Read [docs](https://nextjs.org/docs/app). See `https://example.com/x` and\n"
        f"{FENCE}bash\ncurl https://example.com/y\n{FENCE}\nand https://vercel.com/docs.\n"
    )
    assert h.all_urls(text) == ("https://nextjs.org/docs/app", "https://vercel.com/docs")


def test_url_host_flags_a_disallowed_host():
    assert h.url_host("https://www.typescriptlang.org/tsconfig") == "www.typescriptlang.org"
    assert h.url_host("not a url") == ""
    hosts = {h.url_host(url) for url in h.all_urls(BAD_HOST)}
    assert hosts == {"example.org"}
    assert hosts - h.ALLOWED_SOURCE_HOSTS == {"example.org"}


def test_source_urls_lists_bullets_in_order_without_fragments():
    assert h.source_urls(TOPIC) == (
        "https://nextjs.org/docs/app/api-reference/file-conventions/page",
        "https://nextjs.org/docs/app/guides/upgrading/version-16",
    )
    dup = "## Sources\n\n- https://nextjs.org/a.\n- https://nextjs.org/a#x\n- plain text\n"
    assert h.source_urls(dup) == ("https://nextjs.org/a", "https://nextjs.org/a")
    assert h.source_urls("# T\n\nno sources section\n") == ()


def test_malformed_source_lines_flags_prose_and_multi_url_bullets():
    text = (
        "## Sources\n\n- https://nextjs.org/a\nJust a prose line\n"
        "- https://a.org and https://b.org\n- no url here\n* https://nextjs.org/b\n"
        "- http://nextjs.org/insecure\n\n- https://nextjs.org/ok — with a note\n"
    )
    assert h.malformed_source_lines(text) == (
        "Just a prose line",
        "- https://a.org and https://b.org",
        "- no url here",
        "* https://nextjs.org/b",
        "- http://nextjs.org/insecure",
    )
    assert h.malformed_source_lines(TOPIC) == ()
    assert h.malformed_source_lines("# T\n") == ()


def test_relative_links_strip_anchors_and_skip_absolute_urls():
    text = (
        "See [a](nextjs/typescript.md#rules), [b](https://nextjs.org/docs), [c](#local),\n"
        "[d](../x.md), [m](mailto:a@b.co) and `[e](skip.md)`.\n"
        f"{FENCE}md\n[f](skipped-too.md)\n{FENCE}\n"
    )
    assert h.relative_links(text) == ("nextjs/typescript.md", "../x.md")


def test_missing_terms_is_case_insensitive_over_the_whole_file():
    text = f"Await params.\n{FENCE}ts\nconst slug = await props.params;\n{FENCE}\n"
    assert h.missing_terms(text, ("AWAIT", "props.PARAMS", "cookies()", "Nope")) == [
        "cookies()",
        "Nope",
    ]
    assert h.missing_terms(text, ("await",)) == []
    assert isinstance(h.missing_terms(text, ()), list)


# --- lists, rules and tables -----------------------------------------------------------------


def test_numbered_and_bullet_items_ignore_markers_inside_fences():
    body = f"1. one\n   cont\n{FENCE}md\n2. not an item\n{FENCE}\n2. two\n"
    items = h.numbered_items(body)
    assert len(items) == 2
    assert items[0].startswith("1. one\n   cont") and "2. not an item" in items[0]
    assert items[1] == "2. two"
    assert h.bullet_items("intro\n- a\n  more\n\n- [ ] b\n  - nested\n") == (
        "- a\n  more",
        "- [ ] b\n  - nested",
    )
    assert h.numbered_items("no list here") == ()


def test_rule_items_parse_id_and_text_with_continuations():
    items = h.rule_items(TOPIC)
    assert [rule_id for rule_id, _ in items] == ["TS-1", "TS-2"]
    first = items[0][1]
    assert first.startswith("**TS-1** Type pages")
    assert "file-conventions/page" in first
    assert h.RULE_RE.match(first).group("prefix") == "TS"
    assert h.RULE_RE.match(first).group("n") == "1"
    assert h.rule_items("# T\n\nno rules\n") == ()


def test_rule_items_keep_a_malformed_item_with_an_empty_id():
    text = "# T\n\n## Rules\n\n1. Await params.\n2. **TS-2** Fine. (convention)\n\n## Patterns\n"
    assert h.rule_items(text) == (("", "Await params."), ("TS-2", "**TS-2** Fine. (convention)"))


def test_rule_ids_cited_reads_prose_only():
    text = f"See TS-1 and `TS-2`, also SEC-12.\n{FENCE}text\nAPI-3\n{FENCE}\n"
    assert h.rule_ids_cited(text) == ("TS-1", "SEC-12")


def test_cites_source_accepts_an_allowed_link_or_the_convention_tag():
    items = dict(h.rule_items(TOPIC))
    assert h.cites_source(items["TS-1"]) is True
    assert h.cites_source(items["TS-2"]) is True
    assert h.cites_source("Use it ([typescriptlang](https://www.typescriptlang.org/tsconfig)).")


def test_cites_source_rejects_an_uncited_rule_and_a_disallowed_host():
    items = dict(h.rule_items(UNCITED_RULE))
    assert h.cites_source(items["TS-1"]) is False
    assert h.cites_source(items["TS-2"]) is True
    assert h.cites_source("Rule ([blog](https://example.org/post)).") is False
    assert h.cites_source("Rule `https://nextjs.org/docs` in code only.") is False


def test_checklist_items_lists_unchecked_boxes():
    assert h.checklist_items(TOPIC) == (
        "- [ ] Pages use `PageProps`.",
        "- [ ] Input is validated at the boundary.",
    )
    assert h.checklist_items("# T\n") == ()


def test_anti_patterns_pair_dont_headings_with_bodies():
    pairs = h.anti_patterns(TOPIC)
    assert [title for title, _ in pairs] == ["Don't read params synchronously"]
    assert h.code_blocks(pairs[0][1], ("tsx",))
    text = (
        "## Anti-patterns\n\n### Don’t mutate\n\nbody a\n\n### Prefer this\n\nbody b\n\n"
        "### Don't leak\n\nbody c\n\n## Version notes\n\n### Don't outside\n"
    )
    assert [title for title, _ in h.anti_patterns(text)] == ["Don’t mutate", "Don't leak"]
    assert h.anti_patterns("# T\n") == ()


def test_table_rows_skip_the_separator_row():
    section = (
        "| File | Prefix |\n| --- | :---: |\n"
        "| [`typescript.md`](nextjs/typescript.md) | `TS` |\n| `a|b` | x \\| y |\n\ntext\n"
    )
    assert h.table_rows(section) == (
        ("File", "Prefix"),
        ("[`typescript.md`](nextjs/typescript.md)", "`TS`"),
        ("`a|b`", "x | y"),
    )
    assert h.table_rows("no table") == ()


# --- FIX①: contract-parser gaps (R1-A15) -----------------------------------------------------

TILDE = "~" * 3


def test_section_prefers_the_shallowest_heading_over_an_earlier_deeper_one():
    text = (
        "# T\n\n## Patterns\n\n### Sources\n\n- not a url\n\n"
        "## Sources\n\n- https://nextjs.org/docs\n"
    )
    assert "https://nextjs.org/docs" in h.section(text, "Sources")
    assert h.source_urls(text) == ("https://nextjs.org/docs",)
    assert h.malformed_source_lines(text) == ()
    assert h.section(text, "Sources", level=3).strip() == "- not a url"
    with pytest.raises(LookupError):
        h.section(text, "Patterns", level=3)


def test_contract_readers_ignore_a_deeper_heading_with_a_contract_name():
    text = (
        "# T\n\n## Scope\n\n### Rules\n\n1. not a rule\n\n"
        "## Rules\n\n1. **TS-1** Do it. (convention)\n\n"
        "## Patterns\n\n### Review checklist\n\n- [ ] not here\n\n"
        "## Review checklist\n\n- [ ] here\n"
    )
    assert h.rule_items(text) == (("TS-1", "**TS-1** Do it. (convention)"),)
    assert h.checklist_items(text) == ("- [ ] here",)


def test_tilde_fences_are_fences():
    text = (
        f"# T\n\n{TILDE}\n# not a heading\nhttps://example.org/inside\n{TILDE}\n\n"
        f"{TILDE}ts\nconst a = 1\n{FENCE}\nstill inside\n{TILDE}\n\n"
        "## After\n"
    )
    assert h.headings(text, 1) == ("T",)
    assert h.headings(text, 2) == ("After",)
    assert h.all_urls(text) == ()
    assert h.bare_fence_lines(text) == (3,)
    assert h.code_blocks(text, ("ts",)) == (("ts", f"const a = 1\n{FENCE}\nstill inside"),)


def test_a_backtick_fence_is_not_closed_by_tildes():
    text = f"{FENCE}ts\nconst a = 1\n{TILDE}\n# inside\n{FENCE}\n\n# Outside\n"
    assert h.headings(text, 1) == ("Outside",)
    assert h.code_blocks(text) == (("ts", f"const a = 1\n{TILDE}\n# inside"),)


def test_stray_rule_lines_flag_a_column_zero_fence_and_prose():
    text = (
        "## Rules\n\n1. **TS-1** Do it. (convention)\n"
        f"   {FENCE}ts\nconst indented = true\n   {FENCE}\n"
        "### A group heading\n\n2. **TS-2** Do more. (convention)\n"
        f"{FENCE}ts\nconst stray = 1\n{FENCE}\n"
        "`code` then prose at column 0\n\n## Patterns\n\nfree text\n"
    )
    assert h.stray_rule_lines(text) == (
        f"{FENCE}ts",
        "const stray = 1",
        FENCE,
        "`code` then prose at column 0",
    )
    assert h.stray_rule_lines(TOPIC) == ()
    assert h.stray_rule_lines("# T\n") == ()


def test_cites_source_ignores_a_backticked_convention_tag():
    assert h.cites_source("**TS-1** Do it `(convention)`.") is False
    assert h.cites_source("**TS-1** Do it, see `(convention)` (convention).") is True


# --- FIX①: one shared "no any" check (R1-B17) ------------------------------------------------

ANY_SPELLINGS = (
    "let a: any = 1",
    "const b = value as any",
    "const c = <any>value",
    "const d: Array<any> = []",
    "const e: Record<string, any> = {}",
    "type F = Promise<any>",
    "const g: any[] = []",
    "type H = [string, any]",
    "type I = string | any",
    "type J = any",
)
NOT_ANY = (
    "// works for any request: any",
    "/* any: any */ const ok = 1",
    "const anyValue = company.many",
    "type Mode = 'any' | 'all'",
    "const unknownValue: unknown = input",
)
DUPLICATING_TOPIC_TESTS = (
    "test_nextjs_topic_rendering_and_caching.py",
    "test_nextjs_topic_data_fetching_and_mutations.py",
    "test_nextjs_topic_route_handlers_and_apis.py",
)


@pytest.mark.parametrize("code", ANY_SPELLINGS)
def test_uses_any_type_catches_every_spelling(code):
    assert h.uses_any_type(code), code


@pytest.mark.parametrize("code", NOT_ANY)
def test_uses_any_type_ignores_comments_identifiers_and_strings(code):
    assert not h.uses_any_type(code), code


@pytest.mark.parametrize("name", DUPLICATING_TOPIC_TESTS)
def test_topic_tests_use_the_shared_any_check_and_major(name):
    source = (Path(__file__).parent / name).read_text(encoding="utf-8")
    assert "any\\b" not in source and "any\\[" not in source, "own copy of the no-any regex"
    assert ".split('.')[0]" not in source and '.split(".")[0]' not in source, "own major()"
    assert "uses_any_type" in source


# --- the module itself -----------------------------------------------------------------------

ALLOWED_IMPORTS = frozenset({"__future__", "re", "types", "typing", "urllib", "pathlib"})
MAX_FUNCTION_LINES = 50
MUTABLE_FACTORIES = frozenset({"list", "dict", "set"})


def _module_tree():
    return ast.parse(Path(h.__file__).read_text(encoding="utf-8"))


def _top_level_imports(tree):
    names = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            names.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            names.add(node.module.split(".")[0])
    return names


def _mutable_module_values(tree):
    found = []
    for node in tree.body:
        if not isinstance(node, (ast.Assign, ast.AnnAssign)) or node.value is None:
            continue
        value = node.value
        is_factory = isinstance(value, ast.Call) and ast.unparse(value.func) in MUTABLE_FACTORIES
        if isinstance(value, (ast.List, ast.Dict, ast.Set)) or is_factory:
            found.append(ast.unparse(node)[:60])
    return found


def test_helpers_module_is_stdlib_only_small_and_immutable():
    tree = _module_tree()
    assert _top_level_imports(tree) <= ALLOWED_IMPORTS, _top_level_imports(tree) - ALLOWED_IMPORTS
    long_functions = [
        f"{node.name} ({node.end_lineno - node.lineno + 1} lines)"
        for node in ast.walk(tree)
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
        and node.end_lineno - node.lineno + 1 > MAX_FUNCTION_LINES
    ]
    assert long_functions == []
    assert [node for node in ast.walk(tree) if isinstance(node, ast.Global)] == []
    assert _mutable_module_values(tree) == []
    doc = (ast.get_docstring(tree) or "").lower()
    assert "non-collected" in doc and "stdlib" in doc
    assert not Path(h.__file__).name.startswith("test_")
