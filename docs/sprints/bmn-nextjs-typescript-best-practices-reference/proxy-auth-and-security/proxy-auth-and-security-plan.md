# Plan: proxy-auth-and-security

`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`. Research done live on
2026-10-04 by the planner; the coder writes from this plan and does not re-research. Every URL
the coder may use is in the Verified rule sheet and in
`evidence/sources-verified.md` (already written, fetched 2026-10-04).

## 1. Approach

1. Replace the stub `R/nextjs/proxy-auth-and-security.md` with a full topic file that follows the
   skeleton's **Authoring contract** exactly (read `R/nextjs.md` › Authoring contract,
   `test_nextjs_reference.py` and `nextjs_doc_helpers.py` first; they merged before this story).
2. Content = the 45 rules in §7 (Verified rule sheet), the patterns and anti-patterns in §8, the
   version notes in §9 and the not-confirmed list in §10, copied with only light wording edits.
   Every rule keeps its id, its link(s) and its meaning; no rule is added that is not in §7.
3. Why this shape: the docs' own model is *optimistic check in Proxy, secure check at the data
   source* (authentication guide, data-security guide, proxy reference). The file is ordered the
   way an agent meets the problem: proxy → session cookie → DAL/DTO → Server Actions → Route
   Handlers → CSP/headers → env/secrets → patching/platform.
4. Skills: none routed (stack.md: Markdown skill content; `nextjs-fullstack-standards` is not
   loadable on this machine and is never approximated). Grounding rule from input.md/stack.md
   assumption 4 is the governing "skill guidance": only nextjs.org/vercel.com back Next.js/Vercel
   claims; react.dev backs `cache`/taint/`'use server'` language facts; zod.dev backs `safeParse`.
5. TDD: write `test_nextjs_topic_proxy_auth_and_security.py` first (RED against the stub), then
   the topic file (GREEN), then run the full suite and ruff.

## 2. Files

| File | Purpose |
| --- | --- |
| `R/nextjs/proxy-auth-and-security.md` | Replace the stub. The SEC topic file (≤ 800 lines; target ≤ 760). |
| `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_proxy_auth_and_security.py` | New. Topic-specific tests (§3). Stdlib + `nextjs_doc_helpers` only. |
| `docs/sprints/bmn-nextjs-typescript-best-practices-reference/proxy-auth-and-security/evidence/sources-verified.md` | Already written by the planner. Coder only edits it if a rule id or Source URL changes. |
| `docs/sprints/bmn-nextjs-typescript-best-practices-reference/proxy-auth-and-security/validation.md` | Written at validation: AC results, the one-off Sources == evidence check (§6), assumptions. |

Nothing else changes (AC11). Defects found in shared files (`nextjs.md`, helpers, generic tests)
are logged in `validation.md` › Assumptions for REVIEW①, never fixed here.

## 3. Test plan (written first)

All tests: `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_proxy_auth_and_security.py`,
type **unit**, offline. No browser criteria (ui: false) — no Playwright.

| AC | Test(s) |
| --- | --- |
| 1 Contract | Generic tests in `test_nextjs_reference.py` (owned by the skeleton) run on the file with no skip and pass; plus `test_no_other_topic_rule_ids_are_used` here. |
| 2 Not a stub, ≥ 18 rules | `test_topic_file_is_not_a_stub`, `test_topic_has_at_least_18_sec_rules` |
| 3 Required concepts | `test_required_terms_are_present` |
| 4 Examples | `test_example_block_is_present[proxy-matcher]`, `[dal-server-only-cache]`, `[server-action]`, `[csp-nonce]`, `[session-cookie]`; `test_ts_examples_never_use_any` |
| 5 Optimistic proxy + DAL | `test_rules_keep_proxy_optimistic_and_recheck_in_the_dal` |
| 6 Rename stated exactly | `test_version_notes_state_the_middleware_to_proxy_rename` |
| 7 Auth before write | `test_every_use_server_block_checks_auth_before_writing` |
| 8 Version notes | `test_version_notes_name_the_major_and_link_nextjs_org`, `test_version_notes_list_the_topic_security_advisories` |
| 9 Reviewer-ready | `test_every_review_checklist_item_names_a_sec_rule`, `test_every_anti_pattern_dont_is_paired_with_a_do` |
| 3/6 support | `test_not_confirmed_section_lists_the_urls_checked` |
| 10 Evidence | One-off command in §6 recorded in `validation.md` (not a pytest: tests never read run folders). |
| 11 Scope and gates | `git diff --name-only` check + full suite + ruff (§6), recorded in `validation.md`. |

14 test functions, 18 collected cases. Reference implementation (adapt only call shapes to the
merged helpers; keep names, constants and assertions):

```python
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
    as_of_version,
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
DONT_MARKER = "**Don't**"
DO_MARKER = "**Do**"
ADVISORIES = ("CVE-2025-66478", "CVE-2026-64642")
CHECKLIST_RULE = re.compile(r"\bSEC-\d+\b")


@pytest.fixture(scope="module")
def text() -> str:
    return read(TOPIC)


def _section(text: str, heading: str) -> str:
    return section(text, heading) or ""


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
    for needle in ("middleware", "proxy", "middleware-to-proxy",
                   "https://nextjs.org/docs/app/guides/upgrading/version-16"):
        assert needle in notes


def test_version_notes_name_the_major_and_link_nextjs_org(text):
    notes = _section(text, "Version notes")
    major = as_of_version(text).split(".")[0]
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
    lines = _section(text, "Review checklist").splitlines()
    items = [line for line in lines if line.lstrip().startswith("- [ ]")]
    assert len(items) >= 8
    assert [line for line in items if not CHECKLIST_RULE.search(line)] == []


def test_every_anti_pattern_dont_is_paired_with_a_do(text):
    chunks = _section(text, "Anti-patterns").split(DONT_MARKER)[1:]
    assert len(chunks) >= 3
    for chunk in chunks:
        dont, marker, do = chunk.partition(DO_MARKER)
        assert marker, chunk[:80]
        assert "```" in dont and "```" in do, chunk[:80]


def test_not_confirmed_section_lists_the_urls_checked(text):
    assert "https://nextjs.org/" in _section(text, "Not confirmed by the docs")
```

Adaptation rules for the coder: if the merged `section()` raises instead of returning a falsy
value, wrap it; if `TOPICS` values are not `(prefix, slug)` tuples, read the prefix from the
helper's actual shape; if the Authoring contract fixes a different Don't/Do marker, change only
`DONT_MARKER`/`DO_MARKER` and log it. Never weaken an assertion to pass.

## 4. Data

None. No models, migrations or RLS (stack: supabase false).

## 5. Config / env / deploy_pending

None. Env var names appear only as documentation text (`SESSION_SECRET`,
`NEXT_SERVER_ACTIONS_ENCRYPTION_KEY`, `DANGEROUSLY_DEPLOY_VULNERABLE_CVE_2025_66478`). No
`deploy_pending` entries: Markdown + one pytest file, nothing deployed.

## 6. Risks and gates

Risks:
- **Helper API drift** (skeleton planned in parallel): read the merged helpers first; adapt call
  shapes only (§3 adaptation rules); log in `validation.md`.
