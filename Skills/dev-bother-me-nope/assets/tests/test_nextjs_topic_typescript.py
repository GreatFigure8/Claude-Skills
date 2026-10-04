"""Topic tests for ``references/nextjs/typescript.md`` (story typescript-config-and-typing-patterns).

The generic contract tests in ``test_nextjs_reference.py`` already enforce the shape of every topic
file (sections, rule format, floors, sources, hygiene). These tests add what only the TypeScript
topic owes: its own rule ids, the terms and patterns the story promises, and the rules that keep
``params``, ``searchParams``, ``any`` and build errors in check.

Offline, standard library plus pytest. Parsing lives in ``nextjs_doc_helpers``.
"""

import json
import re
from pathlib import Path

import nextjs_doc_helpers as helpers
import pytest

TOPIC = helpers.TOPICS_DIR / "typescript.md"
RULE_PREFIX = helpers.TOPICS[TOPIC.name][0]
OTHER_PREFIXES = tuple(
    prefix for name, (prefix, _) in helpers.TOPICS.items() if name != TOPIC.name
)
MIN_RULES = 15
MIN_CHECKLIST_ITEMS = 8
MIN_ANTI_PATTERN_PAIRS = 3

OTHER_TOPIC_ID_RE = re.compile(rf"\b(?:{'|'.join(OTHER_PREFIXES)})-\d+\b")
ANY_TYPE_RE = re.compile(r":\s*any\b|<any>|as any\b")
DONT_MARKER = "**Don't**"
DO_MARKER = "**Do**"
FENCE_OPENER = "```"

# The last term keeps its backticks so that words like "many" cannot satisfy it.
TERMS = (
    '"strict": true',
    "noUncheckedIndexedAccess",
    "next-env.d.ts",
    "next.config.ts",
    "NextConfig",
    "typedRoutes",
    "next typegen",
    "PageProps",
    "LayoutProps",
    "RouteContext",
    "searchParams",
    "Promise<",
    "ignoreBuildErrors",
    "safeParse",
    "unknown",
    "satisfies",
    "server-only",
    "NEXT_PUBLIC_",
    "Metadata",
    "`any`",
)


@pytest.fixture(scope="module")
def text() -> str:
    return helpers.read(TOPIC)


def _section(text: str, heading: str) -> str:
    """Body of an H2 section; a missing section fails with a message instead of a crash."""
    try:
        return helpers.section(text, heading)
    except LookupError:
        pytest.fail(f"typescript.md has no '## {heading}' section")


def _anti_pattern_markers(body: str) -> list[tuple[str, bool]]:
    """``(marker, followed_by_a_fence)`` for each Don't/Do marker line outside a fence.

    Which lines sit inside a fence is the contract parser's call, so a four-backtick fence that
    wraps a three-backtick one is read the way the generic contract tests read it.
    """
    lines = body.splitlines()
    fenced = helpers._fenced_indexes(lines)
    markers = []
    for index, line in enumerate(lines):
        stripped = line.strip()
        if index in fenced or stripped not in (DONT_MARKER, DO_MARKER):
            continue
        following = next((later.strip() for later in lines[index + 1 :] if later.strip()), "")
        markers.append((stripped, following.startswith(FENCE_OPENER)))
    return markers


# --- AC1 and AC2: this topic's own rules, and the stub is gone -----------------------------


def test_typescript_topic_uses_only_ts_rule_ids(text):
    ids = [rule_id for rule_id, _ in helpers.rule_items(text)]

    assert ids, "no rules under ## Rules"
    assert ids == [f"{RULE_PREFIX}-{n}" for n in range(1, len(ids) + 1)]
    assert OTHER_TOPIC_ID_RE.search(text) is None


def test_typescript_topic_is_not_a_stub(text):
    assert helpers.is_stub(text) is False


def test_typescript_topic_has_at_least_15_rules(text):
    assert len(helpers.rule_items(text)) >= MIN_RULES


# --- AC3: the promised terms --------------------------------------------------------------


def test_typescript_topic_mentions_every_required_term(text):
    assert helpers.missing_terms(text, TERMS) == []


# --- AC4: the promised code blocks --------------------------------------------------------


def test_typescript_topic_has_strict_tsconfig_json_block(text):
    assert helpers.has_block_with(text, '"strict": true', langs=("json",))


def test_typescript_topic_has_typed_next_config_block(text):
    assert helpers.has_block_with(text, "NextConfig", "typedRoutes")


def test_typescript_topic_has_page_props_block_awaiting_params(text):
    assert helpers.has_block_with(text, "PageProps<'/", "await")


def test_typescript_topic_has_route_context_handler_block(text):
    assert helpers.has_block_with(text, "RouteContext<'/", "await")


