# Plan — data-fetching-server-actions-and-forms

**Story:** [story.md](story.md) · **Owns:** `R/nextjs/data-fetching-and-mutations.md` (prefix `DF`) and
`Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_data_fetching_and_mutations.py`.
`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`.
**Research date:** 2026-10-04. Every URL below was fetched live on that date (nextjs.org and vercel.com as
`<url>.md`, react.dev as `<url>.md`, zod.dev as HTML). The Next.js docs front matter reported
`version: 16.3.8` on every page, and `registry.npmjs.org/next/latest` returned `16.3.8`, so the latest
stable release is **Next.js 16.3.8** (major **16**). React `latest` on npm is 19.3.0. Zod `latest` is 4.6.5.

## 1. Approach

1. Skills: stack.md routes **none** (Markdown content). `nextjs-fullstack-standards` isn't loadable, so
   nothing is approximated from memory. Every claim comes from the rule sheet in §7, which was verified
   against the pages live.
2. The coder first reads `R/nextjs.md` (the **Authoring contract**, the as-of line and the index row),
   `assets/tests/nextjs_doc_helpers.py` and `assets/tests/test_nextjs_reference.py`, all of which the
   skeleton story merged earlier. They then replace the stub `R/nextjs/data-fetching-and-mutations.md`
   **entirely**.
3. File layout, following the contract: H1 → as-of line copied **verbatim** from `R/nextjs.md` → `## Scope` →
   `## Rules` (DF-1…DF-28 from §7) → `## Patterns` (P1–P10 from §8) → `## Anti-patterns` (A1–A8 from §9) →
   `## Version notes` (§10) → `## Review checklist` (§11) → `## Not confirmed by the docs` (§12) → `## Sources` (§13).
4. Why this shape: the reader is an agent, so the file gives imperative rules with a citation on each one,
   typed snippets copied from or checked against the cited page, and Don't/Do pairs that a reviewer can
   match against a diff.
5. Scope boundary: this file says **when and where** a mutation calls `updateTag`, `revalidatePath`,
   `revalidateTag` or `refresh`. What each API does to the cache lives in `rendering-and-caching.md`
   (linked). Security depth lives in `proxy-auth-and-security.md` (linked): the DAL, CSRF/allowedOrigins,
   closure encryption and bodySizeLimit. Here those topics get one short rule each, in mutation context.
6. TDD: write the topic test first (RED against the stub, since `is_stub` is true and the floors fail),
   then write the file until it passes (GREEN), then run the full suite and ruff.
7. Budget: the target is 600–720 lines, and the cap is 800. If the file runs long, shorten the prose
   inside Patterns first. Never drop a rule, a required example or a Source.

## 2. Files

| Path | Change | Purpose |
| --- | --- | --- |
| `R/nextjs/data-fetching-and-mutations.md` | replace stub | The DF topic file: rules, patterns, anti-patterns, version notes, checklist, not-confirmed, sources |
| `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_data_fetching_and_mutations.py` | new | Topic-specific tests (§3). Imports `nextjs_doc_helpers`, stdlib + pytest only |
| `docs/sprints/bmn-nextjs-typescript-best-practices-reference/data-fetching-server-actions-and-forms/evidence/sources-verified.md` | new | AC9: every Sources URL, fetch date 2026-10-04 and the DF ids it backs (table in §13) |
| `docs/sprints/bmn-nextjs-typescript-best-practices-reference/data-fetching-server-actions-and-forms/validation.md` | new (validation phase) | AC9 one-off URL-set equality check, AC10 diff scope, gate output |

Nothing else changes. `nextjs.md`, the helpers, `test_nextjs_reference.py` and every other topic file are
read-only for this story (story Assumptions).

## 3. Test plan (written first)

File: `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_data_fetching_and_mutations.py`, type **unit**,
offline. Import with a plain `import nextjs_doc_helpers as h`. pytest's default `prepend` import mode
puts this tests dir on `sys.path`. If `test_nextjs_reference.py` imports the helpers some other way,
copy that way instead. Module constants:
`TOPIC = h.TOPICS_DIR / "data-fetching-and-mutations.md"`, `TERMS` (the exact 22 strings from AC3),
`AUTH_CALL = re.compile(r"(?i)(session|auth)\w*\(")`, `ANY_TYPE = re.compile(r":\s*any\b|<any>|\bas any\b|any\[\]")`.