- **800-line cap**: budget per section — Scope ≤ 16, Rules ≤ 150, Patterns ≤ 250, Anti-patterns
  ≤ 160, Version notes ≤ 45, Review checklist ≤ 30, Not confirmed ≤ 25, Sources = 43 bullets.
  Check `wc -l` ≤ 780. Trim prose, never rules or Sources.
- **Prose URL ⊆ Sources**: link bare page URLs only — **no `#fragment`** on any link, so prose URLs
  match the Sources bullets exactly. URLs inside code fences/inline code are exempt; keep the
  example URLs that are in code (e.g. `https://www.googletagmanager.com/...`) inside code.
- **Relative links**: link sibling topic files as `route-handlers-and-apis.md`,
  `data-fetching-and-mutations.md`, `typescript.md`, `rendering-and-caching.md`,
  `performance-and-vercel.md` and the entry point as `../nextjs.md`; they exist (stubs at least).
- **AC7 on Don't blocks**: every `ts`/`tsx` block containing `'use server'` — including Don't
  blocks — calls `verifySession(`/`getSession(`/`auth(` before the first `.create|update|upsert|
  delete|insert…(` call. The anti-patterns in §8 are written to satisfy that while still showing
  the flaw (missing ownership check, raw return, page-only gate).
- **No `any`**, no `TODO`/`TBD`, every fence tagged (`ts`, `tsx`, `bash`, `text`).
- **Placeholders**: no realistic key formats (`sk_live_…` etc.); use `replace-me`.
- **as-of line**: copy `R/nextjs.md`'s as-of line verbatim (expected
  `> As of Next.js 16.3.8, verified 2026-10-04.`). If its version differs from 16.3.8, keep it and
  log; the patched-release facts in SEC-42 stay as written (they are dated to the 2026-09-30 post).
- **Docs drift**: facts are as of 2026-10-04; the file says so via its as-of line.

Gates (run from the run worktree):

```bash
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_proxy_auth_and_security.py -q
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q
uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope
wc -l Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/proxy-auth-and-security.md
git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD
```

One-off evidence check (AC10), output pasted into `validation.md`:

```bash
python3 - <<'EOF'
import re, pathlib
topic = pathlib.Path("Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/proxy-auth-and-security.md").read_text()
evidence = pathlib.Path("docs/sprints/bmn-nextjs-typescript-best-practices-reference/proxy-auth-and-security/evidence/sources-verified.md").read_text()
url = re.compile(r"https://[^\s)>\]|`]+")
sources = set(url.findall(topic.split("\n## Sources", 1)[1]))
listed = set(url.findall(evidence))
print("missing from evidence:", sorted(sources - listed))
print("extra in evidence:", sorted(listed - sources))
raise SystemExit(sources != listed)
EOF
```

## 7. Verified rule sheet

Version facts: latest stable **Next.js 16.3.8** (npm dist-tag `latest`, published 2026-09-30;
every fetched docs page reports `version: 16.3.8`; September 2026 security release post).
Latest major: **16**. Rules are numbered items `N. **SEC-n** <imperative> … [link]`, in this
order, ids 1–45 with no gaps. "Says:" is the paraphrase of the page, for the coder and reviewer
only — do not paste it into the topic file.

Short names used below (exact URLs, use them bare, no fragments):

- PROXY = https://nextjs.org/docs/app/api-reference/file-conventions/proxy
- GS-PROXY = https://nextjs.org/docs/app/getting-started/proxy
- UPG16 = https://nextjs.org/docs/app/guides/upgrading/version-16
- CODEMODS = https://nextjs.org/docs/app/guides/upgrading/codemods
- AUTH = https://nextjs.org/docs/app/guides/authentication
- AUTH-CC = https://nextjs.org/docs/app/guides/authentication-with-cache-components
- DATASEC = https://nextjs.org/docs/app/guides/data-security
- SA-GUIDE = https://nextjs.org/docs/app/guides/server-actions
- USE-SERVER = https://nextjs.org/docs/app/api-reference/directives/use-server
- SA-CONFIG = https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions
- CSP = https://nextjs.org/docs/app/guides/content-security-policy
- HEADERS = https://nextjs.org/docs/app/api-reference/config/next-config-js/headers
- COOKIES = https://nextjs.org/docs/app/api-reference/functions/cookies
- ENV = https://nextjs.org/docs/app/guides/environment-variables
- SCC = https://nextjs.org/docs/app/getting-started/server-and-client-components
- TAINT = https://nextjs.org/docs/app/api-reference/config/next-config-js/taint
- SELFHOST = https://nextjs.org/docs/app/guides/self-hosting
- BFF = https://nextjs.org/docs/app/guides/backend-for-frontend
- BLOG16 = https://nextjs.org/blog/next-16 · BLOG161 = https://nextjs.org/blog/next-16-1 ·
  BLOG162 = https://nextjs.org/blog/next-16-2 · BLOG163 = https://nextjs.org/blog/next-16-3
- SECBLOG = https://nextjs.org/blog/security-nextjs-server-components-actions
- ADV-66478 = https://nextjs.org/blog/CVE-2025-66478
- ADV-DEC25 = https://nextjs.org/blog/security-update-2025-12-11
- SR-JUL26 = https://nextjs.org/blog/july-2026-security-release
- SR-AUG26 = https://nextjs.org/blog/august-2026-security-release
- SR-SEP22 = https://nextjs.org/blog/nextjs-security-update-september-22-2026
- SR-SEP26 = https://nextjs.org/blog/september-2026-security-release
- SR-PROG = https://nextjs.org/blog/next-security-release-program
- POSTMORTEM = https://vercel.com/blog/postmortem-on-next-js-middleware-bypass
- V-ENV = https://vercel.com/docs/environment-variables
- V-SENS = https://vercel.com/docs/environment-variables/sensitive-environment-variables
- V-TYPES = https://vercel.com/changelog/environment-variables-now-use-config-and-secret-types
- V-ROTATE = https://vercel.com/docs/environment-variables/rotating-secrets
- V-BLOCK = https://vercel.com/changelog/new-deployments-of-vulnerable-next-js-applications-are-now-blocked-by
- V-DP = https://vercel.com/docs/deployment-protection
- V-FW = https://vercel.com/docs/vercel-firewall
- R-CACHE = https://react.dev/reference/react/cache
- R-TAINT-OBJ = https://react.dev/reference/react/experimental_taintObjectReference
- R-TAINT-VAL = https://react.dev/reference/react/experimental_taintUniqueValue
- R-USE-SERVER = https://react.dev/reference/rsc/use-server
- ZOD = https://zod.dev/basics

These 43 URLs are exactly the `## Sources` list (one bullet each, in this order).

### Proxy

- **SEC-1** Name the request-interception file `proxy.ts` (project root, or `src/` when used, at the
  same level as `app/`) and export one function named `proxy` — as a named export, or as a default
  export of a function named `proxy`; never create a new `middleware.ts`. — PROXY, UPG16, GS-PROXY.
  Says: "The file must export a single function, either as a default export or named `proxy`";
  `middleware` file convention deprecated and renamed; "We recommend changing the function name to
  `proxy`, even if you are using a default export"; only one `proxy.ts` per project, split logic
  into imported modules. **Changed in 16.**
