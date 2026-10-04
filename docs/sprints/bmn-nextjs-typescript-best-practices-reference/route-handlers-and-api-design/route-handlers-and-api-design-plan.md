# Plan: Route Handlers and API design

**Story:** `route-handlers-and-api-design` ([story.md](story.md)) · **Run:** `bmn-nextjs-typescript-best-practices-reference`
**Owns:** `R/nextjs/route-handlers-and-apis.md` (prefix `API`) and
`Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_route_handlers_and_apis.py`.
`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`.
**Depends on:** `nextjs-standard-entry-point-and-skill-wiring`, which must be merged first. It supplies the stub,
`nextjs_doc_helpers.py`, `test_nextjs_reference.py` and the Authoring contract in `R/nextjs.md`.
**Researched live:** 2026-10-04. Latest stable is **Next.js 16.3.8**: the nextjs.org blog lists the
2026-09-30 security release as 16.3.8 (Active LTS), and every docs page fetched reports
`version: 16.3.8`. The latest major is **16**.

## 1. Approach

1. **Skills.** No skill is routed (stack.md: this is a Markdown skill repo, and `nextjs-fullstack-standards` is not on disk). Grounding comes only from live nextjs.org and vercel.com pages, with MDN, zod.dev and typescriptlang.org used only for facts they own. Every rule below was checked against the page it cites (§7).
2. **Replace the stub.** Overwrite the whole stub. Copy its **H1 and as-of line verbatim** so they match what the skeleton wrote, then write the contract sections in order: `Scope`, `Rules`, `Patterns`, `Anti-patterns`, `Version notes`, `Review checklist`, `Not confirmed by the docs`, `Sources`.
3. **39 rules, `API-1` to `API-39`.** Each rule is one imperative line with a citation. Rules the docs don't state carry `(convention)`. That is 2× the AC floor, which buys expert depth while staying under 800 lines.
4. **8 typed Patterns.** They cover the error envelope, a validated POST, a paginated GET, a `RouteContext` dynamic segment, a webhook, CORS, a rate-limited POST with `after()`, and a Cache Components GET. Every error-returning example builds the one `ApiErrorBody` with `satisfies`.
5. **8 Don't/Do anti-patterns, a 17-item review checklist and Version notes for Next.js 16.** Anything I could not confirm goes under "Not confirmed by the docs".
6. **One topic test file with 22 tests,** all checking text with the skeleton's helpers. They are offline and stdlib-only, apart from those helpers.
7. **Why this approach.** input.md says "Don't assume or lie. ground all your findings in NextJS and Vercel documentation". The contract makes that checkable: a per-rule citation, `(convention)` tags and `Not confirmed`.

## 2. Files to create or change

| # | Path | Purpose |
| --- | --- | --- |
| 1 | `R/nextjs/route-handlers-and-apis.md` | Replace the stub with the full topic file (§7–§12). Must stay ≤ 800 lines; target ≤ 760. |
| 2 | `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_route_handlers_and_apis.py` | New topic test (§3). |
| 3 | `docs/sprints/bmn-nextjs-typescript-best-practices-reference/route-handlers-and-api-design/evidence/sources-verified.md` | **Already written by the planner** from the live fetches: URL, date and rule ids. The coder keeps it equal to `## Sources`. |
| 4 | `docs/sprints/bmn-nextjs-typescript-best-practices-reference/route-handlers-and-api-design/validation.md` | Written at validation: AC results plus the one-off Sources-equality check (§6). |

No shared file is touched: not `nextjs.md`, the wiring files, `test_nextjs_reference.py` or `nextjs_doc_helpers.py` (story Assumptions).

## 3. Test plan (written first)

All tests are **unit** tests (pytest, text assertions) in
`Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_route_handlers_and_apis.py`. There is no
UI, so there are no Playwright tests.

The module header:

- docstring: *"Topic test for references/nextjs/route-handlers-and-apis.md."*
- `from nextjs_doc_helpers import TOPICS_DIR, read, is_stub, section, code_blocks, has_block_with, rule_items, as_of_version, missing_terms`
- `TOPIC = TOPICS_DIR / "route-handlers-and-apis.md"`
- `TEXT = read(TOPIC)`, read at module level.

Before writing the module, the coder reads `nextjs_doc_helpers.py` and adapts each call to the real signatures without weakening any assertion. One known open point is whether `section()` takes `"Patterns"` or `"## Patterns"`. Any adaptation is logged in validation.md.

| AC | Test name | What it asserts |
| --- | --- | --- |
| 1 | *(generic, skeleton)* `test_nextjs_reference.py` | Covers the as-of line, section order, rule format and citations, floors, Sources, ≤ 800 lines, tagged fences and resolving links. They run on the file with no skip. The coder confirms with `-rs` that no skip is reported for this file. |
| 1 | `test_topic_uses_only_api_rule_ids` | Every id from `rule_items(TEXT)` matches `^API-\d+$`. No other topic's id appears anywhere in the file, because it cites only its own ids. The check is `r"\b(?:TS\|RT\|RC\|DF\|SSE\|SEC\|PERF\|TEST)-\d+\b"`, built from the `TOPICS` prefixes in the helpers minus `API`. A generic `[A-Z]{2,4}-\d+` would false-match `UTF-8`. |
| 2 | `test_topic_is_not_a_stub` | `is_stub(TEXT)` is `False`. |
| 2 | `test_topic_has_at_least_18_api_rules` | `len(rule_items(TEXT)) >= 18`. |
| 3 | `test_topic_covers_required_terms` | `missing_terms(TEXT, TERMS) == []` with the 24 TERMS from the story, verbatim. |
| 4 | `test_validated_post_example_returns_error_shape` | `has_block_with(TEXT, "export async function POST", "safeParse", ".json(", "status:")`. |
| 4 | `test_dynamic_segment_example_uses_typed_route_context` | `has_block_with(TEXT, "RouteContext<'/", "await")`. |
| 4 | `test_webhook_example_verifies_signature_on_raw_body` | `has_block_with(TEXT, "request.text()", "signature", "timingSafeEqual")`. |
| 4 | `test_cors_example_answers_preflight` | `has_block_with(TEXT, "OPTIONS", "Access-Control-Allow-Origin")`. |
| 4 | `test_examples_contain_no_any` | No `ts`/`tsx` block matches `r":\s*any\b\|\bas\s+any\b\|<any>\|\bany\[\]"`. |
| 5 | `test_error_shape_declared_once_under_patterns_as_convention` | (1) Exactly one `ts` block in `section(TEXT, "Patterns")` matches `r"\b(type\|interface)\s+ApiErrorBody\b"`. (2) That declaration appears once in the whole file. (3) The Patterns prose contains `(convention)`. |
| 5 | `test_post_example_references_error_shape` | The block found for AC4's POST contains `ApiErrorBody`. |
| 5 | `test_pattern_handlers_returning_errors_use_error_shape` | Applies to every Patterns `ts` block that exports a handler (`export (async )?function (GET\|POST\|PUT\|PATCH\|DELETE\|HEAD\|OPTIONS)`) and matches `r"status:\s*[45]\d\d"`. Each such block contains `ApiErrorBody`. |
| 6 | `test_mutating_handler_examples_check_session_or_auth` | Applies to every `ts`/`tsx` block in the file that matches `r"export\s+(?:async\s+)?function\s+(?:POST\|PUT\|PATCH\|DELETE)\b\|export\s+const\s+(?:POST\|PUT\|PATCH\|DELETE)\b"`. Each such block also matches `r"(?i)(session\|auth)\w*\("`, unless it contains `request.text()` (the webhook exemption). At least one block is checked. |
| 7 | `test_rules_frame_route_handler_versus_server_action` | At least one rule item contains `Route Handler`, `Server Action`, `webhook` and `third-party`. It also links `https://nextjs.org/docs/app/guides/backend-for-frontend`. |
| 7 | `test_rules_forbid_server_component_fetching_own_route_handler` | At least one rule item contains `Server Component`, `Route Handler` and (case-insensitive) `fetch`. It also links the backend-for-frontend URL. |
| 8 | `test_version_notes_name_major_and_link_nextjs` | `major = as_of_version(TEXT).split(".")[0]`. `section(TEXT, "Version notes")` is non-empty, contains `f"Next.js {major}"` and contains `https://nextjs.org/`. |
| 9 | `test_review_checklist_items_name_existing_api_rules` | Every `- [ ]` line in `section(TEXT, "Review checklist")` contains `API-\d+`. Every id it names is a rule id. There are at least 8 items. |
| 9 | `test_anti_patterns_pair_dont_with_do` | `section(TEXT, "Anti-patterns")` is split on `**Don't**` into ≥ 3 items. In each item a fence opener (`^\s*` + three backticks + `ts\|tsx`) appears before `**Do**`, and another appears after it. |
| scope | `test_links_sibling_topics_instead_of_duplicating` | TEXT contains the link targets `](sse-and-streaming.md)`, `](proxy-auth-and-security.md)` and `](performance-and-vercel.md)`. |
| contract | `test_not_confirmed_section_states_no_rules` | `section(TEXT, "Not confirmed by the docs")` is non-empty and contains no `**API-` rule item. It contains at least one `https://`. |
| depth | `test_runtime_rule_flags_edge_as_deprecated` | At least one rule item contains, case-insensitive, `runtime`, `edge` and `deprecated`. |
| depth | `test_pattern_examples_never_call_update_tag` | No Patterns `ts` block contains `updateTag(`. |
| 10 | *(one-off, not pytest)* | Run the command in §6 and record the result in validation.md. |
| 11 | *(gates)* | Run the commands in §6. The diff scope check covers AC11. |

