# Plan — nextjs-standard-entry-point-and-skill-wiring

Story: [story.md](story.md) · Run: `bmn-nextjs-typescript-best-practices-reference` · Role: walking
skeleton. Every one of the nine topic stories builds against the contract fixed in §7 below.
`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`.
`T` = `Skills/dev-bother-me-nope/assets/tests`.

**Pinned facts, read live on 2026-10-04:**

- Latest stable Next.js is **16.3.8**. `npm view next version` returns `16.3.8`: dist-tag
  `latest`, published 2026-09-30. Canary is `16.4.0-canary.59` and is not stable.
- https://nextjs.org/docs shows "Latest Version 16.3.8" in its sidebar.
- https://nextjs.org/blog/september-2026-security-release says "Updates are now available in
  v16.3.8 (Active LTS)".
- Every docs page fetched carries `version: 16.3.8` frontmatter.
- The as-of line is therefore `> As of Next.js 16.3.8, verified 2026-10-04.` and the major is
  `16`.

## 1. Approach

1. **No build skill is routed.** stack.md says the repo is Markdown and `nextjs-fullstack-standards`
   can't be loaded here. The guidance applied instead:
   - the repo's coding-style rules: small functions (≤ 50 lines), immutable module state
     (`frozenset`, `MappingProxyType`, tuples), stdlib only;
   - testing.md (TDD, AAA, descriptive names);
   - the conventions of `T/test_skill_text_rules.py`: whitespace-normalised text presence,
     section lookup by heading text so tests survive line shifts.
2. **The shared helper module comes first.** `T/nextjs_doc_helpers.py` is a frozen API (§7.4)
   that the nine topic coders import. It is TDD'd on inline sample text, so it is correct before
   any file depends on it.
3. **Then the entry point.** `R/nextjs.md` is rewritten in place from Jonathan's draft:
   - H1, then the as-of line;
   - seven H2 sections;
   - his tree kept verbatim in meaning, cleaned to box-drawing, with two `# added:` entries
     grounded in the docs.
4. **Then the nine stubs**, in the exact stub format (§7.3), so every generic contract test
   already runs. Stubs are skipped, with a reason, only where the contract covers content.
5. **Then the wiring.** Minimal, exact edits to `stack-routing.md`, `SKILL.md` and `briefs.md`
   (§2.2), plus the 1.6.0 → 1.7.0 bump and its pinned test.
6. **Grounding outranks everything.** Every Placement rule, Non-negotiable and Version note
   carries an allowed-host link or `(convention)`. Each URL is re-fetched live by the coder and
   recorded in `evidence/sources-verified.md`.

**Research and reuse.** I checked PyPI for a Markdown parser: `markdown-it-py` (CommonMark) and
`mistune`. I rejected both because AC1 requires stdlib only, and the gate command installs pytest
alone (`uv run --with pytest`). The parsing needed is line-based and small, so it is hand-rolled
within those limits.

## 2. Files

### 2.1 Create (15)

| File | Purpose |
| --- | --- |
| `T/nextjs_doc_helpers.py` | Shared, non-collected parsing helpers and contract constants (§7.4). Stdlib only, ≤ 50 lines per function, no mutable module state. |
| `T/test_nextjs_doc_helpers.py` | AC1 unit tests of every helper on inline sample text. |
| `T/test_nextjs_reference.py` | AC2–AC10: entry-point shape, tree, index, stubs, the generic topic contract, sources, as-of, hygiene and entry content. Topic stories rely on this file. |
| `T/test_nextjs_wiring.py` | AC11–AC14: `stack-routing.md`, `SKILL.md` and `briefs.md` wiring, and the `plugin.json` invariants. |
| `R/nextjs/typescript.md` | Stub, owned by `typescript-config-and-typing-patterns`. |
| `R/nextjs/routing-and-metadata.md` | Stub, owned by `app-router-routing-and-metadata`. |
| `R/nextjs/rendering-and-caching.md` | Stub, owned by `rendering-caching-and-streaming-ssr`. |
| `R/nextjs/data-fetching-and-mutations.md` | Stub, owned by `data-fetching-server-actions-and-forms`. |
| `R/nextjs/route-handlers-and-apis.md` | Stub, owned by `route-handlers-and-api-design`. |
| `R/nextjs/sse-and-streaming.md` | Stub, owned by `server-sent-events-and-streaming-responses`. |
| `R/nextjs/proxy-auth-and-security.md` | Stub, owned by `proxy-auth-and-security`. |
| `R/nextjs/performance-and-vercel.md` | Stub, owned by `performance-and-vercel-platform`. |
| `R/nextjs/testing-and-observability.md` | Stub, owned by `testing-errors-and-observability`. |
| `docs/sprints/bmn-nextjs-typescript-best-practices-reference/nextjs-standard-entry-point-and-skill-wiring/evidence/sources-verified.md` | AC15. One row per Sources URL of `nextjs.md` and the stubs: URL, fetched 2026-10-04, what it backs. |
| `docs/sprints/bmn-nextjs-typescript-best-practices-reference/nextjs-standard-entry-point-and-skill-wiring/validation.md` | AC15 one-off set-equality command and its output, AC16 gate results, and Assumptions. |

### 2.2 Change (6). Exact lines, from the run worktree at `62b7031`

1. **`R/nextjs.md`** (48-line draft, already committed by the intake): rewrite in place to §3. The
   H1 `NextJS Custom Skill` and the H1 `Folder Structure` are replaced. The tree is kept
   (§3.3).
