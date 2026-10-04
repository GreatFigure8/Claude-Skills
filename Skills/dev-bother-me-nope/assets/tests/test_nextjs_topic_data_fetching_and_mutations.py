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