That gives **22 new pytest tests**. Implementation notes:

- Every `\|` inside a regex in the table above is Markdown table escaping. In Python, the alternation is a bare `|`.

- Every function stays under 50 lines and the module passes ruff.
- Regexes are compiled once as `UPPER_SNAKE_CASE` module constants.
- No test reads the run folder, and none touches the network.

## 4. Data

None. No models, no migrations, no `supabase/` and no RLS (stack.md: `supabase: false`).

## 5. Config, env vars and deploy_pending

None. Env names inside snippets (`VERCEL_WEBHOOK_SECRET`, `APP_ORIGIN`) are illustrative
example code, not config for this repo. **deploy_pending: []**. Nothing here deploys, and
`vercel: false`.

## 6. Risks and gates

**Risks**

- **Helper API drift.** The skeleton's helpers are being planned in parallel. The coder reads `nextjs_doc_helpers.py` and `test_nextjs_reference.py` first and matches their real signatures and parsing. That covers the rule-line regex, how `section()` takes a heading, how anti-pattern items and fences are detected, and how URLs are normalised. Deviations go in validation.md under Assumptions.
- **Rule parsing.** Write **every rule as one physical line**, with no hard wrap. That way the id, the imperative and the citation are all on the line that `rule_items` sees.
- **Fences.** Put every fence at column 0, including the ones in Anti-patterns. Then any `code_blocks` implementation finds them.
- **URL equality.** Use **anchor-free URLs everywhere** in prose (no `#fragment`). Every prose URL must then appear exactly in `## Sources`.
- **Banned words.** Write no `TODO` or `TBD` anywhere, including inside code comments.
- **Snippet correctness.** Snippets are not compiled. They use only APIs shown on the cited pages (§7 "Verified snippet" column). One risk remains: `z.flattenError(...).fieldErrors` assigns into `Partial<Record<string, string[]>>`. The envelope type uses `Partial<…>` for exactly that reason.
- **Length.** The file is about 700–760 lines. If it runs over, first collapse Patterns prose, then shorten anti-pattern Do blocks. Never cut rules below 30.

**Gates** (run in the story worktree)

```bash
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_route_handlers_and_apis.py -q
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests/test_nextjs_reference.py -q -rs
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q
uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope
git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD
wc -l Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/route-handlers-and-apis.md
```

**AC10 one-off check.** Record the command and its output in validation.md:

```bash
python3 - <<'EOF'
import re, pathlib
topic = pathlib.Path("Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/route-handlers-and-apis.md").read_text()
ev = pathlib.Path("docs/sprints/bmn-nextjs-typescript-best-practices-reference/route-handlers-and-api-design/evidence/sources-verified.md").read_text()
src = set(re.findall(r"^- .*?(https://\S+?)\)?$", topic.split("## Sources", 1)[1], re.M))
evs = set(re.findall(r"^\| (https://\S+) \|", ev, re.M))
print("equal:", src == evs, "| only in Sources:", src - evs, "| only in evidence:", evs - src)
EOF
```

## 7. Verified rule sheet

The coder copies each rule's text into `## Rules` as
`N. **API-N** <text>`, one physical line per rule. Links use the given URLs **without anchors**,
with the link text in brackets. "Page says" is the planner's paraphrase of the cited page,
fetched 2026-10-04. **[16]** marks an API that changed in Next.js 16. **[15]** marks a change
from 15 that agents still get wrong.

Short names used in the table (all URLs are listed in §12):

- **RH-GS** = nextjs.org/docs/app/getting-started/route-handlers
- **ROUTE** = …/file-conventions/route
- **SEG** = …/file-conventions/route-segment-config
- **BFF** = …/guides/backend-for-frontend
- **AUTH** = …/guides/authentication
- **SEC** = …/guides/data-security
- **SA** = …/guides/server-actions
- **MUT** = …/getting-started/mutating-data
- **UP16** = …/guides/upgrading/version-16

