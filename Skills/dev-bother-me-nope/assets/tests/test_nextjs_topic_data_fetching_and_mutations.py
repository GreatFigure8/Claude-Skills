"""Topic tests for ``references/nextjs/data-fetching-and-mutations.md`` (rule prefix ``DF``).

The generic contract (section order, rule format, citations, floors, Sources hosts, line cap,
tagged fences, resolving links) is enforced for every non-stub topic by
``test_nextjs_reference.py``. This file adds what only this topic can promise: it is no longer a
stub, it states the data-fetching and mutation concepts the story requires, its examples are the
ones the story asks for, every Server Action example authenticates, and its checklist and
anti-patterns are reviewer-ready.

Offline, standard library plus pytest. Parsing lives in ``nextjs_doc_helpers``.
"""

import re
from functools import cache

import nextjs_doc_helpers as h
import pytest

TOPIC = h.TOPICS_DIR / "data-fetching-and-mutations.md"
PREFIX = "DF"
MIN_RULES = 15
MIN_CHECKLIST_ITEMS = 8
SECURITY_TOPIC = "proxy-auth-and-security.md"

TERMS = (
    "waterfall",
    "Promise.all",
    "preload",
    "'use server'",
    "Server Action",
    "Server Function",
    "action=",
    "useActionState",
    "useFormStatus",
    "useOptimistic",
    "useTransition",
    "startTransition",
    "FormData",
    "safeParse",
    "redirect(",
    "revalidatePath",
    "updateTag",
    "refresh(",
    "use(",
    ".bind(",
    "progressive enhancement",
    "Route Handler",
)

AUTH_CALL = re.compile(r"(?i)(session|auth)\w*\(")
DF_ID = re.compile(r"\bDF-\d+\b")
BOLD_RULE_ID = re.compile(r"\*\*([A-Z]+-\d+)\*\*")
DONT_MARKER = re.compile(r"^\*\*Don['’]t:\*\*\n+```(?:ts|tsx)\b", re.MULTILINE)
DO_MARKER = re.compile(r"^\*\*Do:\*\*\n+```(?:ts|tsx)\b", re.MULTILINE)

REQUIRED_EXAMPLES = {
    "parallel-fetching": ("Promise.all", "await"),
    "validated-server-action": ("'use server'", "safeParse"),
    "action-state-form": ("'use client'", "useActionState"),
    "optimistic-update": ("useOptimistic",),
    "request-dedup-cache": ("'react'", "cache("),
}


@cache
def _text() -> str:
    return h.read(TOPIC)


# --- AC1, AC2: not a stub, own ids, deep enough ---------------------------------------------


def test_topic_is_not_a_stub():
    assert h.is_stub(_text()) is False


def test_topic_uses_only_df_rule_ids():
    text = _text()
    ids = [rule_id for rule_id, _ in h.rule_items(text)]
    assert ids, "no rules under ## Rules"
    assert all(rule_id.startswith(f"{PREFIX}-") for rule_id in ids), ids
    foreign = [i for i in BOLD_RULE_ID.findall(text) if not i.startswith(f"{PREFIX}-")]
    assert not foreign, f"bold rule ids from another topic: {foreign}"


def test_topic_has_at_least_15_df_rules():
    assert len(h.rule_items(_text())) >= MIN_RULES


# --- AC3: required concepts ----------------------------------------------------------------


def test_topic_names_every_required_concept():
    assert h.missing_terms(_text(), TERMS) == []


# --- AC4: required examples -------------------------------------------------------------------


@pytest.mark.parametrize("needles", REQUIRED_EXAMPLES.values(), ids=REQUIRED_EXAMPLES.keys())
def test_topic_has_required_example(needles):
    assert h.has_block_with(_text(), *needles), f"no ts/tsx block with all of {needles}"


def test_examples_never_use_any():
    blocks = h.code_blocks(_text(), ("ts", "tsx"))
    assert blocks, "no ts/tsx examples to check"
    offenders = [body.splitlines()[0] for _, body in blocks if h.uses_any_type(body)]
    assert not offenders, f"blocks that use the any type: {offenders}"


# --- AC5: every mutating example authenticates -----------------------------------------------


def test_every_use_server_block_calls_an_auth_check():
    blocks = [body for _, body in h.code_blocks(_text(), ("ts", "tsx")) if "'use server'" in body]
    assert blocks, "no ts/tsx block with 'use server'"
    unchecked = [body.splitlines()[0] for body in blocks if not AUTH_CALL.search(body)]
    assert not unchecked, f"'use server' blocks with no session or auth call: {unchecked}"


