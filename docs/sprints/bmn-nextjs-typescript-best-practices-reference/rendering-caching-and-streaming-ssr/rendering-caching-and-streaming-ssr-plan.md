# Plan — rendering-caching-and-streaming-ssr

Story: [story.md](story.md). Owns `R/nextjs/rendering-and-caching.md` (prefix `RC`) and
`Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_rendering_and_caching.py`.
`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`.
Research done live on 2026-10-04 by the planner; the coder writes from this plan and must not
add a claim, URL or snippet that is not in the Verified rule sheet below.

## 1. Approach

1. No build skill is routed (stack.md: Markdown content); the rules come from the docs, not from a skill. Current stable is **Next.js 16.3.8** (npm `latest` = 16.3.8; `https://nextjs.org/docs/llms.txt` reads "Reference and guides for Next.js 16.3.8"; every fetched page's front matter says `version: 16.3.8`).
2. Every page was fetched as Markdown (`curl -H 'Accept: text/markdown'` on the canonical URL), so rules and snippets below are checked against page text, not summaries.
3. The topic file is organised around the **caching model** first (RC-1): the 16.x docs split every caching page into "with Cache Components" and "Caching and Revalidating (Previous Model)". Each rule carries a model label.
4. Order inside `## Rules`: model detection and config → Server/Client boundary → request-time APIs → Cache Components caching → previous-model caching → revalidation → streaming SSR → memoization/waterfalls → Cache Components behaviour changes.
5. `## Patterns` holds three tables (rendering strategies per model, previous-model → Cache Components migration map, the post-write invalidation decision table) plus short typed examples copied from or reduced from doc examples.
6. Scope split follows the story, not the broader orchestrator note: parallel fetching, `Promise.all`, preload and `React.cache` *usage* belong to `data-fetching-and-mutations.md`; this file states only memoization-vs-caching semantics and the streaming-side waterfall rule, and links that file (Assumption A1).
7. The topic test uses only `nextjs_doc_helpers` functions plus two tiny local parsers (Markdown tables, anti-pattern pairs), stdlib only.

## 2. Files

| File | Action | Purpose |
| --- | --- | --- |
| `R/nextjs/rendering-and-caching.md` | replace stub entirely | The RC topic file (≤ 800 lines, target ≤ 760) |
| `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_rendering_and_caching.py` | create | Topic-specific tests (AC2–AC8) |
| `docs/sprints/bmn-nextjs-typescript-best-practices-reference/rendering-caching-and-streaming-ssr/evidence/sources-verified.md` | create | AC9: every Sources URL, fetch date 2026-10-04, rule ids it backs |
| `docs/sprints/bmn-nextjs-typescript-best-practices-reference/rendering-caching-and-streaming-ssr/validation.md` | created at validation | AC9 one-off URL-set check, AC10 scope/gates, any shared-file defect found |

Nothing else changes (AC10). Shared files (`nextjs.md`, `nextjs_doc_helpers.py`, `test_nextjs_reference.py`, wiring) are read-only for this story.

## 3. Test plan (written first)

All in `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_rendering_and_caching.py`, type **unit** (pytest, offline, stdlib + helpers). Import with `from nextjs_doc_helpers import (...)` — the tests dir has no `__init__.py`, so pytest's default rootdir import puts it on `sys.path`; mirror whatever `test_nextjs_reference.py` does if it differs. Read the file once in a module-scoped fixture `topic_text` (`read(TOPICS_DIR / "rendering-and-caching.md")`). Check each helper's exact signature in the merged `nextjs_doc_helpers.py` before use (e.g. whether `section()` takes `"Rules"` or `"## Rules"`).

| AC | Test (function name) | Asserts |
| --- | --- | --- |
| 1 | (generic) `test_nextjs_reference.py`, all parametrised checks for `rendering-and-caching.md` | as-of match, section order, rule format + citations, floors, Sources hosts/uniqueness, prose URLs ⊆ Sources, ≤ 800 lines, tagged fences, relative links resolve, no TODO/TBD — run with `-rs` and confirm **no skip** for this file |
| 1 | `test_rendering_topic_uses_only_rc_rule_ids` | every id from `rule_items(text)` starts with `RC-`; a whole-file regex `\*\*([A-Z]+)-\d+\*\*` finds only `RC` |
| 2 | `test_rendering_topic_is_not_a_stub` | `is_stub(text) is False` |
| 2 | `test_rendering_topic_has_at_least_18_rc_rules` | `len(rule_items(text)) >= 18` |
| 3 | `test_rendering_topic_names_every_required_concept` | `missing_terms(text, TERMS) == []` with TERMS exactly: `'use client'`, `Server Component`, `Client Component`, `children`, `serializable`, `'use cache'`, `cacheComponents`, `cacheLife`, `cacheTag`, `revalidateTag`, `updateTag`, `revalidatePath`, `refresh`, `Partial Prerendering`, `<Suspense`, `loading.tsx`, `connection()`, `cookies()`, `headers()`, `searchParams`, `streaming`, `provider` |
| 4 | `test_rendering_topic_has_required_example` parametrised over 5 cases, ids `enable-cache-components`, `cached-with-lifetime`, `tagged-cache`, `suspense-streaming`, `client-wrapper-children` | `has_block_with(text, *needles)` for (`NextConfig`, `cacheComponents`), (`'use cache'`, `cacheLife(`), (`cacheTag(`), (`<Suspense`, `fallback`), (`'use client'`, `children`) |
| 4 | `test_rendering_topic_examples_have_no_any` | no `ts`/`tsx` block body matches `r":\s*any\b|<any>|as any\b"` |
| 5 | `test_rules_section_labels_the_caching_model` | `section(text, "Rules")` contains `cacheComponents` and (`without` or `previous model`, case-insensitive) |
| 6 | `test_patterns_has_revalidation_decision_table` | some Markdown table in `section(text, "Patterns")` (contiguous lines starting `|` with a `|---` separator row) contains `revalidateTag`, `updateTag`, `revalidatePath` and `refresh` |
| 7 | `test_version_notes_name_the_major_and_link_nextjs` | `section(text, "Version notes")` is non-empty, contains `f"Next.js {major}"` where `major = as_of_version(text).split(".")[0]`, and contains `https://nextjs.org/` |
| 8 | `test_every_review_checklist_item_names_an_existing_rc_rule` | every line starting `- [ ]` in `section(text, "Review checklist")` contains `RC-\d+`, and every id it names exists in `rule_items(text)` |
| 8 | `test_every_anti_pattern_pairs_dont_with_do` | in `section(text, "Anti-patterns")`: ≥ 3 Don't markers; each Don't marker is followed by a fenced block, then a Do marker, then a fenced block, before the next Don't (parser keyed on the marker format the contract defines; default `**Don't:**` / `**Do:**`) |
| 9 | one-off (validation.md, not pytest) | URL set of `## Sources` == URL set of `evidence/sources-verified.md` (command in §6) |
| 10 | one-off (validation.md) | `git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD` lists only the owned paths; full suite + ruff clean |

Count: 11 test functions, 15 collected test cases (the example test is parametrised ×5). TDD order: write the test file first against the stub → run → every topic test fails (stub) → write the topic file → green.

No browser criteria (no UI; stack.md `ui: false`), so no Playwright tests.

## 4. Data

None. No models, migrations, Supabase or RLS (stack.md: `supabase: false`).

## 5. Config / env vars and deploy_pending

None. No env vars, no Vercel or Supabase work. `deploy_pending: []`.

## 6. Risks and gate commands

Risks:
- **Helper/contract shapes are fixed by the parallel skeleton plan.** Before writing, read `R/nextjs.md` `## Authoring contract`, `nextjs_doc_helpers.py` and `test_nextjs_reference.py` on the merged branch and match: the stub's H1 (keep it verbatim), the as-of line (copy verbatim from `R/nextjs.md`), the Sources bullet format, the Don't/Do marker format, `section()` heading matching. If the as-of major in `R/nextjs.md` is not `16`, stop and record it in validation.md: every rule here is 16-specific.
- **Line cap.** Target ≤ 760 lines. If over, shorten AP9/AP10 (keep AP1–AP8), never drop rules.
- **Prose URL ⊆ Sources.** Use page URLs with **no `#fragment`** anywhere in links; name the section in words instead (Assumption A3). Every URL used must be one of the 46 in §8.
- **Rule parsing.** One physical line per rule, no H3 inside `## Rules`, the citation link on that same line (Assumption A4).
- **Version-specific APIs.** `io()` exists only from 16.3.0; RC-17 tells the reader to check the installed version and use `connection()` below 16.3.
- **Docs drift.** Pages are dated `lastUpdated` 2026-06 to 2026-09; the file pins "as of 16.3.8, verified 2026-10-04".

Gates (run from the run worktree):

```bash
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_rendering_and_caching.py -q
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests/test_nextjs_reference.py -q -rs   # confirm no SKIPPED line names rendering-and-caching.md
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q
uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope
wc -l Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/rendering-and-caching.md   # <= 800
git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD
# AC9 one-off (record output in validation.md):
python3 - <<'EOF'
import re, pathlib
t = pathlib.Path("Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/rendering-and-caching.md").read_text()
src = t.split("\n## Sources", 1)[1]
e = pathlib.Path("docs/sprints/bmn-nextjs-typescript-best-practices-reference/rendering-caching-and-streaming-ssr/evidence/sources-verified.md").read_text()
url = re.compile(r"https://[^\s)>\]|`]+")
a, b = set(url.findall(src)), set(url.findall(e))
print("equal:", a == b, "| only in file:", sorted(a - b), "| only in evidence:", sorted(b - a))
EOF
```

## 7. Topic file blueprint (`R/nextjs/rendering-and-caching.md`)

Section order (contract): H1 (stub's H1 verbatim) → as-of line (verbatim from `R/nextjs.md`) → `## Scope` → `## Rules` → `## Patterns` → `## Anti-patterns` → `## Version notes` → `## Review checklist` → `## Not confirmed by the docs` → `## Sources`.

