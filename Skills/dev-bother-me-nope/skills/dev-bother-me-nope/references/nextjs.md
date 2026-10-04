# Next.js + TypeScript standard

> As of Next.js 16.3.8, verified 2026-10-04.

The repo-owned, dated standard for Next.js + TypeScript work in dev-bother-me-nope. It is read
with the Read tool, so it is always available. This file is the entry point: how each agent uses
the standard, the non-negotiable rules, the canonical folder layout for new projects, and an index
that routes a story to the deep-topic files in [nextjs/](nextjs/). Rules carry ids such as
`SEC-3` so plans, reviews and fixes can cite them.

## How bmn agents use this

The path agents read is
`${CLAUDE_PLUGIN_ROOT}/skills/dev-bother-me-nope/references/nextjs.md`. Topic files sit beside it
in `nextjs/`.

- **Planner** reads `nextjs.md` plus the topic files the Topic index routes the story to (it
  always includes `typescript.md` and `testing-and-observability.md`), and **lists the rule ids**
  it applies in the plan.
- **Coder** follows those rules.
- **Reviewer** cites the violated rule id in each finding.
- **Fixer** names the rule id its fix restores.

Precedence on a conflict: `nextjs.md` wins over `nextjs-fullstack-standards`, because it is dated
and verified live against nextjs.org and vercel.com. For layout, an existing repo's established
conventions win over the tree below.

## Non-negotiables

These hold for every Next.js + TypeScript story. Each links the topic file that owns the detail
and carries its source, or `(convention)` for a house rule.

1. Await every request-time API: `params`, `searchParams`, `cookies()`, `headers()` and
   `draftMode()`. Synchronous access was removed in Next.js 16.
   ([routing-and-metadata.md](nextjs/routing-and-metadata.md),
   [typescript.md](nextjs/typescript.md);
   [upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16))