def test_mutation_examples_link_the_security_topic():
    text = _text()
    for heading in ("Rules", "Patterns"):
        assert SECURITY_TOPIC in h.section(text, heading), f"## {heading} omits {SECURITY_TOPIC}"


# --- AC6: redirect placement and expected errors ---------------------------------------------


def test_rules_state_redirect_outside_try_catch():
    rules = h.section(_text(), "Rules")
    assert "redirect" in rules
    assert "try" in rules


def test_redirect_rule_says_outside_try_and_after_revalidation():
    matching = [
        item
        for _, item in h.rule_items(_text())
        if "redirect(" in item and "try" in item and "revalidat" in item and "outside" in item
    ]
    assert matching, "no single rule ties redirect( to try/catch, revalidation and 'outside'"


# --- AC7: version notes ---------------------------------------------------------------------


def test_version_notes_name_the_major_and_link_nextjs():
    text = _text()
    major = h.major(h.as_of_version(text))
    notes = h.section(text, "Version notes")
    assert notes.strip()
    assert f"Next.js {major}" in notes
    assert "https://nextjs.org/" in notes


# --- AC8: reviewer-ready ---------------------------------------------------------------------


def test_every_checklist_item_names_a_df_rule():
    items = h.checklist_items(_text())
    assert len(items) >= MIN_CHECKLIST_ITEMS
    missing = [item[:60] for item in items if not DF_ID.search(item)]
    assert not missing, f"checklist items that name no DF rule: {missing}"


def test_checklist_rule_ids_exist():
    text = _text()
    known = {rule_id for rule_id, _ in h.rule_items(text)}
    cited = set(DF_ID.findall("\n".join(h.checklist_items(text))))
    assert cited, "the checklist cites no DF rule"
    assert cited <= known, f"checklist cites rules that do not exist: {sorted(cited - known)}"


def test_every_dont_is_paired_with_a_do():
    antis = h.anti_patterns(_text())
    assert len(antis) >= 3
    for title, body in antis:
        assert len(DONT_MARKER.findall(body)) == 1, f"{title!r}: one **Don't:** block expected"
        assert len(DO_MARKER.findall(body)) == 1, f"{title!r}: one **Do:** block expected"
        dont_at = DONT_MARKER.search(body).start()
        do_at = DO_MARKER.search(body).start()
        assert dont_at < do_at, f"{title!r}: the Do must follow the Don't"
        assert DF_ID.search(body), f"{title!r}: name the DF rule it breaks"


# --- FIX1: REVIEW1 R1-B4, R1-B13 and this file's side of R1-B15 --------------------------------

PATTERN_TITLE = re.compile(r"^P\d+ ")
CACHING_MODEL_LABEL = re.compile(r"\b(?:both models|previous model|Cache Components)\b")
CACHE_COMPONENTS_LABEL = re.compile(r"\b(?:both models|Cache Components)\b")
CACHING_PAGE = "https://nextjs.org/docs/app/getting-started/caching"
RENDERING_TOPIC = "rendering-and-caching.md"
NEEDLES_CC_PARAMS_RULE = ("Cache Components", "params", "Suspense", RENDERING_TOPIC, CACHING_PAGE)
DAL_MODULE = "@/lib/dal"
ACTIONS_DIR = "src/lib/actions/"
PATH_COMMENT = re.compile(r"^// (?P<path>[\w./\[\]()@-]+\.(?:ts|tsx))\b")
ROOT_FOLDERS = ("app/", "lib/", "features/", "shared/")
SESSION_IMPORT = re.compile(
    r"import\s*\{[^}]*\b(?:verifySession|getSession)\b[^}]*\}\s*from\s*'(?P<module>[^']+)'"
)
BARE_RETURN = re.compile(r"^\s*return\s*(?://.*)?$", re.MULTILINE)
AWAITS_PARAMS = re.compile(r"\bawait\s+(?:props\.)?params\b")
ASYNC_DEFAULT_EXPORT = re.compile(r"export\s+default\s+async\s+function")
PASSES_PARAMS_PROMISE = re.compile(r"params=\{params\}|\bparams\.then\(")


def _patterns() -> tuple[tuple[str, str], ...]:
    body = h.section(_text(), "Patterns")
    return tuple((t, b) for t, b in h._subsections(body, 3) if PATTERN_TITLE.match(t))


def _pattern_blocks(body: str) -> tuple[str, ...]:
    return tuple(code for _, code in h.code_blocks(body, ("ts", "tsx")))


