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


# --- FIX1: R1-C9, R1-C15, R1-C16, R1-C32 --------------------------------------------------------

SNIPPET_PATH = re.compile(r"^//\s+(?P<path>[\w./@()\[\]-]+\.tsx?)(?:\s|$)")
ROOT_SNIPPET_FILES = ("next.config.ts",)
ACTIONS_DIR = "src/lib/actions/"
MIN_PATHED_SNIPPETS = 8
CONTRACT_NEEDLES = (
    "src/lib/dal.ts", "@/lib/dal", "getSession", "verifySession", "Promise<Session | null>",
    "Promise<Session>", "/login", ACTIONS_DIR,
)


def _ts_block(text: str, *needles: str) -> str:
    for _, body in code_blocks(text, TS_LANGS):
        if all(needle in body for needle in needles):
            return body
    return ""


def _rule(text: str, rule_id: str) -> str:
    return next((body for found, body in rule_items(text) if found == rule_id), "")


def _path_blocks(text: str) -> list[tuple[str, str]]:
    found = []
    for _, body in code_blocks(text, TS_LANGS):
        match = SNIPPET_PATH.match(body.splitlines()[0]) if body else None
        if match:
            found.append((match.group("path"), body))
    return found


def test_one_rule_states_the_session_helper_contract_other_topics_import(text):
    # R1-C9: five topic files had five session-helper module paths.
    owners = [
        rule_id for rule_id, body in rule_items(text)
        if all(needle in body for needle in CONTRACT_NEEDLES)
    ]
    assert owners, "no rule names src/lib/dal.ts, getSession, verifySession and src/lib/actions"


def test_ts_examples_name_files_in_the_canonical_src_layout(text):
    # R1-C9: snippets copied side by side must resolve the `@/*` -> `src/*` alias against each other.
    paths = _path_blocks(text)
    assert len(paths) >= MIN_PATHED_SNIPPETS
    offenders = [p for p, _ in paths if not (p.startswith("src/") or p in ROOT_SNIPPET_FILES)]
    assert offenders == []


def test_server_action_files_live_in_src_lib_actions(text):
    # R1-C9: the canonical layout puts "use server" files in src/lib/actions/, not under app/.
    action_files = [
        path for path, body in _path_blocks(text)
        if any(line == "'use server'" for line in body.splitlines())
    ]
    assert action_files
    assert [p for p in action_files if not p.startswith(ACTIONS_DIR)] == []


def test_proxy_and_get_session_share_one_validity_function(text):
    # R1-C15: Proxy treated any truthy userId as signed in while getSession also required a known
    # role, so a validly signed token with an unknown role looped /login <-> /dashboard.
    proxy = _ts_block(text, "export async function proxy", "PUBLIC_ROUTES")
    dal = _ts_block(text, "export const getSession")
    session = _ts_block(text, "export async function decrypt")
    assert proxy and dal and session
    assert "decrypt(" in proxy and "decrypt(" in dal
    assert "isRole" in session and "isRole" not in dal
    assert "?.userId" not in proxy
    assert "getSession" in _rule(text, "SEC-4")


def test_session_secret_is_read_lazily_but_still_fails_closed(text):
    # R1-C32: a module-level throw fires at import, so `next build` fails without the secret.
    session = _ts_block(text, "jwtVerify", "SESSION_SECRET")
    reads = [line for line in session.splitlines() if "process.env.SESSION_SECRET" in line]
    assert reads
    assert all(line.startswith(" ") for line in reads), reads
    assert "throw new Error('SESSION_SECRET is not set')" in session
    assert "next build" in session


def test_security_headers_pattern_sends_the_frame_ancestors_sec_36_asks_for(text):
    # R1-C16: SEC-36 says use CSP frame-ancestors, but the pattern sent neither it nor X-Frame-Options.
    assert "frame-ancestors" in _rule(text, "SEC-36")
    headers = _ts_block(text, "securityHeaders", "async headers()")
    assert "key: 'Content-Security-Policy'" in headers
    assert "frame-ancestors" in headers