| AC | Test name(s) | What it asserts |
| --- | --- | --- |
| 1 | *(generic)* every check in `test_nextjs_reference.py` | Runs on the file with no skip: as-of line, section order, rule format, citations, floors, Sources hosts, ≤800 lines, tagged fences, resolving links |
| 1 | `test_topic_uses_only_df_rule_ids` | every id from `h.rule_items(text)` starts with `DF-`, and no other `[A-Z]+-\d+` rule id appears in bold at the start of a rule |
| 2 | `test_topic_is_not_a_stub` | `h.is_stub(text) is False` |
| 2 | `test_topic_has_at_least_15_df_rules` | `len(h.rule_items(text)) >= 15` |
| 3 | `test_topic_names_every_required_concept` | `h.missing_terms(text, TERMS) == []` |
| 4 | `test_topic_has_required_example[parallel-fetching]` | `h.has_block_with(text, "Promise.all", "await")` |
| 4 | `test_topic_has_required_example[validated-server-action]` | `h.has_block_with(text, "'use server'", "safeParse")` |
| 4 | `test_topic_has_required_example[action-state-form]` | `h.has_block_with(text, "'use client'", "useActionState")` |
| 4 | `test_topic_has_required_example[optimistic-update]` | `h.has_block_with(text, "useOptimistic")` |
| 4 | `test_topic_has_required_example[request-dedup-cache]` | `h.has_block_with(text, "'react'", "cache(")` |
| 4 | `test_examples_never_use_any` | no `ts`/`tsx` block matches `ANY_TYPE` |
| 5 | `test_every_use_server_block_calls_an_auth_check` | the blocks from `h.code_blocks(text, ("ts", "tsx"))` that contain `'use server'` are non-empty, and each matches `AUTH_CALL` |
| 5 | `test_mutation_examples_link_the_security_topic` | `h.section(text, "Patterns")` and `h.section(text, "Rules")` each contain `proxy-auth-and-security.md` |
| 6 | `test_rules_state_redirect_outside_try_catch` | `rules = h.section(text, "Rules")`, and `"redirect" in rules and "try" in rules` |
| 7 | `test_version_notes_name_the_major_and_link_nextjs` | `major = h.as_of_version(text).split(".")[0]`; `## Version notes` contains `f"Next.js {major}"` and `https://nextjs.org/` |
| 8 | `test_every_checklist_item_names_a_df_rule` | every `- [ ]` line in `## Review checklist` contains `DF-` (and ≥ 8 lines exist) |
| 8 | `test_checklist_rule_ids_exist` | every `DF-\d+` cited in the checklist is an id in `h.rule_items(text)` |
| 8 | `test_every_dont_is_paired_with_a_do` | in `## Anti-patterns`, the number of Don't items equals the number of Do items (≥ 3), and each Don't and each Do is followed by a fenced block before the next item. Use the **same** Don't/Do item syntax the skeleton's contract and test use. Default if the contract is silent: §9's `- **Don't:**` / `- **Do:**` |
| 9 | one-off, not a test | `validation.md` records a command comparing `h.source_urls(text)` with the URL column of `evidence/sources-verified.md` (sets equal) |
| 10 | gates | `git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD` lists only the 4 paths in §2. The full suite and ruff pass (§6) |

Count: **14 test functions → 18 collected cases** (one is parametrized ×5). No browser criteria: `ui: false`,
so there is no Playwright.

## 4. Data

None: no models, no migrations, no RLS. `supabase: false`.

## 5. Config / env and deploy_pending

- Env vars this story creates: **none**. The topic file mentions `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY` only as
  documented guidance (DF-27). Nothing is configured.
- `deploy_pending`: **[]**. This is Markdown plus a pytest file in a skills repo, with no Vercel and no Supabase.

## 6. Risks and gates

| Risk | Mitigation |
| --- | --- |
| The contract's exact syntax (Don't item form, citation check, `source_urls` normalisation of `#fragment`s) is set by the parallel skeleton plan | Read `R/nextjs.md` and `test_nextjs_reference.py` before writing. **Use no `#fragment` in any URL**, so prose URLs and Sources match byte for byte. If the skeleton disagrees with §9's default syntax, follow the skeleton and record the change in validation.md |
| A Don't block that contains `'use server'` must still match `AUTH_CALL` (AC5 is block-level) | Every block in §8/§9 that contains `'use server'` already calls `verifySession()`. A3's Don't shows the *page-level* check, which is the documented bug, so the regex holds while the anti-pattern stays accurate |
| A link to a host outside `ALLOWED_SOURCE_HOSTS` slips in (swr.vercel.app, tanstack.com, 19.react.dev, owasp.org, valibot.dev, npmjs.com) | Name SWR / TanStack Query in plain text and cite the nextjs.org guide. Link only the §13 URLs |
| The Next.js docs' Zod snippets are Zod 3 (`invalid_type_error`, `.error.flatten()`), while zod.dev documents Zod 4: `invalid_type_error` dropped, `.flatten()` deprecated, `z.flattenError()` used | Snippets follow zod.dev (`import * as z from 'zod'`, `{ error: … }`, `z.flattenError(...)`). A8 and DF-13 cite zod.dev for this, and the Next.js auth guide already uses Zod 4 `{ error }` / `z.email()` |
| Snippets are not compiled (there is no Next.js project here) | Use only the signatures quoted in §7/§8. REVIEW① spot-checks them against the links |
| 800-line cap | Budget in §1.7. Run `wc -l` before committing |
| A required term is missing because of case or punctuation (`redirect(`, `refresh(`, `use(`, `.bind(`, `action=`) | The §8 snippets contain each one literally, and `missing_terms` is case-insensitive |

**Gates (run all three, in this order):**

```bash
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_data_fetching_and_mutations.py Skills/dev-bother-me-nope/assets/tests/test_nextjs_reference.py -q
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q
uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope
```

## 7. Verified rule sheet (every rule the file will state)

Each rule goes into `## Rules` as `N. **DF-N** <imperative sentence> … [link](url)`. Sources are cited by
the short keys in §13; the coder writes the full URL. ★ = API **new or changed in Next.js 16** (see §10).

### Reading data

| Id | Rule (imperative, checkable) | Source(s) | What the page says |
| --- | --- | --- | --- |
| DF-1 | Fetch server data in **async Server Components**: `await fetch(...)` or an ORM/DB call. Don't fetch it in a Client Component effect. | N1 | "You can fetch data in Server Components using any asynchronous I/O"; DB credentials and query logic "will not be included in the client bundle" |
| DF-2 | Read and write through a `server-only` **Data Access Layer** that authorizes and returns minimal **DTOs**. Never pass a raw row to a Client Component. Depth: `proxy-auth-and-security.md`. | N6, N1 | A DAL "for new projects" should "only run on the server", "perform authorization checks", "return safe, minimal DTOs". Passing a whole `userData` to a Client Component "exposes all the fields" |
| DF-3 | Call the data source or DAL directly from Server Components. **Never `fetch` your own Route Handler** from one. Route Handler design: `route-handlers-and-apis.md`. | N18 | "Fetch data in Server Components directly from its source, not via Route Handlers." Prerendering "will fail the build step", and on-demand rendering is slower because of "the extra HTTP round trip" |
| DF-4 | Start independent requests before awaiting any of them, then await `Promise.all` (or `Promise.allSettled` when a partial failure is acceptable). Sequential `await`s of independent data create a **waterfall**. | N1 | "multiple `async`/`await` requests can still be sequential". "Start multiple requests… then await them with `Promise.all`." "If one request fails… use `Promise.allSettled`." Preloading avoids "a request waterfall" |
| DF-5 | Keep a truly dependent request sequential, but wrap the dependent child in `<Suspense>` so the rest renders first. Make the blocking first request fast, or cache it. | N1 | Sequential example with `<Playlists>` in `<Suspense>`: "Ensure your data source can resolve the first request quickly… consider caching" |
| DF-6 | Wrap every non-`fetch` data function (ORM/DB) in React `cache(` **at module scope in a shared module**, so all components in one request share one result. Rely on built-in `fetch` memoization (GET, same URL and options) for `fetch`. Expect neither to persist across requests; persistence is `rendering-and-caching.md`. | N1, N19, R5 | N1: "For data access that does not use `fetch`… wrap the function in `React.cache`". The cache is "scoped to the current request only". N19: GET `fetch` with the same URL and options is memoized "during a server render pass", "separate from persistent caching". R5: call `cache` "outside of any components", each call "creates a new function", errors are cached, it's for Server Components only |
| DF-7 | **Preload** by calling the deduplicated function without `await` (`void getItem(id)`) before other blocking work. Export the `preload` helper next to the component that consumes the data. | N1 | "call the data-fetching function without `await` before blocking work, then call the same function in the component". The function "must deduplicate matching calls". "Keep the preload function next to the component" |
| DF-8 | Stream data to a Client Component by passing the **un-awaited promise** from a Server Component as a prop typed `Promise<T>`. Read it with `use(` inside a `<Suspense>` boundary. `T` must be serializable. Never call `use(` inside `try`/`catch`. | N1, R4 | N1: "Don't await the data fetching function"; pass the promise; "use the `use` API to read the promise", wrapped in `<Suspense>`. R4: the resolved value "must be serializable"; `use` "cannot be called inside a try-catch block"; promises "must be cached" (create them in the Server Component, not during a client render) |
| DF-9 | Reach for SWR or TanStack Query only when Client Components need a shared browser cache, polling, focus revalidation or client-only Web APIs. For read-once server data, pass a promise and call `use(`. When a library cache was seeded from a cached server read, invalidate that server read after a mutation too. | N15, N18 | N15: "If a Client Component only needs to read server data once, pass it a Promise… `use()`". Use a library "when Client Components need a shared browser cache". "After a mutation, invalidate any cached server read that provided the initial data." N18: client fetching for client-only Web APIs and "frequently polled data" |
| DF-10 | **Never use a Server Function to fetch data.** Don't parallelize actions from the client with `Promise.all`, because they are dispatched one at a time. Read in Server Components or a **Route Handler**, and do parallel work inside a single action. | N3, N2, N18, R7 | N3: "Next.js dispatches Server Actions one at a time per client… do not rely on `Promise.all`". N18: "Server Actions are queued. Using them for data fetching introduces sequential execution." R7: "not recommended for data fetching" |

