"""Topic tests for references/nextjs/proxy-auth-and-security.md (rule prefix SEC).

test_nextjs_reference.py enforces the generic authoring contract on every topic file. These tests
check what is specific to this topic: depth, required concepts, the five examples, that every
Server Action example authenticates before it writes, the version notes and the reviewer lists.
Offline and stdlib-only.
"""

import re

import pytest
from nextjs_doc_helpers import (
    TOPICS,
    TOPICS_DIR,
    anti_patterns,
    as_of_version,
    checklist_items,
    code_blocks,
    has_block_with,
    is_stub,
    missing_terms,
    read,
    rule_items,
    section,
)

TOPIC = TOPICS_DIR / "proxy-auth-and-security.md"
PREFIX = "SEC"
MIN_RULES = 18
MIN_CHECKLIST_ITEMS = 8
MIN_ANTI_PATTERNS = 3
TS_LANGS = ("ts", "tsx")
TERMS = (
    "proxy.ts", "middleware.ts", "matcher", "NextResponse.redirect", "NextResponse.next",
    "optimistic", "Data Access Layer", "DTO", "server-only", "cache(", "httpOnly", "secure",
    "sameSite", "'use server'", "allowedOrigins", "bodySizeLimit", "nonce",
    "Content-Security-Policy", "NEXT_PUBLIC_", "taint", "headers()",
)
EXAMPLES = {
    "proxy-matcher": ("proxy", "matcher"),
    "dal-server-only-cache": ("import 'server-only'", "cache("),
    "server-action": ("'use server'",),
    "csp-nonce": ("Content-Security-Policy", "nonce"),
    "session-cookie": ("httpOnly",),
}
AUTH_CALL = re.compile(r"(?i)(session|auth)\w*\(")
WRITE_CALL = re.compile(r"\.(?:create|update|upsert|delete|insert)\w*\(")
ANY_TYPE = re.compile(r":\s*any\b|\bas\s+any\b|<any>")
DO_MARKER = "**Do**"
ADVISORIES = ("CVE-2025-66478", "CVE-2026-64642")
UPGRADE_GUIDE = "https://nextjs.org/docs/app/guides/upgrading/version-16"
CHECKLIST_RULE = re.compile(r"\bSEC-\d+\b")


@pytest.fixture(scope="module")
def text() -> str:
    return read(TOPIC)


def _section(text: str, heading: str) -> str:
    try:
        return section(text, heading)
    except LookupError:
        return ""


def test_topic_file_is_not_a_stub(text):
    assert not is_stub(text)


def test_topic_has_at_least_18_sec_rules(text):
    ids = [rule_id for rule_id, _ in rule_items(text)]
    assert len(ids) >= MIN_RULES
    assert all(rule_id.startswith(f"{PREFIX}-") for rule_id in ids)


def test_no_other_topic_rule_ids_are_used(text):
    others = sorted({prefix for prefix, _slug in TOPICS.values()} - {PREFIX})
    foreign = re.compile(rf"\b(?:{'|'.join(others)})-\d+\b")
    assert foreign.findall(text) == []


def test_required_terms_are_present(text):
    assert missing_terms(text, TERMS) == []


@pytest.mark.parametrize("needles", EXAMPLES.values(), ids=EXAMPLES.keys())
def test_example_block_is_present(text, needles):
    assert has_block_with(text, *needles, langs=TS_LANGS)


def test_ts_examples_never_use_any(text):
    offenders = [body for _, body in code_blocks(text, TS_LANGS) if ANY_TYPE.search(body)]
    assert offenders == []


def test_rules_keep_proxy_optimistic_and_recheck_in_the_dal(text):
    rules = _section(text, "Rules")
    assert "optimistic" in rules
    assert "Data Access Layer" in rules


def test_version_notes_state_the_middleware_to_proxy_rename(text):
    notes = _section(text, "Version notes")
    for needle in ("middleware", "proxy", "middleware-to-proxy", UPGRADE_GUIDE):
        assert needle in notes


def test_version_notes_name_the_major_and_link_nextjs_org(text):
    notes = _section(text, "Version notes")
    major = (as_of_version(text) or "").split(".")[0]
    assert major
    assert f"Next.js {major}" in notes
    assert "https://nextjs.org/" in notes


def test_version_notes_list_the_topic_security_advisories(text):
    notes = _section(text, "Version notes")
    assert [cve for cve in ADVISORIES if cve not in notes] == []


def test_every_use_server_block_checks_auth_before_writing(text):
    blocks = [body for _, body in code_blocks(text, TS_LANGS) if "'use server'" in body]
    assert blocks
    for body in blocks:
        auth = AUTH_CALL.search(body)
        assert auth, body
        write = WRITE_CALL.search(body)
        assert write is None or auth.start() < write.start(), body


def test_every_review_checklist_item_names_a_sec_rule(text):
    items = checklist_items(text)
    assert len(items) >= MIN_CHECKLIST_ITEMS
    assert [item for item in items if not CHECKLIST_RULE.search(item)] == []


def test_every_anti_pattern_dont_is_paired_with_a_do(text):
    antis = anti_patterns(text)
    assert len(antis) >= MIN_ANTI_PATTERNS
    for title, body in antis:
        dont, marker, do = body.partition(DO_MARKER)
        assert marker, title
        assert "```" in dont and "```" in do, title


def test_not_confirmed_section_lists_the_urls_checked(text):
    assert "https://nextjs.org/" in _section(text, "Not confirmed by the docs")