### `## Scope` (≈ 12 lines)

- Covers: Server/Client Component boundary and client bundle size; rendering strategies (prerendered/static shell, dynamic/request-time, ISR, Partial Prerendering); Cache Components (`'use cache'`, `cacheLife`, `cacheTag`, private/remote variants); request-time APIs; the previous caching model; invalidation semantics (`revalidateTag`, `updateTag`, `revalidatePath`, `refresh`); streaming HTML with `<Suspense>` and `loading.tsx`; the HTTP status contract.
- Not here (link, don't repeat): fetching patterns, `Promise.all`, preload, `React.cache` usage, Server Action/form wiring → [data-fetching-and-mutations.md](data-fetching-and-mutations.md); streaming *responses* (SSE, `ReadableStream`) → [sse-and-streaming.md](sse-and-streaming.md); `generateStaticParams`, metadata → [routing-and-metadata.md](routing-and-metadata.md); Route Handler design → [route-handlers-and-apis.md](route-handlers-and-apis.md); auth, data exposure, Proxy → [proxy-auth-and-security.md](proxy-auth-and-security.md); Core Web Vitals and Vercel platform → [performance-and-vercel.md](performance-and-vercel.md). Entry point: [../nextjs.md](../nextjs.md).
- Legend: each rule ends with its model label — *(Cache Components)* = `cacheComponents: true` in `next.config`; *(previous model)* = without it; *(both models)*.

### `## Rules`

Write each rule as **one line**: `N. **RC-N** <imperative sentence(s)> <model label> ([page title](URL))`. Text is from the sheet in §8 — tighten wording, never add facts. 47 rules (≥ 18 required).

### `## Patterns` (≈ 210 lines)

1. **Detect the caching model** — one `bash` block: `grep -nE "cacheComponents\s*:\s*true" next.config.* 2>/dev/null` plus one sentence: a hit means Cache Components; no hit means the previous model (RC-1).
2. **Rendering strategies table** (rows from §8 RC-1, RC-14, RC-15, RC-19, RC-31; ISR/App Shell; sources: glossary, caching, caching-without-cache-components, ISR guides):

   | Strategy | Previous model | Cache Components |
   | --- | --- | --- |
   | Prerendered (static) | Default when the route uses no request-time API and no uncached-at-build data; `fetch` with no `cache` option runs once at `next build` | Predictable work, `'use cache'` results and `<Suspense>` fallbacks become the static shell |
   | Dynamic (request time) | Any `cookies()`/`headers()`/`searchParams` read, `cache: 'no-store'`, `revalidate = 0`, `dynamic = 'force-dynamic'`, `connection()` | Everything not cached; must sit under `<Suspense>` |
   | ISR | `export const revalidate = n` or `fetch` `next.revalidate` + `generateStaticParams` | `cacheLife` revalidate + `generateStaticParams`; unknown params served the App Shell (with `partialPrefetching`) then upgraded |
   | Partial Prerendering | Not available (the experimental flag was removed in 16) | Default: static shell + streamed dynamic holes in one response |

3. **Enable Cache Components** — Example A.
4. **Cache data and UI** — Example B (data-level) and Example C (static + cached + streaming page).
5. **Pass runtime values into a cache** — Example F.
6. **Push dynamic access down** — Example G.
7. **Non-deterministic values** — Example H.
8. **Server/Client composition** — Example D (client wrapper + server page) and Example E (provider).
9. **Invalidate after a write** — the decision table below, then Example I (Server Action) and Example J (webhook Route Handler).

   | API | Call from | What it does to the cache | What the user sees | Use when |
   | --- | --- | --- | --- | --- |
   | `updateTag(tag)` | Server Actions only (throws elsewhere) | Expires the tag immediately; next read waits for fresh data | The action's response carries the re-rendered current route with fresh data (one roundtrip) | Read-your-own-writes: forms, settings |
   | `revalidateTag(tag, 'max')` | Server Actions and Route Handlers | Marks the tag stale (stale-while-revalidate); `{ expire: 0 }` expires it immediately | No re-render in the action response; stale content until a later request finishes revalidating | Content where a short delay is fine; webhooks |
   | `revalidatePath(path, type?)` | Server Functions and Route Handlers | Invalidates cached data for that route path (via path soft tags) | Server Function: UI updates immediately on that path (currently also refreshes previously visited pages on next visit, documented as temporary). Route Handler: on the next visit | One route affected and tagging is overkill |
   | `refresh()` | Server Actions only (throws elsewhere) | Invalidates nothing; refetches the current route's RSC Payload | The current route re-rendered in the same roundtrip; cached parts unchanged | The action changed uncached data shown on the page |

   Follow with one sentence: calling any of these from a Server Action clears the whole client router cache, bypassing `stale` ([cacheLife](https://nextjs.org/docs/app/api-reference/functions/cacheLife)).
10. **Return a real 404** — Example K.
11. **Previous model** — Example L, then the migration map table (source: migrating-to-cache-components):

    | Previous model | Under Cache Components |
    | --- | --- |
    | `dynamic = 'force-dynamic'` | Remove (dynamic is the default) |
    | `dynamic = 'force-static'` | Remove; `'use cache'` + `cacheLife('max')` near the data |
    | `revalidate = n` | `'use cache'` + `cacheLife(profile)` |
    | `fetchCache` | Remove; fetches inside `'use cache'` are cached |
    | `fetch(url, { cache: 'force-cache', next: { revalidate, tags } })` | `'use cache'` function + `cacheLife` + `cacheTag` |
    | `unstable_cache(fn, keys, { tags, revalidate })` | `'use cache'` function + `cacheLife` + `cacheTag` |
    | `unstable_noStore()` | Remove; `connection()` + `<Suspense>` if it must run per request |
    | `dynamicParams = false` | Delete; call `notFound()` for unknown params |
    | `generateStaticParams` returning `[]` | Return at least one param |
    | `experimental_ppr` / `experimental.ppr` | Remove; `cacheComponents: true` |
    | `runtime = 'edge'` | Remove (Node.js runtime required) |

### Examples (each ≤ 30 lines, typed, no `any`; app helpers such as `db`, `auth`, `getProfile` are placeholders named in a comment)

**Example A** — `ts` (verbatim, cacheComponents/caching pages):

```ts
// next.config.ts
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  cacheComponents: true,
}

export default nextConfig
```

**Example B** — `ts` (caching, revalidating, cacheTag, use-cache pages):

```ts
// app/lib/products.ts
import { cacheLife, cacheTag } from 'next/cache'
import { db } from '@/lib/db' // your data layer

export type Product = { id: string; name: string }

export async function getProducts(): Promise<Product[]> {
  'use cache'
  cacheLife('hours')
  cacheTag('products')
  return db.products.findMany()
}

export async function getProduct(id: string): Promise<Product | null> {
  'use cache'
  cacheLife('days')
  cacheTag('products', `product-${id}`) // id is also part of the cache key
  return db.products.findUnique({ where: { id } })
}
```

**Example C** — `tsx` (caching page, "Static, cached, and streaming"):

```tsx
// app/shop/page.tsx
import { Suspense } from 'react'
import { cookies } from 'next/headers'
import { cacheLife } from 'next/cache'
import { getProducts } from '@/app/lib/products'

export default function ShopPage() {
  return (
    <>
      <h1>Shop</h1> {/* static: in the shell */}
      <ProductList /> {/* cached: in the shell */}
      <Suspense fallback={<p>Loading your preferences...</p>}>
        <Greeting /> {/* runtime: streams at request time */}
      </Suspense>
    </>
  )
}

async function ProductList() {
  'use cache'
  cacheLife('hours')
  const products = await getProducts()
  return <ul>{products.map((p) => <li key={p.id}>{p.name}</li>)}</ul>
}

async function Greeting() {
  const name = (await cookies()).get('name')?.value ?? 'there'
  return <p>Welcome back, {name}</p>
}
```

**Example D** — two `tsx` blocks (server-and-client-boundary guide; the first block alone satisfies the `'use client'` + `children` needle):

```tsx
// app/ui/modal.tsx
'use client'

import { useState, type ReactNode } from 'react'

export function Modal({ title, children }: { title: ReactNode; children: ReactNode }) {
  const [open, setOpen] = useState(true)
  if (!open) return null
  return (
    <div role="dialog">
      <header>
        {title}
        <button onClick={() => setOpen(false)}>Close</button>
      </header>
      {children}
    </div>
  )
}
```

```tsx
// app/cart/page.tsx: Page and Cart are Server Components, Modal is a Client Component
import { Modal } from '@/app/ui/modal'
import { Cart } from '@/app/ui/cart'

export default function Page() {
  return (
    <Modal title={<h2>Your cart</h2>}>
      <Cart />
    </Modal>
  )
}
```

**Example E** — `tsx` (server-and-client-components, "Context providers"):

```tsx
// app/theme-provider.tsx
'use client'

import { createContext, type ReactNode } from 'react'

export const ThemeContext = createContext<'light' | 'dark'>('light')

export default function ThemeProvider({ children }: { children: ReactNode }) {
  return <ThemeContext.Provider value="dark">{children}</ThemeContext.Provider>
}
```

```tsx
// app/layout.tsx: the provider wraps {children}, not <html>
import type { ReactNode } from 'react'
import ThemeProvider from './theme-provider'

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>
        <ThemeProvider>{children}</ThemeProvider>
      </body>
    </html>
  )
}
```

**Example F** — `tsx` (caching page, "Passing runtime values to cached functions"):

```tsx
import { Suspense } from 'react'
import { cookies } from 'next/headers'
import { cacheLife } from 'next/cache'
import { getProfile } from '@/lib/profile' // your data layer

export default function Page() {
  return (
    <Suspense fallback={<p>Loading...</p>}>
      <ProfileContent />
    </Suspense>
  )
}

async function ProfileContent() {
  const sessionId = (await cookies()).get('session')?.value // read outside the cache
  if (!sessionId) return <p>Signed out</p>
  return <CachedProfile sessionId={sessionId} />
}

async function CachedProfile({ sessionId }: { sessionId: string }) {
  'use cache'
  cacheLife('minutes')
  const profile = await getProfile(sessionId) // sessionId is part of the cache key
  return <p>{profile.displayName}</p>
}
```

**Example G** — `tsx` (caching page, "Maximizing the static shell"):

```tsx
// app/shop/[slug]/layout.tsx: not async, never awaits params
import { Suspense } from 'react'
import { Sidebar } from './sidebar'

export default function Layout({ children, params }: LayoutProps<'/shop/[slug]'>) {
  return (
    <div>
      <Sidebar />
      <Suspense fallback={<h1>Loading...</h1>}>
        {params.then(({ slug }) => <h1>{slug}</h1>)}
      </Suspense>
      {children}
    </div>
  )
}
```

**Example H** — `tsx` (io page, verbatim apart from comments; 16.3+):

```tsx
import { Suspense } from 'react'
import { io } from 'next/cache'

export default function Page() {
  return (
    <Suspense fallback={<p>Loading...</p>}>
      <CurrentTime />
    </Suspense>
  )
}

async function CurrentTime() {
  await io() // below 16.3: await connection() from 'next/server'
  return <p>{new Date().toISOString()}</p>
}
```

**Example I** — `ts` (updateTag, refresh, server-actions pages; auth shape from the server-actions guide):

```ts
// app/posts/actions.ts
'use server'

import { refresh, updateTag } from 'next/cache'
import { redirect } from 'next/navigation'
import { auth } from '@/lib/auth' // your auth check, see proxy-auth-and-security.md
import { db } from '@/lib/db'

export async function createPost(formData: FormData): Promise<void> {
  const session = await auth()
  if (!session?.user) throw new Error('Unauthorized')
  const post = await db.post.create({ data: { title: String(formData.get('title')) } })
  updateTag('posts') // read-your-own-writes
  updateTag(`post-${post.id}`)
  redirect(`/posts/${post.id}`) // throws: invalidate before it
}

export async function markNotificationRead(id: string): Promise<void> {
  const session = await auth()
  if (!session?.user) throw new Error('Unauthorized')
  await db.notifications.markAsRead(id)
  refresh() // re-render the current route; no cache entry is touched
}
```

**Example J** — `ts` (revalidateTag page, Route Handler example + `{ expire: 0 }` note):

```ts
// app/api/revalidate/route.ts
import type { NextRequest } from 'next/server'
import { revalidateTag } from 'next/cache'
import { verifyWebhook } from '@/lib/webhooks' // signature check, see proxy-auth-and-security.md

export async function POST(request: NextRequest): Promise<Response> {
  if (!(await verifyWebhook(request))) {
    return Response.json({ revalidated: false }, { status: 401 })
  }
  const tag = request.nextUrl.searchParams.get('tag')
  if (!tag) {
    return Response.json({ revalidated: false, message: 'Missing tag' }, { status: 400 })
  }
  revalidateTag(tag, 'max') // { expire: 0 } when stale data must never be served
  return Response.json({ revalidated: true })
}
```

**Example K** — `tsx` (streaming guide, "When does streaming start?"):

```tsx
// app/post/[slug]/page.tsx
import { Suspense } from 'react'
import { notFound } from 'next/navigation'
import { PostContent } from './post-content'
import { postExists } from '@/lib/posts' // fast existence check

export default async function PostPage({ params }: PageProps<'/post/[slug]'>) {
  const { slug } = await params
  if (!(await postExists(slug))) notFound() // real 404: before any Suspense boundary
  return (
    <Suspense fallback={<p>Loading post...</p>}>
      <PostContent slug={slug} />
    </Suspense>
  )
}
```

Add one sentence: awaiting `params` at the top makes the page request-bound for params not returned by `generateStaticParams` ([Caching](https://nextjs.org/docs/app/getting-started/caching)); alternatively run the existence check in Proxy ([loading.js](https://nextjs.org/docs/app/api-reference/file-conventions/loading), Status Codes).

**Example L** — `tsx` (previous model; caching-without-cache-components, ISR, fetch pages):

```tsx
// app/blog/page.tsx: repo WITHOUT cacheComponents
export const revalidate = 3600 // regenerate at most hourly (statically analyzable literal)

type Post = { id: string; title: string }

export default async function BlogPage() {
  const res = await fetch('https://api.vercel.app/blog', {
    cache: 'force-cache', // fetch is not cached by default since Next.js 15
    next: { tags: ['posts'] },
  })
  const posts: Post[] = await res.json()
  return <ul>{posts.map((post) => <li key={post.id}>{post.title}</li>)}</ul>
}
```

### `## Anti-patterns` (≈ 230 lines)

Format: the contract's Don't/Do markers (default `**Don't:** <one sentence> (RC-n)` + `tsx`/`ts` block, then `**Do:** <one sentence>` + block). All blocks tagged. AP1–AP8 required; AP9–AP10 if the line budget allows.

- **AP1 (RC-5)** Don't mark a whole page `'use client'` for one widget.
  ```tsx
  'use client' // the page, its imports and everything it renders ship to the browser
  import { useState } from 'react'
  import { ProductDetails } from './product-details'

  export default function ProductPage() {
    const [qty, setQty] = useState(1)
    return (
      <main>
        <ProductDetails />
        <button onClick={() => setQty(qty + 1)}>{qty}</button>
      </main>
    )
  }
  ```
  Do: keep the page a Server Component; the directive lives only in `quantity-picker.tsx`.
  ```tsx
  import { ProductDetails } from './product-details'
  import { QuantityPicker } from './quantity-picker' // 'use client' file

  export default function ProductPage() {
    return (
      <main>
        <ProductDetails />
        <QuantityPicker />
      </main>
    )
  }
  ```
- **AP2 (RC-7)** Don't pass a plain function from a Server Component.
  ```tsx
  // Server Component
  export default function Page() {
    return <Counter onClick={() => console.log('clicked')} /> // throws: not serializable
  }
  ```
  Do: own the handler in the Client Component (or pass a `'use server'` Server Action).
  ```tsx
  'use client'
  import { useState } from 'react'

  export function Counter() {
    const [count, setCount] = useState(0)
    return <button onClick={() => setCount(count + 1)}>{count}</button>
  }
  ```
- **AP3 (RC-8)** Don't import a Server Component into a `'use client'` file.
  ```tsx
  'use client'
  import { Cart } from './cart' // Cart joins the client bundle and runs in the browser

  export function Modal() {
    return <div role="dialog"><Cart /></div>
  }
  ```
  Do: take it as `children` (Example D).
  ```tsx
  <Modal title={<h2>Your cart</h2>}>
    <Cart />
  </Modal>
  ```
- **AP4 (RC-23)** Don't read `cookies()` inside `'use cache'`.
  ```tsx
  async function Recommendations() {
    'use cache'
    const userId = (await cookies()).get('uid')?.value // error: next-request-in-use-cache
    return <List items={await getRecommendations(userId)} />
  }
  ```
  Do: read outside, pass the value (render `<Recommendations />` inside `<Suspense>`).
  ```tsx
  async function Recommendations() {
    const userId = (await cookies()).get('uid')?.value ?? 'anonymous'
    return <CachedRecommendations userId={userId} />
  }

  async function CachedRecommendations({ userId }: { userId: string }) {
    'use cache'
    cacheLife('minutes')
    return <List items={await getRecommendations(userId)} />
  }
  ```
- **AP5 (RC-16)** Don't await `cookies()` at the top of a layout under Cache Components.
  ```tsx
  export default async function DashboardLayout({ children }: { children: ReactNode }) {
    const user = (await cookies()).get('user')?.value // the layout and its children leave the shell
    return <div><Nav user={user} />{children}</div>
  }
  ```
  Do: start the promise, resolve it inside a boundary (streaming guide, "Push dynamic access down").
  ```tsx
  export default function DashboardLayout({ children }: { children: ReactNode }) {
    const cookieStore = cookies() // start, don't await
    return (
      <div>
        <Nav>
          <Suspense fallback={<p>Loading user...</p>}>
            <UserMenu cookiePromise={cookieStore} />
          </Suspense>
        </Nav>
        {children}
      </div>
    )
  }
  ```
  (`UserMenu` prop typed `cookiePromise: ReturnType<typeof cookies>`.)
- **AP6 (RC-32, RC-33)** Don't call `updateTag` or one-argument `revalidateTag` in a Route Handler.
  ```ts
  import { revalidateTag, updateTag } from 'next/cache'

  export async function POST(): Promise<Response> {
    updateTag('posts') // throws: Server Actions only
    revalidateTag('posts') // deprecated one-argument form, behaves like { expire: 0 }
    return Response.json({ ok: true })
  }
  ```
  Do:
  ```ts
  import { revalidateTag } from 'next/cache'

  export async function POST(): Promise<Response> {
    revalidateTag('posts', 'max')
    return Response.json({ ok: true })
  }
  ```
- **AP7 (RC-40)** Don't decide "not found" after streaming started.
  ```tsx
  export default function PostPage({ params }: PageProps<'/post/[slug]'>) {
    return (
      <Suspense fallback={<p>Loading...</p>}>
        <Post params={params} /> {/* notFound() in here: status 200 + noindex meta, not 404 */}
      </Suspense>
    )
  }
  ```
  Do: check existence before any boundary (Example K, reduced).
  ```tsx
  export default async function PostPage({ params }: PageProps<'/post/[slug]'>) {
    const { slug } = await params
    if (!(await postExists(slug))) notFound()
    return <Suspense fallback={<p>Loading...</p>}><PostContent slug={slug} /></Suspense>
  }
  ```
- **AP8 (RC-2)** Don't keep route segment caching config with `cacheComponents` on.
  ```tsx
  export const dynamic = 'force-static' // errors under Cache Components
  export const revalidate = 3600

  export default async function Page() {
    const data = await getData()
    return <div>{data.title}</div>
  }
  ```
  Do (migrating guide):
  ```tsx
  import { cacheLife } from 'next/cache'

  export default async function Page() {
    'use cache'
    cacheLife('hours')
    const data = await getData()
    return <div>{data.title}</div>
  }
  ```
- **AP9 (RC-22)** Don't nest a short-lived cache in `'use cache'` without an explicit `cacheLife` (cacheLife page, "Nested short-lived caches").
  ```tsx
  export default async function Page() {
    'use cache' // no cacheLife: a nested cacheLife('seconds') fails the build during prerender
    return <ShortLivedWidget />
  }
  ```
  Do:
  ```tsx
  export default async function Page() {
    'use cache'
    cacheLife('default') // explicit: the page stays prerendered
    return <ShortLivedWidget />
  }
  ```
- **AP10 (RC-17)** Don't render a random value in a prerendered component.
  ```tsx
  export default function Page() {
    return <p>Request ID: {crypto.randomUUID()}</p> // blocking-prerender-crypto insight
  }
  ```
  Do: Example H shape (`await io()` / `await connection()` inside a `<Suspense>`-wrapped component).
  ```tsx
  import { connection } from 'next/server'

  async function RequestId() { // render inside <Suspense>
    await connection()
    return <p>Request ID: {crypto.randomUUID()}</p>
  }
  ```

### `## Version notes` (≈ 22 lines)

Open with "Changes to this topic in **Next.js 16** (16.0.0 to 16.3.x):", then one bullet each, each with its link (all from §8 V-items). Then "Earlier, as the upgrade guides state it:" with the 15.x bullets.

### `## Review checklist` (17 items, each `- [ ] … (RC-n)`)

1. Caching model read from `next.config` and every caching change follows that model (RC-1).
2. No `dynamic`, `revalidate`, `fetchCache`, `dynamicParams`, `experimental_ppr` or `runtime = 'edge'` export in a Cache Components repo; `generateStaticParams` returns ≥ 1 param (RC-2, RC-3, RC-4).
3. `'use client'` only on interactive leaves, first line of the file (RC-5, RC-6).
4. Props into Client Components are serializable; no function props except Server Actions (RC-7).
5. Server UI nested via `children`/slots, never imported into a `'use client'` file (RC-8).
6. Providers are `'use client'` wrappers around `{children}`, as deep as possible (RC-9).
7. Server-only modules import `server-only`; secrets never in `NEXT_PUBLIC_` vars (RC-12).
8. `cookies()`, `headers()`, `draftMode()`, `params`, `searchParams` awaited (RC-13).
9. Under Cache Components, runtime reads sit inside `<Suspense>` and not at the top of a layout or page (RC-15, RC-16).
10. `Math.random()`, `Date.now()`, `new Date()`, `crypto.randomUUID()` behind `io()`/`connection()` + `<Suspense>`, or inside `'use cache'` (RC-17).
11. Every `'use cache'` scope has its own `cacheLife` call and a `cacheTag` when a write must invalidate it (RC-20, RC-28).
12. No `cookies()`/`headers()`/`searchParams` (or runtime promise) reaches a cached scope (RC-23).
13. Short-lived caches under `<Suspense>`; outer caches nesting them set an explicit `cacheLife` (RC-22).
14. Previous model: `fetch` caching is explicit and never combines `revalidate` with `no-store` (RC-29, RC-31).
15. `revalidateTag` has a profile; `updateTag`/`refresh` only in Server Actions; invalidation before `redirect()` (RC-32, RC-33, RC-34).
16. Each slow subtree has its own `<Suspense>` near the access; no layout read hidden behind `loading.tsx` (RC-38, RC-39).
17. `notFound()`/`redirect()` that need a real status run before any suspending `await` or `<Suspense>`; LCP element outside boundaries (RC-40, RC-41).

### `## Not confirmed by the docs`

List exactly the items in §9 with the URLs checked. Nothing there is stated as a rule.

### `## Sources`

The 46 URLs in §8 "Sources", each once, in the contract's bullet format.

## 8. Verified rule sheet

All URLs fetched 2026-10-04 (front matter `version: 16.3.8` on every nextjs.org page). "[changed in 16]" marks an API whose behaviour or signature changed in the latest major.

### Sources (the complete list; use no other URL)

| # | URL | Short name used below |
| --- | --- | --- |
| S1 | https://nextjs.org/docs/app/getting-started/server-and-client-components | SCC |
| S2 | https://nextjs.org/docs/app/guides/server-and-client-boundary | Boundary |
| S3 | https://nextjs.org/docs/app/api-reference/directives/use-client | use client |
| S4 | https://nextjs.org/docs/app/guides/rendering-philosophy | Philosophy |
| S5 | https://nextjs.org/docs/app/getting-started/caching | Caching |
| S6 | https://nextjs.org/docs/app/api-reference/config/next-config-js/cacheComponents | cacheComponents |
| S7 | https://nextjs.org/docs/app/api-reference/directives/use-cache | use cache |
| S8 | https://nextjs.org/docs/app/api-reference/directives/use-cache-private | use cache: private |
| S9 | https://nextjs.org/docs/app/api-reference/directives/use-cache-remote | use cache: remote |
| S10 | https://nextjs.org/docs/app/api-reference/functions/cacheLife | cacheLife |
| S11 | https://nextjs.org/docs/app/api-reference/functions/cacheTag | cacheTag |
| S12 | https://nextjs.org/docs/app/getting-started/revalidating | Revalidating |
| S13 | https://nextjs.org/docs/app/api-reference/functions/revalidateTag | revalidateTag |
| S14 | https://nextjs.org/docs/app/api-reference/functions/updateTag | updateTag |
| S15 | https://nextjs.org/docs/app/api-reference/functions/revalidatePath | revalidatePath |
| S16 | https://nextjs.org/docs/app/api-reference/functions/refresh | refresh |
| S17 | https://nextjs.org/docs/app/guides/server-actions | Server Actions guide |
| S18 | https://nextjs.org/docs/app/guides/how-revalidation-works | How revalidation works |
| S19 | https://nextjs.org/docs/app/guides/caching-without-cache-components | Previous Model |
| S20 | https://nextjs.org/docs/app/guides/migrating-to-cache-components | Migrating |
| S21 | https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config | Segment config |
| S22 | https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/dynamicParams | dynamicParams |
| S23 | https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/instant | instant |
| S24 | https://nextjs.org/docs/app/api-reference/functions/connection | connection |
| S25 | https://nextjs.org/docs/app/api-reference/functions/io | io |
| S26 | https://nextjs.org/docs/app/api-reference/functions/cookies | cookies |
| S27 | https://nextjs.org/docs/app/api-reference/functions/headers | headers |
| S28 | https://nextjs.org/docs/app/api-reference/file-conventions/page | page.js |
| S29 | https://nextjs.org/docs/app/api-reference/functions/fetch | fetch |
| S30 | https://nextjs.org/docs/app/guides/streaming | Streaming |
| S31 | https://nextjs.org/docs/app/api-reference/file-conventions/loading | loading.js |
| S32 | https://nextjs.org/docs/app/getting-started/fetching-data | Fetching Data |
| S33 | https://nextjs.org/docs/app/guides/incremental-static-regeneration | ISR |
| S34 | https://nextjs.org/docs/app/guides/incremental-static-regeneration-cache-components | ISR with CC |
| S35 | https://nextjs.org/docs/app/api-reference/functions/unstable_cache | unstable_cache |
| S36 | https://nextjs.org/docs/app/api-reference/functions/unstable_noStore | unstable_noStore |
| S37 | https://nextjs.org/docs/app/api-reference/config/next-config-js/partialPrefetching | partialPrefetching |
| S38 | https://nextjs.org/docs/app/glossary | Glossary |
| S39 | https://nextjs.org/docs/app/guides/upgrading/version-16 | v16 guide |
| S40 | https://nextjs.org/docs/app/guides/upgrading/version-15 | v15 guide |
| S41 | https://nextjs.org/blog/next-16 | Next.js 16 post |
| S42 | https://nextjs.org/blog/next-16-3 | Next.js 16.3 post |
| S43 | https://vercel.com/docs/frameworks/full-stack/nextjs | Next.js on Vercel |
| S44 | https://vercel.com/docs/caching/runtime-cache | Vercel Runtime Cache |
| S45 | https://react.dev/reference/rsc/use-client | react.dev use client |
| S46 | https://react.dev/reference/react/Suspense | react.dev Suspense |

### Rules

**Caching model and config**

- **RC-1** Detect the caching model before applying any caching rule: if `next.config.*` sets `cacheComponents: true`, the Cache Components rules apply; without it, the previous model (`fetch` options, `unstable_cache`, route segment config `dynamic`/`revalidate`/`fetchCache`) applies. *(both models)*
  - S5: page banner "This page covers caching with Cache Components, enabled by setting `cacheComponents: true` … If you're not using Cache Components, see the Caching and Revalidating (Previous Model) guide." S19: guide "assumes you are not using Cache Components which was introduced in version 16 under the `cacheComponents` flag" and documents `fetch` options, `unstable_cache`, `dynamic`, `fetchCache`, `revalidate`.
- **RC-2** Remove `dynamic`, `revalidate`, `fetchCache` and `dynamicParams` exports when `cacheComponents` is enabled; replace them per the migration map, return at least one param from `generateStaticParams` (details in routing-and-metadata.md), and call `notFound()` instead of `dynamicParams = false`. *(Cache Components)* [changed in 16]
  - S21 version history: "`v16.0.0` `dynamic`, `dynamicParams`, `revalidate`, and `fetchCache` removed when Cache Components is enabled." S20: "route segments that still export `dynamic`, `revalidate`, or `fetchCache` will error"; exporting `dynamicParams` fails the build ("Route segment config "dynamicParams" is not compatible with `nextConfig.cacheComponents`"); "Returning an empty array now errors" (`empty-generate-static-params`); "If you used `dynamicParams: false` to reject them, call `notFound()`". S22: "`dynamicParams` is not available when Cache Components is enabled."
- **RC-3** Replace `experimental.ppr`, the `experimental_ppr` segment export, `experimental.dynamicIO` and `experimental.useCache` with the top-level `cacheComponents: true` flag, and treat enabling it as adopting a new model, not a rename. *(Cache Components)* [changed in 16]
  - S6: "`cacheComponents` implements Partial Prerendering (PPR) as the default behavior … the `experimental.ppr` configuration flag and the `experimental_ppr` route segment configuration are no longer necessary and have been removed"; version history 16.0.0 "controls the `ppr`, `useCache`, and `dynamicIO` flags as a single, unified configuration". S39: "`experimental.dynamicIO` and `experimental.useCache` flags have been removed … Enabling `cacheComponents` is not a rename-only change: it can surface build errors for uncached data outside of `<Suspense>`."
- **RC-4** Keep Cache Components routes on the Node.js runtime: remove any deprecated `runtime = 'edge'` export (use Proxy for edge behaviour). *(Cache Components)*
  - S6: "Cache Components requires the Node.js runtime. Migrate any routes that set the deprecated `runtime = 'edge'` export". S20 `runtime = 'edge'`: "Not supported … If you need edge behavior for specific routes, use Proxy instead." S21 table: `runtime` `'nodejs' | 'edge' (deprecated)`.

**Server and Client Components**

- **RC-5** Leave layouts and pages as Server Components (the default) and add `'use client'` only to the specific interactive components that need state, event handlers, effects, browser-only APIs or custom hooks. *(both models)*
  - S1: "By default, layouts and pages are Server Components"; Client Components for state/event handlers, lifecycle (`useEffect`), browser-only APIs, custom hooks; "To reduce the size of your client JavaScript bundles, add `'use client'` to specific interactive components instead of marking large parts of your UI as Client Components." S2: built-in HTML behaviour (`<details>`, `<form action>`, `<video controls>`) needs no Client Component.
- **RC-6** Put `'use client'` at the very top of the file, before imports, and only on the entry files Server Components render — every module such a file imports joins the client bundle, so the directive is not needed on files inside the subtree. *(both models)*
  - S3: "add the `'use client'` directive at the top of the file, before any imports … You only need to add it to the files whose components you want to render directly within Server Components." S1: "all of its imports and the components it directly renders are included in the client bundle." S45: "must be at the very beginning of a file, above any imports or other code (comments are OK)."
- **RC-7** Pass only serializable props from Server to Client Components (primitives, plain objects, arrays, `Date`, `Map`, `Set`, typed arrays, Promises, JSX, Server Functions); never pass event handlers, other plain functions or class instances. *(both models)*
  - S1: "Props passed to Client Components need to be serializable by React." S2: "Passing a function as a prop from a Server Component to a Client Component throws … A Server Function marked with `'use server'` crosses as a reference"; "the TypeScript plugin allows a Client Component prop typed as a function when its name is `action` or ends in `Action`." S45 lists supported/unsupported types (functions not exported from client modules or `'use server'`, classes, class instances, null-prototype objects, unregistered symbols are unsupported).
- **RC-8** Nest server-rendered UI inside a Client Component by passing it as `children` or another `ReactNode` prop from a Server Component; never import a Server Component into a `'use client'` file. *(both models)*
  - S1 "Interleaving Server and Client Components": "You can pass Server Components as a prop to a Client Component … A common pattern is to use `children` to create a slot." S2: "Passing rendered output as `children` lets a Server Component nest inside a Client Component without importing the Server Component's code into the client graph." Snippet: Example D (Modal with `title`/`children: ReactNode`) matches S2.
- **RC-9** Wrap React context in a `'use client'` provider component that takes `children`, and render it as deep as possible (around `{children}`, not the whole `<html>`). *(both models)*
  - S1 "Context providers": "React context is not supported in Server Components … create a Client Component that accepts `children`"; "You should render providers as deep as possible in the tree – notice how `ThemeProvider` only wraps `{children}` instead of the entire `<html>` document." Example E matches (typed `createContext<'light' | 'dark'>` instead of `createContext({})`).
- **RC-10** Wrap a third-party component that uses client-only features but lacks `'use client'` in your own `'use client'` file that re-exports it, then render that from Server Components. *(both models)*
  - S1 "Third-party components": `'use client'; import { Carousel } from 'acme-carousel'; export default Carousel`.
- **RC-11** Export compound-component parts (`Menu.Item`, `Tabs.Panel`) as named exports when Server Components use them; static members of a Client Component are `undefined` across the boundary. *(both models)*
  - S2 "Compound components across the boundary": "`Menu.Item` is `undefined`, and React throws 'Element type is invalid.' … expose them as named exports instead of static properties."
- **RC-12** Add `import 'server-only'` to modules holding secrets or server-only logic so a client import fails the build, and expect only `NEXT_PUBLIC_`-prefixed env vars in the client bundle (data exposure rules: proxy-auth-and-security.md). *(both models)*
  - S1 "Preventing environment poisoning": "only environment variables prefixed with `NEXT_PUBLIC_` are included in the client bundle … if you try to import the module into a Client Component, there will be a build-time error"; installing `server-only` is optional; Next.js ships its own types for it.

**Request-time APIs and rendering**

- **RC-13** Await `cookies()`, `headers()`, `draftMode()`, `params` and `searchParams` (or read them with React `use` in a Client Component); synchronous access was removed in Next.js 16. *(both models)* [changed in 16]
  - S39 "Async Request APIs (Breaking change)": "Starting with Next.js 16, synchronous access is fully removed"; `PageProps`/`LayoutProps` helpers via `next typegen`. S26/S27: "asynchronous function … You must use async/await or React's `use`". (S28 still says sync access works "in Next.js 15" — superseded by S39; see §9.)
- **RC-14** Expect any read of `cookies()`, `headers()` or `searchParams` in a layout or page to opt the whole route into dynamic rendering, so keep these reads out of routes meant to be prerendered. *(previous model)*
  - S26: "Using it in a layout or page will opt a route into dynamic rendering." S28: "`searchParams` … Using it will opt the page into dynamic rendering at request time." S20: "Without Cache Components, reading `cookies()`, `headers()`, or `searchParams` opts the whole route into dynamic rendering." S38 "Request-time APIs".
- **RC-15** Read `cookies()`, `headers()`, `searchParams` and unknown `params` inside a component wrapped in `<Suspense>`, so the rest of the route prerenders into the static shell; a read outside any boundary is a blocking-route error. *(Cache Components)*
  - S5 "Working with runtime APIs": "Components that access runtime APIs should be wrapped in `<Suspense>`"; "Reading `cookies()` here doesn't opt-in the whole route into dynamic rendering, the way the previous rendering model did." S26/S27: "With Cache Components, calling `cookies()` outside of a `<Suspense>` boundary prevents the route from being prerendered." S30: if no boundary is found, "the build fails with a blocking route error."
- **RC-16** Pass the un-awaited `params`, `searchParams` or `cookies()` promise down to the component that needs the value and await it there (or `.then()` it) inside the `<Suspense>` boundary; never await it at the top of a layout or page. *(Cache Components)*
  - S5 "Maximizing the static shell": "If this param is dynamic … the layout cannot be prerendered … pass the params promise down and await there"; "The same principle applies to `cookies()`, `headers()`, `searchParams`, and data fetches." S30 "Push dynamic access down": "If you `await` any of these at the top of a layout or page, everything below that point becomes dynamic." Snippets: Example G (S5), AP5 Do (S30).
- **RC-17** Put `Math.random()`, `Date.now()`, `new Date()` and `crypto.randomUUID()` behind `await io()` (Next.js 16.3+; `await connection()` on earlier 16.x or when the work must wait for a real request) in a `<Suspense>`-wrapped component, or capture one shared value inside `'use cache'`. *(Cache Components)*
  - S5 "Random values and timestamps": "Cache Components requires you to explicitly handle these … defer to request time by calling `connection()` … and wrap the component in `<Suspense>` … Alternatively, you can cache the result"; insights `blocking-prerender-random`/`-current-time`/`-crypto`. S25: "To keep it out of the static shell, use `await io()`"; "Prefer `io()` over `connection()`, and reach for `connection()` only when you need to wait for a real user request" (connection blocks prefetches); version history `v16.3.0 io added`; `import { io } from 'next/cache'`. S20: synchronous IO errors are not cleared by `instant = false`. Snippet: Example H is S25's example.
- **RC-18** Replace `unstable_noStore()` with `await connection()` (from `next/server`); under Cache Components simply remove it, since nothing is cached without `'use cache'`. *(both models)*
  - S36: "legacy API and no longer recommended … we recommend using `connection` instead"; version history `v15.0.0 deprecated for connection`. S24: "`connection` replaces `unstable_noStore`"; `function connection(): Promise<void>`. S20 `unstable_noStore`: "Not needed … nothing is cached unless you add `use cache`."

**Cache Components caching**

- **RC-19** Add `'use cache'` only to work that does not depend on runtime data and may be served from cache for a while — at the top of an async function, an async component, or a file (file level caches every export, and every export must be async). *(Cache Components)*
  - S7: "Functions and components that use `use cache` must be async"; file level: "every exported function becomes a cached function and must also be async". S12 "What should I cache?": "Cache data that doesn't depend on runtime data and that you're OK serving from cache for a period of time." S5 "Streaming uncached data": for data that must be fresh per request, "do not use `"use cache"`" — use `<Suspense>`.
- **RC-20** Call `cacheLife(...)` in every `'use cache'` scope, in the same function (not a shared helper, never at module scope), with exactly one call executing per invocation. *(Cache Components)*
  - S10: "`cacheLife` can only be used within a cache directive scope … Calling it at the top level of a file will throw"; "We recommend setting a `cacheLife` in every `use cache` scope"; "Avoid abstracting it into shared utilities"; "ensure only one call executes per function invocation." S5: "We recommend pairing every cache directive with a `cacheLife`. Without one, the implicit `default` profile applies." Default profile: stale 5 min, revalidate 15 min, expire never.
- **RC-21** Choose a preset profile by change frequency (`seconds`, `minutes`, `hours`, `days`, `weeks`, `max`) or define a named custom profile in `next.config.ts` `cacheLife`; document any redefined built-in. *(Cache Components)*
  - S10 preset table (default 5m/15m/never; seconds 30s/1s/1m; minutes 5m/1m/1h; hours 5m/1h/1d; days 5m/1d/1w; weeks 5m/1w/30d; max 5m/30d/1y); custom profiles in `next.config.ts`; "Redefining a built-in is a supported pattern, but document it in your project"; `expire` must be longer than `revalidate`; omitted properties inherit from `default`.
- **RC-22** Treat `revalidate: 0`, `expire` under 5 minutes, `stale` under 30 seconds and the `seconds` profile as short-lived: wrap such a component in `<Suspense>` (it becomes a dynamic hole), and give any outer `'use cache'` that nests one an explicit `cacheLife`. *(Cache Components)*
  - S10 "Prerendering behavior": `revalidate` 0 or `expire` < 5 min → excluded from prerenders ("dynamic hole"); `stale` < 30 s excluded; 30 s ≤ `stale` < 5 min included but excluded from the App Shell; "Of the presets, only `seconds` falls under any of these thresholds"; "Use a `<Suspense>` boundary around dynamic caches"; "Nested short-lived caches … Next.js throws an error during prerendering … To fix the error, add an explicit `cacheLife()` to the outer `use cache`." AP9 snippets from S10.
- **RC-23** Never call `cookies()` or `headers()` or read `searchParams` inside a `'use cache'` scope or any helper it calls; read them outside, pass the extracted values as arguments (they join the cache key), and never pass the un-awaited runtime promise in. *(Cache Components)*
  - S7 "Request-time APIs": "Cached functions and components cannot access runtime APIs … the restriction follows the call stack … `next-request-in-use-cache` error … it can pass `next build` and fail under `next start`. Read these values outside the cached scope and pass them as arguments." S7 "Build Hangs": passing runtime-data Promises as props/closures/Maps into a cache times out after 50 seconds. S5 "Passing runtime values to cached functions". Snippets: Example F, AP4.
- **RC-24** Use `'use cache: private'` only when a function must read cookies, headers or `searchParams` directly and cannot be refactored; its result is never stored in a server cache across requests and is excluded from the static shell. *(Cache Components)*
  - S8: "allows functions to access runtime request APIs … Next.js does not store it in a server cache across requests … Private Cache Functions run at request time and are excluded from static shell generation … not possible to configure custom cache handlers." S7: "For compliance requirements or when you can't refactor … see `use cache: private`."
- **RC-25** Keep a cached function's arguments and return values serializable (no class instances, `URL` instances, symbols or functions), and pass `children` or Server Actions through a cached component without reading or calling them. *(Cache Components)*
  - S7 "Serialization": supported/unsupported lists; "Pass-through (non-serializable arguments) … as long as you don't introspect them"; "Interleaving … As long as you don't directly reference any of the JSX slots inside the body … their presence … won't affect the cache entry."
- **RC-26** Pass data into a `'use cache'` scope only through arguments — `React.cache` values set outside a cache scope are not visible inside it. *(Cache Components)*
  - S7 "React.cache isolation": "`React.cache` operates in an isolated scope inside `use cache` boundaries … use function arguments instead." S20 `React.cache`: "each Cache Function has an isolated React cache scope."
- **RC-27** Assume default `'use cache'` entries live in a per-instance in-memory LRU (often not reused between requests on serverless) and are scoped to one deployment; use `'use cache: remote'` (a cache handler such as Vercel Runtime Cache) only where a high hit rate justifies the extra network roundtrip. *(Cache Components)*
  - S7 "Runtime caching considerations": serverless entries "typically don't persist across requests"; self-hosted persist (`cacheMaxMemorySize`); "Neither caching directive carries over to a new deploy, because the cache key includes the build (or `deploymentId`) ID." S5 "Where cached content is stored": remote is "a network roundtrip that pays off only at a high hit rate". S9 comparison table. S44: "`use cache` is in-memory by default … `use cache: remote` is a declarative way telling the system to store the cached output in a remote cache such Vercel runtime cache"; Next.js 16 row uses `use cache: remote`.
- **RC-28** Tag every cached entry that a write or webhook must invalidate with `cacheTag(...)` inside its `'use cache'` scope (up to 128 tags per call, 256 characters each, case-sensitive). *(Cache Components)* [stable in 16]
  - S11: "The `cacheTag` function takes one or more string values"; limits "up to 128 tags, each with a maximum length of 256 characters … Tags longer than 256 characters are skipped"; can tag from fetched data. S13: "Tags are case-sensitive and must not exceed 256 characters." S39: `cacheLife` and `cacheTag` "are now stable. The `unstable_` prefix is no longer needed."

**Previous model**

- **RC-29** Opt a `fetch` into the Data Cache explicitly with `cache: 'force-cache'` or `next: { revalidate: n }`, tag it with `next: { tags: [...] }`, and never combine `revalidate` with `cache: 'no-store'`. *(previous model)* [changed in 15]
  - S19: "By default, `fetch` requests are not cached. You can cache individual requests by setting the `cache` option to `'force-cache'`." S29: default "auto no cache" fetches once during `next build` when the route is prerendered, every request if Request-time APIs are detected; `force-cache` matches on URL, method, headers and body; only `200` responses stored; "Conflicting options such as `{ revalidate: 3600, cache: 'no-store' }` are not allowed, both will be ignored"; tags max 256 chars, 128 items. S40: "`fetch` requests are no longer cached by default." Example L.
- **RC-30** Cache non-`fetch` work with `unstable_cache(fn, keyParts, { tags, revalidate })` only in repos without Cache Components, and prefer migrating it to `'use cache'`. *(previous model)*
  - S19 "`unstable_cache` for non-`fetch` functions" (signature and options). S35: "This API has been replaced by `use cache` in Next.js 16. We recommend opting into Cache Components and replacing `unstable_cache`." S20: `unstable_cache` "persists cached values across deployments and serverless instances, while `use cache` does not."
- **RC-31** Set route-level ISR with a literal `export const revalidate = <seconds>` (statically analyzable) and use `dynamic = 'force-dynamic'`/`'force-static'` only as deliberate all-or-nothing switches; the lowest `revalidate` across a route's layouts, pages and fetches sets its frequency. *(previous model)*
  - S19 "Route segment config": `dynamic` values and equivalences; "`revalidate = 600` is valid, but `revalidate = 60 * 10` is not"; "The lowest `revalidate` across each layout and page of a single route will determine the revalidation frequency of the entire route." S33: ISR example with `export const revalidate = 60` + `generateStaticParams`; caveat: a `fetch` with `revalidate: 0` or `no-store` makes the route dynamic.

**Revalidation**

- **RC-32** Pass a profile as the second argument to every `revalidateTag` call — `'max'` for stale-while-revalidate, or `{ expire: 0 }` to stop serving stale data; the one-argument form is deprecated (TypeScript error) and behaves like `{ expire: 0 }`. *(both models)* [changed in 16]
  - S13: signature `revalidateTag(tag: string, profile: string | { expire?: number }): void`; "`profile="max"` (recommended)"; "No second argument (deprecated): Behaves like `{ expire: 0 }`"; "A revalidation is triggered by a request, not by the `revalidateTag` call." S39: "now requires a second argument … The single-argument form is deprecated and will produce a TypeScript error." S41 deprecations table.
- **RC-33** Call `updateTag` and `refresh` only inside Server Actions (both throw elsewhere); from a Route Handler or webhook use `revalidateTag(tag, 'max')` or `revalidateTag(tag, { expire: 0 })`; never call any of these from a Client Component or Proxy. *(both models)* [new in 16]
  - S14: "`updateTag` can only be called from within Server Actions. It cannot be used in Route Handlers, Client Components, or any other context." S16: "`refresh` can only be called from within Server Actions." S13/S15: `revalidateTag`/`revalidatePath` "can be called in Server Functions and Route Handlers … cannot be called in Client Components or Proxy." S13: from a webhook "`updateTag` is not available. Pass `{ expire: 0 }`."
- **RC-34** Call `updateTag(tag)` after a mutation whose result the same user must see next (read-your-own-writes), and run every invalidation before `redirect()`, which throws. *(both models)* [new in 16]
  - S14: "designed for read-your-own-writes … The next request will wait to fetch fresh data rather than serving stale content." S17: "Because `redirect` throws a control-flow exception, any code after it does not run. Place revalidation calls before `redirect`." S20: "`updateTag` isn't exclusive to Cache Components (it also works with the previous caching model)." Example I.
- **RC-35** Prefer tag-based invalidation to `revalidatePath`; when you do use it, pass the route file path (the rewrite destination, never `/page` or `/layout` suffixes) and add `type` (`'page'` or `'layout'`) for a dynamic-segment pattern. *(both models)*
  - S12: "Prefer tag-based revalidation (`revalidateTag`/`updateTag`) over path-based when possible — it's more precise and avoids over-invalidating." S15: signature `revalidatePath(path: string, type?: 'page' | 'layout'): void`; "If `path` contains a dynamic segment … this parameter is required"; "you must pass the destination path"; "Do not append `/page` or `/layout`"; `revalidatePath('/', 'layout')` purges the Client Cache and all cached data. S18 soft tags.
- **RC-36** Call `refresh()` in a Server Action when the action changed data that is not cached (not tag-addressable); it re-renders the current route without invalidating any cache entry. *(both models)* [new in 16]
  - S17 "Choosing a cache update": "`refresh`: refetch the current route's RSC Payload without invalidating cached data. Use when the view depends on state outside the cache that the action just changed." S41: "`refresh()` is a new Server Actions-only API for refreshing uncached data only. It doesn't touch the cache at all … complementary to the client-side `router.refresh()`."
- **RC-37** Configure a shared cache handler when self-hosting more than one instance: on-demand revalidation only reaches the instance that receives the call by default. *(both models)*
  - S18 "Multi-Instance Considerations": "revalidation events are local by default. Calling `revalidateTag()` on instance A only invalidates the cache on that instance" — `updateTags()`/`refreshTags()` hooks. S33 caveat: "the default file-system cache is per-instance … Use a shared custom cache handler." Link performance-and-vercel.md for hosting.

**Streaming SSR**

- **RC-38** Wrap each independently slow or request-time subtree in its own `<Suspense fallback={…}>` placed close to the access (siblings stream in parallel); use `loading.tsx` only when nothing meaningful renders before the page's data. *(both models)*
  - S30: "Each `<Suspense>` boundary is an independent streaming point … They don't block each other"; "`loading.js` is useful when there's nothing meaningful to show until the page's data resolves"; "Prefer explicit `<Suspense>` boundaries close to the dynamic access … A `loading.js` high in the tree … the entire page falls back to a full-page skeleton." S31: `loading.js` wraps the page in `<Suspense>`; fallback is prefetched. S5: "`<Suspense>` … does not itself opt a component into dynamic rendering." S43 (Vercel streaming with `loading` and `Suspense`).
- **RC-39** Keep uncached or runtime reads out of a segment's `layout.tsx`, or wrap them in their own `<Suspense>` — `loading.tsx` wraps the page and nested layouts, not the layout in the same segment. *(both models)*
  - S31: "`loading.js` wraps `not-found.js`, `page.js`, and nested `layout.js` files … It does not wrap the `layout.js`, `template.js`, or `error.js` in the same segment"; "If the layout accesses uncached or runtime data … `loading.js` will not show a fallback for it. Without Cache Components: Navigation blocks … With Cache Components: … must be explicitly wrapped in `<Suspense>`."
- **RC-40** Decide the HTTP status before streaming starts: call `notFound()` or `redirect()` before any `await` that may suspend and before any `<Suspense>` boundary, or run the check in Proxy — after the first chunk the status is fixed at `200`. *(both models)*
  - S30 "The HTTP contract": "You cannot change the status code or headers after streaming starts … If a `notFound()` fires mid-stream … it injects `<meta name="robots" content="noindex">` … a `redirect()` mid-stream becomes a client-side redirect"; "place `notFound()` before any `await` or `<Suspense>` boundary". S31 "Status Codes" and Proxy option. S30 "Error handling mid-stream": `error.js` replaces only the failed section; status stays 200. Example K.
- **RC-41** Keep the LCP element outside and above Suspense boundaries, size fallbacks to the final content to avoid layout shift, and add no boundary you do not need (Core Web Vitals detail: performance-and-vercel.md). *(both models)*
  - S30 "Streaming and Web Vitals": "Keep LCP elements outside or above Suspense boundaries"; "Design skeleton fallbacks that match the dimensions"; "if there's a Suspense boundary, React might use it … don't add one you don't need." S46: what activates a boundary; Suspense does not detect data fetched inside an Effect or event handler.
- **RC-42** Make sure everything the static shell depends on is also available at request time — HTML-limited bots skip the shell and render the whole page dynamically. *(Cache Components)*
  - S5 "Bots and crawlers": "Next.js skips the shell and renders the entire page dynamically at request time … Make sure the data your shell relies on is also available at request time." S30 "Bots and crawlers" → "Cache Components".

**Memoization and waterfalls**

- **RC-43** Distinguish request memoization from caching: identical `GET` `fetch` calls are memoized for one render pass and `React.cache` dedupes non-`fetch` calls within one request, but neither persists across requests — use `'use cache'` (or the previous model's options) for that (usage patterns: data-fetching-and-mutations.md). *(both models)*
  - S29 "Memoization": "memoization lasts only for a single render pass, while cached responses persist across requests"; not in Route Handlers; opt out with an `AbortController` signal. S32: "`React.cache` is scoped to the current request only." S38 "Memoization".
- **RC-44** Avoid render waterfalls: never await independent slow data one after another in the same component; give each independent part its own `<Suspense>` boundary or start the requests together (`Promise.all` and preload patterns: data-fetching-and-mutations.md). *(both models)*
  - S32 "Parallel data fetching": "within any component, multiple `async`/`await` requests can still be sequential if placed after the other"; preload "avoid a request waterfall". S30 sibling boundaries resolve independently.

**Cache Components behaviour changes**

- **RC-45** Expect `GET` Route Handlers to prerender like pages under Cache Components; put cached data access in a separate `'use cache'` helper the handler calls (the directive cannot go on the `GET` export; handler design: route-handlers-and-apis.md). *(Cache Components)*
  - S5: "When Cache Components is enabled, `GET` Route Handlers follow the same prerendering model as pages." S20 "Route Handlers (`GET`)": "The directive can't be applied to the `GET` export itself, so the handler calls a cached helper"; reading uncached/runtime data bails out of prerendering "by throwing" (a surrounding `try/catch` catches it). S40 (previous model): "`GET` functions in Route Handlers are no longer cached by default."
- **RC-46** Reset UI state explicitly wherever code relied on unmounting: with Cache Components, navigation hides routes with React `<Activity>` instead of unmounting them, so state and form inputs survive back-and-forth navigation. *(Cache Components)*
  - S6 "Navigation with Activity": "Component state is preserved when navigating between routes … Effects are cleaned up when a route is hidden." S20 "UI state preservation": dropdowns stay open, dialog effects don't re-fire, `useActionState` results persist — add reset logic.
- **RC-47** Adopt Cache Components incrementally with `export const instant = false` on segments not yet converted, never by keeping the removed segment config; it does not clear synchronous-IO build errors. *(Cache Components)*
  - S20 "Opting out of validation" / "Adopting incrementally": "set the `instant` config to `false` on the segment that raised it"; "`instant = false` marks a segment as allowed to block. It does not force the route to be dynamic … It also does not clear synchronous IO build errors"; codemod `cache-components-instant-false`. S23: "The `instant` export only works when `cacheComponents` is enabled … cannot be used in Client Components"; version history `v16.x.x`.

### Version notes items (V)

Next.js 16:
- V1 16.0.0: `cacheComponents` introduced, unifying `ppr`, `useCache`, `dynamicIO`; `experimental.ppr`, `experimental_ppr`, `experimental.dynamicIO`, `experimental.useCache` removed — S6, S39, S41.
- V2 16.0.0: Partial Prerendering is the default with Cache Components; PPR in 16 "works differently than in Next.js 15 canaries" — S39, S43 ("As of Next.js 16, PPR is no longer experimental").
- V3 16.0.0: `'use cache'` (experimental since 15.0.0) enabled with Cache Components, as are `'use cache: private'` and `'use cache: remote'` — S7, S8, S9.
- V4 16.0.0: `cacheLife` and `cacheTag` stable (drop `unstable_` aliases) — S39.
- V5 16.0.0: `revalidateTag(tag, profile)` second argument required; one-argument form deprecated — S39, S41.
- V6 16.0.0: new Server-Actions-only `updateTag` and `refresh` — S39, S41.
- V7 16.0.0: synchronous `cookies()`, `headers()`, `draftMode()`, `params`, `searchParams` access removed — S39.
- V8 16.0.0: `dynamic`, `dynamicParams`, `revalidate`, `fetchCache` removed when Cache Components is enabled — S21.
- V9 16.0.0: `unstable_cache` replaced by `'use cache'` — S35.
- V10 With Cache Components, routes are preserved with React `<Activity>` across navigations — S6.
- V11 16.3.0: `io()` added — S25.
- V12 16.3: Partial Prefetching (`partialPrefetching`, requires `cacheComponents`), Instant Insights, Navigation Inspector, ISR with Cache Components serving the App Shell for unlisted params — S42, S37, S34.
- V13 16.x: `instant` route segment export (Cache Components only; the page lists `v16.x.x`) — S23.

Earlier, as the guides state it:
- V14 15.0: `fetch` and `GET` Route Handlers no longer cached by default; Client Cache no longer reuses page segments on `<Link>` navigation; Request-time APIs became async with temporary sync access — S40.
- V15 15.0.0: `connection()` stabilized, `unstable_noStore` deprecated for it — S24, S36.

## 9. Not confirmed by the docs (goes into the file's section, with URLs checked)

- The story's hint URL `https://nextjs.org/docs/app/getting-started/cache-components` returns the docs "Page Not Found" Markdown in 16.3.8; the content lives at S5. The file cites S5 only. (Checked: that URL, S5, `https://nextjs.org/docs/llms.txt` — llms.txt is not cited; mention the hint URL as inline code, not a link, so it is not a prose URL.)
- Which 16.x minor introduced the `instant` export, and whether it is considered stable: S23 lists `v16.x.x` and calls only the validation-level tuning (`experimental.instantInsights`) experimental. Checked S23, S20, S42.
- Whether `'use cache: remote'` entries survive a redeploy on Vercel: S44 says Vercel Runtime Cache data "persists across deployments", while S7/S9 say entries are unreachable after a new deploy because the key includes the build/deployment ID. The file states only the Next.js-documented key behaviour. Checked S7, S9, S44.
- `page.js` (S28) still says `searchParams` "can still access it synchronously in Next.js 15"; the v16 guide (S39) says synchronous access is removed. The file follows S39. Checked S28, S39, S41.
- How `refresh()` differs from client-side `router.refresh()` beyond "complementary": not documented in detail. Checked S16, S17, S41.

## 10. Assumptions

- A1. The story's scope split outranks the orchestrator's broader topic note: `React.cache` usage, `Promise.all` and preload code live in `data-fetching-and-mutations.md`; this file keeps the semantic rules RC-43/RC-44 and links that file.
- A2. Model labels are written as an italic suffix — *(Cache Components)*, *(previous model)*, *(both models)* — so every rule still starts with an imperative verb and AC5's `## Rules` check is satisfied by RC-1 ("`cacheComponents` … without it, the previous model").
- A3. No `#fragment` in any link: the generic test compares prose URLs to Sources exactly; sections are named in words.
- A4. `## Rules` is one flat numbered list (RC-1…RC-47), one physical line per rule, citation on that line, no H3 inside — the safest shape for `rule_items()` before the skeleton's helper is visible.
- A5. As-of version 16.3.8 (npm `latest` and docs llms.txt on 2026-10-04). The coder copies the as-of line from `R/nextjs.md` verbatim.
- A6. Placeholder app helpers (`db`, `auth`, `getProfile`, `verifyWebhook`, `postExists`, `getData`, `getRecommendations`, `List`, `Nav`, `UserMenu`, `Sidebar`, `Cart`, `ProductDetails`, `ShortLivedWidget`) are application code, not Next.js APIs; every Next.js/React API used appears in the cited pages. Snippets are not compiled (no Next.js project in this repo).
- A7. The Server Action example includes an auth check shaped like S17's example so it doesn't model an unauthenticated mutation; validation of `FormData` stays in data-fetching-and-mutations.md.
- A8. The evidence file is written by the coder from §8 (URL → rule ids), dated 2026-10-04: the planner fetched every URL live in this run (curl with `Accept: text/markdown`; react.dev via WebFetch).
- A9. Anti-pattern marker format follows the skeleton's contract; `**Don't:**`/`**Do:**` is the default if the contract does not fix one, and the test parser keys on whichever is used.