- **SEC-2** Leave the `runtime` segment option out of `proxy.ts`: Proxy runs on the Node.js
  runtime, the option is not available and setting it throws; check that session and auth
  libraries used there run on Node.js. — PROXY, UPG16, AUTH. Says: "Proxy defaults to using the
  Node.js runtime. The `runtime` config option is not available in Proxy files. Setting the
  `runtime` config option in Proxy will throw an error."; upgrade guide: edge "NOT supported in
  proxy … cannot be configured. If you want to continue using the edge runtime, keep using
  middleware". **Changed in 16.**
- **SEC-3** Export `config.matcher` with literal values only, run it on every page route for auth,
  and exclude `_next/static`, `_next/image` and static files so redirects cannot block CSS, JS or
  images. — PROXY, AUTH. Says: without a matcher Proxy runs on every request incl. static files,
  "auth logic or redirects can unintentionally block CSS, JS, or images"; "matcher values need to
  be constants … Dynamic values such as variables will be ignored"; auth guide tip: "for auth, it's
  recommended Proxy runs on all routes".
- **SEC-4** Keep auth in Proxy **optimistic**: read the session from the cookie only (e.g.
  `request.cookies.get('session')` then decrypt), answer with `NextResponse.redirect` or
  `NextResponse.next()`, and never query a database or do slow fetches there. — AUTH, GS-PROXY.
  Says: Proxy runs on every route "including prefetched routes … only read the session from the
  cookie (optimistic checks), and avoid database checks"; "not intended for slow data fetching …
  should not be used as a full session management or authorization solution"; fetch cache options
  have no effect in Proxy.
- **SEC-5** Re-check authentication and authorisation where data is read or written — in the Data
  Access Layer, in every Server Action and in every Route Handler — and never let Proxy be the only
  line of defence. — AUTH, PROXY, BFF, POSTMORTEM, SR-JUL26. Says: "it should not be your only line
  of defense"; Server Functions are POSTs to the route that uses them, so a matcher that excludes
  a path also skips them, and "A matcher change or a refactor that moves a Server Function … can
  silently remove Proxy coverage. Always verify authentication and authorization inside each
  Server Function"; BFF: "Do not rely on proxy alone"; postmortem: "We do not recommend Middleware
  to be the sole method of protecting routes"; July 2026: CVE-2026-64642 Proxy bypass skipped "any
  authentication or security checks that a middleware/proxy may perform".
- **SEC-6** Forward values to the app with `NextResponse.next({ request: { headers } })`, and never
  put session data or secrets in response headers (`NextResponse.next({ headers })`,
  `response.headers.set`), which reach the browser. — PROXY, BFF. Says: "**NOT**
  `NextResponse.next({ headers: requestHeaders })` which makes `requestHeaders` available to
  clients"; BFF: response headers "will be visible to clients".

### Sessions and cookies

- **SEC-7** Set the session cookie only on the server — in a Server Action or Route Handler (or on a
  Proxy response) — with `httpOnly: true`, `secure: true`, `sameSite: 'lax'` (or `'strict'`), an
  `expires` or `maxAge`, and `path: '/'`. — AUTH, COOKIES. Says: recommended options HttpOnly,
  Secure, SameSite, Max-Age/Expires, Path; "Cookies should be set on the server to prevent
  client-side tampering"; "HTTP does not allow setting cookies after streaming starts, so you must
  use `.set` in a Server Function or Route Handler"; option table (`httpOnly`, `secure`,
  `sameSite`, `maxAge`, `expires`, `path` default `'/'`).
- **SEC-8** Sign or encrypt the session with a secret read from an environment variable (e.g.
  `SESSION_SECRET`) through a session library, prefer an auth library over hand-rolled auth, and
  keep the payload to the minimum (user id, role) — no PII, no passwords. — AUTH. Says: "we
  recommend using an authentication library"; session libraries iron-session or Jose; secret key
  stored as env var; payload "should contain the **minimum** … It should not contain personally
  identifiable information … or sensitive data like passwords."
- **SEC-9** Use database sessions — data in a table, only an encrypted session ID in the cookie —
  when you need server-side revocation such as logging out every device; otherwise stateless
  cookie sessions are acceptable. — AUTH. Says: database sessions "more secure, but can be
  complex"; tip: "give users the ability to log out of all devices".
- **SEC-10** Perform logout and every other mutation (cookie `set`/`delete`, database writes,
  revalidation) in a Server Action or Route Handler, never as a side effect of rendering. —
  DATASEC, COOKIES. Says: "Mutations … should never be a side-effect … Next.js explicitly prevents
  setting cookies or triggering cache revalidation within render methods"; `.delete` only in a
  Server Function or Route Handler.
- **SEC-11** Await `cookies()` and `headers()` everywhere auth code reads them; synchronous access
  is removed in Next.js 16. — UPG16. Says: "Starting with **Next.js 16**, synchronous access is
  fully removed." **Changed in 16.**

### Data Access Layer, DTOs, server-only

- **SEC-12** Put every data read and its authorisation check in a Data Access Layer: a module that
  starts with `import 'server-only'`, whose session check is wrapped in React `cache(` and called by
  every DAL function. — AUTH, DATASEC, R-CACHE. Says: "We recommend creating a DAL to centralize
  your data requests and authorization logic"; `verifySession()` wrapped in `cache` "to memoize the
  return value … during a React render pass"; DAL should "Only run on the server. Perform
  authorization checks. Return safe, minimal DTOs"; react.dev: `cache` is "only for use with React
  Server Components" and is invalidated for each server request.
- **SEC-13** Return DTOs from the DAL: select explicit columns and apply per-field visibility
  rules; never return whole records. — AUTH, DATASEC. Says: "return only the necessary data …
  rather than the entire user object which could contain passwords, phone numbers"; example
  `getProfileDTO` with `canSeePhoneNumber`.
- **SEC-14** Import database clients and read secret `process.env` values only inside the Data
  Access Layer. — DATASEC. Says: "only the Data Access Layer should access `process.env`"; audit:
  "Verify that database packages and environment variables are not imported outside the Data
  Access Layer."
- **SEC-15** Start every module that holds secrets, session logic or database access with
  `import 'server-only'`, so a Client Component import fails the build. — DATASEC, SCC. Says:
  `server-only` causes "a build error if the module is imported in the client environment";
  installing the package is optional, Next.js handles the import internally.
- **SEC-16** Give Client Components only the fields they render, with narrow prop types — never a
  whole user or database object. — DATASEC. Says: component-level access "makes it easier to
  accidentally expose private data"; "BAD: … accepts way more data than the Client Component
  needs"; audit: "Are the Component props expecting private data? Are the type signatures overly
  broad?"
- **SEC-17** Check auth in the DAL, the page or the leaf component that renders protected data,
  not only in a layout, and never `return null` from a layout as access control. — AUTH. Says:
  layouts "don't re-render on navigation … the user session won't be checked on every route
  change"; a layout "does not control whether the rest of the route renders"; returning null in a
  layout "is **not recommended** … will not prevent nested route segments and Server Actions from
  being accessed".