### Mutating data

| Id | Rule | Source(s) | What the page says |
| --- | --- | --- | --- |
| DF-11 | Put `'use server'` either at the top of a dedicated `actions.ts`, or as the first statement of an **async** function inside a Server Component. Never define a Server Function in a Client Component. Client Components import actions from a `'use server'` module, or receive them as props. | N2, N5, R7 | N2: "It's not possible to define Server Functions in Client Components… import them from a file that has the `"use server"` directive"; "Passing actions as props". R7: the directive must be first, works only on async functions, and must be "used on a module level" to import into client code |
| DF-12 | **Authenticate and authorize inside every Server Action**, before any write: call `verifySession()` / `auth()`, then check ownership of the specific resource. A page-level check doesn't protect the actions on that page, because every action is reachable by direct POST. Read identity from the session cookie, never from a token argument. Depth: `proxy-auth-and-security.md`. | N2, N3, N5, N6 | N2: "Server Functions are reachable via direct POST requests… Always verify authentication and authorization inside every Server Function." N6: "A page-level authentication check does not extend to the Server Actions defined within it." N5: "Read authentication from cookies or headers rather than accepting tokens as function parameters" |
| DF-13 | Treat every action argument as untrusted: `FormData`, `.bind(`-ed args, plain values. Validate with a schema `safeParse` before use. Accept an ID plus the change, and re-read ownership from a trusted source. For Zod 4, build field errors with `z.flattenError(result.error)`. | N3, N4, R7, Z1, Z2, Z3 | N3: "Validate inputs. Treat `FormData`… as untrusted". Schema validation "only checks the *shape*"; send "a reference (typically an ID) plus the user's change". N4: server-side validation with Zod `safeParse`. R7: "Arguments to Server Functions are fully client-controlled." Z1: `.safeParse()` returns a discriminated union. Z2: `z.flattenError()` → `{ formErrors, fieldErrors }`. Z3: `.flatten()` deprecated |
| DF-14 | **Return expected errors as typed state.** Validation failures, business-rule rejections and failed upstream calls go back as a serializable object the form renders through `useActionState`. Don't throw them, and don't wrap them in `try`/`catch`. Throw only unexpected errors, which reach the nearest error boundary. | N16, R1, N17 | N16: "For these errors, avoid using `try`/`catch` blocks and throw errors. Instead, model expected errors as return values." R1: return known errors "as part of your `reducerAction` state"; a thrown error cancels queued actions and "shows the nearest Error Boundary". N17: a throw inside `useTransition` "is forwarded to the nearest error boundary" |
| DF-15 | Return only what the UI renders: a DTO, an `{ ok }` flag or field errors. Never return a raw database record. Return values are serialized to the client. | N3, N5, N6 | N3: "Constrain return values. Action returns are serialized to the client." N6: "Only return what the UI needs, not raw database records" |
| DF-16 | Invalidate **inside the action, after the write succeeds**. Use `updateTag(tag)` for read-your-own-writes (★, Server Actions only), `revalidatePath(path)` for one route, `revalidateTag(tag, 'max')` (★, second argument required) when stale data is acceptable, and `refresh(` (★, Server Actions only) for uncached data on the current route. What each one does: `rendering-and-caching.md`. | N3, N2, N8, N9, N10, N11 | N3, "Choosing a cache update": `updateTag` is "read-your-own-writes… Server Actions only"; `revalidateTag` is stale-while-revalidate and "does **not** wait"; `revalidatePath` "invalidate by URL path"; `refresh` "refetch the current route's RSC Payload without invalidating cached data". The `updateTag`/`revalidatePath`/`refresh` re-render ships in the same response. N9/N10: either one throws outside a Server Action |
| DF-17 | Call `redirect(` **outside** any `try`/`catch`, and **after** revalidation. It throws a framework control-flow exception (`NEXT_REDIRECT`), so code after it never runs. In a Server Action it defaults to a `push` navigation and serves a 303 for a no-JS submission. Revalidation APIs don't throw, so an action can call them and still return a value. | N7, N2, N3 | N7: "`redirect` throws an error so it should be called **outside** the `try` block"; "default in Server Actions" is `push`; for progressive-enhancement submissions "it serves a 303". N2: "Any code after it won't execute. If you need fresh data, call `revalidatePath` or `revalidateTag` beforehand." N3: "none of these throw" |
| DF-18 | Submit mutations with `<form action={serverAction}>`, or `formAction` on a `<button>`, so React runs them in a transition, passes `FormData` automatically, and the form works before hydration (**progressive enhancement**). Use `next/form`'s `<Form action="/path">` for GET forms that navigate with search params. | N2, N4, N13, RF | N2: a Server Action is automatically wrapped in `startTransition` "when passed to a `<form>` using the `action` prop" or to `formAction`. "Server Components support progressive enhancement by default". Client forms "queue submissions if JavaScript isn't loaded yet". N13: a string `action` gives a GET with prefetch and client-side navigation; a function `action` behaves like a React form. RF: the no-JS error display needs a Server Function plus `useActionState` |
| DF-19 | Pass non-field arguments with `serverAction.bind(null, id)`, not hidden inputs. Re-authorize the bound value inside the action, because it is still client-controlled. | N4, R7 | N4: `bind` "works in both Server and Client Components and supports progressive enhancement". A hidden input's value "will be part of the rendered HTML and will not be encoded". R7: arguments are "fully client-controlled" |
| DF-20 | Show pending state with `useActionState`'s third value (`pending`), or with `useFormStatus().pending` in a **child component rendered inside the `<form>`**. Disable the submit button while pending. | N4, R1, R3 | N4: "`useActionState` hook exposes a `pending` boolean"; with `useFormStatus` "you'll need to create a separate component". R3: it "only return[s] status information for a parent `<form>`" |
| DF-21 | Type an action used with `useActionState` as `(prevState: State, formData: FormData) => Promise<State>`, with a **serializable** `initialState: State` of the same type. Keep schemas and `State` types in a non-`'use server'` module. | N4, R1, N16 | N4: "the Server function signature will change to receive a new `prevState` or `initialState` parameter as its first argument". R1: with Server Functions, `initialState` must be serializable; the return type "must match the type of `initialState`" |
| DF-22 | Call an action from an event handler or `useEffect` inside `startTransition` (take `isPending` from `useTransition`). Wrap any state update made **after an `await`** in another `startTransition`. Call a `useActionState` dispatch only from an Action. | N2, N3, N17, R6, R1 | N3: invoke "from an event handler or `useEffect` wrapped in `startTransition`". N17: "State updates after the `await` aren't automatically part of that transition"; wrap them in `startTransition`. R1: "`dispatchAction` must be called from an Action" |
| DF-23 | Use `useOptimistic` for instant feedback. Call its setter **inside the Action** (form action or `startTransition`) before awaiting the Server Action. Let the value revert to the server prop when the transition ends, without clearing it by hand. | N4, N17, R2 | N4: "optimistically update the UI before the Server Function finishes". N17: "The optimistic value applies for as long as that transition is pending… reverts to the new server-rendered prop". R2: the setter "must be called inside an Action"; "There's no extra render to 'clear' the optimistic state" |
| DF-24 | **Never mutate during render.** No DB writes, cookie `set`/`delete` or revalidation in a Server Component body. Mutate in a Server Action, where `(await cookies()).set(...)` re-renders the current page with the new value, or in a Route Handler. | N6, N2 | N6: "Mutations… should never be a side-effect… Next.js explicitly prevents setting cookies or triggering cache revalidation within render methods." N2: setting or deleting a cookie in a Server Action makes Next.js re-render "the current page and its layouts" |
| DF-25 | Put post-response work (audit logs, analytics) in `after(` from `next/server`. In a Server Component, read `cookies()`/`headers()` **before** `after` and pass the values in. On Vercel, work that must finish after the response goes in `after` or `waitUntil`. | N12, V1 | N12: `after` "schedule[s] work to be executed after a response", in Server Components, Server Functions, Route Handlers and Proxy. It "will be executed even if the response didn't complete successfully", including on `redirect`. Request APIs inside `after` are allowed in Server Functions and Route Handlers but throw in Server Components. Stable since v15.1.0. V1: wrap must-complete work "in `waitUntil` or `after`" |
| DF-26 | Keep action payloads under `serverActions.bodySizeLimit` (1MB default). Raise it in `next.config` under `experimental.serverActions` only for real uploads, leaving 10–20 KB for multipart overhead. Behind a proxy, set `allowedOrigins`. Depth: `proxy-auth-and-security.md`. | N14, N3 | N14: "the maximum size of the request body sent to a Server Action is 1MB"; configure with `serverActions.bodySizeLimit`. The example sits under `experimental.serverActions`, and the limit includes multipart overhead ("10–20 KB is a reasonable rule of thumb"). `allowedOrigins` handles proxy hosts |
| DF-27 | Don't capture secrets in an inline action's closure. Closed-over values round-trip through the client encrypted, and the docs advise against relying on that encryption. For multi-instance self-hosting, set one stable `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY`. Depth: `proxy-auth-and-security.md`. | N6, N3 | N6: "captured variables are sent to the client and back"; "Next.js automatically encrypts the closed-over variables"; "We don't recommend relying on encryption alone". Set the key so "all server instances use the same key" |
| DF-28 | Treat "Failed to find Server Action" after a deploy as a **retry path** in the UI, not a hard failure. Prefer rolling deploys, because action IDs change between builds. | N3 | N3, "Deployment considerations": new deployments generate new IDs, "rotates them at most every 14 days", and an old client hits "Failed to find Server Action". "Surface the error as a retry path" |