def test_typescript_topic_has_safe_parse_boundary_block(text):
    assert helpers.has_block_with(text, "safeParse")


def test_typescript_topic_examples_never_use_any(text):
    blocks = helpers.code_blocks(_section(text, "Patterns"), ("ts", "tsx"))

    assert blocks, "## Patterns holds no ts or tsx block"
    offenders = [body.splitlines()[0] for _, body in blocks if ANY_TYPE_RE.search(body)]
    assert not offenders, f"Patterns blocks that write any: {offenders}"


# --- AC5: async params and generated route helpers ----------------------------------------


def test_typescript_topic_awaits_search_params_in_tsx(text):
    assert helpers.has_block_with(text, "searchParams", "await", langs=("tsx",))


def test_typescript_rules_say_how_route_helpers_are_generated(text):
    rules = _section(text, "Rules")

    missing = [term for term in ("next typegen", "next dev", "next build", "Promise") if term not in rules]
    assert not missing, f"## Rules never mentions: {missing}"


# --- AC6: build errors and any ------------------------------------------------------------


def test_typescript_rules_forbid_ignore_build_errors_and_ban_any(text):
    rules = _section(text, "Rules")

    missing = [term for term in ("ignoreBuildErrors", "unknown", "`any`") if term not in rules]
    assert not missing, f"## Rules never mentions: {missing}"


# --- AC7: version notes -------------------------------------------------------------------


def test_typescript_version_notes_name_major_and_link_nextjs(text):
    version = helpers.as_of_version(text)
    assert version is not None, "no as-of line right after the H1"
    notes = _section(text, "Version notes")

    assert notes.strip()
    assert f"Next.js {helpers.major(version)}" in notes
    assert "https://nextjs.org/" in notes


# --- AC8: checklist and anti-patterns -----------------------------------------------------


def test_typescript_review_checklist_items_cite_rule_ids(text):
    items = helpers.checklist_items(text)

    assert len(items) >= MIN_CHECKLIST_ITEMS
    uncited = [item[:60] for item in items if f"{RULE_PREFIX}-" not in item]
    assert not uncited, f"checklist items without a rule id: {uncited}"


def test_typescript_anti_patterns_pair_each_dont_with_a_do(text):
    markers = _anti_pattern_markers(_section(text, "Anti-patterns"))
    kinds = [marker for marker, _ in markers]
    pairs = len(kinds) // 2

    assert pairs >= MIN_ANTI_PATTERN_PAIRS
    assert kinds == [DONT_MARKER, DO_MARKER] * pairs
    unfenced = [marker for marker, has_fence in markers if not has_fence]
    assert not unfenced, f"{len(unfenced)} marker(s) not followed by a fenced block"
    assert len(helpers.anti_patterns(text)) == pairs, "each ### Don't heading holds one pair"


# --- AC9: every source is used ------------------------------------------------------------


def test_typescript_every_source_is_linked_in_the_body(text):
    body, _, _ = text.rpartition("\n## Sources")

    unused = sorted(set(helpers.source_urls(text)) - set(helpers.all_urls(body)))
    assert not unused, f"Sources entries no rule, pattern or note links to: {unused}"


# --- FIX1 guards: each one failed against the first draft of typescript.md or of this module ----

ES_LIB_RE = re.compile(r"^es(?P<year>\d{4})$")
MIN_LIB_YEAR = 2022
CREATE_NEXT_APP_INCLUDE = (
    "next-env.d.ts",
    "**/*.ts",
    "**/*.tsx",
    "**/*.mts",
    ".next/types/**/*.ts",
    ".next/dev/types/**/*.ts",
)
ROUTE_LITERAL_RE = re.compile(r"\b(?:PageProps|LayoutProps|RouteContext)<'(?P<literal>[^']*)'")
GROUP_FOLDER_RE = re.compile(r"\([A-Za-z][\w-]*\)/")
BARE_PARSE_RE = re.compile(r"\.parse\(")
THIS_MODULE = Path(__file__)


def _rule(text: str, rule_id: str) -> str:
    return dict(helpers.rule_items(text))[rule_id]


def _p1_tsconfig(text: str) -> dict:
    """The parsed P1 block: the first json fence under ## Patterns that sets strict."""
    for _, body in helpers.code_blocks(_section(text, "Patterns"), ("json",)):
        if '"strict": true' in body:
            return json.loads(body)
    pytest.fail("## Patterns has no tsconfig json block with strict")


def _lib_reaches(libs: list[str], year: int) -> bool:
    for lib in (name.lower() for name in libs):
        found = ES_LIB_RE.match(lib)
        if lib == "esnext" or (found and int(found.group("year")) >= year):
            return True
    return False