- **SEC-18** Derive identity and role from the verified session on every request; never authorise
  from `searchParams`, `params`, form fields or headers, and validate bracketed route params. —
  DATASEC. Says: "BAD: Trusting searchParams directly … GOOD: Re-verify every time"; audit:
  "`/[param]/.` Folders with brackets are user input. Are params validated?"
- **SEC-19** Treat the taint APIs (`experimental_taintObjectReference`,
  `experimental_taintUniqueValue`, enabled with `experimental.taint`) as an experimental extra
  layer, never the only guard: copies and derived values are not tracked. — TAINT, DATASEC,
  R-TAINT-OBJ, R-TAINT-VAL. Says: taint config "experimental … not recommended for production";
  "Do not rely on the taint API as your only mechanism"; copying an object creates an untainted
  version; derived values are not tracked; enabling it also enables the React experimental
  channel and taints `process.env` by reference only; react.dev: "not available in a stable
  version of React yet".
- **SEC-20** With Cache Components, resolve the user in the exported getter and pass only the id to
  an unexported `'use cache'` function, and never read `cookies()` inside a plain `use cache`
  scope. — AUTH-CC. Says: "Keep `getNotesByUserId` unexported so a caller can't request another
  user's notes by passing a different id"; "Reading `cookies()` or `headers()` inside a plain `use
  cache` function. This throws."

### Server Actions

- **SEC-21** Authenticate and authorise inside every Server Action as for a public POST endpoint —
  page-level checks do not extend to the actions on that page — and check that the caller owns the
  target resource. — DATASEC, SA-GUIDE, AUTH, R-USE-SERVER. Says: an exported action "is reachable
  via a direct POST request"; "A page-level authentication check does not extend to the Server
  Actions defined within it"; IDOR example with ownership check; "Treat every action as an
  untrusted entry point"; react.dev: "make sure to validate that the logged-in user is allowed to
  perform that action".
- **SEC-22** Validate every Server Action argument at runtime (for example zod `safeParse`), because
  TypeScript annotations are not enforced, and accept an id plus the change — never the row or its
  ownership from the client. — SA-GUIDE, SECBLOG, R-USE-SERVER, ZOD. Says: "Validate inputs. Treat
  `FormData`, query parameters, and headers as untrusted"; "Send a reference (typically an ID) plus
  the user's change, and re-read the rest from a trusted source using the session. Schema
  validation … only checks the *shape*"; blog: "The TypeScript annotations are not enforced";
  react.dev: "Arguments to Server Functions are fully client-controlled"; zod: `.safeParse()`
  returns `{ success, data | error }`.
- **SEC-23** Return only what the UI renders from a Server Action — return values are serialised to
  the client — never raw database records. — DATASEC, USE-SERVER. Says: "Server Action return
  values are serialized and sent to the client. Only return what the UI needs, not raw database
  records."
- **SEC-24** Read authentication from cookies or headers inside the action; never accept tokens as
  Server Action parameters. — USE-SERVER. Says: "Read authentication from cookies or headers rather
  than accepting tokens as function parameters."
- **SEC-25** Keep secrets out of inline Server Action closures, and do not rely on closure
  encryption to hide them. — DATASEC. Says: captured variables "are sent to the client and back …
  Next.js automatically encrypts the closed-over variables"; "We don't recommend relying on
  encryption alone".
- **SEC-26** Set one stable `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY` (base64, a 16-, 24- or 32-byte AES
  key, supplied at build) when you self-host more than one instance. — DATASEC, SELFHOST. Says:
  "all instances must use the same encryption key"; "base64-encoded value with a valid AES key
  length (16, 24, or 32 bytes)"; example `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY=… next build`, "The
  key is embedded in the build output".
- **SEC-27** Keep the built-in Origin/Host CSRF check: add `experimental.serverActions.allowedOrigins`
  entries only for the browser-visible host of a reverse proxy or CDN that does not forward
  `x-forwarded-host`, written as `host[:port]` with `*`/`**` wildcards only as documented. —
  SA-CONFIG, DATASEC, SA-GUIDE. Says: Origin host compared to `x-forwarded-host`/`host`, mismatch
  rejected; "If not provided, only the same origin is allowed"; "no entry is needed as long as the
  proxy forwards the public host in `x-forwarded-host`"; `*` = one label, `**` = one or more, only
  at the start; ports can't be wildcarded; "The check runs in production as well as in
  development"; a request with no `Origin` header "is allowed through with a warning". Config key
  shown in every example: `experimental.serverActions`.
- **SEC-28** Keep `experimental.serverActions.bodySizeLimit` at its 1MB default and raise it only for
  a real upload, to the smallest value that fits plus 10–20 KB of multipart overhead. — SA-CONFIG,
  SA-GUIDE. Says: default 1MB "to prevent the consumption of excessive server resources … as well
  as potential DDoS attacks"; accepts bytes or strings like `'2mb'`; limit covers multipart
  overhead, "an additional 10–20 KB is a reasonable rule of thumb".
- **SEC-29** Rate-limit expensive Server Actions and Route Handlers (sending email, writes) in code
  and turn on the host's rate-limiting features. — DATASEC, BFF, V-FW. Says: "consider adding rate
  limiting to prevent abuse"; BFF: "enable any rate limiting features provided by your host";
  Vercel WAF (custom rules, IP blocking, managed rulesets) "available on all plans".

### Route Handlers

- **SEC-30** Authorise every Route Handler like a public API endpoint: `401` without a session,
  `403` without permission; CORS, CSRF and webhook verification are in
  [route-handlers-and-apis.md](route-handlers-and-apis.md). — AUTH. Says: "Treat Route Handlers
  with the same security considerations as public-facing API endpoints"; example returns 401 then
  403.

### Content Security Policy and headers

- **SEC-31** For a strict CSP, generate a fresh nonce per request in `proxy.ts`, set the
  `Content-Security-Policy` header on both the forwarded request and the response, and pass the
  nonce as an `x-nonce` request header. — CSP. Says: "Every time a page is viewed, a fresh nonce
  should be generated"; Next.js "parses the `Content-Security-Policy` header and extracts the
  nonce" during render and applies it to framework scripts, page bundles, inline styles/scripts and
  `<Script nonce>`; example builds `nonce` with `Buffer.from(crypto.randomUUID()).toString('base64')`.
- **SEC-32** Accept that a nonce CSP makes every page dynamically rendered — no static
  optimisation, ISR or default CDN caching, and Partial Prerendering is incompatible — or keep pages
  static with a no-nonce CSP in `next.config` `headers()` or the experimental SRI option. — CSP.
  Says: "you **must use dynamic rendering to add nonces**"; "Static optimization and Incremental
  Static Regeneration (ISR) are disabled"; "PPR is incompatible with nonce-based CSP"; force with
  `await connection()`; "Without Nonces" via `headers()`; SRI experimental, App Router only.
- **SEC-33** Add `'unsafe-eval'` to `script-src` only when `NODE_ENV === 'development'`. — CSP. Says:
  "`unsafe-eval` is not required for production. Neither React nor Next.js use `eval` in
  production by default."
- **SEC-34** Read the nonce in a Server Component with `(await headers()).get('x-nonce')` and pass it
  to `<Script nonce>` and third-party script components. — CSP. Says: "You can read the nonce from
  a Server Component using `headers`"; GoogleTagManager example passes `nonce`.
- **SEC-35** Skip prefetches and static assets in the CSP Proxy matcher with `missing` conditions on
  the `next-router-prefetch` and `purpose: prefetch` headers. — CSP. Says: "We recommend ignoring
  matching prefetches (from `next/link`) and static assets that don't need the CSP header."
- **SEC-36** Send baseline security headers from `next.config.ts` `headers()` for
  `source: '/(.*)'` — `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`,
  `Referrer-Policy`, `Permissions-Policy` — and use CSP `frame-ancestors` instead of
  `X-Frame-Options`. — HEADERS. Says: documented values `max-age=63072000; includeSubDomains;
  preload`, `nosniff` ("The only valid value"), `origin-when-cross-origin`,
  `camera=(), microphone=(), geolocation=(), browsing-topics=()`; X-Frame-Options "has been
  superseded by CSP's `frame-ancestors` option".

### Environment variables and secrets

- **SEC-37** Never prefix a secret with `NEXT_PUBLIC_`: the value is inlined into the client bundle
  at `next build`, while unprefixed variables stay server-only. — ENV, SCC. Says: prefix tells
  Next.js to "inline a value, at build time, into the js bundle that is delivered to the client";
  "only environment variables prefixed with `NEXT_PUBLIC_` are included in the client bundle. If
  variables are not prefixed, Next.js replaces them with an empty string."
- **SEC-38** Treat `NEXT_PUBLIC_` values as frozen at build time, and read per-environment runtime
  values on the server after `await connection()`; `serverRuntimeConfig` and `publicRuntimeConfig`
  are removed in Next.js 16. — ENV, UPG16. Says: after build "your app will no longer respond to
  changes to these environment variables"; dynamic lookups (`process.env[varName]`, `const env =
  process.env`) are not inlined; `connection()` example "evaluated at runtime"; runtime config
  removed, "Use environment variables instead". **Changed in 16.**
- **SEC-39** Commit no `.env*.local` file and no `.env` file holding secrets, and keep `.env*` files
  in the project root, not in `src/`. — ENV. Says: "You almost never want to commit these files";
  `.env*.local` "intended to be ignored through `.gitignore`"; "Next.js will load the .env files
  **only** from the parent folder and **not** from the `/src` folder"; load order `process.env` →
  `.env.$(NODE_ENV).local` → `.env.local` (not in test) → `.env.$(NODE_ENV)` → `.env`.
- **SEC-40** Store passwords, API keys and tokens on Vercel as **Secret**-type environment variables
  (formerly "Sensitive"; not readable after saving), and use **Config** only for non-sensitive
  values such as `NEXT_PUBLIC_` ones. — V-TYPES, V-SENS. Says (changelog 2026-08-24): "you now
  choose Config or Secret instead of using the Sensitive toggle. Existing variables marked
  Sensitive are automatically treated as Secrets"; Secret: "members cannot view or retrieve it after
  saving. Use Secret for passwords, API keys, and tokens"; sensitive page: only production and
  preview environments; values ≥ 32 chars redacted from build logs. **Changed 2026-08 (Vercel).**
- **SEC-41** Redeploy after changing or rotating a Vercel environment variable, and rotate by adding
  the new credential, redeploying, then invalidating the old one. — V-ENV, V-ROTATE. Says: "Any
  change you make to environment variables are not applied to previous deployments, they only
  apply to new deployments"; "updating Vercel *before* you invalidate the old credential".

### Patching and platform

- **SEC-42** Keep `next` on the latest patched release of a supported line — 16.3.8 (16.3) or
  15.5.27 (15.5) as of the 2026-09-30 security release — follow the pre-announced monthly security
  releases on the Next.js blog, and rotate secrets after patching an exploitable advisory. —
  SR-SEP26, SR-PROG, ADV-66478, SR-JUL26. Says: "Updates are now available in v16.3.8 (Active LTS)
  and v15.5.27 (Maintenance LTS)"; "roughly once a month, we'll publish advance notice of upcoming
  security releases"; React2Shell: "we recommend rotating all your application secrets".
- **SEC-43** Leave Vercel's block on deploying vulnerable Next.js versions on — never set
  `DANGEROUSLY_DEPLOY_VULNERABLE_CVE_2025_66478`. — V-BLOCK. Says: new deployments vulnerable to
  CVE-2025-66478 "will now automatically fail to deploy"; the env var disables it.
- **SEC-44** Enable Vercel Deployment Protection (Standard Protection, the recommended scope) so
  preview deployments are not public. — V-DP. Says: "**Standard Protection** is the recommended
  option for most projects. It protects all domains except production domains"; available on all
  plans.
- **SEC-45** Serve production only from a production build (`next build` + `next start`, or the
  platform) — never `next dev` — and when self-hosting put a reverse proxy in front of the server.
  — SECBLOG, SR-SEP26, SELFHOST. Says: "always run in Next.js in production mode for production
  workloads. Development mode does not optimize for security"; dev-mode server errors "sent in
  plain text"; Sept 2026: dev server MCP endpoint disclosure, "Only applications run with `next
  dev` are affected"; self-hosting: reverse proxy handles "malformed requests, slow connection
  attacks, payload size limits, rate limiting".

## 8. Section content for the topic file

### H1, as-of, Scope (≤ 16 lines)

H1: `# Proxy, authentication and security`. Next line: the as-of line copied from `R/nextjs.md`.