2. Intercept requests in `proxy.ts`, exporting `proxy`. Never add a `middleware.ts`: the
   convention is deprecated and renamed to Proxy. Proxy runs on Node.js and its runtime can't be
   configured, so keep an existing `middleware.ts` only while it depends on the Edge runtime,
   and plan its move to `proxy.ts` with the `middleware-to-proxy` codemod.
   ([proxy-auth-and-security.md](nextjs/proxy-auth-and-security.md);
   [proxy.js](https://nextjs.org/docs/app/api-reference/file-conventions/proxy);
   [upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16))
3. Check authentication and authorization inside every Server Function. Don't rely on Proxy
   alone, because a matcher change can silently remove its coverage.
   ([proxy-auth-and-security.md](nextjs/proxy-auth-and-security.md),
   [data-fetching-and-mutations.md](nextjs/data-fetching-and-mutations.md);
   [proxy.js, Execution order](https://nextjs.org/docs/app/api-reference/file-conventions/proxy))
4. Never put a `route.ts` in the same route segment as a `page.tsx`.
   ([route-handlers-and-apis.md](nextjs/route-handlers-and-apis.md);
   [Route Handlers](https://nextjs.org/docs/app/getting-started/route-handlers))
5. Give every parallel-route slot a `default.tsx`; builds fail without one.
   ([routing-and-metadata.md](nextjs/routing-and-metadata.md);
   [upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16))
6. Call `revalidateTag(tag, profile)` with a `cacheLife` profile, and use `updateTag` in a Server
   Action when the user must see their own write at once.
   ([data-fetching-and-mutations.md](nextjs/data-fetching-and-mutations.md),
   [rendering-and-caching.md](nextjs/rendering-and-caching.md);
   [upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16))
7. Type pages, layouts and Route Handler context with the global `PageProps`, `LayoutProps` and
   `RouteContext` helpers, which `next dev`, `next build` and `next typegen` generate.
   ([typescript.md](nextjs/typescript.md);
   [route.js](https://nextjs.org/docs/app/api-reference/file-conventions/route))
8. Only `NEXT_PUBLIC_` variables reach the browser, and they are inlined at build time. Keep
   secrets in server-only variables.
   ([proxy-auth-and-security.md](nextjs/proxy-auth-and-security.md);
   [environment variables](https://nextjs.org/docs/app/guides/environment-variables))
9. Lint outside `next build`, which no longer lints and has no `next lint` to call: a new project
   lints with the ESLint CLI and `eslint-config-next`, a repo that already uses Biome keeps
   Biome, and the gate runs the repo's configured linter (`eslint .` or `biome check .`).
   ([typescript.md](nextjs/typescript.md),
   [testing-and-observability.md](nextjs/testing-and-observability.md);
   [ESLint](https://nextjs.org/docs/app/api-reference/config/eslint);
   [upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16)) (convention)
10. Report server errors to your observability provider from `onRequestError` in
    `instrumentation.ts`.
    ([testing-and-observability.md](nextjs/testing-and-observability.md);
    [instrumentation.js](https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation))
11. Allow remote images with `images.remotePatterns`, not the deprecated `images.domains`.
    ([performance-and-vercel.md](nextjs/performance-and-vercel.md);
    [upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16))
12. Stream a long Route Handler response by passing a Web `ReadableStream` to `new Response(...)`.
    ([sse-and-streaming.md](nextjs/sse-and-streaming.md);
    [route.js, Streaming](https://nextjs.org/docs/app/api-reference/file-conventions/route))
13. Make caching an explicit, opt-in decision: with Cache Components, nothing is cached until you
    add `'use cache'`.
    ([rendering-and-caching.md](nextjs/rendering-and-caching.md);
    [Next.js 16](https://nextjs.org/blog/next-16))
14. Validate every untrusted input at the boundary before use.
    ([typescript.md](nextjs/typescript.md),
    [route-handlers-and-apis.md](nextjs/route-handlers-and-apis.md)) (convention)

## Folder structure

When creating a new Next.js project, use this layout.

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

### Placement rules

1. `src/` is optional. It separates application code from the configuration that stays at the
   project root: `public/`, `next.config.ts`, `tsconfig.json`, `package.json` and `.env*` files.
   ([src folder](https://nextjs.org/docs/app/api-reference/file-conventions/src-folder))
2. A folder under `app/` becomes a public route only when it has a `page` or `route` file, so
   colocated files are never routable.
   ([project structure](https://nextjs.org/docs/app/getting-started/project-structure))
3. A route group `(name)` organises routes without changing the URL. Routes in different groups
   should not resolve to the same URL path.
   ([route groups](https://nextjs.org/docs/app/api-reference/file-conventions/route-groups))
4. A `route.ts` can't share a route segment with a `page.tsx`
   ([route handlers](https://nextjs.org/docs/app/getting-started/route-handlers)). This layout
   keeps handlers under `app/api/` (convention).
5. With `src/`, `proxy.ts` sits inside `src/`, at the same level as `app/`.
   ([proxy.js](https://nextjs.org/docs/app/api-reference/file-conventions/proxy))
6. `instrumentation.ts` sits in the project root, or inside `src/` when one is used.
   ([instrumentation.js](https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation))
7. With `src/`, a TypeScript `@/*` path alias must include `src/` in the `tsconfig.json` `paths`.
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

## Topic index

Read the topic files this table routes the story to. The Prefix is the rule-id prefix the file
uses.

| File | Prefix | Covers | Read when |
| --- | --- | --- | --- |
| [`typescript.md`](nextjs/typescript.md) | `TS` | tsconfig, typed `next.config.ts`, generated route types (`PageProps`, `LayoutProps`, `RouteContext`), env typing, boundary validation types | Always, for any `.ts`/`.tsx` change |
| [`routing-and-metadata.md`](nextjs/routing-and-metadata.md) | `RT` | File conventions, layouts, dynamic/parallel/intercepting routes, navigation, Metadata API, sitemap/robots/OG images | Adding or changing pages, layouts, URLs, links or SEO |
| [`rendering-and-caching.md`](nextjs/rendering-and-caching.md) | `RC` | Server vs Client Components, Cache Components and `'use cache'`, Suspense streaming, prerendering | Rendering data or changing what is cached |
| [`data-fetching-and-mutations.md`](nextjs/data-fetching-and-mutations.md) | `DF` | Fetching in Server Components, Server Functions/Actions, forms, revalidation (`updateTag`, `revalidateTag`, `refresh`) | Reading or writing data, building forms |
| [`route-handlers-and-apis.md`](nextjs/route-handlers-and-apis.md) | `API` | `route.ts`, HTTP methods, request parsing and validation, error responses, webhooks, CORS | Building HTTP endpoints or webhooks |
| [`sse-and-streaming.md`](nextjs/sse-and-streaming.md) | `SSE` | Streaming responses and Server-Sent Events from Route Handlers, client `EventSource` | Live updates, LLM token streams, progress feeds |
| [`proxy-auth-and-security.md`](nextjs/proxy-auth-and-security.md) | `SEC` | `proxy.ts`, authentication and authorization, Server Function security, CSP, secrets and env exposure | Auth, sessions, protected routes, secrets, security headers |
| [`performance-and-vercel.md`](nextjs/performance-and-vercel.md) | `PERF` | `next/image`, `next/font`, `next/script`, bundling and Turbopack, runtimes, Vercel function config | Performance work, assets, deployment-platform config |
| [`testing-and-observability.md`](nextjs/testing-and-observability.md) | `TEST` | Unit and E2E tests (Vitest, Playwright), error boundaries, `instrumentation.ts`/`onRequestError`, logging | Always, since every story ships tests; also error handling and monitoring |

## Authoring contract

Every topic file follows this contract, and the generic tests in `test_nextjs_reference.py`
enforce it for each file that is no longer a stub.

**Shape.** The first non-blank line is the H1. The next non-blank line is the as-of line,
`> As of Next.js <version>, verified <date>.`, with nothing between them. Then come these H2
sections, in order, and no others: `Scope`, `Rules`, `Patterns`, `Anti-patterns`,
`Version notes`, `Review checklist`, an optional `Not confirmed by the docs`, and `Sources` last.
H3s are free inside a section.

**Rules.** A numbered list. Each item is `N. **<PREFIX>-<n>** <Imperative sentence> …`.

- `<PREFIX>` is the file's own, from the Topic index. `n` runs 1..N with no gaps, in order.
- The first word after the id is not a subject word (`The`, `This`, `It`, `You`, `We`, `There`,
  `A`, `An`).
- Continuation lines are indented. Nothing but list items belongs under `## Rules`.
- Every rule contains a link to an allowed source host, or the literal tag `(convention)`.
- A file writes only its own rule ids. It points to another topic by linking its file.

**Floors.** At least 12 rules. At least 4 fenced blocks tagged `ts` or `tsx`. `## Anti-patterns`
holds at least 3 `### Don't …` headings, each with at least 1 fenced block. `## Review checklist`
holds at least 8 `- [ ]` items.

**Version notes.** `## Version notes` names `Next.js <major>`, where `<major>` comes from the
as-of version.

**Not confirmed by the docs.** The optional section lists what was checked and not confirmed.
Each item gives the URL that was checked. Nothing in it is stated as a rule.

**Sources.** `## Sources` is a bullet list: one `https://` URL per bullet, optionally followed by
a note, with no duplicates once fragments are dropped. Every URL in prose is listed there. Prose
means everything outside fenced code and inline code, so placeholder URLs belong in code. The
allowed hosts are `nextjs.org`, `vercel.com`, `react.dev`, `typescriptlang.org`,
`www.typescriptlang.org`, `developer.mozilla.org`, `html.spec.whatwg.org`, `zod.dev`,
`vitest.dev` and `playwright.dev`. At least 3 sources are on `nextjs.org` or `vercel.com`. Only
nextjs.org or vercel.com may back a Next.js or Vercel behaviour claim. The other hosts back the
React, TypeScript, web-platform or library facts they own.

**Hygiene.** At most 800 lines per file. Every fence opener carries a language tag. Every relative
link resolves. Anything a doc doesn't confirm is left out, or listed in the optional section.

**Stubs.** A topic that is not written yet is a stub: the H1, the as-of line, the marker line
`` > Stub: pending story `<owning-slug>`. ``, and a `## Sources` section. The owning story
replaces the whole file.

## Version notes

Headline changes of Next.js 16, up to 16.3. Each links its source and the topic file that owns
the detail.

- `proxy.ts` replaces `middleware.ts`, and Proxy runs on the Node.js runtime
  ([Next.js 16](https://nextjs.org/blog/next-16);
  [proxy-auth-and-security.md](nextjs/proxy-auth-and-security.md)).
- Synchronous access to `params`, `searchParams`, `cookies()`, `headers()` and `draftMode()` is
  removed ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16);
  [routing-and-metadata.md](nextjs/routing-and-metadata.md)).
- Cache Components (`cacheComponents`, `'use cache'`) replace `experimental.ppr`,
  `experimental.dynamicIO` and `experimental.useCache`
  ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16);
  [rendering-and-caching.md](nextjs/rendering-and-caching.md)).
- `revalidateTag` needs a `cacheLife` profile, and `updateTag` and `refresh` are new
  ([Next.js 16](https://nextjs.org/blog/next-16);
  [data-fetching-and-mutations.md](nextjs/data-fetching-and-mutations.md)).
- Turbopack is the default bundler for `next dev` and `next build`
  ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16);
  [performance-and-vercel.md](nextjs/performance-and-vercel.md)).
- Node.js 20.9 and TypeScript 5.1 are the minimums, and `next typegen` generates route type
  helpers ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16);
  [typescript.md](nextjs/typescript.md)).
- `next lint` is removed and `next build` no longer lints
  ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16);
  [testing-and-observability.md](nextjs/testing-and-observability.md)).
- Parallel-route slots require `default.js`
  ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16);
  [routing-and-metadata.md](nextjs/routing-and-metadata.md)).
- `next/image` defaults changed: `minimumCacheTTL` is 4 hours, `qualities` is `[75]`, local IPs
  are blocked and at most 3 redirects are followed; `images.domains` is deprecated
  ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16);
  [performance-and-vercel.md](nextjs/performance-and-vercel.md)).
- 16.3 adds root params through `next/root-params`
  ([Next.js 16.3](https://nextjs.org/blog/next-16-3);
  [routing-and-metadata.md](nextjs/routing-and-metadata.md)).
- 16.3 adds `catchError` custom error boundaries
  ([Next.js 16.3](https://nextjs.org/blog/next-16-3);
  [testing-and-observability.md](nextjs/testing-and-observability.md)).
- 16.3 adds opt-in Instant Navigations behind `cacheComponents` and `partialPrefetching`
  ([Next.js 16.3](https://nextjs.org/blog/next-16-3);
  [rendering-and-caching.md](nextjs/rendering-and-caching.md)).
- 16.3 lets `next build` use TypeScript 7 for type checking
  ([Next.js 16.3](https://nextjs.org/blog/next-16-3); [typescript.md](nextjs/typescript.md)).

## Sources

- https://nextjs.org/docs — the docs version picker shows "Latest Version 16.3.8"
- https://nextjs.org/blog/september-2026-security-release — names v16.3.8 as Active LTS
- https://nextjs.org/blog/next-16 — Next.js 16 release post
- https://nextjs.org/blog/next-16-3 — Next.js 16.3 release post
- https://nextjs.org/docs/app/guides/upgrading/version-16 — upgrade guide to version 16
- https://nextjs.org/docs/app/getting-started/project-structure — project structure and organization
- https://nextjs.org/docs/app/api-reference/file-conventions/src-folder — the `src` folder
- https://nextjs.org/docs/app/api-reference/file-conventions/route-groups — route groups
- https://nextjs.org/docs/app/getting-started/route-handlers — Route Handlers
- https://nextjs.org/docs/app/api-reference/file-conventions/route — `route.js` reference
- https://nextjs.org/docs/app/api-reference/file-conventions/proxy — `proxy.js` reference
- https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation — `instrumentation.js` reference
- https://nextjs.org/docs/app/guides/environment-variables — environment variables
- https://nextjs.org/docs/app/api-reference/config/eslint — ESLint plugin and `eslint-config-next`