| Id | Rule text (imperative, goes into the file) | Source(s) | Page says (paraphrase) | Verified snippet / flag |
| --- | --- | --- | --- | --- |
| API-1 | Put every endpoint in a `route.ts` file inside `app/`, never in the same route segment as a `page.tsx`. A `route.ts` and a `page.tsx` at the same segment conflict, and a `route` takes over every HTTP verb for its URL. | RH-GS | Route Handlers live only in `app/` in `route.js\|ts`. There can't be a `route.js` at the same segment level as `page.js`. Each `route.js` or `page.js` takes over all HTTP verbs for that route. | Table: `app/page.js` + `app/route.js` is a conflict. |
| API-2 | Export one named function per HTTP method you serve (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS`). Next.js answers any other method with `405 Method Not Allowed`. When you don't export `OPTIONS`, it implements it with an `Allow` header for you. | ROUTE, RH-GS | The supported methods are those seven. Unsupported methods get 405. If `OPTIONS` is not defined, Next.js implements it and sets `Allow`. | `export async function OPTIONS(request: Request) {}` |
| API-3 | Type the first argument as `NextRequest` when you need `request.nextUrl` or `request.cookies`, and as the Web `Request` otherwise. Return Web responses (`Response.json(body, { status, headers })`, `new Response(...)`), and use `NextResponse` when you need its helpers (`redirect()`, `rewrite()`, response `cookies`). A `NextRequest` is accepted wherever a `Request` is, and a `NextResponse` can be returned wherever a `Response` is. | BFF, next-request, next-response, MDN `Response.json` | NextRequest adds `cookies` and `nextUrl`. NextResponse adds `json`, `redirect`, `rewrite`, `next` and `cookies`. A NextRequest can be passed to any function expecting `Request`, and a NextResponse returned where a `Response` is expected. `Response.json(data, { status, statusText, headers })` sets `Content-Type: application/json`. | `NextResponse.json({ error: 'Internal Server Error' }, { status: 500 })` |
| API-4 | Type the context argument with the global `RouteContext<'/route/[param]'>` helper and `await ctx.params` before reading a segment. `params` is a Promise, and Next.js 16 removed synchronous access. The helper is generated by `next dev`, `next build` or `next typegen` and needs no import. | ROUTE, UP16 | **[16]** Sync access to `params` in `route.js` is fully removed. `context.params` became a promise in **[15]** v15.0.0-RC. `RouteContext` becomes global after type generation (typegen since 15.5). | `export async function GET(_req: NextRequest, ctx: RouteContext<'/users/[id]'>) { const { id } = await ctx.params; return Response.json({ id }) }` |
| API-5 | Build public, third-party, mobile, webhook and callback endpoints as Route Handlers, along with non-UI responses (JSON, XML, files, `rss.xml`). Build the app's own UI mutations as Server Actions. Route Handlers are public HTTP endpoints any client can call, while a Server Action's primary purpose is mutating data from your own frontend. Server Actions are dispatched one at a time, so client-side parallel non-mutation requests belong in a Route Handler. | BFF, SA, MUT | BFF: Route Handlers are public HTTP endpoints, receive webhooks and callback URLs, and return any content type. A Server Action's primary purpose is to mutate data from your frontend client, and actions are queued. SA: actions are dispatched sequentially, so use a Route Handler for non-mutation requests. MUT: actions are designed for server-side mutations. | (AC7) |
| API-6 | Read data in Server Components straight from its source (the DAL or service function), never by `fetch`ing your own Route Handler. A Server Component prerendered at build fails, because no server is listening. One rendered on demand pays an extra HTTP round trip. | BFF | Caveats, Server Components: fetch data directly from its source, not via Route Handlers. At build time the build fails because no server is listening. On demand it is slower because of the extra round trip. | (AC7) |
| API-7 | Name resources as plural nouns and let methods carry the verb. `app/api/projects/route.ts` serves `GET` (list) and `POST` (create); `app/api/projects/[id]/route.ts` serves `GET`, `PATCH` and `DELETE` for one item. Put no verbs such as `/api/createProject` in paths. (convention; dynamic segments per [route.js]) | ROUTE | Dynamic segments: `app/items/[slug]/route.js` gets `params` as `Promise<{ slug }>`. The naming itself is a house rule. | — |
| API-8 | Validate every input at the boundary before using it: the body, `params`, `searchParams` and any header you act on. Use a schema's `safeParse`, and pass only the parsed `data` onward. Bracketed folders are user input too. | BFF, SEC, zod basics | BFF: validate data before passing it to other systems, and never trust incoming request data. SEC: always validate client input (form data, URL params, headers, searchParams). The audit list says `/[param]/` folders are user input. Zod: `.safeParse()` returns a discriminated union `{ success, data \| error }`. | `const result = Player.safeParse(input); if (!result.success) { result.error } else { result.data }` |
| API-9 | Check `Content-Type` before reading a body, answering `415` when it isn't what the endpoint accepts. Wrap `await request.json()` in `try`/`catch` and answer a parse failure with `400` `invalid_json`. `request.json()` rejects with `SyntaxError` on malformed JSON, which is the client's error, not a `500`. | BFF, MDN Request.json, MDN Status | BFF: validate content type and size. MDN: `json()` rejects with `SyntaxError` when the body can't be parsed as JSON. 400 means a client error, and 415 means the media format is unsupported. | — |
| API-10 | Return every error as the one `ApiErrorBody` envelope from Patterns, `{ error: { code, message, fieldErrors? } }`, via `Response.json(body, { status })`. Return every success as `{ data }`, with lists adding `nextCursor`. Clients then branch on `error.code`, never on message text. (convention; [MDN Response.json()]) | MDN Response.json | No nextjs.org or vercel.com page prescribes an envelope, so this is a house rule. MDN confirms the `Response.json` signature. | — |
| API-11 | Pick the status by meaning: `200` read or update; `201` plus a `Location` header after a create; `202` when work is queued; `204` with no body; `400` invalid input; `401` no valid credentials; `403` known caller without rights; `404` unknown resource; `409` state conflict; `415` unsupported media type; `429` rate limited; `500` unexpected failure. | MDN Status, MDN 201 | MDN gives these definitions. 401 means "unauthenticated", while 403 means the identity is known but lacks rights. 201 resources must be locatable by the request URL or the `Location` header. | — |
| API-12 | Keep internal detail out of error responses: no `error.message`, stack, SQL or upstream body. Log it server-side and return `500` with code `internal`. Strip sensitive or unneeded fields from responses and logs. | BFF | "Avoid exposing sensitive information in error messages sent to the client." Under protected resources: remove sensitive or unnecessary data from responses and backend logs. (The page's own snippets echo `reason.message`; the rule follows its prose.) | — |
| API-13 | Authenticate and authorize inside every Route Handler that is not public by design. Return `401` when there is no valid session and `403` when the caller lacks the role or permission. Mark intentionally public handlers with a `// public by design` comment (convention). | AUTH, BFF | AUTH: treat Route Handlers with the same security considerations as public-facing API endpoints, with a 401-then-403 two-tier example. BFF: "To restrict access, implement authentication and authorization." | `if (!session) return new Response(null, { status: 401 }); if (session.user.role !== 'admin') return new Response(null, { status: 403 })` |
| API-14 | Call a session reader that returns `null` when unauthenticated (for example `getSession()`, see [proxy-auth-and-security.md](proxy-auth-and-security.md)) and answer with `401` JSON. Don't reuse a page-oriented helper that calls `redirect('/login')`: `redirect()` answers with a `307` redirect, not an API error. | AUTH, redirect | AUTH: the DAL `verifySession()` example calls `redirect('/login')`, while the Route Handler example checks `if (!session)` and returns 401. redirect FAQ: `redirect()` uses 307 by default. | — |
| API-15 | Authorize the specific resource, not just the user. Scope every read and write by the session's user (`where: { id, ownerId }`), and answer `404` when the caller may not know the resource exists. Authentication alone leaves Insecure Direct Object Reference holes. | SEC, MDN Status | SEC: check authorization (ownership of the specific resource) to prevent IDOR. MDN 404: servers may send 404 instead of 403 to hide a resource's existence. | — |
| API-16 | Never rely on `proxy.ts` alone to protect an API. Proxy checks are optimistic, the documented auth matcher excludes `/api`, and the docs require verifying credentials before granting access. Re-check the session inside every protected handler. | BFF, AUTH, proxy | BFF: "Do not rely on proxy alone for authentication and authorization." AUTH: proxy does optimistic, cookie-only checks and "should not be your only line of defense". Its sample matcher is `'/((?!api\|_next/static\|_next/image\|.*\\.png$).*)'`. | — |
| API-17 | Reject cookie-authenticated `POST`/`PUT`/`PATCH`/`DELETE` requests with `403` when their `Origin` header is not your app's origin. Next.js documents its built-in Origin-versus-Host CSRF check for Server Actions only, and nothing in the Route Handler docs describes one (convention). | SEC, SA | SEC and SA: Server Actions compare `Origin` with `Host`/`X-Forwarded-Host` and reject mismatches. The route.js and BFF pages describe no such check for Route Handlers. The rule is a house rule built on that documented mechanism. | — |
| API-18 | Return `401` or `403` responses yourself instead of calling `unauthorized()` or `forbidden()` in a Route Handler. Both need the experimental `authInterrupts` flag, which the docs say is not recommended for production. | forbidden | The banner says the feature is experimental and "not recommended for production", and it needs `experimental.authInterrupts`. It can be invoked in Route Handlers. | — |
| API-19 | Rate-limit expensive and abuse-prone endpoints (sign-in, sign-up, email, exports, AI calls) and answer `429` with the envelope. On Vercel, either add a WAF rate-limit rule or call `checkRateLimit('<rule id>', { request, rateLimitKey })` from `@vercel/firewall`. WAF rules are on all plans and use a fixed window keyed by IP or JA4 by default. `checkRateLimit` works against a rule configured in the dashboard. Counters are tracked per region. | BFF, Vercel WAF rate limiting, Vercel rate-limiting SDK | BFF: implement rate limiting and enable your host's features, returning 429 on limit. WAF: available on all plans, with fixed-window and IP/JA4 keys on Hobby and Pro, a default 429 action, and per-region counters. SDK: `checkRateLimit('update-object', { request, rateLimitKey })` returns `{ rateLimited }` and requires a dashboard rule with that Rate limit ID. | `const { rateLimited } = await checkRateLimit('update-object', { request });` |
| API-20 | Paginate every list endpoint with a bounded `limit` (default 20, max 100) and an opaque `cursor`. Parse both from `request.nextUrl.searchParams` with `z.coerce`, and return `{ data, nextCursor }`. Never return an unbounded result set. (convention; [NextRequest], [Zod API]) | next-request, zod api | `request.nextUrl.searchParams` exposes the query. Zod has `z.coerce.number()` → `Number(input)`, `z.int()`, `.min()`/`.max()`, `.default()` and `.pipe()`. The pagination shape is a house rule. | — |
| API-21 | Keep `PUT` and `DELETE` idempotent. Make retried creates safe by accepting an `Idempotency-Key` header on `POST` and replaying the stored response for a repeated key. `POST` and `PATCH` are not idempotent, so a client retry otherwise creates duplicates. (convention for the header; [MDN idempotent]) | MDN Idempotent | MDN: GET, HEAD, PUT, DELETE and OPTIONS are idempotent; POST and PATCH are not. Clients can safely retry idempotent requests. The header is a house rule (§11). | — |
| API-22 | Send sensitive values (location, personal data, tokens) in a `POST` body rather than a `GET` query string. `GET` requests may be cached or logged. | BFF | "This example uses POST to avoid putting geo-location data in the URL. GET requests may be cached or logged." | — |
| API-23 | Treat Route Handlers as uncached unless you opt in. Only `GET` can be cached. Without Cache Components, opt in with `export const dynamic = 'force-static'` (or `revalidate`). That makes `cookies()` and `headers()` return empty values, so never read per-user data in such a handler. Other methods are never cached, even beside a cached `GET`. | RH-GS, caching-without-cache-components | **[15]** Not cached by default since v15.0.0-RC. You can opt `GET` in, and other methods are not cached even alongside a cached GET. `force-static` forces `cookies`, `headers()` and `useSearchParams()` to return empty values. | `export const dynamic = 'force-static'` |
| API-24 | With `cacheComponents: true`, expect a `GET` handler that touches no runtime or uncached data to be prerendered at build. Reading `request` properties, `cookies()`, `headers()`, `connection()`, a database or the network makes it run per request. To cache uncached data, put `'use cache'` (with `cacheLife` and `cacheTag`) in a helper function, because it is not allowed in the handler body. | RH-GS | **[16]** "With Cache Components": GET Route Handlers follow the UI-route model. Prerendering stops on network, DB, async FS, request properties, `cookies()`/`headers()`/`connection()` and non-deterministic operations. "`use cache` cannot be used directly inside a Route Handler body; extract it to a helper function." | `async function getProducts() { 'use cache'; cacheLife('hours'); return await db.query(...) }` |
| API-25 | Don't export `dynamic`, `revalidate` or `fetchCache` from `route.ts` when Cache Components is enabled. Next.js 16 removed them under `cacheComponents`; the version history also lists `dynamicParams`. | SEG | **[16]** v16.0.0: "`dynamic`, `dynamicParams`, `revalidate`, and `fetchCache` removed when Cache Components is enabled." | — |
| API-26 | Put CDN cache headers only on responses identical for every caller. On a `GET`, set `Cache-Control: public, s-maxage=N, stale-while-revalidate=M` (or `CDN-Cache-Control` / `Vercel-CDN-Cache-Control`), with `Vary` naming any request header the body depends on (for example `Accept` for content negotiation). Vercel never caches responses with `set-cookie` or `private`/`no-store`, nor requests carrying `Authorization`. Per-user data does not belong in the CDN cache. | Vercel CDN cache, BFF | Vercel: Functions are cached on `s-maxage` (± `stale-while-revalidate`). Cacheability criteria exclude `Authorization`, `set-cookie`, `private`/`no-cache`/`no-store` and `Vary: Cookie`. CDN cache "isn't the right fit when responses include sensitive user data". BFF: `Vary: Accept` for content negotiation. | `headers: { 'Cache-Control': 'public, s-maxage=1', 'CDN-Cache-Control': 'public, s-maxage=60', 'Vercel-CDN-Cache-Control': 'public, s-maxage=3600' }` |
| API-27 | Invalidate cache from a Route Handler with `revalidatePath`, or with `revalidateTag(tag, 'max')` for stale-while-revalidate. Use `revalidateTag(tag, { expire: 0 })` when a webhook needs the data gone now. Never call `updateTag`, which is Server Actions-only and throws in a Route Handler. Never use the deprecated one-argument `revalidateTag(tag)`. | revalidateTag, updateTag | **[16]** `revalidateTag(tag, profile)` can be called in Route Handlers, and `{ expire: 0 }` serves no stale data, for webhooks. The single-argument form is deprecated. `updateTag` can only be called from Server Actions; the page shows it throwing in a `POST` route. | `revalidateTag(tag, 'max')`, `revalidateTag(tag, { expire: 0 })` |
| API-28 | Read cookies and headers with `await cookies()` and `await headers()` from `next/headers`, or with `request.cookies` / `request.headers`. `headers()` is read-only, so set response headers on the `Response` you return. Set cookies with `(await cookies()).set()` or `response.cookies.set()`, using `httpOnly`, `secure`, `sameSite`, `path` and an expiry. Do it before any streaming starts, because HTTP can't set cookies after that. | ROUTE, cookies, AUTH | **[16]** Async only. ROUTE: the `headers` instance is read-only, so return a new `Response` to set headers. cookies: `.set`/`.delete` work in Route Handlers and Server Functions, and HTTP does not allow setting cookies after streaming starts. AUTH recommends HttpOnly, Secure, SameSite, Max-Age/Expires and Path. | `const cookieStore = await cookies(); cookieStore.set('b', '1')` |
| API-29 | Never copy incoming request headers onto the response or forward them wholesale upstream. Allow-list the few you need, because sensitive values on response headers are visible to clients. | BFF, next-response | BFF Security: "avoid directly passing incoming request headers to the outgoing response". NextResponse: avoid copying all incoming request headers, and prefer an allow-list. | — |
| API-30 | Call `redirect()` outside any `try`/`catch`: it throws, and answers `307` (`permanentRedirect()` answers `308`). Alternatively return `NextResponse.redirect(new URL(path, request.url))`. Refuse with `400` any user-supplied redirect target whose origin differs from `request.nextUrl.origin`, to prevent open redirects. | redirect, next-response, BFF | redirect: "In Server Actions and Route Handlers, redirect should be called outside the try block". The default is 307 and `permanentRedirect` gives 308. BFF callback example: `if (destination.origin !== request.nextUrl.origin) return new Response('Invalid redirect', { status: 400 })`. | `NextResponse.redirect(new URL('/new', request.url))` |
| API-31 | Add CORS only for endpoints that browsers call cross-origin. Allow-list origins and echo the matching `Origin` in `Access-Control-Allow-Origin` with `Vary: Origin`, never `*` on credentialed requests. Export `OPTIONS` to answer the preflight with `Access-Control-Allow-Methods`, `-Headers` and `-Max-Age`; the auto-generated `OPTIONS` is documented only as setting `Allow`. Repeat the origin header on the actual response. Put CORS that many routes share in `next.config` `headers()` or `proxy.ts`. | ROUTE, next-config headers, proxy, MDN CORS, MDN OPTIONS | ROUTE: CORS headers via the Web API. For multiple handlers, use Proxy or `next.config.js`. The proxy example uses an `allowedOrigins` array, handles `OPTIONS`, and sets ACAO only for allowed origins. MDN: credentialed responses must not use `*`, and an echoed single origin should add `Vary: Origin`. Both 200 and 204 are permitted for preflight, but some browsers mishandle 204. | proxy.ts CORS snippet (`isAllowedOrigin && { 'Access-Control-Allow-Origin': origin }`) |
| API-32 | Verify a webhook before trusting it. Read the raw body once with `await request.text()` and compute the provider's signature over that exact string. Compare with `crypto.timingSafeEqual` after a length check, and reject mismatches with `401`. Only then `JSON.parse` the same string and `safeParse` the event. Re-serialized JSON is not the signed payload, and a body can be read only once. | ROUTE, Vercel request headers, Vercel raw-body guide, BFF | ROUTE: the Webhooks example reads `await request.text()`, with no `bodyParser` needed. Vercel `x-vercel-signature`: HMAC-SHA1 of the raw body, with a Next.js `POST` example that uses `request.text()`, `createHmac`, a length check plus `timingSafeEqual`, then `JSON.parse(rawBody)`. KB: "Certain providers require access to the raw body … to validate the signature". BFF: the body can only be read once (clone to re-read). | `crypto.createHmac('sha1', secret).update(rawBody).digest('hex')` and `crypto.timingSafeEqual(Buffer.from(headerSignature), Buffer.from(bodySignature))` |
| API-33 | Acknowledge webhooks fast and idempotently. Return `2xx` well inside the sender's timeout: on Vercel the timeout is 30 s, and non-`2xx` deliveries are retried for up to 24 h with backoff. Dedupe on the event `id` and run follow-up work in `after()`. Hand work that must survive a crash to a durable job (convention). | Vercel webhooks API, Vercel webhooks, after | Webhooks API: "schedule a task for your action"; the request times out after 30 s without a 2xx; non-2xx gets retries for up to 24 h with exponential backoff. Webhooks: events arrive as POST with `"id": "<eventId>"`. after: runs after the response. | — |
| API-34 | Schedule post-response side effects (logging, analytics, notifications) with `after()` from `next/server` instead of un-awaited promises. The callback runs even when the handler throws or redirects, and it is bounded by the route's `maxDuration`. Inside a Route Handler it may call `cookies()`/`headers()`. On Vercel it replaces `waitUntil()` for Next.js 15.1+. | after, @vercel/functions | after: usable in Route Handlers; runs even if the response didn't complete successfully; runs for the platform's default or configured max duration; `cookies`/`headers` are allowed inside it in Route Handlers. Vercel: for Next.js 15.1+, "we recommend using the built-in `after()` … instead of `waitUntil()`". | `after(async () => { const userAgent = (await headers()).get('user-agent') \|\| 'unknown' })` |
| API-35 | Remove `export const runtime = 'edge'` and `export const preferredRegion` from route files. The Edge runtime is deprecated and Node.js is the default. Vercel recommends migrating to Node.js and states `runtime = 'edge'` is no longer supported from Next.js 16.3. `preferredRegion` is deprecated. | runtime, edge-runtime-deprecated, Vercel Functions API, Vercel Edge runtime, SEG | **[16]** runtime: `'edge'` is deprecated, so remove the export. The message page says Node.js is the default and no replacement is needed. Vercel: "Starting in Next.js 16.3, setting `runtime = 'edge'` is no longer supported", with "We recommend migrating from edge to Node.js". SEG: `preferredRegion` is deprecated. | `- export const runtime = 'edge'` |
| API-36 | Export `maxDuration` (seconds) only on handlers that legitimately run long, and pick the value with [performance-and-vercel.md](performance-and-vercel.md). On Vercel with Fluid compute the default is 300 s; Hobby's maximum is 300 s and Pro/Enterprise's is 800 s. A function that runs past it ends with `504 FUNCTION_INVOCATION_TIMEOUT`. | maxDuration, Vercel duration, Vercel limits | maxDuration is in seconds, read by the platform from the build output. Vercel table: default 300 s; max 300 (Hobby) or 800 (Pro/Ent), with 1800 extended beta. Overrun returns 504 `FUNCTION_INVOCATION_TIMEOUT`. | `export const maxDuration = 5` |
| API-37 | Keep request and response bodies under Vercel's 4.5 MB function payload limit; larger requests fail with `413 FUNCTION_PAYLOAD_TOO_LARGE`. Validate body size, and upload user files from the browser straight to a storage service, sending only the resulting URL to the handler. | Vercel limits, BFF | Vercel: the maximum payload for the request or response body is 4.5 MB, giving 413 `FUNCTION_PAYLOAD_TOO_LARGE`. BFF: validate size; store user assets in dedicated services and upload from the browser. | — |
| API-38 | Keep no per-request or per-user state in module scope, and don't write to the local filesystem. Handlers may be deployed as functions that cannot share data between requests or write files, and long-running handlers may be terminated on timeout. | BFF | Deployment environment: Route Handlers as lambdas can't share data between requests, may not write to the FS, and may be terminated on timeouts. | — |
| API-39 | Proxy to another backend with `rewrites` in `next.config` or `NextResponse.rewrite()` in `proxy.ts` when no logic is needed. When a Route Handler must sit in between, validate before forwarding and pass `request.signal` to the upstream `fetch`, so a client disconnect can cancel it. On Vercel, cancellation is opt-in per path. | BFF, Vercel Functions API | BFF: a Route Handler can proxy to a backend, but "Add validation logic before forwarding", or use proxy rewrites or next.config rewrites. Vercel: `request.signal` fires on client disconnect once `supportsCancellation` is enabled, and you pass it to `fetch`. | `fetch(url, { signal: request.signal })` |

## 8. Topic file content: Scope and Patterns

### `## Scope` (prose, about 8 lines)

- **What the file covers:** building Route Handlers (`route.ts`) as real HTTP APIs, and choosing between a Route Handler, a Server Action and a Server Component. Cite BFF: Next.js backend capabilities are "not a full backend replacement" but a publicly reachable API layer.
- **Where to look for the rest:**
  - streaming and SSE: [sse-and-streaming.md](sse-and-streaming.md);
  - sessions, the DAL, `proxy.ts` and CSP: [proxy-auth-and-security.md](proxy-auth-and-security.md);
  - choosing `maxDuration`, regions and runtime trade-offs: [performance-and-vercel.md](performance-and-vercel.md);
  - Server Action details: [data-fetching-and-mutations.md](data-fetching-and-mutations.md);
  - the Cache Components model: [rendering-and-caching.md](rendering-and-caching.md);
  - testing handlers: [testing-and-observability.md](testing-and-observability.md).
- **Back-link** to the entry point: [../nextjs.md](../nextjs.md).

### `## Patterns`

Open the section with one prose line:

> The envelope below is this standard's single error shape (convention). `satisfies` checks each
> literal against it without widening ([TypeScript 4.9](https://www.typescriptlang.org/docs/handbook/release-notes/typescript-4-9.html)).
> Handlers get the session from `getSession()` (`Promise<Session | null>`), defined in
> [proxy-auth-and-security.md](proxy-auth-and-security.md). Field errors come from
> `z.flattenError` ([Zod error formatting](https://zod.dev/error-formatting)).

Give each block a `####` heading. Write each block verbatim except for formatting; keep 2-space indents and no semicolons.

**P1. The error envelope (convention)**, declared once:

```ts
// lib/api/errors.ts — the one response envelope every handler uses (convention)
export type ApiErrorCode =
  | 'invalid_json' // 400
  | 'validation_failed' // 400
  | 'unauthenticated' // 401
  | 'invalid_signature' // 401
  | 'forbidden' // 403
  | 'not_found' // 404
  | 'conflict' // 409
  | 'unsupported_media_type' // 415
  | 'rate_limited' // 429
  | 'internal' // 500

export type ApiErrorBody = {
  error: {
    code: ApiErrorCode
    message: string // safe for clients: no stack, SQL or upstream detail
    fieldErrors?: Partial<Record<string, string[]>>
  }
}

export type ApiData<T> = { data: T }
export type ApiPage<T> = { data: T[]; nextCursor: string | null }
```

**P2. Validated `POST` (create)**. This is the AC4 example, and its rules are API-8 to API-11 and API-13.

```ts
// app/api/projects/route.ts — POST /api/projects
import { z } from 'zod'
import { getSession } from '@/lib/auth/session'
import { createProject } from '@/lib/projects'
import type { ApiErrorBody } from '@/lib/api/errors'

const CreateProjectBody = z.strictObject({
  name: z.string().trim().min(1).max(100),
  visibility: z.enum(['private', 'team']),
})

export async function POST(request: Request) {
  const session = await getSession()
  if (!session) {
    return Response.json(
      { error: { code: 'unauthenticated', message: 'Sign in to create a project.' } } satisfies ApiErrorBody,
      { status: 401 },
    )
  }
  if (!request.headers.get('content-type')?.startsWith('application/json')) {
    return Response.json(
      { error: { code: 'unsupported_media_type', message: 'Send application/json.' } } satisfies ApiErrorBody,
      { status: 415 },
    )
  }
  let body: unknown
  try {
    body = await request.json()
  } catch {
    return Response.json(
      { error: { code: 'invalid_json', message: 'The body is not valid JSON.' } } satisfies ApiErrorBody,
      { status: 400 },
    )
  }
  const parsed = CreateProjectBody.safeParse(body)
  if (!parsed.success) {
    return Response.json(
      {
        error: {
          code: 'validation_failed',
          message: 'The body failed validation.',
          fieldErrors: z.flattenError(parsed.error).fieldErrors,
        },
      } satisfies ApiErrorBody,
      { status: 400 },
    )
  }
  const project = await createProject({ ...parsed.data, ownerId: session.userId })
  return Response.json(
    { data: project },
    { status: 201, headers: { Location: `/api/projects/${project.id}` } },
  )
}
```

**P3. Paginated `GET` (list)**. Rules: API-8 and API-20.

```ts
// app/api/projects/route.ts — GET /api/projects?limit=20&cursor=…
import type { NextRequest } from 'next/server'
import { z } from 'zod'
import { getSession } from '@/lib/auth/session'
import { listProjects, type Project } from '@/lib/projects'
import type { ApiErrorBody, ApiPage } from '@/lib/api/errors'

const ListQuery = z.object({
  limit: z.coerce.number().pipe(z.int().min(1).max(100)).default(20),
  cursor: z.string().min(1).optional(),
})

export async function GET(request: NextRequest) {
  const session = await getSession()
  if (!session) {
    return Response.json(
      { error: { code: 'unauthenticated', message: 'Sign in to list projects.' } } satisfies ApiErrorBody,
      { status: 401 },
    )
  }
  const query = ListQuery.safeParse(Object.fromEntries(request.nextUrl.searchParams))
  if (!query.success) {
    return Response.json(
      {
        error: {
          code: 'validation_failed',
          message: 'The query string failed validation.',
          fieldErrors: z.flattenError(query.error).fieldErrors,
        },
      } satisfies ApiErrorBody,
      { status: 400 },
    )
  }
  const page: ApiPage<Project> = await listProjects({ ownerId: session.userId, ...query.data })
  return Response.json(page)
}
```

**P4. Dynamic segment with `RouteContext`**. This is the AC4 example, and its rules are API-4 and API-15.

```ts
// app/api/projects/[id]/route.ts — GET and DELETE /api/projects/:id
import type { NextRequest } from 'next/server'
import { z } from 'zod'
import { getSession } from '@/lib/auth/session'
import { deleteProjectForOwner, findProjectForOwner } from '@/lib/projects'
import type { ApiErrorBody } from '@/lib/api/errors'

const ProjectId = z.uuid()

const unauthenticated = () =>
  Response.json(
    { error: { code: 'unauthenticated', message: 'Sign in first.' } } satisfies ApiErrorBody,
    { status: 401 },
  )
// Another user's project is indistinguishable from a missing one (API-15).
const projectNotFound = () =>
  Response.json(
    { error: { code: 'not_found', message: 'Project not found.' } } satisfies ApiErrorBody,
    { status: 404 },
  )

export async function GET(_request: NextRequest, ctx: RouteContext<'/api/projects/[id]'>) {
  const session = await getSession()
  if (!session) return unauthenticated()
  const { id } = await ctx.params
  const projectId = ProjectId.safeParse(id)
  if (!projectId.success) return projectNotFound()
  const project = await findProjectForOwner(projectId.data, session.userId)
  return project ? Response.json({ data: project }) : projectNotFound()
}

export async function DELETE(_request: NextRequest, ctx: RouteContext<'/api/projects/[id]'>) {
  const session = await getSession()
  if (!session) return unauthenticated()
  const { id } = await ctx.params
  const projectId = ProjectId.safeParse(id)
  if (!projectId.success) return projectNotFound()
  const deleted = await deleteProjectForOwner(projectId.data, session.userId)
  return deleted ? new Response(null, { status: 204 }) : projectNotFound()
}
```

**P5. Webhook with signature verification on the raw body**. This is the AC4 example, and its rules are API-32 to API-34. The prose line before the block says three things:

- it uses Vercel's documented `x-vercel-signature` (HMAC-SHA1 of the raw body);
- for other providers, use their documented algorithm and header, keeping the same order of steps;
- it answers `401` like the Next.js webhook example ([Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend)), while Vercel's own sample answers `403`.

```ts
// app/api/webhooks/vercel/route.ts — no session: the signature is the credential
import crypto from 'crypto'
import { after } from 'next/server'
import { z } from 'zod'
import { handleVercelEvent, markEventReceived } from '@/lib/webhooks/vercel'
import type { ApiErrorBody } from '@/lib/api/errors'

const VercelEvent = z.object({
  id: z.string(),
  type: z.string(),
  createdAt: z.number(),
  payload: z.unknown(),
})

export async function POST(request: Request) {
  const secret = process.env.VERCEL_WEBHOOK_SECRET
  if (!secret) {
    return Response.json(
      { error: { code: 'internal', message: 'Webhook is not configured.' } } satisfies ApiErrorBody,
      { status: 500 },
    )
  }
  const signature = request.headers.get('x-vercel-signature')
  const rawBody = await request.text() // the exact signed bytes; a body can be read once
  const expected = crypto.createHmac('sha1', secret).update(rawBody).digest('hex')
  if (
    !signature ||
    signature.length !== expected.length ||
    !crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))
  ) {
    return Response.json(
      { error: { code: 'invalid_signature', message: 'Signature verification failed.' } } satisfies ApiErrorBody,
      { status: 401 },
    )
  }
  const event = VercelEvent.safeParse(JSON.parse(rawBody))
  if (!event.success) {
    return Response.json(
      { error: { code: 'validation_failed', message: 'Unexpected event shape.' } } satisfies ApiErrorBody,
      { status: 400 },
    )
  }
  // Retries redeliver the same id: act on the first delivery only (API-33).
  if (await markEventReceived(event.data.id)) {
    after(() => handleVercelEvent(event.data))
  }
  return new Response(null, { status: 200 })
}
```

**P6. CORS with preflight**. This is the AC4 example, and its rule is API-31. The prose line before it says the preflight answers `200` because some browsers mishandle `204` ([MDN OPTIONS](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Methods/OPTIONS)).

```ts
// app/api/public/status/route.ts — public by design, called from partner sites
import { getPublicStatus } from '@/lib/status'

const ALLOWED_ORIGINS = new Set(['https://partner.example.com', 'https://admin.example.com'])

function corsHeaders(origin: string | null): Headers {
  const headers = new Headers({ Vary: 'Origin' })
  if (origin && ALLOWED_ORIGINS.has(origin)) {
    headers.set('Access-Control-Allow-Origin', origin)
  }
  return headers
}

export function OPTIONS(request: Request) {
  const headers = corsHeaders(request.headers.get('origin'))
  headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS')
  headers.set('Access-Control-Allow-Headers', 'Content-Type')
  headers.set('Access-Control-Max-Age', '600')
  return new Response(null, { status: 200, headers })
}

export async function GET(request: Request) {
  const status = await getPublicStatus()
  return Response.json({ data: status }, { headers: corsHeaders(request.headers.get('origin')) })
}
```

**P7. Rate-limited, origin-checked `POST` with `after()` and `maxDuration`**. Rules: API-17, API-19, API-34 and API-36.

```ts
// app/api/exports/route.ts — POST queues an expensive export
import { checkRateLimit } from '@vercel/firewall'
import { after } from 'next/server'
import { getSession } from '@/lib/auth/session'
import { notifyExportQueued, queueExport } from '@/lib/exports'
import type { ApiErrorBody } from '@/lib/api/errors'

export const maxDuration = 30 // seconds; choose values with performance-and-vercel.md

const APP_ORIGIN = process.env.APP_ORIGIN // for example 'https://app.example.com'

export async function POST(request: Request) {
  if (request.headers.get('origin') !== APP_ORIGIN) {
    return Response.json(
      { error: { code: 'forbidden', message: 'Cross-site request rejected.' } } satisfies ApiErrorBody,
      { status: 403 },
    )
  }
  const session = await getSession()
  if (!session) {
    return Response.json(
      { error: { code: 'unauthenticated', message: 'Sign in to export.' } } satisfies ApiErrorBody,
      { status: 401 },
    )
  }
  // Needs a Vercel WAF rule whose Rate limit ID is 'create-export'.
  const { rateLimited } = await checkRateLimit('create-export', { request, rateLimitKey: session.userId })
  if (rateLimited) {
    return Response.json(
      { error: { code: 'rate_limited', message: 'Too many exports. Try again later.' } } satisfies ApiErrorBody,
      { status: 429 },
    )
  }
  const job = await queueExport(session.userId)
  after(() => notifyExportQueued(job.id))
  return Response.json({ data: job }, { status: 202 })
}
```

**P8. Cache Components: a cached public `GET`**. Rules: API-24 and API-27. The prose line says three things:

- it applies with `cacheComponents: true`;
- a CMS webhook handler invalidates it with `revalidateTag('catalog', 'max')`;
- the previous model uses `export const dynamic = 'force-static'` instead (API-23).

```ts
// app/api/catalog/route.ts — public by design, identical for every caller
import { cacheLife, cacheTag } from 'next/cache'
import { listPublishedProducts } from '@/lib/catalog'

export async function GET() {
  return Response.json({ data: await getCatalog() })
}

async function getCatalog() {
  'use cache' // allowed in a helper, not in the handler body
  cacheLife('hours')
  cacheTag('catalog')
  return listPublishedProducts()
}
```

## 9. Anti-patterns (8 Don't/Do pairs)

Format each item exactly like this, with fences at column 0. If the skeleton's generic
anti-pattern check needs another shape, follow it.

````text
- **Don't** <what>; it breaks API-N.

```ts
…
```

**Do** <the fix>.

```ts
…
```
````

The coder must keep AC6 in mind. A Don't/Do block that *exports* `POST`, `PUT`, `PATCH` or
`DELETE` must also call a session or auth function. So the Don't blocks below are either `GET`
handlers or fragments with no export.

| # | Rule | Don't | Do |
| --- | --- | --- | --- |
| A1 | API-6 | Server Component `fetch('http://localhost:3000/api/projects')`, then `await res.json()` (`tsx`). | `const projects = await listProjectsForCurrentUser()` from the DAL (`tsx`). |
| A2 | API-4 | `export async function GET(_req: Request, { params }: { params: { id: string } })` with `params.id`; comment it as removed in 16. | `RouteContext<'/api/projects/[id]'>` plus `const { id } = await ctx.params`. |
| A3 | API-16 | `GET /api/me` returning `db.user.findFirst()` with the comment "proxy.ts already checks the cookie". | The same `GET` with `getSession()`, answering `401` `satisfies ApiErrorBody`. |
| A4 | API-12 | `try { … } catch (error) { return new Response(error instanceof Error ? error.message : 'Error', { status: 500 }) }` as a fragment. | `console.error('create project failed', error)`, then a `500` `internal` envelope. |
| A5 | API-32 | `const payload = await request.json(); const expected = sign(JSON.stringify(payload))` as a fragment. | `const rawBody = await request.text()`, `createHmac(...).update(rawBody)`, `timingSafeEqual`, then `JSON.parse(rawBody)` as a fragment. |
| A6 | API-31 | A headers object with `'Access-Control-Allow-Origin': '*'` and `'Access-Control-Allow-Credentials': 'true'`. | Echo `origin` only if it is in `ALLOWED_ORIGINS`, set `Access-Control-Allow-Credentials`, and add `Vary: Origin`. |
| A7 | API-27, API-35 | `export const runtime = 'edge'`, then `updateTag('catalog')` inside the handler (fragment, no exported method). | No runtime export, and `revalidateTag('catalog', 'max')` (or `{ expire: 0 }`). |
| A8 | API-30 | `try { … redirect('/dashboard') } catch { return Response.json(…) }`: the catch swallows `NEXT_REDIRECT`. | Do the work in `try`, then call `redirect('/dashboard')` after the block. |

## 10. Version notes (Next.js 16)

The section opens with *"Changes in **Next.js 16** (16.0 → 16.3) that affect Route Handlers:"*,
followed by bullets, each with its link:

1. **Async request APIs (breaking).** Next.js 16 removed synchronous access to `route.js` `params`, `cookies()`, `headers()` and `draftMode()`. `await` them, and type context with `RouteContext` from `next typegen`, which arrived in 15.5. Links: [Upgrading to 16](https://nextjs.org/docs/app/guides/upgrading/version-16), [Next.js 16](https://nextjs.org/blog/next-16). Rules: API-4, API-28.
2. **`middleware.ts` renamed `proxy.ts`.** The middleware name is deprecated. Proxy runs on Node.js only and its runtime can't be configured. Auth there is still only optimistic. Links: [Upgrading to 16](https://nextjs.org/docs/app/guides/upgrading/version-16), [proxy.js](https://nextjs.org/docs/app/api-reference/file-conventions/proxy). Rule: API-16.
3. **Caching APIs.** `revalidateTag` now requires a `cacheLife` second argument, and the one-argument form is deprecated. The new `updateTag` is Server Actions-only and throws in a Route Handler. Links: [Next.js 16](https://nextjs.org/blog/next-16), [updateTag](https://nextjs.org/docs/app/api-reference/functions/updateTag). Rule: API-27.
4. **Cache Components.** `cacheComponents: true` makes `GET` handlers follow the prerender model. It removes `dynamic`, `dynamicParams`, `revalidate` and `fetchCache`, and `experimental_ppr` is removed outright. Links: [Route Segment Config](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config), [Route Handlers](https://nextjs.org/docs/app/getting-started/route-handlers). Rules: API-24, API-25.
5. **Edge runtime.** It is deprecated, and Vercel states `runtime = 'edge'` is not supported from 16.3. Links: [runtime](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/runtime), [Vercel Functions API](https://vercel.com/docs/functions/functions-api-reference). Rule: API-35.
6. **Root params (16.3).** `next/root-params` works in Server Components only, and Route Handler support is planned. Read segments from `ctx.params`. Link: [Next.js 16.3](https://nextjs.org/blog/next-16-3). Rule: API-4.
7. **Not new in 16** (agents often date these wrong): `GET` handlers uncached by default and `context.params` as a Promise both date from 15.0.0-RC, and `after()` has been stable since 15.1. Links: [route.js](https://nextjs.org/docs/app/api-reference/file-conventions/route), [after](https://nextjs.org/docs/app/api-reference/functions/after).

## 11. Review checklist, and Not confirmed by the docs

### `## Review checklist` (17 items)

Each item names its rule id(s):

- [ ] Each endpoint is a `route.ts` with no `page.tsx` in the same segment (API-1)
- [ ] Only HTTP-method exports and segment config are exported (API-2)
- [ ] Dynamic handlers use `RouteContext<'/…'>` and `await ctx.params` (API-4)
- [ ] Public, third-party and webhook endpoints are Route Handlers; UI mutations are Server Actions (API-5)
- [ ] No Server Component fetches its own `/api` route (API-6)
- [ ] Body, params, query and headers are `safeParse`d before use (API-8)
- [ ] `Content-Type` is checked (415) and invalid JSON answers 400 (API-9)
- [ ] Every error is an `ApiErrorBody` with the status that matches its meaning (API-10, API-11)
- [ ] No `error.message`, stack or SQL in any response (API-12)
- [ ] Every non-public handler checks the session in the handler (401) and the role or ownership (403/404) (API-13, API-14, API-15, API-16)
- [ ] Cookie-authenticated mutating handlers check `Origin` (API-17)
- [ ] Abuse-prone endpoints are rate-limited with 429 (API-19)
- [ ] List endpoints are paginated with a bounded `limit` (API-20)
- [ ] Caching intent is explicit: no `s-maxage` on per-user responses, no `dynamic` or `revalidate` under Cache Components (API-23, API-24, API-25, API-26)
- [ ] No `updateTag` in Route Handlers, and `revalidateTag` has two arguments (API-27)
- [ ] CORS echoes allow-listed origins with `Vary: Origin` and an exported `OPTIONS` (API-31)
- [ ] Webhooks verify a signature on `request.text()` with a constant-time compare, dedupe by event id and return 2xx fast, with no `runtime = 'edge'` (API-32, API-33, API-35)

Item 2 is a house review check grounded in API-2's method list.

### `## Not confirmed by the docs`

Each bullet names the URLs checked. None is stated as a rule.

- **A standard error envelope** (for example problem+json). No nextjs.org or vercel.com page prescribes one, so `ApiErrorBody` is a convention. Checked: BFF, ROUTE.
- **`Idempotency-Key` semantics.** These are not on nextjs.org or vercel.com; MDN defines only method idempotency. Checked: MDN Idempotent, BFF.
- **Automatic `HEAD`.** The docs state only that `OPTIONS` is auto-implemented; whether `HEAD` is derived from `GET` is not stated. Checked: ROUTE, RH-GS.
- **A request body size limit outside Vercel.** The 4.5 MB limit is Vercel's. Checked: ROUTE, BFF, Vercel limits.
- **Whether `dynamicParams` is still accepted under Cache Components.** The segment-config option table lists it, but its v16.0.0 history row says it was removed. Checked: SEG.
- **Whether `maxDuration` must be a static literal.** The docs say this only for `revalidate`. Checked: maxDuration, caching-without-cache-components.
- **Third-party signature schemes** (Stripe, GitHub). Their docs are outside the allowed hosts, so the example uses Vercel's documented scheme. Checked: Vercel request headers, Vercel webhooks API.
- **Vercel's webhooks-API validator exports `GET`**, while webhooks are delivered as POST, per vercel.com/docs/webhooks. This file follows the request-headers page's `POST` example. Checked: both pages.
- **A built-in CSRF check for Route Handlers.** None is documented; only the Server Actions Origin check is. API-17 is therefore a convention. Checked: SEC, SA, ROUTE, BFF.
- **WebSockets in Route Handlers.** BFF says they won't work on lambda-style hosts, while Vercel documents an `experimental_upgradeWebSocket` public beta. This is out of scope and not a rule. Checked: BFF, `@vercel/functions`.

## 12. `## Sources` and assumptions

`## Sources` is a bullet list of exactly the 48 URLs in
[evidence/sources-verified.md](evidence/sources-verified.md), in that order, one bare URL per
bullet. Every prose link in the file must use one of these URLs exactly, with no anchors.

### Assumptions (decided, not asked)

1. **H1 and as-of line.** Both are copied verbatim from the skeleton's stub. The as-of version is expected to read `16.3.8`. If the skeleton read a different version string, the stub wins, and the version notes still name `Next.js 16`.
2. **Error-shape interpretation (AC5).** The shape is the type `ApiErrorBody`, and examples use it inline through `satisfies` rather than a helper. That way every error site, the POST example included, literally references the type and is type-checked without `any`. "Every handler example that returns an error" means the handler blocks under `## Patterns`, and the test scopes to that section. Don't blocks show wrong code by design.
3. **400, not 422, for schema failures.** This is a convention: MDN defines both, and 400 keeps one client-error code for input problems. The 422 meaning stays available for domain rules if a project wants it.
4. **Preflight status 200, not 204.** This follows MDN's browser note. Next.js's proxy CORS example also answers 200, via `NextResponse.json({}, …)`.
5. **Invalid webhook signature answers 401.** This follows the Next.js BFF webhook example (bad token gives 401). Vercel's sample answers 403, and the Patterns prose says so.
6. **The session reader stays in another file.** `getSession()` and the `Session` type belong to `proxy-auth-and-security.md`. This file only calls them. The name matches AC6's `session\w*\(` regex naturally.
7. **The evidence file is written by the planner.** The planner did the live fetches. The coder must keep `## Sources` identical to it, or update both in one commit.
8. **No version bump.** `plugin.json` is owned by the skeleton story.
9. **The Vercel webhook example** is a real, documented signature scheme on an allowed host, so it is preferred over an invented generic HMAC example.