`## Scope` (bullets): covers the `proxy.ts` file (name, export, runtime, matcher, what it may and
may not do), sessions and cookies, optimistic vs secure checks, the Data Access Layer and DTOs,
`server-only` and taint, Server Action security (`allowedOrigins`, `bodySizeLimit`, closures),
Route Handler authorisation, nonce CSP and security headers, `NEXT_PUBLIC_` exposure and secrets
on Vercel, patch levels. Not covered (link each): form/action mechanics →
[data-fetching-and-mutations.md](data-fetching-and-mutations.md); CORS, webhooks, CSRF for
handlers → [route-handlers-and-apis.md](route-handlers-and-apis.md); env var typing →
[typescript.md](typescript.md); caching → [rendering-and-caching.md](rendering-and-caching.md);
image optimisation and platform limits → [performance-and-vercel.md](performance-and-vercel.md);
entry point [../nextjs.md](../nextjs.md). One line: no auth library is mandated; examples follow the
authentication guide's library-agnostic pattern; `@/lib/prisma` is the canonical tree's DB client.

### Rules

The 45 items from §7, flat numbered list `1. **SEC-1** …` to `45. **SEC-45** …`, each 1–3 lines,
each with its markdown link(s) to the short-named URLs (bare URLs, link text = page title or short
name). No subheadings inside `## Rules` unless the contract allows them; if it does, use the §7
group names.

### Patterns (≤ 250 lines)

Short lead-in sentence per block naming the rules it implements. Blocks, in order (copy verbatim;
filename in a first-line comment):

1. Session cookie (SEC-7, SEC-8, SEC-15) — `ts`:

```ts
// lib/session.ts — stateless session, server-only
import 'server-only'
import { cookies } from 'next/headers'
import { SignJWT, jwtVerify } from 'jose'

export type SessionPayload = { userId: string; role: 'admin' | 'user'; expiresAt: Date }

const SESSION_TTL_MS = 7 * 24 * 60 * 60 * 1000
const secret = process.env.SESSION_SECRET
if (!secret) throw new Error('SESSION_SECRET is not set')
const encodedKey = new TextEncoder().encode(secret)

export async function encrypt(payload: SessionPayload): Promise<string> {
  return new SignJWT(payload)
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('7d')
    .sign(encodedKey)
}

export async function decrypt(token: string | undefined = '') {
  try {
    const { payload } = await jwtVerify(token, encodedKey, { algorithms: ['HS256'] })
    return payload
  } catch {
    return undefined // invalid or expired token: treated as "no session"
  }
}

export async function createSession(userId: string, role: SessionPayload['role']): Promise<void> {
  const expiresAt = new Date(Date.now() + SESSION_TTL_MS)
  const session = await encrypt({ userId, role, expiresAt })
  const cookieStore = await cookies()
  cookieStore.set('session', session, {
    httpOnly: true,
    secure: true,
    expires: expiresAt,
    sameSite: 'lax',
    path: '/',
  })
}

export async function deleteSession(): Promise<void> {
  const cookieStore = await cookies()
  cookieStore.delete('session')
}
```

   Note under it: the fail-fast `SESSION_SECRET` check is `(convention)`; the rest mirrors the
   authentication guide.

2. Data Access Layer (SEC-12, SEC-13, SEC-14, SEC-15) — `ts`:

```ts
// lib/dal.ts — every read goes through a cached session check
import 'server-only'
import { cache } from 'react'
import { cookies } from 'next/headers'
import { redirect } from 'next/navigation'
import { decrypt } from '@/lib/session'
import { prisma } from '@/lib/prisma' // your DB client

export type Session = { userId: string; role: 'admin' | 'user' }
export type UserDTO = { id: string; name: string }

const isRole = (value: unknown): value is Session['role'] => value === 'admin' || value === 'user'

// Secure check, memoised per request. Returns null so Route Handlers can answer 401.
export const getSession = cache(async (): Promise<Session | null> => {
  const payload = await decrypt((await cookies()).get('session')?.value)
  const userId = payload?.userId
  const role = payload?.role
  if (typeof userId !== 'string' || !isRole(role)) return null
  return { userId, role }
})

// Pages and Server Actions: redirect when there is no session.
export const verifySession = cache(async (): Promise<Session> => {
  const session = await getSession()
  if (!session) redirect('/login')
  return session
})

export const getCurrentUser = cache(async (): Promise<UserDTO | null> => {
  const { userId } = await verifySession()
  return prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, name: true }, // DTO: only what the UI renders
  })
})
```

   Note: the `getSession`/`verifySession` split is `(convention)`, built on the guide's
   `verifySession()`.

3. Optimistic proxy (SEC-1, SEC-3, SEC-4) — `ts`:

```ts
// proxy.ts — optimistic check only: a valid session cookie, no database
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'
import { decrypt } from '@/lib/session'

const PROTECTED_PREFIXES = ['/dashboard']
const PUBLIC_ROUTES = ['/login', '/signup']

const isProtected = (pathname: string): boolean =>
  PROTECTED_PREFIXES.some((prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`))

export async function proxy(request: NextRequest): Promise<NextResponse> {
  const { pathname } = request.nextUrl
  const session = await decrypt(request.cookies.get('session')?.value)

  if (isProtected(pathname) && !session?.userId) {
    return NextResponse.redirect(new URL('/login', request.nextUrl))
  }
  if (PUBLIC_ROUTES.includes(pathname) && session?.userId) {
    return NextResponse.redirect(new URL('/dashboard', request.nextUrl))
  }
  return NextResponse.next()
}

export const config = {
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico|.*\\.png$).*)'],
}
```

   Note: `api` is excluded because every Route Handler authorises itself (SEC-30); Server Actions
   still pass through because they POST to page routes (SEC-5).

4. Server Action that authorises before it mutates (SEC-21, SEC-22, SEC-23, SEC-24) — `ts`:

```ts
// app/posts/actions.ts
'use server'
import { revalidatePath } from 'next/cache'
import * as z from 'zod'
import { verifySession } from '@/lib/dal'
import { prisma } from '@/lib/prisma'

const PostId = z.string().min(1)

export type DeletePostResult = { ok: true } | { ok: false; error: 'invalid' | 'not-found' }

export async function deletePost(postId: string): Promise<DeletePostResult> {
  const { userId } = await verifySession() // 1. authenticate: identity from the cookie
  const parsed = PostId.safeParse(postId) // 2. validate: TS types are not enforced at runtime
  if (!parsed.success) return { ok: false, error: 'invalid' }
  const post = await prisma.post.findFirst({
    where: { id: parsed.data, authorId: userId }, // 3. authorise: caller owns the row
    select: { id: true },
  })
  if (!post) return { ok: false, error: 'not-found' }
  await prisma.post.delete({ where: { id: post.id } })
  revalidatePath('/posts')
  return { ok: true } // 4. minimal return value
}
```

5. Route Handler (SEC-30) — `ts`:

```ts
// app/api/reports/route.ts
import { getSession } from '@/lib/dal'
import { listReports } from '@/lib/reports' // DAL function returning DTOs

export async function GET(): Promise<Response> {
  const session = await getSession()
  if (!session) return new Response(null, { status: 401 })
  if (session.role !== 'admin') return new Response(null, { status: 403 })
  return Response.json(await listReports())
}
```

6. Nonce CSP in Proxy (SEC-31, SEC-32, SEC-33, SEC-35) — `ts`:

```ts
// proxy.ts — nonce-based CSP (one proxy.ts per project: compose with the auth check above)
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function proxy(request: NextRequest): NextResponse {
  const nonce = Buffer.from(crypto.randomUUID()).toString('base64')
  const isDev = process.env.NODE_ENV === 'development'
  const csp = `
    default-src 'self';
    script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${isDev ? " 'unsafe-eval'" : ''};
    style-src 'self' 'nonce-${nonce}';
    img-src 'self' blob: data:;
    font-src 'self';
    object-src 'none';
    base-uri 'self';
    form-action 'self';
    frame-ancestors 'none';
    upgrade-insecure-requests;
  `.replace(/\s{2,}/g, ' ').trim()

  const requestHeaders = new Headers(request.headers)
  requestHeaders.set('x-nonce', nonce)
  requestHeaders.set('Content-Security-Policy', csp)

  const response = NextResponse.next({ request: { headers: requestHeaders } })
  response.headers.set('Content-Security-Policy', csp)
  return response
}

export const config = {
  matcher: [
    {
      source: '/((?!api|_next/static|_next/image|favicon.ico).*)',
      missing: [
        { type: 'header', key: 'next-router-prefetch' },
        { type: 'header', key: 'purpose', value: 'prefetch' },
      ],
    },
  ],
}
```

   Prose after it (SEC-1, SEC-34): one `proxy.ts` per project — put the auth check and the CSP in
   modules and call both from the single `proxy` function ([GS-PROXY]); read the nonce with
   `(await headers()).get('x-nonce')` and pass it to `<Script nonce>`; pages need dynamic
   rendering (`await connection()`).

7. Security headers and Server Action limits in `next.config.ts` (SEC-27, SEC-28, SEC-36) — `ts`:

```ts
// next.config.ts
import type { NextConfig } from 'next'