2. **`R/stack-routing.md`**
   - **Lines 5–6** (intro). Change "…exactly the skills routed here — via
     `Skill({skill: "<name>"})` — **before** writing or judging code." to "…exactly the skills
     routed here — via `Skill({skill: "<name>"})` — and reads every reference file routed here,
     **before** writing or judging code."
   - **Line 34** (the `TypeScript / Next.js repo` row) becomes:
     ``| TypeScript / Next.js repo | Read `references/nextjs.md` and the topic files its index routes the story to; also `nextjs-fullstack-standards`, when the session has it (the python skills don't apply to `.ts`/`.tsx`) | `references/nextjs.md` (findings cite its rule ids); `nextjs-fullstack-standards` lens, when the session has it |``
   - **New paragraph after line 34** (blank line before and after; it goes ahead of the existing
     line 36, `python-library-quality:keeping-git-repos-clean`…): "Reference files such as
     `references/nextjs.md` are read with the Read tool, not loaded with `Skill(...)`. They ship
     inside this plugin, so they are always available. Workers get the absolute path
     `${CLAUDE_PLUGIN_ROOT}/skills/dev-bother-me-nope/references/nextjs.md`."
   - **Lines 39–40** ("If a routed skill isn't in the session's skill list, … never approximate a
     skill from memory.") stay **unchanged**.
3. **`skills/dev-bother-me-nope/SKILL.md`**
   - **Line 271–272**, "### 0 · INTAKE" step 3, after "It returns the stack classification and
     routing.". Insert "For a TypeScript / Next.js repo the routing also names
     [references/nextjs.md](references/nextjs.md), the plugin's dated Next.js + TypeScript
     standard. The planner, coder, reviewer and fixer read it with the Read tool
     ([references/stack-routing.md](references/stack-routing.md))." Then "Write `stack.md`, …"
     continues unchanged.
   - **Lines 403–405**, "### 6 · REVIEW①". Change "…that match it, and
     `nextjs-fullstack-standards` for TypeScript." to "…that match it, and for TypeScript
     `nextjs-fullstack-standards` (when the session has it) plus
     [references/nextjs.md](references/nextjs.md), each finding citing the rule id it breaks."
   - Frontmatter (lines 1–4) is untouched. Its `description` sha256 is
     `ff1c4ebd1232745ee8c4de5a117cc7ee74eb1036ec898fadd708d999a617697c`, pinned by a test.
4. **`R/briefs.md`.** Only these four code blocks change. `P` =
   `${CLAUDE_PLUGIN_ROOT}/skills/dev-bother-me-nope/references/nextjs.md`, written out literally.
   - **planner, line 125.** After "Load {routed_skills} first and follow them." add a new line:
     "TypeScript/Next.js story: also read P and the topic files its Topic index routes this story
     to; list every rule id you apply in the plan's Approach."
   - **coder, after line 149**, which reads "validate input at boundaries; explicit error
     handling." and ends the paragraph that starts "UI matches docs/sprints/{run}/design.md and
     design/*.html.". Add "TypeScript/Next.js story: follow the rule ids the plan lists from P and
     its topic files."
   - **reviewer, lines 173–174.** Keep "(add nextjs-fullstack-standards for any TypeScript in the
     diff)". After that sentence add "For TypeScript/Next.js code also read P and the topic files
     it routes the diff to; a finding that breaks one of its rules cites that rule id (e.g.
     SEC-3) in its summary." The return JSON shape is unchanged.
   - **fixer, before line 200** ("Run gates {gates}."). Add "For a TypeScript/Next.js finding,
     name in validation.md the rule id from P that the fix restores."
   - No other brief changes. Add no new "squash" wording, and no helper-script invocation, so
     `test_squash_is_only_ever_forbidden` and
     `test_every_helper_invocation_uses_the_plugin_root_form` stay green.
5. **`Skills/dev-bother-me-nope/.claude-plugin/plugin.json`.** Line 4 changes from
   `"version": "1.6.0"` to `"1.7.0"`. Nothing else changes: the keys stay
   `author, description, name, version`, and the description sha256 stays
   `bbda88acb08a513c0f17ac9243d946ce7c996af61abd86f248a7a903c7358860`.
6. **`T/test_skill_text_rules.py`.** Lines 185–187: rename
   `test_plugin_json_is_version_1_6_0` to `test_plugin_json_is_version_1_7_0` and assert
   `"1.7.0"`. Nothing else changes in this file. The docstring "for the 1.6.0 rules" stays,
   because it describes those rules, and `OWNED_MARKDOWN` stays as it is.

Topic content beyond the stubs, `marketplace.json`, `bmn-worker.md` and the deploy guard are
**not** touched (story, Out of scope).

## 3. Entry point `R/nextjs.md`, exact shape

### 3.1 Skeleton

```text
# Next.js + TypeScript standard

> As of Next.js 16.3.8, verified 2026-10-04.

<one-paragraph purpose: repo-owned, dated, read with the Read tool; entry point + index>

## How bmn agents use this
## Non-negotiables
## Folder structure
### Placement rules
## Topic index
## Authoring contract
## Version notes
## Sources
```

Target length is ≤ 300 lines; the cap is 800.

### 3.2 `## How bmn agents use this`

The test asserts these phrases after whitespace normalisation, case-insensitively, with `*`
stripped:

- "**Planner** reads `nextjs.md` plus the topic files the Topic index routes the story to" (it
  always includes `typescript.md` and `testing-and-observability.md`), "and **lists the rule
  ids** it applies in the plan";
- "**Coder** follows those rules";
- "**Reviewer** cites the violated rule id in each finding";
- "**Fixer** names the rule id its fix restores";
- precedence: "`nextjs.md` wins over `nextjs-fullstack-standards`" on a conflict (it is dated and
  verified live), and "an existing repo's established conventions win" for its layout;
- the path agents use: `${CLAUDE_PLUGIN_ROOT}/skills/dev-bother-me-nope/references/nextjs.md`.

### 3.3 `## Folder structure`

The section is one ```` ```text ```` fence containing exactly this tree. I generated it and
checked it against the AC3 line regex `^(?:│   |    )*(?:├── |└── )\S` and the spacer rule.

```text
my-app/
├── src/
│   ├── app/                          # NEXT.JS APP ROUTER (Routing Layer only)
│   │   ├── (auth)/                   # Route Group: Grouping without affecting URL
│   │   │   ├── login/
│   │   │   │   └── page.tsx          # Route page component
│   │   │   └── layout.tsx            # Auth-specific shared UI
│   │   ├── (dashboard)/
│   │   │   └── dashboard/
│   │   │       └── page.tsx
│   │   ├── api/                      # API Route Handlers (REST endpoints)
│   │   │   └── webhooks/
│   │   │       └── route.ts
│   │   ├── layout.tsx                # Global Root Layout
│   │   ├── page.tsx                  # Homepage
│   │   └── globals.css               # Global Tailwind/CSS rules
│   │
│   ├── features/                     # FEATURE MODULES (The core of your business logic)
│   │   ├── auth/                     # Isolated domain logic
│   │   │   ├── components/           # Feature-specific UI components
│   │   │   ├── hooks/                # Feature-specific hooks
│   │   │   ├── services/             # Feature API calls / logic
│   │   │   └── tests/                # Test files
│   │   └── billing/
│   │
│   ├── shared/                       # REUSABLE LAYER (Cross-feature code)
│   │   ├── components/               # Base UI primitives (Button, Input, Modal)
│   │   ├── hooks/                    # Global React hooks (useDebounce, useAuth)
│   │   ├── utils/                    # Pure utility functions (cn formatting)
│   │   ├── types/                    # Shared TypeScript definitions
│   │   └── tests/                    # Test files
│   │
│   ├── lib/                          # THIRD-PARTY CONFIGS / SERVER LAYER
│   │   ├── prisma.ts                 # Database client singletons
│   │   ├── actions/                  # Server Actions ("use server" files)
│   │   ├── auth.ts                   # Auth configurations (e.g., NextAuth/Auth.js)
│   │   └── tests/                    # Test files
│   │
│   ├── tests/                        # Tests for pages/routes/etc.
│   ├── instrumentation.ts            # added: OpenTelemetry and Instrumentation file
│   └── proxy.ts                      # added: Next.js request proxy, inside src/ when src/ is used
│
├── public/                           # Static assets (images, fonts, favicons)
├── next.config.ts                    # Next.js configurations
└── tsconfig.json                     # TypeScript configurations
```

- Every draft comment is verbatim except one typo fix: "Tests files" → "Test files".
- Draft order is preserved.
- Ambiguous nesting is resolved as the story says: `(dashboard)/dashboard/page.tsx`,
  `api/webhooks/route.ts`, and `src/tests/` sitting directly under `src/`.

**Cross-check against the docs (fetched 2026-10-04). No draft entry needed moving.**

- `src/` is optional, and `public/`, `next.config.*`, `tsconfig.json`, `package.json` and `.env*`
  stay at the root. Matches the draft
  (https://nextjs.org/docs/app/api-reference/file-conventions/src-folder).
- Route groups `(name)` are omitted from the URL. Matches the draft's comment
  (https://nextjs.org/docs/app/api-reference/file-conventions/route-groups).
- Colocation in `app/` is safe, because only `page`/`route` make a segment public. The draft keeps
  `app/` routing-only, which is the docs' "store project files outside of `app`" strategy
  (https://nextjs.org/docs/app/getting-started/project-structure). Private folders `_name` are
  documented there but not used by the draft, so the tree doesn't add them.
- `route.ts` can't share a segment with `page.tsx`. The draft's handlers under `app/api/` comply
  (https://nextjs.org/docs/app/getting-started/route-handlers).
- **Adjustment (added):** `proxy.ts` "inside `src` if applicable, so that it is located at the
  same level as `pages` or `app`"
  (https://nextjs.org/docs/app/api-reference/file-conventions/proxy). The src-folder page agrees:
  "If you're using Proxy, ensure it is placed inside the `src` folder."
- **Adjustment (added):** `instrumentation.ts` goes "in the **root** of your application or inside
  a `src` folder if using one"
  (https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation).
- Not added: `middleware.ts`, which is deprecated in 16. `next-env.d.ts` and `.env*` are not
  added either: the docs say they shouldn't be tracked by version control, and they aren't layout
  decisions.

### 3.4 `### Placement rules`

This is a numbered list after the tree. Every item has an allowed link or `(convention)`. Draft
items:

1. `src/` is optional. It separates application code from the configuration that stays at the
   project root: `public/`, `next.config.ts`, `tsconfig.json`, `package.json` and `.env*` files.
   ([src folder](https://nextjs.org/docs/app/api-reference/file-conventions/src-folder))
2. A folder under `app/` becomes a public route only when it has a `page` or `route` file, so
   colocated files are never routable. ([project structure](https://nextjs.org/docs/app/getting-started/project-structure))
3. A route group `(name)` organises routes without changing the URL. Routes in different groups
   must not resolve to the same URL path.
   ([route groups](https://nextjs.org/docs/app/api-reference/file-conventions/route-groups))
4. A `route.ts` can't share a route segment with a `page.tsx`
   ([route handlers](https://nextjs.org/docs/app/getting-started/route-handlers)). This layout
   keeps handlers under `app/api/` (convention).
5. With `src/`, `proxy.ts` sits inside `src/`, at the same level as `app/`.
   ([proxy.js](https://nextjs.org/docs/app/api-reference/file-conventions/proxy))
6. `instrumentation.ts` sits in the project root, or inside `src/` when one is used.
   ([instrumentation.js](https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation))
7. With `src/`, a TypeScript `@/*` path alias must include `src/` in `tsconfig.json` `paths`.
   ([src folder](https://nextjs.org/docs/app/api-reference/file-conventions/src-folder))
8. Next.js is unopinionated about organisation
   ([project structure](https://nextjs.org/docs/app/getting-started/project-structure)).
   `features/`, `shared/`, `lib/` and the `tests/` folders are this standard's choice
   (convention).
9. Domain logic lives in `features/<domain>/`. Code that two or more features use moves to
   `shared/`. Server-side setup (database clients, auth config, `"use server"` action files)
   lives in `lib/`. (convention)
10. This layout is canonical for **new** projects; an existing repo keeps its established layout.
    (convention)

The test asserts the phrases "canonical for new projects" and "an existing repo keeps its
established layout", with `*` stripped.

### 3.5 `## Topic index`

The columns are exactly `File | Prefix | Covers | Read when`. There is one row per `TOPICS`
entry, in order. The File cell is ``[`<file>`](nextjs/<file>)`` and the Prefix cell is
`` `<PREFIX>` ``. The Covers and Read when cells are fixed here, and topic stories don't edit
`nextjs.md`:

| File | Prefix | Covers | Read when |
| --- | --- | --- | --- |
| `typescript.md` | `TS` | tsconfig, typed `next.config.ts`, generated route types (`PageProps`, `LayoutProps`, `RouteContext`), env typing, boundary validation types | Always, for any `.ts`/`.tsx` change |
| `routing-and-metadata.md` | `RT` | File conventions, layouts, dynamic/parallel/intercepting routes, navigation, Metadata API, sitemap/robots/OG images | Adding or changing pages, layouts, URLs, links or SEO |
| `rendering-and-caching.md` | `RC` | Server vs Client Components, Cache Components and `'use cache'`, Suspense streaming, prerendering | Rendering data or changing what is cached |
| `data-fetching-and-mutations.md` | `DF` | Fetching in Server Components, Server Functions/Actions, forms, revalidation (`updateTag`, `revalidateTag`, `refresh`) | Reading or writing data, building forms |
| `route-handlers-and-apis.md` | `API` | `route.ts`, HTTP methods, request parsing and validation, error responses, webhooks, CORS | Building HTTP endpoints or webhooks |
| `sse-and-streaming.md` | `SSE` | Streaming responses and Server-Sent Events from Route Handlers, client `EventSource` | Live updates, LLM token streams, progress feeds |
| `proxy-auth-and-security.md` | `SEC` | `proxy.ts`, authentication and authorization, Server Function security, CSP, secrets and env exposure | Auth, sessions, protected routes, secrets, security headers |
| `performance-and-vercel.md` | `PERF` | `next/image`, `next/font`, `next/script`, bundling and Turbopack, runtimes, Vercel function config | Performance work, assets, deployment-platform config |
| `testing-and-observability.md` | `TEST` | Unit and E2E tests (Vitest, Playwright), error boundaries, `instrumentation.ts`/`onRequestError`, logging | Always, since every story ships tests; also error handling and monitoring |

### 3.6 `## Non-negotiables`

This section holds ≤ 15 numbered items. Each links ≥ 1 `nextjs/<file>` and carries an
allowed-host link or `(convention)`. Each candidate below was confirmed on a page fetched
2026-10-04, unless it is marked (convention). The coder re-verifies each and drops any that
don't hold up.

1. Await every request-time API: `params`, `searchParams`, `cookies()`, `headers()` and
   `draftMode()`. Synchronous access was removed in 16. Owners: routing-and-metadata,
   typescript. Source: https://nextjs.org/docs/app/guides/upgrading/version-16
2. Intercept requests in `proxy.ts` (exporting `proxy`) and never add a new `middleware.ts`. Proxy
   runs on Node.js. Owner: proxy-auth-and-security. Source:
   https://nextjs.org/docs/app/api-reference/file-conventions/proxy
3. Check authentication and authorization inside every Server Function, and don't rely on Proxy
   alone. Owners: proxy-auth-and-security, data-fetching-and-mutations. Source: the proxy page,
   "Execution order" Good to know.
4. Never put `route.ts` in the same segment as `page.tsx`. Owner: route-handlers-and-apis.
   Source: https://nextjs.org/docs/app/getting-started/route-handlers
5. Give every parallel-route slot a `default.tsx`. Owner: routing-and-metadata. Source: the
   upgrade guide.
6. Call `revalidateTag(tag, profile)` with a `cacheLife` profile, and use `updateTag` in a Server
   Action for read-your-writes. Owners: data-fetching-and-mutations, rendering-and-caching.
   Source: the upgrade guide.
7. Type pages, layouts and handlers with the generated `PageProps`, `LayoutProps` and
   `RouteContext`. Owner: typescript. Sources: the upgrade guide;
   https://nextjs.org/docs/app/api-reference/file-conventions/route
8. Only `NEXT_PUBLIC_` variables reach the browser; keep secrets server-side. Owner:
   proxy-auth-and-security. Source: the upgrade guide, Runtime Configuration. The coder also
   checks https://nextjs.org/docs/app/guides/environment-variables.
9. Lint with ESLint or Biome directly, because `next build` no longer lints. Owner:
   testing-and-observability. Source: the upgrade guide.
10. Report server errors through `instrumentation.ts` `onRequestError`. Owner:
    testing-and-observability. Source: the instrumentation page.
11. Use `images.remotePatterns`, never the deprecated `images.domains`. Owner:
    performance-and-vercel. Source: the upgrade guide.
12. Stream long responses from a Route Handler as a Web `ReadableStream`. Owner:
    sse-and-streaming. Source: the route.js page, Streaming.
13. Make caching an explicit, opt-in decision with Cache Components (`'use cache'`). Owner:
    rendering-and-caching. Source: https://nextjs.org/blog/next-16, Cache Components ("entirely
    opt-in").
14. Validate every untrusted input at the boundary before use. Owners: typescript,
    route-handlers-and-apis. (convention)

### 3.7 `## Version notes`

This section must contain `Next.js 16`. It is a list; each item has an allowed link **and** a
`nextjs/<file>` link. All candidates were confirmed 2026-10-04:

| Change | Owner | Source |
| --- | --- | --- |
| `proxy.ts` replaces `middleware.ts`; Proxy runs on Node.js | proxy-auth-and-security | https://nextjs.org/blog/next-16 |
| Synchronous request-API access removed | routing-and-metadata | https://nextjs.org/docs/app/guides/upgrading/version-16 |
| Cache Components (`cacheComponents`, `'use cache'`) replace `experimental.ppr`/`dynamicIO` | rendering-and-caching | blog next-16 |
| `revalidateTag` needs a profile; new `updateTag` and `refresh` | data-fetching-and-mutations | blog next-16 |
| Turbopack is the default for `next dev` and `next build` | performance-and-vercel | upgrade guide |
| Node.js 20.9+ and TypeScript 5.1+ minimums; `next typegen` route-type helpers | typescript | upgrade guide |
| `next lint` removed | testing-and-observability | upgrade guide |
| Parallel-route slots require `default.js` | routing-and-metadata | upgrade guide |
| `next/image` defaults (`minimumCacheTTL` 4 h, `qualities` `[75]`, local IP blocked, ≤ 3 redirects) | performance-and-vercel | upgrade guide |
| 16.3: root params (`next/root-params`), `catchError` boundaries, opt-in Instant Navigations (`partialPrefetching`), TypeScript 7 for type checking | routing-and-metadata / testing-and-observability / rendering-and-caching / typescript | https://nextjs.org/blog/next-16-3 |

### 3.8 `## Authoring contract`

This states §7.1–§7.3 in prose. The test asserts these phrases, normalised:

- every `TOPIC_SECTIONS` name;
- `` `N. **<PREFIX>-<n>**` ``;
- `(convention)`;
- "at least 12 rules", "at least 4", "at least 3", "at least 8", "800 lines";
- `Stub: pending story`;
- each `ALLOWED_SOURCE_HOSTS` entry;
- "only nextjs.org or vercel.com";
- "Not confirmed by the docs";
- `### Don't`;
- `- [ ]`.

No `TODO`/`TBD` text may appear anywhere: the hygiene test bans those tokens even as examples.

### 3.9 `## Sources`

This is a bullet list, one `https://` URL per bullet (an optional ` — note` may follow). It holds
every URL used in prose, plus `VERSION_SOURCE_URL` and `https://nextjs.org/docs` (the version
picker). Expect ~13 URLs, all nextjs.org.

## 4. Test plan (written first)

Everything here is `[unit]`, offline and stdlib-plus-pytest. There is no browser surface (stack:
`ui: false`), so there are no Playwright tests. **Assumption:** the story says tests live in
`test_nextjs_reference.py` "unless stated". This plan states two more files: the helper unit tests
and the wiring tests. That keeps every file ≤ 800 lines and cohesive, and
`test_nextjs_reference.py` remains the contract file topic stories rely on.

### AC1 Helpers module: `T/test_nextjs_doc_helpers.py` (33 tests)

The inline samples are module constants:

- `STUB` (marker line);
- `TOPIC`: well-formed, with H1, as-of, all sections, 2 rules (one linked, one
  `(convention)`), a ```` ```ts ```` and a ```` ```json ```` block, an `### Don't` item and
  Sources;
- `UNCITED_RULE`;
- `BARE_FENCE`;
- `BAD_HOST` (a `https://example.org` link in prose).

`test_paths_point_at_the_reference_tree` · `test_topics_match_the_story_table_in_order` ·
`test_topics_mapping_is_read_only` · `test_allowed_source_hosts_are_exactly_the_ten_hosts` ·
`test_version_constants` · `test_read_returns_utf8_text` ·
`test_is_stub_detects_the_marker_line` · `test_is_stub_ignores_a_marker_inside_a_code_fence` ·
`test_stub_slug_returns_the_owning_slug` ·
`test_section_returns_body_up_to_the_next_same_level_heading` ·
`test_section_prefix_match_finds_a_heading_by_its_start` ·
`test_section_ignores_headings_inside_fences` · `test_section_raises_for_a_missing_heading` ·
`test_headings_lists_titles_by_level_outside_fences` ·
`test_code_blocks_returns_lang_and_body_pairs` ·
`test_code_blocks_reports_a_bare_fence_with_an_empty_lang` (also `bare_fence_lines`) ·
`test_has_block_with_needs_every_needle_in_one_block` (needles split across blocks → False;
exact, case-sensitive) · `test_has_block_with_respects_langs` (json) ·
`test_rule_items_parse_id_and_text_with_continuations` ·
`test_rule_items_keep_a_malformed_item_with_an_empty_id` ·
`test_cites_source_accepts_an_allowed_link_or_the_convention_tag` ·
`test_cites_source_rejects_an_uncited_rule_and_a_disallowed_host` ·
`test_source_urls_lists_bullets_in_order_without_fragments` ·
`test_malformed_source_lines_flags_prose_and_multi_url_bullets` ·
`test_all_urls_skip_code_fences_and_inline_code` (`https://example.com` in code is exempt) ·
`test_url_host_flags_a_disallowed_host` ·
`test_as_of_version_parses_the_line_right_after_h1` ·
`test_as_of_version_is_none_when_anything_sits_between` ·
`test_missing_terms_is_case_insensitive_over_the_whole_file` ·
`test_relative_links_strip_anchors_and_skip_absolute_urls` ·
`test_table_rows_skip_the_separator_row` · `test_anti_patterns_pair_dont_headings_with_bodies` ·
`test_helpers_module_is_stdlib_only_small_and_immutable`. That last one parses the module's AST:
imports ⊆ `{"__future__", "re", "types", "typing", "urllib", "pathlib"}`, every `def` is ≤ 50
lines, and no module-level list/dict/set literal or `list()`/`dict()`/`set()` call.

### AC2–AC10 Entry point and contract: `T/test_nextjs_reference.py` (41 test functions)

`ALL_FILES = (NEXTJS_MD, *topic_paths())` is the 10-file parametrisation. The topic
parametrisation is `TOPICS` (9), with ids equal to the file names.

| AC | Tests |
| --- | --- |
| 2 | `test_entry_point_h1_is_the_standard_title` · `test_entry_point_as_of_line_directly_follows_h1` (equals `as_of_line_for(NEXTJS_VERSION)`) · `test_entry_point_h2_sections_in_order` (`headings(text, 2) == ENTRY_SECTIONS`) |
| 3 | `test_folder_tree_is_one_text_fence` · `test_folder_tree_keeps_every_draft_entry_at_its_path` (39 full paths in `DRAFT_PATHS`, built from indentation depth) · `test_folder_tree_keeps_draft_order` (subsequence) · `test_folder_tree_keeps_draft_comments` (`DRAFT_COMMENTS`: path → draft keywords, case-insensitive) · `test_folder_tree_uses_box_drawing_lines_only` (regex + spacer rule + no ASCII `\|`) · `test_folder_tree_comments_use_space_hash_space` · `test_folder_tree_additions_are_marked_and_sourced` (`ADDED_SOURCES = {"src/proxy.ts": proxy URL, "src/instrumentation.ts": instrumentation URL}`; every non-draft path has `# added:` and its URL in Sources) · `test_placement_rules_follow_the_tree_and_cite_or_tag` · `test_placement_rules_scope_the_layout_to_new_projects` |
| 4 | `test_topic_index_columns` · `test_topic_index_rows_match_topics_in_order` · `test_topic_index_links_point_into_nextjs_dir` · `test_every_topic_file_on_disk_has_an_index_row` · `test_every_indexed_topic_file_exists` |
| 5 | `test_stubs_have_h1_as_of_marker_and_version_source` (loops over the files that are stubs now; no skip) · `test_stub_marker_names_the_owning_story` (all 9: `stub_slug(text) in (None, TOPICS[name][1])`) |
| 6 | Parametrised over `TOPICS`. Each calls `pytest.skip(f"{name} is a stub pending {slug}")` when `is_stub`, and **only** then: `test_topic_sections_follow_the_contract` · `test_topic_rules_are_well_formed_and_numbered` (format, own prefix, ids 1..N gapless, first word ∉ `SUBJECT_WORDS`) · `test_topic_rules_cite_a_source_or_convention` · `test_topic_meets_the_floors` · `test_topic_cites_only_its_own_rule_ids` · `test_topic_version_notes_name_the_major` · `test_topic_not_confirmed_section_lists_urls_and_no_rules`. Not parametrised: `test_rule_ids_are_unique_across_topic_files` · `test_authoring_contract_states_the_contract` |
| 7 | Over `ALL_FILES`: `test_sources_is_a_bullet_list_of_unique_https_urls` · `test_every_url_host_is_allowed` (prose and Sources) · `test_every_prose_url_is_listed_in_sources` · `test_primary_source_floor` (requirement 3 for `nextjs.md` and non-stubs, 0 for stubs; no skip) |
| 8 | Over `TOPICS`: `test_topic_as_of_matches_the_entry_point` (version equals `nextjs.md`'s; line equals `as_of_line_for(version)`, so the date is `AS_OF_DATE`) |
| 9 | Over `ALL_FILES`: `test_file_is_at_most_800_lines` · `test_no_bare_code_fences` · `test_relative_links_resolve` (relative to the file's dir, anchor dropped) · `test_no_todo_or_tbd` |
| 10 | `test_non_negotiables_are_few_linked_and_cited` · `test_how_agents_use_this_covers_every_agent` · `test_how_agents_use_this_states_precedence` · `test_entry_version_notes_cite_and_point_to_topics` |

At merge, all nine topics are stubs, so exactly **63** cases skip (7 × 9), each with the reason
`"<file> is a stub pending <slug>"`. Validation runs with `-rs` and checks that every skip reason
matches that pattern.

### AC11–AC14 Wiring: `T/test_nextjs_wiring.py` (12 test functions) plus one rename

| AC | Tests |
| --- | --- |
| 11 | `test_stack_routing_typescript_row_names_the_reference_in_both_cells` (the row is split on `\|`; cells 2 and 3 each contain `references/nextjs.md`) · `test_stack_routing_keeps_fullstack_standards_when_available` (both cells contain `nextjs-fullstack-standards` and "when the session has it") · `test_stack_routing_says_references_are_read_not_loaded` (section `Route` contains "read with the Read tool" and "not loaded with `Skill(...)`") · `test_stack_routing_never_approximate_sentence_unchanged` (the exact normalised sentence) |
| 12 | `test_skill_intake_links_the_nextjs_reference` (`section(skill, "0 · INTAKE", prefix=True)`) · `test_skill_review1_links_the_reference_next_to_fullstack_standards` (the same normalised sentence holds both) · `test_skill_frontmatter_description_unchanged` (sha256 pin) |
| 13 | `test_brief_reads_the_nextjs_reference_for_typescript` [planner, coder, reviewer, fixer] (the block contains `P` and "TypeScript/Next.js") · `test_planner_and_reviewer_briefs_ask_for_rule_ids` [planner, reviewer] · `test_reviewer_brief_keeps_fullstack_standards` · `test_other_briefs_do_not_mention_the_reference` (stack-scout, designer, splitter, integrator, merger, cleaner, db-sync and tester lack `nextjs.md`). The existing `test_squash_is_only_ever_forbidden` and `test_every_helper_invocation_uses_the_plugin_root_form` must stay green. |
| 14 | `T/test_skill_text_rules.py::test_plugin_json_is_version_1_7_0` (renamed) · `test_plugin_json_only_the_version_moved` (keys, name, author, description sha256) |

### AC15 Grounding evidence (not pytest)

`evidence/sources-verified.md` is a table, `| URL | Fetched | Backs |`, with one row per URL. The
coder re-fetches each URL with WebFetch on 2026-10-04. The version row names both the docs
sidebar ("Latest Version 16.3.8") and the security-release post. URLs appear only in the table.
The one-off command below is recorded with its output in `validation.md`:

```bash
cd /Users/jonathanstevenson/Source/claude-skills-nextjs-typescript-best-practices-reference && uv run --quiet python - <<'EOF'
import sys
from pathlib import Path
sys.path.insert(0, "Skills/dev-bother-me-nope/assets/tests")
import nextjs_doc_helpers as h
files = [h.NEXTJS_MD, *(p for p in h.topic_paths() if h.is_stub(h.read(p)))]
cited = {u for p in files for u in h.source_urls(h.read(p))}
ev = Path("docs/sprints/bmn-nextjs-typescript-best-practices-reference/nextjs-standard-entry-point-and-skill-wiring/evidence/sources-verified.md")
listed = {h.normalize_url(u) for u in h.URL_RE.findall(h.read(ev))}
print("only cited:", sorted(cited - listed)); print("only listed:", sorted(listed - cited))
sys.exit(cited != listed)
EOF
```

### AC16 Gates

The full suite and ruff run as listed in §6.

**Totals:** 86 new test functions plus 1 renamed, making 87. About 200 collected cases after
parametrisation, with 63 skipped at merge.

## 5. Data, config, deploy

- **Data:** none. No models, no migrations, no Supabase, no RLS.
- **Env vars:** none.
- **deploy_pending:** `[]`. The change is Markdown and tests inside the plugin. Nothing deploys,
  and plugin users pick up 1.7.0 through the local marketplace update after the change lands on
  `dev`/`main`.

## 6. Risks and gates

1. **The helper API is a cross-story contract.** Nine coders import it in parallel, so the API in
   §7.4 is frozen. A defect a topic coder finds goes into their `validation.md` Assumptions for
   REVIEW①. They don't edit the module.
2. **Import path.** `T/` has no `__init__.py`. Under pytest's default `prepend` import mode the
   test dir is put on `sys.path` (`conftest.py` already lives there), so
   `import nextjs_doc_helpers` works. The first RED run confirms it.
3. **Paraphrase risk in grounding.** WebFetch summarises. The coder quotes only what the page
   states, and anything unconfirmed is dropped or tagged `(convention)`. The 16.3 and 16.0 facts
   above were read from the full page text.
4. **Version drift.** 16.3.8 is pinned in `NEXTJS_VERSION`. A future refresh changes one constant
   plus the ten as-of lines.
5. **Shared checkout.** Jonathan's main checkout is never touched (stack.md, assumption 6). Commits
   happen only in the coder's worktree on `wip/nextjs-typescript-best-practices-reference/nextjs-standard-entry-point-and-skill-wiring`,
   with `git branch --show-current` in the same command.
6. **Existing tests.** The `SKILL.md` INTAKE step 5 item and the policy tests are untouched,
   because the edit is in step 3. Every brief edit avoids "squash" and helper-script calls.

**Gate commands:**

- `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`
  (full suite, ~476 existing tests plus the new ones).
- `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests/test_nextjs_doc_helpers.py Skills/dev-bother-me-nope/assets/tests/test_nextjs_reference.py Skills/dev-bother-me-nope/assets/tests/test_nextjs_wiring.py -q -rs`
  (skip reasons: 63, all stubs).
- `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope`.
- The AC15 one-off command (§4).
- TDD order: write the helper tests and watch them fail RED (ImportError), then write the helpers
  until GREEN. Next, write the reference and wiring tests and watch them fail RED (draft shape,
  missing stubs, wiring, version). Then write the content until GREEN, and refactor.

## 7. The contract topic coders build against (frozen)

### 7.1 Topic file shape

The first non-blank line is the H1 `# <Topic title>`. The next non-blank line is
`> As of Next.js 16.3.8, verified 2026-10-04.`, with nothing between them. Then come these H2
sections, **in order**:

1. `Scope`
2. `Rules`
3. `Patterns`
4. `Anti-patterns`
5. `Version notes`
6. `Review checklist`
7. *(optional)* `Not confirmed by the docs`
8. `Sources` (last)

No other H2s are allowed. H3s are free inside sections.

- **Rules:** a numbered list. Each item is `N. **<PREFIX>-<n>** <Imperative sentence> …` and
  contains either an allowed-host URL or the literal `(convention)`.
  - `<PREFIX>` is the file's own.
  - `n` runs 1..N with no gaps, in order.
  - The first word after the id is not one of `The This It You We There A An`.
  - Continuation lines are indented. Nothing but list items belongs in `## Rules`, because text
    after the last item is folded into it.
- **Rule ids in prose:** the only ids written are the file's own. Point to another topic with a
  relative link, e.g. `[routing-and-metadata.md](routing-and-metadata.md)`.
- **Floors:**
  - ≥ 12 rules;
  - ≥ 4 fences tagged `ts` or `tsx` (file-wide);
  - `## Anti-patterns` holds ≥ 3 `### Don't …` H3s, each with ≥ 1 fenced block in its body;
  - `## Review checklist` holds ≥ 8 `- [ ]` lines.
- **Version notes:** contains `Next.js 16`.
- **Not confirmed by the docs** (if present): every list item contains ≥ 1 URL (the page
  checked), and the section contains no `**<PREFIX>-<n>**` rule id.
- **Hygiene:**
  - ≤ 800 lines;
  - every fence opener has a language tag (`ts`, `tsx`, `json`, `bash`, `text`, `http`, …);
  - every relative link resolves (the anchor is ignored);
  - no `TODO`/`TBD` anywhere.

### 7.2 Sources and hosts

`## Sources` is a bullet list: one `https://` URL per bullet, optionally followed by text, and no
duplicates once fragments are dropped. Every URL in prose must be listed there. Prose means
everything outside fences and inline code, so placeholder URLs belong in code.

`ALLOWED_SOURCE_HOSTS` is exactly: `nextjs.org`, `vercel.com`, `react.dev`,
`typescriptlang.org`, `www.typescriptlang.org`, `developer.mozilla.org`,
`html.spec.whatwg.org`, `zod.dev`, `vitest.dev` and `playwright.dev`.

At least 3 Sources URLs must be on `nextjs.org` or `vercel.com`. Only those two hosts may back a
Next.js or Vercel behaviour claim. The other hosts back the React, TypeScript, web-platform or
library facts they own.

### 7.3 Stub format and detection

```text
# <Topic title>

> As of Next.js 16.3.8, verified 2026-10-04.

> Stub: pending story `<owning slug>`.

## Sources

- https://nextjs.org/blog/september-2026-security-release
```

`is_stub(text)` is true when some line **outside fences** matches
`^> Stub: pending story `(?P<slug>[a-z0-9-]+)`\.$`. A topic story replaces the whole file, and
its own `test_nextjs_topic_<x>.py` asserts `not is_stub(text)`.

The stub H1s are:

| File | Stub H1 |
| --- | --- |
| `typescript.md` | `TypeScript in Next.js` |
| `routing-and-metadata.md` | `Routing and metadata` |
| `rendering-and-caching.md` | `Rendering, caching and streaming SSR` |
| `data-fetching-and-mutations.md` | `Data fetching, Server Actions and forms` |
| `route-handlers-and-apis.md` | `Route Handlers and API design` |
| `sse-and-streaming.md` | `Server-Sent Events and streaming responses` |
| `proxy-auth-and-security.md` | `Proxy, auth and security` |
| `performance-and-vercel.md` | `Performance and the Vercel platform` |
| `testing-and-observability.md` | `Testing, errors and observability` |

Topic stories may retitle their H1.

### 7.4 `T/nextjs_doc_helpers.py` API (frozen)

The module docstring says it is non-collected, stdlib only, and imported by
`test_nextjs_*.py`. All return values are immutable (tuples, frozensets, str or None), except
`missing_terms`, which returns a `list` as the story specifies.

**Constants**

| Name | Value |
| --- | --- |
| `PLUGIN` | `Path(__file__).resolve().parents[2]` |
| `REFERENCES_DIR` | `PLUGIN / "skills" / "dev-bother-me-nope" / "references"` |
| `NEXTJS_MD` | `REFERENCES_DIR / "nextjs.md"` |
| `TOPICS_DIR` | `REFERENCES_DIR / "nextjs"` |
| `TOPICS` | `MappingProxyType` file → `(prefix, owning slug)`, in story-table order, exactly the nine rows |
| `ALLOWED_SOURCE_HOSTS` | `frozenset` of the ten hosts in §7.2 |
| `PRIMARY_SOURCE_HOSTS` | `frozenset({"nextjs.org", "vercel.com"})` |
| `AS_OF_DATE` | `"2026-10-04"` |
| `NEXTJS_VERSION` | `"16.3.8"` |
| `VERSION_SOURCE_URL` | `"https://nextjs.org/blog/september-2026-security-release"` |
| `ENTRY_TITLE` | `"Next.js + TypeScript standard"` |
| `ENTRY_SECTIONS` | `("How bmn agents use this", "Non-negotiables", "Folder structure", "Topic index", "Authoring contract", "Version notes", "Sources")` |
| `TOPIC_SECTIONS` | `("Scope", "Rules", "Patterns", "Anti-patterns", "Version notes", "Review checklist", "Not confirmed by the docs", "Sources")` |
| `OPTIONAL_TOPIC_SECTION` | `"Not confirmed by the docs"` |
| `SUBJECT_WORDS` | `frozenset({"The", "This", "It", "You", "We", "There", "A", "An"})` |
| `CONVENTION_TAG` | `"(convention)"` |
| `MAX_LINES` | `800` |
| `MIN_RULES` | `12` |
| `MIN_TS_FENCES` | `4` |
| `MIN_ANTI_PATTERNS` | `3` |
| `MIN_CHECKLIST_ITEMS` | `8` |
| `MIN_PRIMARY_SOURCES` | `3` |
| `MAX_NON_NEGOTIABLES` | `15` |
| `URL_RE` | No capture groups. `https?://`, then a run of characters excluding whitespace, `<`, `>`, `(`, `)`, `[`, `]`, `"`, `'`, the backtick and the pipe. Callers strip trailing `.,;:!?` through `normalize_url`. |
| `AS_OF_RE` | `^> As of Next\.js (?P<version>\d+\.\d+\.\d+), verified (?P<date>\d{4}-\d{2}-\d{2})\.$` |
| `STUB_RE` | As in §7.3. |
| `RULE_RE` | ``^\*\*(?P<id>(?P<prefix>[A-Z]+)-(?P<n>\d+))\*\*\s+(?P<body>.+)`` (applied to the item text after `N. `) |
| `RULE_ID_RE` | `\b(?:TS\|RT\|RC\|DF\|API\|SSE\|SEC\|PERF\|TEST)-\d+\b`, built from `TOPICS` prefixes |

**Functions.** Each is ≤ 50 lines, pure, and takes `text: str` unless noted.

| Signature | Behaviour |
| --- | --- |
| `read(path: Path) -> str` | UTF-8 text. |
| `topic_paths() -> tuple[Path, ...]` | `TOPICS_DIR / name` in `TOPICS` order. |
| `as_of_line_for(version: str) -> str` | `f"> As of Next.js {version}, verified {AS_OF_DATE}."` |
| `stub_marker_for(slug: str) -> str` | ``f"> Stub: pending story `{slug}`."`` |
| `is_stub(text) -> bool` | A `STUB_RE` line outside fences. |
| `stub_slug(text) -> str \| None` | The slug from that line. |
| `h1(text) -> str \| None` | The title if the first non-blank line is `# Title`. |
| `as_of_line(text) -> str \| None` | The first non-blank line after the H1 line. |
| `as_of_version(text) -> str \| None` | `AS_OF_RE` on `as_of_line`, giving `version`. |
| `major(version: str) -> str` | `"16.3.8"` → `"16"`. |
| `headings(text, level: int) -> tuple[str, ...]` | Titles of `#`×level headings outside fences, in order. |
| `section(text, heading: str, *, prefix: bool = False) -> str` | Body of the first heading whose title equals `heading` (or starts with it when `prefix`), up to the next heading of the same or a higher level. Headings in fences are ignored. Raises `LookupError` when absent. |
| `code_blocks(text, langs: tuple[str, ...] \| None = None) -> tuple[tuple[str, str], ...]` | `(lang, body)` for each fence. `lang` is the first token of the info string, or `""` for a bare fence. `langs=None` returns all fences. An opener is a line whose left-stripped text starts with ```` ``` ````; it closes on a left-stripped line made only of an equal or longer backtick run. |
| `bare_fence_lines(text) -> tuple[int, ...]` | 1-based line numbers of openers with no language. |
| `has_block_with(text, *needles, langs=("ts", "tsx")) -> bool` | True when one block of those langs contains every needle (exact substring). |
| `prose(text) -> str` | Text with fenced blocks and inline code spans removed. |
| `normalize_url(url: str) -> str` | Strips trailing `.,;:!?` and the `#fragment`. |
| `url_host(url: str) -> str` | `urlsplit(url).hostname or ""`. |
| `all_urls(text) -> tuple[str, ...]` | Normalised `URL_RE` matches in `prose(text)`. |
| `source_urls(text) -> tuple[str, ...]` | The normalised URL of each bullet in `## Sources`, in order, duplicates kept so tests can detect them. |
| `malformed_source_lines(text) -> tuple[str, ...]` | Non-blank `## Sources` lines that are not `- ` bullets, or do not hold exactly one `https://` URL. |
| `numbered_items(section_text: str) -> tuple[str, ...]` | Items starting `^\d+\. ` at column 0. Each runs until the next item or the end, joined and stripped. |
| `bullet_items(section_text: str) -> tuple[str, ...]` | The same for `- ` items, `- [ ]` included. |
| `rule_items(text) -> tuple[tuple[str, str], ...]` | `(rule_id, item_text)` for every numbered item in `## Rules`, with `rule_id` set to `""` when `RULE_RE` doesn't match. |
| `rule_ids_cited(text) -> tuple[str, ...]` | `RULE_ID_RE` matches in `prose(text)`. |
| `cites_source(item_text: str) -> bool` | Contains `CONVENTION_TAG` or a URL whose host is in `ALLOWED_SOURCE_HOSTS`. |
| `anti_patterns(text) -> tuple[tuple[str, str], ...]` | `(title, body)` for each `### Don't…` H3 inside `## Anti-patterns`. |
| `checklist_items(text) -> tuple[str, ...]` | The `- [ ] ` lines in `## Review checklist`. |
| `table_rows(section_text: str) -> tuple[tuple[str, ...], ...]` | Pipe-table rows, header first, separator skipped, cells stripped. |
| `relative_links(text) -> tuple[str, ...]` | Prose `](target)` targets with no scheme and no leading `#`, with the `#anchor` dropped. |
| `missing_terms(text, terms) -> list[str]` | Terms not found as a case-insensitive substring anywhere in `text` (code included), in the input order. |

## 8. Assumptions

1. The version source for the stubs is the security-release blog post, not the docs sidebar,
   because the post is a permanent record that names `v16.3.8`. `nextjs.md` cites both.
2. Only two `# added:` entries (`src/instrumentation.ts`, `src/proxy.ts`) are made. Both are
   confirmed by their file-convention pages and appear under `src/`, as the docs require when
   `src/` is used.
3. Helper unit tests and wiring tests get their own files (§4). Every file stays ≤ 800 lines, and
   the contract tests stay in `test_nextjs_reference.py`, which is what topic stories name.
4. The plan adds constants and helpers beyond the story's "at least" list (`NEXTJS_VERSION`,
   `VERSION_SOURCE_URL`, section and floor constants, `stub_slug`, `anti_patterns`,
   `table_rows`, …). That way topic tests and the contract tests share one definition.
5. Anti-patterns use `### Don't …` H3 headings, not list items, so "each with a fenced block" is
   unambiguous to parse.
6. The `stack-routing.md` intro gets a one-clause edit ("and reads every reference file routed
   here"), so it stays accurate for the TypeScript row. The "never approximate" sentence is
   untouched.
7. "No other brief changes" is enforced by a test: the eight other briefs don't mention
   `nextjs.md`. The four edited blocks gain only the lines in §2.2.
8. Frontmatter immutability is pinned by sha256 of the `SKILL.md` description and the
   `plugin.json` description. The hashes were computed from the run worktree at `62b7031`.