def _use_server_modules() -> tuple[str, ...]:
    """Pattern blocks that are a whole ``'use server'`` module (directive right after the path)."""
    modules = []
    for _, body in _patterns():
        for code in _pattern_blocks(body):
            lines = code.splitlines()
            if len(lines) > 1 and PATH_COMMENT.match(lines[0]) and lines[1].strip() == "'use server'":
                modules.append(code)
    return tuple(modules)


def test_patterns_intro_defines_the_two_caching_models():
    intro = h.section(_text(), "Patterns").split("\n### ", 1)[0]
    assert "Cache Components" in intro and "previous model" in intro, "name both caching models"
    assert RENDERING_TOPIC in intro, f"point at {RENDERING_TOPIC} for the model rules"


def test_every_pattern_names_the_caching_model_it_assumes():
    patterns = _patterns()
    assert len(patterns) >= 8
    unlabelled = [title for title, _ in patterns if not CACHING_MODEL_LABEL.search(title)]
    assert not unlabelled, f"patterns whose heading names no caching model: {unlabelled}"


def test_a_rule_sends_cache_components_params_into_suspense():
    matching = [
        rule_id
        for rule_id, item in h.rule_items(_text())
        if all(n in " ".join(item.split()) for n in NEEDLES_CC_PARAMS_RULE)
    ]
    assert matching, "no rule links the caching page and rendering-and-caching.md for params"


def test_cache_components_patterns_do_not_await_params_in_the_page():
    cc = [(t, b) for t, b in _patterns() if CACHE_COMPONENTS_LABEL.search(t)]
    assert cc, "no pattern is labelled for Cache Components"
    for title, body in cc:
        for code in _pattern_blocks(body):
            assert not (ASYNC_DEFAULT_EXPORT.search(code) and AWAITS_PARAMS.search(code)), (
                f"{title!r}: an async page awaits params at the top"
            )
    assert any(
        "<Suspense" in code and PASSES_PARAMS_PROMISE.search(code)
        for _, body in cc
        for code in _pattern_blocks(body)
    ), "no Cache Components pattern passes the params promise into a <Suspense> boundary"


def test_top_level_await_params_sits_only_in_previous_model_patterns():
    offenders = [
        title
        for title, body in _patterns()
        for code in _pattern_blocks(body)
        if ASYNC_DEFAULT_EXPORT.search(code)
        and AWAITS_PARAMS.search(code)
        and "previous model" not in title
    ]
    assert not offenders, f"patterns awaiting params at the top without saying previous model: {offenders}"


def test_df14_forbids_returning_void_when_a_check_fails():
    rule = next(item for rule_id, item in h.rule_items(_text()) if rule_id == "DF-14")
    assert "void" in rule, "DF-14 does not say a failed check must not return void"


def test_validating_actions_return_typed_state_never_void():
    modules = _use_server_modules()
    assert len(modules) >= 3
    for code in modules:
        label = code.splitlines()[0]
        assert not BARE_RETURN.search(code), f"{label}: a bare return hides a failed check"
        validates = "safeParse(" in code or "verifySession(" in code
        assert not (validates and "Promise<void>" in code), f"{label}: returns Promise<void>"


# R1-B15: one session-helper contract. src/lib/dal.ts exports getSession and verifySession.


def test_session_helpers_are_imported_from_the_dal_module():
    text = _text()
    assert "@/lib/dal/session" not in text, "the session helpers do not live in lib/dal/session"
    modules = [
        match.group("module")
        for _, body in _patterns()
        for code in _pattern_blocks(body)
        for match in SESSION_IMPORT.finditer(code)
    ]
    assert modules, "no pattern imports verifySession or getSession"
    assert set(modules) == {DAL_MODULE}, f"session helpers imported from {sorted(set(modules))}"


def test_server_actions_live_in_src_lib_actions():
    modules = _use_server_modules()
    assert len(modules) >= 3
    misplaced = [m.splitlines()[0] for m in modules if f"// {ACTIONS_DIR}" not in m.splitlines()[0]]
    assert not misplaced, f"'use server' modules outside {ACTIONS_DIR}: {misplaced}"


def test_snippet_paths_use_the_src_layout():
    paths = []
    for _, body in _patterns():
        for code in _pattern_blocks(body):
            match = PATH_COMMENT.match(code.splitlines()[0]) if code.strip() else None
            if match:
                paths.append(match.group("path"))
    assert len(paths) >= 10
    rooted = [p for p in paths if p.startswith(ROOT_FOLDERS)]
    assert not rooted, f"snippet paths without the src/ prefix: {rooted}"