const securityHeaders = [
  { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=(), browsing-topics=()' },
]

const nextConfig: NextConfig = {
  async headers() {
    return [{ source: '/(.*)', headers: securityHeaders }]
  },
  experimental: {
    serverActions: {
      allowedOrigins: ['shop.example.com'], // only if a proxy forwards its own host (SEC-27)
      bodySizeLimit: '2mb', // only if an upload needs more than the 1MB default (SEC-28)
    },
  },
}

export default nextConfig
```

### Anti-patterns (≤ 160 lines)

Format per item (adapt the markers only if the Authoring contract fixes another format):
`### <title> (SEC-n)`, then `**Don't** — <one line why>` + fenced block, then `**Do** — <one
line>` + fenced block. Seven items:

1. **Proxy as the only gate** (SEC-4, SEC-5; cite POSTMORTEM for CVE-2025-29927 and SR-JUL26 for
   CVE-2026-64642 in the why-line). Don't (`ts`):

```ts
// proxy.ts — DON'T: database lookup on every route and prefetch; pages below trust it
export async function proxy(request: NextRequest): Promise<NextResponse> {
  const token = request.cookies.get('session')?.value ?? ''
  const row = await prisma.session.findUnique({ where: { token } })
  if (!row) return NextResponse.redirect(new URL('/login', request.nextUrl))
  return NextResponse.next()
}
```

   Do (`ts`):

```ts
const session = await decrypt(request.cookies.get('session')?.value) // proxy.ts: optimistic only
const { userId } = await verifySession() // every page, action and handler: the secure check
```

2. **Page-level check only** (SEC-21). Don't (`tsx`):

```tsx
// app/admin/page.tsx — DON'T: the page is gated, the inline action is not
export default async function AdminPage() {
  await verifySession() // gates the UI only
  async function purge(): Promise<void> {
    'use server'
    await prisma.record.deleteMany() // anyone who can POST to /admin runs this
  }
  return <form action={purge}><button>Delete records</button></form>
}
```

   Do (`tsx`):

```tsx
async function purge(): Promise<void> {
  'use server'
  const { role } = await verifySession() // the action is its own entry point
  if (role !== 'admin') throw new Error('Forbidden')
  await prisma.record.deleteMany()
}
```

3. **Trusting the client's row (IDOR)** (SEC-21, SEC-22). Don't (`ts`):

```ts
'use server'
// DON'T: authenticated, but the row and its id come from the client: any item can be changed
export async function completeItem(item: { id: string; ownerId: string }): Promise<void> {
  await verifySession()
  await prisma.item.update({ where: { id: item.id }, data: { completed: true } })
}
```

   Do (`ts`):

```ts
'use server'
export async function completeItem(itemId: string): Promise<void> {
  const { userId } = await verifySession()
  const id = z.string().min(1).parse(itemId)
  const item = await prisma.item.findFirst({ where: { id, ownerId: userId }, select: { id: true } })
  if (!item) throw new Error('Forbidden')
  await prisma.item.update({ where: { id: item.id }, data: { completed: true } })
}
```

4. **Secret behind `NEXT_PUBLIC_`** (SEC-37). Don't (`bash`):

```bash
# .env — DON'T: inlined into every client bundle at next build
NEXT_PUBLIC_PAYMENTS_SECRET_KEY=replace-me
```

   Do (`ts`):

```ts
// lib/payments.ts — read the secret only on the server, inside the DAL
import 'server-only'
const secretKey = process.env.PAYMENTS_SECRET_KEY
```

5. **Raw records to the client** (SEC-13, SEC-16, SEC-23). Don't (`ts`):

```ts
'use server'
// DON'T: returns the full row (password hash, internal flags) to the browser
export async function renameUser(formData: FormData) {
  const { userId } = await verifySession()
  return prisma.user.update({ where: { id: userId }, data: { name: String(formData.get('name')) } })
}
```

   Do (`ts`):

```ts
'use server'
export async function renameUser(formData: FormData): Promise<{ ok: true }> {
  const { userId } = await verifySession()
  const name = z.string().min(1).max(100).parse(formData.get('name'))
  await prisma.user.update({ where: { id: userId }, data: { name } })
  return { ok: true }
}
```

6. **Mutating cookies during render** (SEC-10). Don't (`tsx`):

```tsx
// app/profile/page.tsx — DON'T: a GET with ?logout=1 deletes the cookie while rendering
export default async function Page({ searchParams }: { searchParams: Promise<{ logout?: string }> }) {
  if ((await searchParams).logout) (await cookies()).delete('session')
  return <Profile />
}
```

   Do (`tsx`):

```tsx
import { logout } from './actions' // a Server Action that calls deleteSession(), then redirects
export default function Page() {
  return <form action={logout}><button type="submit">Log out</button></form>
}
```

7. **Secrets in Proxy response headers** (SEC-6). Don't (`ts`):

```ts
// proxy.ts — DON'T: NextResponse.next({ headers }) sends these headers to the browser
const headers = new Headers(request.headers)
headers.set('x-session-token', token)
return NextResponse.next({ headers })
```

   Do (`ts`):

```ts
return NextResponse.next({ request: { headers } }) // visible to the app, not to the client
```

Every `'use server'` block above calls `verifySession(` before its first write call (AC7).

## 9. Version notes content (≤ 45 lines)

Heading text must contain `Next.js 16` (major of the as-of version). Items, each with its link:

1. **`middleware` → `proxy` (Next.js 16.0)** — UPG16, PROXY, BLOG16, CODEMODS: the `middleware`
   file convention is deprecated and renamed to `proxy`; rename `middleware.ts` → `proxy.ts` and
   the exported function `middleware` → `proxy` (recommended even for a default export). Runtime:
   Proxy runs on Node.js and the runtime cannot be configured; the `edge` runtime is not supported
   in `proxy` — the docs say to keep the deprecated `middleware.ts` if you need `edge`, and the
   Next.js 16 post says it "will be removed in a future version". Codemod:
   `npx @next/codemod@latest middleware-to-proxy .` (codemods page; the proxy reference shows
   `@canary`). It also renames `skipMiddlewareUrlNormalize` → `skipProxyUrlNormalize`,
   `experimental.middlewarePrefetch` → `experimental.proxyPrefetch`,
   `experimental.middlewareClientMaxBodySize` → `experimental.proxyClientMaxBodySize` and
   `experimental.externalMiddlewareRewritesResolve` → `experimental.externalProxyRewritesResolve`.
   The proxy reference version history: "`v16.0.0` Middleware is deprecated and renamed to Proxy.
   Proxy defaults to the Node.js runtime".
2. **Async request APIs** — UPG16: synchronous `cookies()`, `headers()`, `draftMode()`, `params`,
   `searchParams` access is removed (SEC-11).
3. **Runtime config removed** — UPG16: `serverRuntimeConfig`/`publicRuntimeConfig` removed; use env
   vars, `NEXT_PUBLIC_` for client values and `connection()` for runtime reads; the guide points to
   the taint API for sensitive values (SEC-38, SEC-19).
4. **Image local-IP restriction** — UPG16: local IP optimisation blocked by default
   (`images.dangerouslyAllowLocalIP` only for private networks); detail in
   [performance-and-vercel.md](performance-and-vercel.md).
5. **No change** — UPG16 lists no change to Server Action security options or CSP/nonce handling;
   the CSP guide's version history ends at `v14.0.0`; the 16.1, 16.2 and 16.3 release posts
   (BLOG161, BLOG162, BLOG163) list no change to this topic.
6. **Security advisories in the 16.x line** (patch-level floor; SEC-42), each linked:
   - CVE-2025-66478 (React2Shell, RSC remote code execution, CVSS 10.0) — fixed in 16.0.7 — ADV-66478;
     rotate secrets if exposed.
   - CVE-2025-55184 / CVE-2025-67779 (DoS) and CVE-2025-55183 (Server Function source exposure) —
     16.0.10 — ADV-DEC25.
   - July 2026 — 16.2.11 (and 16.3.0): CVE-2026-64642 Proxy bypass with Turbopack and a single
     `i18n` locale; CVE-2026-64641 Server Actions DoS; CVE-2026-64643 action/`use cache` ID
     disclosure; CVE-2026-64649 SSRF via Server Actions on custom servers; CVE-2026-64645 SSRF in
     `rewrites`/open redirect in `redirects` from request-controlled hostnames — SR-JUL26.
   - August 2026 — 16.3.3: AVIF image optimisation RCE, Windows-hosted RCE — SR-AUG26.
   - 2026-09-22 — 16.3.6: `next/og` Node.js `ImageResponse` RCE — SR-SEP22.
   - 2026-09-30 — 16.3.8: image optimisation SSRF, SSG/ISR cache poisoning, nested `use cache`
     root-param leak, Draft Mode `use cache` leak, `next dev` MCP endpoint disclosure — SR-SEP26.
   - Background (pre-16, why SEC-5 exists): CVE-2025-29927 Middleware bypass, fixed in 15.2.3 /
     14.2.25 — POSTMORTEM.

## 10. Not confirmed by the docs (content)

Each item states what was checked and lists the URLs. Nothing here becomes a rule.

1. Whether a 16.x minor published the "further `edge` runtime instructions" the upgrade guide
   promises — not found in UPG16, PROXY, BLOG161, BLOG162, BLOG163.
2. Which release removes `middleware.ts` — BLOG16 says only "a future version"; UPG16 names none.
3. Which codemod dist-tag is canonical — CODEMODS uses `@latest`, PROXY uses `@canary`.
4. Whether `serverActions` options are read outside `experimental` — SA-CONFIG and SA-GUIDE
   headings say `serverActions.allowedOrigins`, but every example nests it under `experimental`;
   the file uses `experimental.serverActions`.
5. When Server Actions started letting a request with no `Origin` header through with a warning —
   SA-CONFIG states the current behaviour; no version history entry.
6. Nonce CSP with Cache Components — CSP says PPR is incompatible with nonces; neither CSP nor
   AUTH-CC addresses nonces under Cache Components.
7. Vercel team policy for secrets — V-SENS (updated 2026-08-28) still describes an "Environment
   variables policy" that makes new variables Sensitive, while V-TYPES (2026-08-24) deprecates the
   "Enforce Sensitive Environment Variables" policy and adds "Separate Production Secret Values";
   the file states only the Secret/Config types.
8. Vercel WAF rate-limit rule specifics — only V-FW's overview was read; the file says only that
   the WAF exists on all plans.

## 11. Review checklist content (≥ 8; each names its rule)

```text
- [ ] SEC-1/SEC-2: the file is proxy.ts exporting proxy; no runtime option; no new middleware.ts.
- [ ] SEC-3: matcher is literal and excludes _next/static, _next/image and static files.
- [ ] SEC-4: proxy reads only the cookie; no database or slow fetch in proxy.ts.
- [ ] SEC-5/SEC-21: every Server Action authenticates, authorises and checks ownership itself.
- [ ] SEC-5/SEC-30: every Route Handler returns 401/403 from its own session check.
- [ ] SEC-6: no session data or secret in a response header set by proxy.
- [ ] SEC-7: session cookie set server-side with httpOnly, secure, sameSite, expiry, path.
- [ ] SEC-8: session payload holds ids/roles only; secret comes from an env var.
- [ ] SEC-10: no cookie or data mutation during render.
- [ ] SEC-12/SEC-15: DAL modules start with import 'server-only' and use cache( for the session check.
- [ ] SEC-13/SEC-16/SEC-23: DTOs and action returns carry only rendered fields.
- [ ] SEC-14: no DB client or secret process.env read outside the DAL.
- [ ] SEC-17: no layout-only auth check; no return null as access control.
- [ ] SEC-18/SEC-22: params, searchParams and action arguments are validated at runtime.
- [ ] SEC-24/SEC-25: no tokens as action parameters; no secrets in inline action closures.
- [ ] SEC-27/SEC-28: allowedOrigins and bodySizeLimit absent or justified.
- [ ] SEC-31/SEC-32/SEC-33: nonce CSP on request and response; pages dynamic; unsafe-eval dev-only.
- [ ] SEC-36: next.config headers() sends HSTS, nosniff, Referrer-Policy, Permissions-Policy.
- [ ] SEC-37/SEC-39: no secret behind NEXT_PUBLIC_; no .env*.local committed.
- [ ] SEC-40/SEC-41: secrets are Secret-type on Vercel; rotation redeploys before invalidating.
- [ ] SEC-42/SEC-43: next is on the latest patched release; vulnerable-deploy block not disabled.
```

(Write these as plain `- [ ]` lines in the topic file, not inside a fence. In the file, wrap
code-ish names such as `proxy.ts` in backticks.)

## Assumptions

1. The skeleton's helpers and generic tests are merged before this story is coded (story Deps);
   their exact signatures are taken from the merged code, and only call shapes in §3 adapt.
2. As-of version is expected to be 16.3.8 (verified three ways on 2026-10-04); the coder copies
   `R/nextjs.md`'s line verbatim regardless.
3. Links in prose carry no `#fragment` so prose URLs equal Sources bullets exactly; this is safer
   against any exact-match implementation of the generic prose-URL check.
4. The Don't/Do marker format (`**Don't**` / `**Do**` after an H3 per item) is a guess at the
   contract; the coder conforms to the contract if it differs and changes only the two marker
   constants in the test.
5. Example DB client is `prisma` from `@/lib/prisma` (Jonathan's tree lists `lib/prisma.ts`);
   query shapes (`findFirst`, `findUnique`, `select`) match those shown on DATASEC/SA-GUIDE/
   USE-SERVER.
6. zod is used with `import * as z from 'zod'` as the authentication guide does; `safeParse` per
   zod.dev/basics; `.parse` throws, which is acceptable inside a Server Action that throws on
   failure (DATASEC examples throw `Error('Unauthorized')`).
7. `nextjs.org/docs/app/api-reference/config/next-config-js/authInterrupts` (canary-only
   `forbidden()`/`unauthorized()`) is left out to stay under the line cap.
8. The vercel.com postmortem replaces `nextjs.org/blog/cve-2025-29927`, which redirects to it.