**Rule text that must appear (AC6):** DF-17 contains the words `redirect` and `try`. DF-14 contains `try`/`catch`.
**Rules that link `proxy-auth-and-security.md` (AC5):** DF-2, DF-12, DF-26, DF-27. The Patterns intro links it too.
**Other cross-links:** `rendering-and-caching.md` (DF-6, DF-16, Scope), `route-handlers-and-apis.md` (DF-3, DF-10),
`typescript.md` (Scope: generated `PageProps` helpers live there), `testing-and-observability.md` (Scope: error boundaries).

### Scope section (prose, ≤ 12 lines)

Covers: reading in Server Components, the DAL and DTOs, waterfalls, dedup and preload, streaming promises
to `use(`, when to fetch client-side, Server Functions and Server Actions (terms from N2: "A Server Action
is a Server Function used in a specific way… Server Function is the broader term"), forms, validation,
pending and optimistic UI, revalidate/redirect placement, `after(`, `next/form`.
Links out: `rendering-and-caching.md` (cache semantics), `proxy-auth-and-security.md` (the DAL, session,
action security config), `route-handlers-and-apis.md` (public HTTP APIs and webhooks),
`testing-and-observability.md` (error boundaries, `error.tsx`), `../nextjs.md` (entry point).

## 8. Patterns (exact snippets — copy them; each is typed, with no `any`)

Open `## Patterns` with one line: *"Every `'use server'` example authenticates first. The session and DAL
helpers (`verifySession`, `@/lib/dal/*`) follow the Next.js authentication guide; see
[proxy-auth-and-security.md](proxy-auth-and-security.md)."* Use `### P<n> <title>` subheadings and a
one-line lead-in that cites the rule ids. Always write `'use server'` / `'use client'` with **single quotes**.

**P1 Parallel fetching in an async Server Component (DF-1, DF-4).** Verified against N1, "Parallel data fetching".
```tsx
// app/artist/[username]/page.tsx
import { getAlbums, getArtist } from '@/lib/dal/artists'

export default async function Page({
  params,
}: {
  params: Promise<{ username: string }>
}) {
  const { username } = await params
  // Both requests start now; neither waits for the other.
  const artistPromise = getArtist(username)
  const albumsPromise = getAlbums(username)
  const [artist, albums] = await Promise.all([artistPromise, albumsPromise])

  return (
    <>
      <h1>{artist.name}</h1>
      <ul>
        {albums.map((album) => (
          <li key={album.id}>{album.title}</li>
        ))}
      </ul>
    </>
  )
}
```

**P2 Request-scoped dedup with React `cache` in the DAL (DF-2, DF-6).** Verified against N1, "Reusing data with
`React.cache`" (same `db.query.users.findFirst({ where: eq(users.id, id) })` shape), N6 (`server-only`, DTO) and R5.
```ts
// lib/dal/users.ts
import 'server-only'
import { cache } from 'react'
import { db, eq, users } from '@/lib/db'
import type { UserDTO } from '@/lib/dto'

// Module scope: every component in this request shares one call per id.
export const getUser = cache(async (id: string): Promise<UserDTO | null> => {
  const row = await db.query.users.findFirst({ where: eq(users.id, id) })
  if (!row) return null
  return { id: row.id, name: row.name } // DTO: only what the UI renders
})
```

**P3 Preload before blocking work (DF-7).** Verified against N1, "Preloading data".
```tsx
// app/item/[id]/item.tsx
import { getItem } from '@/lib/dal/items' // wrapped in cache(), see P2

export const preload = (id: string): void => {
  void getItem(id)
}

export default async function Item({ id }: { id: string }) {
  const item = await getItem(id)
  return <div>{item?.name}</div>
}
```
```tsx
// app/item/[id]/page.tsx
import Item, { preload } from './item'
import { checkIsAvailable } from '@/lib/dal/items'

export default async function Page({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params
  preload(id) // starts the item request now
  const isAvailable = await checkIsAvailable(id)
  return isAvailable ? <Item id={id} /> : null
}
```

**P4 Stream a promise to a Client Component with `use(` (DF-8).** Verified against N1, "Streaming data with the
`use` API", and R4.
```tsx
// app/posts/[id]/page.tsx (Server Component)
import { Suspense } from 'react'
import { getComments } from '@/lib/dal/comments'
import { Comments } from './comments'

export default async function Page({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params
  const comments = getComments(id) // not awaited: the request starts, the HTML streams

  return (
    <Suspense fallback={<p>Loading comments…</p>}>
      <Comments comments={comments} />
    </Suspense>
  )
}
```
```tsx
// app/posts/[id]/comments.tsx
'use client'

import { use } from 'react'
import type { CommentDTO } from '@/lib/dto'

export function Comments({ comments }: { comments: Promise<CommentDTO[]> }) {
  const list = use(comments)
  return (
    <ul>
      {list.map((comment) => (
        <li key={comment.id}>{comment.body}</li>
      ))}
    </ul>
  )
}
```

**P5 Server Action that validates `FormData`, returns typed state, invalidates, then redirects (DF-12–DF-17, DF-21).**
Verified against N2 ("Redirect after a mutation"), N4 ("Form validation", "Validation errors"), N9 (the `updateTag` then
`redirect` example), N16, the Next.js auth guide's Zod 4 style (N-AUTH) and Z1/Z2.
```ts
// app/posts/definitions.ts (no directive: shared by the action and the form)
import * as z from 'zod'

export const CreatePostSchema = z.object({
  title: z.string().trim().min(1, { error: 'Title is required.' }),
  body: z.string().trim().min(1, { error: 'Write something first.' }),
})

export type CreatePostState = {
  fieldErrors?: Partial<Record<'title' | 'body', string[]>>
  message?: string
}
```
```ts
// app/posts/actions.ts
'use server'

import * as z from 'zod'
import { revalidatePath, updateTag } from 'next/cache'
import { redirect } from 'next/navigation'
import { verifySession } from '@/lib/dal/session'
import { createPost } from '@/lib/dal/posts'
import { CreatePostSchema, type CreatePostState } from './definitions'

export async function createPostAction(
  _prev: CreatePostState,
  formData: FormData,
): Promise<CreatePostState> {
  const { userId } = await verifySession() // redirects to /login when signed out

  const parsed = CreatePostSchema.safeParse({
    title: formData.get('title'),
    body: formData.get('body'),
  })
  if (!parsed.success) {
    return { fieldErrors: z.flattenError(parsed.error).fieldErrors }
  }

  const post = await createPost(userId, parsed.data) // DAL: authz + write, returns { id } | null
  if (!post) return { message: 'Could not save the post. Try again.' }

  updateTag('posts') // read-your-own-writes for every page tagged 'posts'
  revalidatePath('/posts')
  redirect(`/posts/${post.id}`) // last: it throws, nothing after it runs
}
```

**P6 Form bound to the action with pending and error state (DF-18, DF-20, DF-21).** Verified against N4, "Validation
errors" and "Pending states", R1 and R3.
```tsx
// app/posts/new/create-post-form.tsx
'use client'

import { useActionState } from 'react'
import { useFormStatus } from 'react-dom'
import { createPostAction } from '@/app/posts/actions'
import type { CreatePostState } from '@/app/posts/definitions'

const initialState: CreatePostState = {}

function SubmitButton() {
  const { pending } = useFormStatus() // reads the parent <form>
  return (
    <button type="submit" disabled={pending}>
      {pending ? 'Publishing…' : 'Publish'}
    </button>
  )
}

export function CreatePostForm() {
  const [state, formAction, pending] = useActionState(createPostAction, initialState)

  return (
    <form action={formAction} aria-busy={pending}>
      <label htmlFor="title">Title</label>
      <input id="title" name="title" required />
      {state.fieldErrors?.title && <p aria-live="polite">{state.fieldErrors.title[0]}</p>}
      <label htmlFor="body">Body</label>
      <textarea id="body" name="body" required />
      {state.fieldErrors?.body && <p aria-live="polite">{state.fieldErrors.body[0]}</p>}
      {state.message && <p aria-live="polite">{state.message}</p>}
      <SubmitButton />
    </form>
  )
}
```

**P7 Extra arguments with `.bind(` (DF-13, DF-19).** Verified against N4, "Passing additional arguments".
```tsx
// app/users/[id]/user-name-form.tsx
'use client'

import { updateUserNameAction } from './actions'

export function UserNameForm({ userId }: { userId: string }) {
  const updateWithId = updateUserNameAction.bind(null, userId)
  return (
    <form action={updateWithId}>
      <input name="name" required />
      <button type="submit">Save</button>
    </form>
  )
}
```
```ts
// app/users/[id]/actions.ts
'use server'

import * as z from 'zod'
import { revalidatePath } from 'next/cache'
import { verifySession } from '@/lib/dal/session'
import { updateUserName } from '@/lib/dal/users'

const Name = z.string().trim().min(1).max(80)

export async function updateUserNameAction(userId: string, formData: FormData): Promise<void> {
  const session = await verifySession()
  if (session.userId !== userId) return // the bound id is client-controlled: re-check it
  const parsed = Name.safeParse(formData.get('name'))
  if (!parsed.success) return
  await updateUserName(userId, parsed.data)
  revalidatePath(`/users/${userId}`)
}
```

**P8 Optimistic toggle from an event handler (DF-22, DF-23, DF-16 `refresh(`).** Verified against N17, "Step 2: Respond
instantly to a toggle", and R2 and R6.
```tsx
// app/posts/[id]/like-button.tsx
'use client'

import { useOptimistic, useTransition } from 'react'
import { toggleLikeAction } from './actions'

export function LikeButton({ postId, liked }: { postId: string; liked: boolean }) {
  const [optimisticLiked, setOptimisticLiked] = useOptimistic(liked)
  const [isPending, startTransition] = useTransition()

  function handleClick() {
    startTransition(async () => {
      setOptimisticLiked(!optimisticLiked) // renders now, reverts to `liked` when the transition ends
      await toggleLikeAction(postId)
    })
  }

  return (
    <button type="button" onClick={handleClick} aria-pressed={optimisticLiked} aria-busy={isPending}>
      {optimisticLiked ? 'Unlike' : 'Like'}
    </button>
  )
}
```
```ts
// app/posts/[id]/actions.ts
'use server'

import * as z from 'zod'
import { refresh } from 'next/cache'
import { verifySession } from '@/lib/dal/session'
import { toggleLike } from '@/lib/dal/likes'

export async function toggleLikeAction(postId: string): Promise<void> {
  const { userId } = await verifySession()
  const id = z.uuid().safeParse(postId)
  if (!id.success) return
  await toggleLike(userId, id.data)
  refresh() // like counts are uncached: re-render the current route in this response
}
```

**P9 Post-response work with `after(` in a Server Action (DF-15, DF-25).** Verified against N12, "In Route Handlers and
Server Functions".
```ts
// app/posts/archive-action.ts
'use server'

import * as z from 'zod'
import { after } from 'next/server'
import { revalidatePath } from 'next/cache'
import { verifySession } from '@/lib/dal/session'
import { archivePost } from '@/lib/dal/posts'
import { logAudit } from '@/lib/audit'

export async function archivePostAction(postId: string): Promise<{ ok: boolean }> {
  const { userId } = await verifySession()
  const id = z.uuid().safeParse(postId)
  if (!id.success) return { ok: false }
  const archived = await archivePost(userId, id.data) // DAL checks ownership
  if (!archived) return { ok: false }
  revalidatePath('/posts')
  after(async () => {
    await logAudit({ userId, postId: id.data, event: 'post.archived' }) // runs after the response
  })
  return { ok: true }
}
```

**P10 Search form with `next/form` (DF-18).** Verified against N13, "Search form that leads to a search result page".
```tsx
// app/ui/search-form.tsx
import Form from 'next/form'

export function SearchForm() {
  return (
    <Form action="/search">
      {/* Submits GET /search?query=…, prefetches /search, navigates client-side */}
      <input name="query" />
      <button type="submit">Search</button>
    </Form>
  )
}
```

## 9. Anti-patterns (Don't/Do pairs — default syntax)

Default syntax (replace it with the skeleton contract's syntax if that one differs): each item is a line
`- **Don't:** <one sentence> (DF-n)`, a blank line, an **unindented** fenced block, then
`- **Do:** <one sentence>`, a blank line, an unindented fenced block. Every block is `ts` or `tsx`. Each block that
contains `'use server'` calls `verifySession()`.

| # | Don't (block content in short) | Do (block content in short) | Rule | Source |
| --- | --- | --- | --- | --- |
| A1 | `const artist = await getArtist(u); const albums = await getAlbums(u)`: a waterfall | start both, then `await Promise.all([...])` | DF-4 | N1 |
| A2 | in a Server Component, `await fetch('http://localhost:3000/api/posts')` | `const posts = await getPosts()` from the DAL | DF-3 | N18 |
| A3 | the page calls `await verifySession()` and renders `<form action={async () => { 'use server'; await db.record.deleteMany() }}>`: the action has no check of its own | the action calls `const session = await verifySession()` plus a role/ownership check before `deleteMany` | DF-12 | N6 ("Authentication and authorization" example) |
| A4 | `try { await createPost(...); redirect('/posts') } catch { return { message: 'Failed' } }`: the `NEXT_REDIRECT` throw is caught, so the user never navigates | no `try`: `const post = await createPost(...)`, then `if (!post) return { message }`, then `revalidatePath('/posts')`, then `redirect('/posts')` last. The lead-in sentence says that when a `try`/`catch` is unavoidable (say, around a third-party SDK), `redirect(` still goes after the block | DF-17, DF-14 | N7, N2, N16 |
| A5 | `if (!parsed.success) throw new Error('Invalid')` and `return db.post.update(...)` (the raw row) | `return { fieldErrors: z.flattenError(parsed.error).fieldErrors }` and `return { ok: true }` | DF-14, DF-15 | N16, N6, Z2 |
| A6 | a Client Component `useEffect(() => { getPostsAction().then(setPosts) }, [])`: a Server Action used to fetch | the Server Component passes `getPosts()` as a promise, and the client calls `use(posts)` inside `<Suspense>` | DF-10, DF-8 | N3, N18, N1 |
| A7 | `revalidateTag('posts')` with one argument inside a Server Action (deprecated in 16, a TypeScript error) | `updateTag('posts')` in the Server Action, or `revalidateTag('posts', 'max')` when stale data is fine | DF-16 | N20, N11, N9 |
| A8 | Zod 3 snippet: `z.string({ invalid_type_error: '…' })` plus `parsed.error.flatten().fieldErrors` | Zod 4: `z.string({ error: '…' })` plus `z.flattenError(parsed.error).fieldErrors` | DF-13 | Z3, Z2 |

## 10. Version notes (Next.js 16): content for `## Version notes`

It must name **Next.js 16** (the major of the as-of line) and link nextjs.org. Items, each with its link:

- ★ `updateTag(tag)`, **new in 16**: a Server Actions-only API with read-your-writes semantics. N20 ("Caching APIs → updateTag"), N22.
- ★ `refresh()`, **new in 16**: a Server Actions-only API that refreshes the client router and leaves cached data alone. N20, N22.
- ★ `revalidateTag(tag, profile)` **now requires a second argument**. The single-argument form is deprecated and gives a
  TypeScript error. Use `'max'` for stale-while-revalidate, or `updateTag` in a Server Action for immediate expiry. N20, N11.
- ★ Synchronous `cookies()`, `headers()`, `draftMode()`, `params` and `searchParams` access is **removed** in 16; await them,
  including inside Server Actions. N20 ("Async Request APIs (Breaking change)").
- The App Router in 16 runs the React canary with **React 19.2** features. N20 ("React 19.2").
- 16.2: the dev server **logs each Server Function execution** (name, arguments, duration, file) in the terminal. N23.
- 16.3: **experimental** `experimental.useOffline` keeps a Server Action pending while the network is down and retries it
  on reconnect. Not for production. N24, N25.
- The v16 upgrade guide lists **no other change** for `'use server'`, `useActionState`, `useFormStatus`, `next/form`,
  `after` or the `serverActions` config. N20.
- Carried over from Next.js 15 and still current: `useActionState` replaces the deprecated `useFormState`; `useFormStatus` gained
  `data`/`method`/`action`; `fetch` requests are no longer cached by default. N21. `after` has been stable since v15.1.0. N12.

## 11. Review checklist (each `- [ ]` names its rule)

1. `- [ ]` No sequential `await` of independent requests; they start first and are awaited with `Promise.all` (DF-4).
2. `- [ ]` No Server Component `fetch`es its own Route Handler (DF-3).
3. `- [ ]` Non-`fetch` data functions are wrapped in React `cache` at module scope (DF-6). Preload helpers sit next to the component that consumes them (DF-7).
4. `- [ ]` Promises passed to Client Components are created on the server, typed `Promise<T>`, and read with `use(` under `<Suspense>` (DF-8).
5. `- [ ]` No Server Action is used to read data, and no client code runs actions through `Promise.all` (DF-10).
6. `- [ ]` Every `'use server'` function authenticates **and** authorizes the specific resource before writing (DF-12).
7. `- [ ]` Every action input (`FormData`, bound args, values) goes through a schema `safeParse` (DF-13, DF-19).
8. `- [ ]` Expected errors come back as typed state rather than thrown errors, and return values are DTOs (DF-14, DF-15).
9. `- [ ]` Each mutation invalidates in the action with the right API: `updateTag`, `revalidatePath`, `revalidateTag(tag, 'max')` or `refresh()` (DF-16).
10. `- [ ]` `redirect(` sits outside `try`/`catch`, after revalidation (DF-17).
11. `- [ ]` Forms use `action={…}`/`formAction` with a Server Action. GET search forms use `next/form` (DF-18).
12. `- [ ]` Pending UI uses `useActionState` `pending` or a child `useFormStatus` (DF-20), and the action signature is `(prevState, formData)` with typed, serializable state (DF-21).
13. `- [ ]` Event-handler calls go through `startTransition`, and post-`await` state updates are wrapped (DF-22). Optimistic setters are called inside the Action (DF-23).
14. `- [ ]` No mutation, cookie write or revalidation happens during render (DF-24). Post-response work uses `after(` (DF-25).
15. `- [ ]` Any `bodySizeLimit` change is justified, no secret is captured in an inline-action closure (DF-26, DF-27), and the UI offers a retry for "Failed to find Server Action" (DF-28).

## 12. Not confirmed by the docs: content for that section

Nothing here becomes a rule. Each item lists the URLs that were checked.

- **Whether a client-side wrapper function passed to `action=`** (for example one that calls an optimistic setter, then the
  Server Action) still submits before hydration. The pages document progressive enhancement only for a Server Action
  passed directly, `.bind(`-ed, or through `useActionState`. Checked: N2, N4, RF, R-SF.
- **Whether `.bind(` arguments are encrypted like closure variables.** N4 says only that a hidden-input value "will not be
  encoded", and N6 covers encryption for closures only. Checked: N4, N6, N3.
- **Exporting types or constants from a `'use server'` file.** No page covers it, so the examples keep schemas and types in
  a separate module. Checked: N5, R7.
- **Which Zod major the Next.js forms guide targets.** The page doesn't say, and its snippet uses Zod 3 APIs that zod.dev
  documents as dropped or deprecated in Zod 4. This file follows zod.dev. Checked: N4, Z3, Z2.

## 13. Sources (exact URLs; no `#fragment`s): also the AC9 evidence table

`evidence/sources-verified.md` = this table with columns `URL | Fetched | Backs (rule ids)`. The fetch date is
**2026-10-04 (fetched live this run)** in every row. `## Sources` in the topic file is the same URL list as bullets.

| Key | URL | Backs |
| --- | --- | --- |
| N1 | https://nextjs.org/docs/app/getting-started/fetching-data | DF-1, DF-2, DF-4, DF-5, DF-6, DF-7, DF-8, P1–P4, A1, A6 |
| N2 | https://nextjs.org/docs/app/getting-started/mutating-data | DF-10, DF-11, DF-12, DF-16, DF-17, DF-18, DF-22, DF-24, Scope, A4 |
| N3 | https://nextjs.org/docs/app/guides/server-actions | DF-10, DF-12, DF-13, DF-15, DF-16, DF-17, DF-22, DF-26, DF-27, DF-28, A6 |
| N4 | https://nextjs.org/docs/app/guides/forms | DF-13, DF-18, DF-19, DF-20, DF-21, DF-23, P5–P7 |
| N5 | https://nextjs.org/docs/app/api-reference/directives/use-server | DF-11, DF-12, DF-15 |
| N6 | https://nextjs.org/docs/app/guides/data-security | DF-2, DF-12, DF-15, DF-24, DF-27, P2, A3, A5 |
| N7 | https://nextjs.org/docs/app/api-reference/functions/redirect | DF-17, A4 |
| N8 | https://nextjs.org/docs/app/api-reference/functions/revalidatePath | DF-16 |
| N9 | https://nextjs.org/docs/app/api-reference/functions/updateTag | DF-16, P5, A7 |
| N10 | https://nextjs.org/docs/app/api-reference/functions/refresh | DF-16, P8 |
| N11 | https://nextjs.org/docs/app/api-reference/functions/revalidateTag | DF-16, A7, Version notes |
| N12 | https://nextjs.org/docs/app/api-reference/functions/after | DF-25, P9, Version notes |
| N13 | https://nextjs.org/docs/app/api-reference/components/form | DF-18, P10 |
| N14 | https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions | DF-26 |
| N15 | https://nextjs.org/docs/app/guides/client-side-data-fetching | DF-9 |
| N16 | https://nextjs.org/docs/app/getting-started/error-handling | DF-14, DF-21, A5 |
| N17 | https://nextjs.org/docs/app/guides/interactive-apps | DF-14, DF-22, DF-23, P8 |
| N18 | https://nextjs.org/docs/app/guides/backend-for-frontend | DF-3, DF-9, DF-10, A2, A6 |
| N19 | https://nextjs.org/docs/app/api-reference/functions/fetch | DF-6 |
| N20 | https://nextjs.org/docs/app/guides/upgrading/version-16 | DF-16, A7, Version notes |
| N21 | https://nextjs.org/docs/app/guides/upgrading/version-15 | Version notes |
| N22 | https://nextjs.org/blog/next-16 | Version notes |
| N23 | https://nextjs.org/blog/next-16-2 | Version notes |
| N24 | https://nextjs.org/blog/next-16-3 | Version notes |
| N25 | https://nextjs.org/docs/app/guides/offline-support | Version notes |
| N-AUTH | https://nextjs.org/docs/app/guides/authentication | DF-12, P5 (the `verifySession` and Zod 4 `{ error }` style) |
| V1 | https://vercel.com/docs/functions/functions-api-reference | DF-25 |
| R1 | https://react.dev/reference/react/useActionState | DF-14, DF-20, DF-21, DF-22 |
| R2 | https://react.dev/reference/react/useOptimistic | DF-23 |
| R3 | https://react.dev/reference/react-dom/hooks/useFormStatus | DF-20 |
| R4 | https://react.dev/reference/react/use | DF-8 |
| R5 | https://react.dev/reference/react/cache | DF-6 |
| R6 | https://react.dev/reference/react/useTransition | DF-22 |
| R7 | https://react.dev/reference/rsc/use-server | DF-10, DF-11, DF-13, DF-19 |
| R-SF | https://react.dev/reference/rsc/server-functions | DF-18, Not confirmed |
| RF | https://react.dev/reference/react-dom/components/form | DF-18, Not confirmed |
| Z1 | https://zod.dev/basics | DF-13 |
| Z2 | https://zod.dev/error-formatting | DF-13, A5, A8 |
| Z3 | https://zod.dev/v4/changelog | DF-13, A8 |

That is 39 URLs: 27 on nextjs.org or vercel.com (the contract needs ≥ 3), 9 on react.dev and 3 on zod.dev. All of these
hosts are in `ALLOWED_SOURCE_HOSTS`. Every URL that appears in prose must be in this list exactly. No other URL is
allowed outside code fences.

## Assumptions

1. **As-of version.** The skeleton's as-of line is expected to read `Next.js 16.3.8` (it matched both npm `latest` and the
   docs front matter on 2026-10-04). The coder copies the line from `R/nextjs.md` verbatim whatever it says. If its major
   isn't 16, the coder re-checks §10 against that major's upgrade guide before writing.
2. **Security overlap.** The orchestrator's notes put closures/encryption, `bodySizeLimit` and "every action is a public
   endpoint" in scope, while the story assigns their depth to `proxy-auth-and-security.md`. Resolution: one short DF rule
   each (DF-12, DF-26, DF-27), stated in mutation context and linking the SEC file. Ids stay unique because of the prefix.
3. **Helper names.** `verifySession` and `@/lib/dal/*` follow the auth guide's DAL. `verifySession()` redirects when the user
   is signed out, so it also sits outside any `try`. These are illustrative module paths, not APIs.
4. **Zod 4 over the Next.js forms snippet** (§6 risk row, §12). Facts about Zod come from zod.dev only.
5. **Default Don't/Do syntax** (§9) applies only if the skeleton contract leaves it unspecified. The coder records
   the syntax actually used in validation.md.
6. **No `#fragment` URLs**, so `source_urls`/`all_urls` comparisons can't break on normalisation.
7. **`PageProps<'/route'>`** appears in N5's snippet, but the examples use the explicit
   `{ params: Promise<{ … }> }` from N1 so they don't depend on generated types. `typescript.md` owns that helper.
8. **Research and reuse.** Nothing is hand-rolled. The test is stdlib (`re`) plus the shared helpers, and no npm or PyPI
   package applies to a Markdown reference.