# R1-A3 (also R1-C4): P1 must match what create-next-app 16 writes, so ES2022 built-ins compile.


def test_p1_tsconfig_lib_reaches_es2022_builtins(text):
    libs = _p1_tsconfig(text)["compilerOptions"]["lib"]

    assert _lib_reaches(libs, MIN_LIB_YEAR), f"lib {libs} lacks .at(), replaceAll and Object.hasOwn"


def test_p1_tsconfig_include_matches_create_next_app(text):
    include = _p1_tsconfig(text)["include"]

    missing = [entry for entry in CREATE_NEXT_APP_INCLUDE if entry not in include]
    assert not missing, f"P1 include lacks {missing}"


def test_ts4_names_the_dev_types_include(text):
    assert ".next/dev/types/**/*.ts" in _rule(text, "TS-4")


# R1-A4: route literals are written as typegen produces them, without (group) and @slot folders.


def test_route_literals_in_code_never_contain_groups_or_slots(text):
    literals = [
        found.group("literal")
        for _, body in helpers.code_blocks(text, ("ts", "tsx"))
        for found in ROUTE_LITERAL_RE.finditer(body)
    ]

    assert literals, "no PageProps, LayoutProps or RouteContext literal in any block"
    offenders = [literal for literal in literals if "(" in literal or "@" in literal]
    assert not offenders, f"literals with a group or slot folder: {offenders}"


def test_rules_say_route_literals_drop_groups_and_slots(text):
    rule = _rule(text, "TS-13")

    assert "exactly as its folder path" not in rule
    assert "route group" in rule.lower()
    assert "@slot" in rule


def test_a_pattern_shows_a_route_group_folder_with_its_literal(text):
    blocks = helpers.code_blocks(_section(text, "Patterns"), ("ts", "tsx"))

    assert any(
        GROUP_FOLDER_RE.search(body) and re.search(r"(?:Page|Layout)Props<'/[^'(@]*'>", body)
        for _, body in blocks
    ), "no Patterns block pairs a (group) folder path with the literal typegen produces"


# R1-A13: boundary values, process.env included, go through safeParse (TS-19), never parse.


def test_patterns_never_call_the_throwing_parse(text):
    blocks = helpers.code_blocks(_section(text, "Patterns"), ("ts", "tsx"))

    offenders = [body.splitlines()[0] for _, body in blocks if BARE_PARSE_RE.search(body)]
    assert not offenders, f"Patterns blocks that call .parse(): {offenders}"


def test_public_env_pattern_validates_with_safe_parse(text):
    blocks = helpers.code_blocks(_section(text, "Patterns"), ("ts", "tsx"))

    reading = [body for _, body in blocks if "process.env.NEXT_PUBLIC_" in body]
    assert reading, "no Patterns block reads a NEXT_PUBLIC_ variable"
    assert all("safeParse" in body for body in reading)


# R1-A5 (TS-12 side): a new project lints with ESLint, a repo on Biome keeps Biome.


def test_ts12_lets_a_biome_repo_keep_its_linter(text):
    rule = _rule(text, "TS-12")

    for term in ("eslint-config-next", "Biome", "next lint", "configured linter"):
        assert term in rule, f"TS-12 never mentions {term}"
    assert re.search(r"new (?:project|repo)", rule, re.IGNORECASE), "TS-12 never says new projects"


def test_review_checklist_covers_the_lint_rule(text):
    assert any("TS-12" in item for item in helpers.checklist_items(text))


# R1-A16: this module takes prefixes, fences and checklist items from the contract helpers.


def test_anti_pattern_markers_ignore_text_inside_a_longer_fence():
    wrapped = f"````md\n```\n{DO_MARKER}\n```\n````"
    entry = f"{DONT_MARKER}\n{wrapped}\n\n{DO_MARKER}\n```ts\nconst x = 1\n```"

    assert _anti_pattern_markers(entry) == [(DONT_MARKER, True), (DO_MARKER, True)]


def test_module_uses_the_contract_for_prefixes_fences_and_checklist():
    source = THIS_MODULE.read_text(encoding="utf-8")
    smells = {
        "hard-coded topic prefix list": r"\(\?:[A-Z]+\|[A-Z]+\|[A-Z]+",
        "fence toggled on any backtick line": r"in_fence\s*=\s*not\s+in_fence",
        "checklist counted by raw line prefix": r"startswith\(\s*[\"']- \[ \]",
    }

    found = [name for name, pattern in smells.items() if re.search(pattern, source)]
    assert not found, f"{found}: use helpers.TOPICS, the helper fence parser and helpers.checklist_items"
