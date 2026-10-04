# Rendering, caching and streaming SSR

> As of Next.js 16.3.8, verified 2026-10-04.

## Scope

Covers:

- the Server and Client Component boundary, and how much JavaScript reaches the browser;
- rendering strategies: prerendered (the static shell), dynamic (request time), ISR and Partial Prerendering;
- Cache Components: `'use cache'`, `cacheLife`, `cacheTag` and the private and remote variants;
- request-time APIs: `cookies()`, `headers()`, `searchParams` and `params`;
- the previous caching model: `fetch` options, `unstable_cache` and route segment config;
- invalidation: `revalidateTag`, `updateTag`, `revalidatePath` and `refresh`;
- streaming HTML with `<Suspense>` and `loading.tsx`, and the HTTP status contract.

Not here, read the owning file: fetching patterns, `Promise.all`, preload, `React.cache` usage and form wiring in [data-fetching-and-mutations.md](data-fetching-and-mutations.md); streaming responses (SSE, `ReadableStream`) in [sse-and-streaming.md](sse-and-streaming.md); `generateStaticParams` and metadata in [routing-and-metadata.md](routing-and-metadata.md); Route Handler design in [route-handlers-and-apis.md](route-handlers-and-apis.md); auth, data exposure and Proxy in [proxy-auth-and-security.md](proxy-auth-and-security.md); Core Web Vitals and the Vercel platform in [performance-and-vercel.md](performance-and-vercel.md). Entry point: [../nextjs.md](../nextjs.md).

Legend: every rule ends with a model label. *(Cache Components)* means `cacheComponents: true` is set in `next.config`; *(previous model)* means it is not; *(both models)* holds either way. `[new in 16]` and `[changed in 16]` mark an API that is new or changed in Next.js 16.

Rule map: RC-1 to RC-4 caching model and config; RC-5 to RC-12 Server and Client Components; RC-13 to RC-18 request-time APIs and dynamic rendering; RC-19 to RC-28 Cache Components caching; RC-29 to RC-31 previous-model caching; RC-32 to RC-37 invalidation; RC-38 to RC-42 streaming SSR; RC-43 and RC-44 memoization and waterfalls; RC-45 to RC-47 other Cache Components behaviour changes.

## Rules

1. **RC-1** Detect the caching model before applying any caching rule: if `next.config.*` sets `cacheComponents: true`, the Cache Components rules apply; without it, the previous model applies (`fetch` options, `unstable_cache` and the route segment config `dynamic`, `revalidate` and `fetchCache`). *(both models)* ([Caching](https://nextjs.org/docs/app/getting-started/caching); [Caching and Revalidating, Previous Model](https://nextjs.org/docs/app/guides/caching-without-cache-components))
2. **RC-2** Remove the `dynamic`, `revalidate`, `fetchCache` and `dynamicParams` exports when `cacheComponents` is enabled and replace them with the migration table in Patterns; return at least one param from `generateStaticParams` and call `notFound()` for unknown params instead of setting `dynamicParams = false`. *(Cache Components)* [changed in 16] ([Route Segment Config](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config); [Migrating to Cache Components](https://nextjs.org/docs/app/guides/migrating-to-cache-components); [dynamicParams](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/dynamicParams))
3. **RC-3** Replace `experimental.ppr`, the `experimental_ppr` segment export, `experimental.dynamicIO` and `experimental.useCache` with the single top-level `cacheComponents: true` flag, and treat enabling it as adopting a new model rather than a rename: it can surface build errors for uncached data outside `<Suspense>`. *(Cache Components)* [changed in 16] ([cacheComponents](https://nextjs.org/docs/app/api-reference/config/next-config-js/cacheComponents); [Upgrading to Version 16](https://nextjs.org/docs/app/guides/upgrading/version-16))
4. **RC-4** Keep Cache Components routes on the Node.js runtime: remove any deprecated `runtime = 'edge'` export and use Proxy for edge behaviour. *(Cache Components)* ([cacheComponents](https://nextjs.org/docs/app/api-reference/config/next-config-js/cacheComponents); [Migrating to Cache Components](https://nextjs.org/docs/app/guides/migrating-to-cache-components))
5. **RC-5** Leave layouts and pages as Server Components (the default) and add `'use client'` only to the specific interactive components that need state, event handlers, effects, browser-only APIs or custom hooks; built-in HTML such as `<details>` and `<form action>` needs no Client Component. *(both models)* ([Server and Client Components](https://nextjs.org/docs/app/getting-started/server-and-client-components); [Server and Client Boundary](https://nextjs.org/docs/app/guides/server-and-client-boundary))
6. **RC-6** Put `'use client'` at the very top of the file, above any imports (comments are fine), and only on the entry files that Server Components render: every module such a file imports joins the client bundle, so files inside that subtree do not need the directive. *(both models)* ([use client](https://nextjs.org/docs/app/api-reference/directives/use-client); [Server and Client Components](https://nextjs.org/docs/app/getting-started/server-and-client-components); [react.dev use client](https://react.dev/reference/rsc/use-client))
7. **RC-7** Pass only serializable props from a Server Component to a Client Component (primitives, plain objects, arrays, `Date`, `Map`, `Set`, typed arrays, Promises, JSX and Server Functions); never pass event handlers, other plain functions or class instances. *(both models)* ([Server and Client Components](https://nextjs.org/docs/app/getting-started/server-and-client-components); [Server and Client Boundary](https://nextjs.org/docs/app/guides/server-and-client-boundary); [react.dev use client](https://react.dev/reference/rsc/use-client))
8. **RC-8** Nest server-rendered UI inside a Client Component by passing it as `children` or another `ReactNode` prop from a Server Component; never import a Server Component into a `'use client'` file. *(both models)* ([Server and Client Components](https://nextjs.org/docs/app/getting-started/server-and-client-components); [Server and Client Boundary](https://nextjs.org/docs/app/guides/server-and-client-boundary))
9. **RC-9** Wrap React context in a `'use client'` provider component that takes `children`, and render the provider as deep as possible, around `{children}` and not around the whole `<html>` document. *(both models)* ([Server and Client Components](https://nextjs.org/docs/app/getting-started/server-and-client-components))
10. **RC-10** Wrap a third-party component that uses client-only features but lacks `'use client'` in your own `'use client'` file that re-exports it, then render that file from Server Components. *(both models)* ([Server and Client Components](https://nextjs.org/docs/app/getting-started/server-and-client-components))
11. **RC-11** Export compound-component parts such as `Menu.Item` as named exports when Server Components use them; static members of a Client Component are `undefined` across the boundary. *(both models)* ([Server and Client Boundary](https://nextjs.org/docs/app/guides/server-and-client-boundary))
12. **RC-12** Add `import 'server-only'` to modules that hold secrets or server-only logic so a client import fails the build, and expect only `NEXT_PUBLIC_`-prefixed environment variables in the client bundle (exposure rules: [proxy-auth-and-security.md](proxy-auth-and-security.md)). *(both models)* ([Server and Client Components](https://nextjs.org/docs/app/getting-started/server-and-client-components))
13. **RC-13** Await `cookies()`, `headers()`, `draftMode()`, `params` and `searchParams`, or read them with React `use` in a Client Component; synchronous access was removed in Next.js 16. *(both models)* [changed in 16] ([Upgrading to Version 16](https://nextjs.org/docs/app/guides/upgrading/version-16); [cookies](https://nextjs.org/docs/app/api-reference/functions/cookies); [headers](https://nextjs.org/docs/app/api-reference/functions/headers))
14. **RC-14** Expect any read of `cookies()`, `headers()` or `searchParams` in a layout or page to opt the whole route into dynamic rendering, and keep these reads out of routes that must be prerendered. *(previous model)* ([cookies](https://nextjs.org/docs/app/api-reference/functions/cookies); [page.js](https://nextjs.org/docs/app/api-reference/file-conventions/page); [Migrating to Cache Components](https://nextjs.org/docs/app/guides/migrating-to-cache-components))
15. **RC-15** Read `cookies()`, `headers()`, `searchParams` and unknown `params` inside a component wrapped in `<Suspense>` so the rest of the route prerenders into the static shell; a read outside any boundary is a blocking-route error. *(Cache Components)* ([Caching](https://nextjs.org/docs/app/getting-started/caching); [cookies](https://nextjs.org/docs/app/api-reference/functions/cookies); [Streaming](https://nextjs.org/docs/app/guides/streaming))
16. **RC-16** Pass the un-awaited `params`, `searchParams` or `cookies()` promise down to the component that needs the value and await it there (or `.then()` it) inside the `<Suspense>` boundary; never await it at the top of a layout or page. *(Cache Components)* ([Caching](https://nextjs.org/docs/app/getting-started/caching); [Streaming](https://nextjs.org/docs/app/guides/streaming))
17. **RC-17** Put `Math.random()`, `Date.now()`, `new Date()` and `crypto.randomUUID()` behind `await io()` (Next.js 16.3 and later; `await connection()` on earlier 16.x, or when the work must wait for a real user request) in a `<Suspense>`-wrapped component, or capture one shared value inside `'use cache'`. *(Cache Components)* ([io](https://nextjs.org/docs/app/api-reference/functions/io); [Caching](https://nextjs.org/docs/app/getting-started/caching); [connection](https://nextjs.org/docs/app/api-reference/functions/connection))
18. **RC-18** Replace `unstable_noStore()` with `await connection()` from `next/server`; under Cache Components remove it instead, since nothing is cached without `'use cache'`. *(both models)* ([unstable_noStore](https://nextjs.org/docs/app/api-reference/functions/unstable_noStore); [connection](https://nextjs.org/docs/app/api-reference/functions/connection); [Migrating to Cache Components](https://nextjs.org/docs/app/guides/migrating-to-cache-components))
19. **RC-19** Add `'use cache'` only to work that does not depend on runtime data and may be served from cache for a while, at the top of an async function, an async component or a file (a file-level directive caches every export, and every export must be async). *(Cache Components)* ([use cache](https://nextjs.org/docs/app/api-reference/directives/use-cache); [Revalidating](https://nextjs.org/docs/app/getting-started/revalidating); [Caching](https://nextjs.org/docs/app/getting-started/caching))
20. **RC-20** Call `cacheLife(...)` in every `'use cache'` scope, in the same function and never at module scope or in a shared helper, with exactly one call executing per invocation; without it the implicit `default` profile applies. *(Cache Components)* ([cacheLife](https://nextjs.org/docs/app/api-reference/functions/cacheLife); [Caching](https://nextjs.org/docs/app/getting-started/caching))
21. **RC-21** Choose a preset profile by change frequency (`seconds`, `minutes`, `hours`, `days`, `weeks`, `max`) or define a named custom profile in the `cacheLife` option of `next.config.ts`, and document any built-in profile you redefine. *(Cache Components)* ([cacheLife](https://nextjs.org/docs/app/api-reference/functions/cacheLife))
22. **RC-22** Treat `revalidate: 0`, an `expire` under 5 minutes, a `stale` under 30 seconds and the `seconds` profile as short-lived: wrap such a component in `<Suspense>` (it becomes a dynamic hole), and give any outer `'use cache'` that nests one an explicit `cacheLife`. *(Cache Components)* ([cacheLife](https://nextjs.org/docs/app/api-reference/functions/cacheLife))
23. **RC-23** Never call `cookies()` or `headers()` or read `searchParams` inside a `'use cache'` scope or any helper it calls; read them outside, pass the extracted values as arguments (they join the cache key), and never pass the un-awaited runtime promise in. *(Cache Components)* ([use cache](https://nextjs.org/docs/app/api-reference/directives/use-cache); [Caching](https://nextjs.org/docs/app/getting-started/caching))
24. **RC-24** Use `'use cache: private'` only when a function must read cookies, headers or `searchParams` directly and cannot be refactored to take them as arguments; its result is never stored in a server cache across requests and is excluded from the static shell. *(Cache Components)* ([use cache: private](https://nextjs.org/docs/app/api-reference/directives/use-cache-private); [use cache](https://nextjs.org/docs/app/api-reference/directives/use-cache))
25. **RC-25** Keep a cached function's arguments and return values serializable (no class instances, `URL` instances, symbols or functions), and pass `children` or Server Actions through a cached component without reading or calling them. *(Cache Components)* ([use cache](https://nextjs.org/docs/app/api-reference/directives/use-cache))
26. **RC-26** Pass data into a `'use cache'` scope only through arguments: `React.cache` values set outside a cache scope are not visible inside it. *(Cache Components)* ([use cache](https://nextjs.org/docs/app/api-reference/directives/use-cache); [Migrating to Cache Components](https://nextjs.org/docs/app/guides/migrating-to-cache-components))
27. **RC-27** Assume default `'use cache'` entries live in a per-instance in-memory store (often not reused between requests on serverless) and are scoped to one deployment; use `'use cache: remote'` only where a high hit rate justifies the extra network roundtrip. *(Cache Components)* ([use cache](https://nextjs.org/docs/app/api-reference/directives/use-cache); [use cache: remote](https://nextjs.org/docs/app/api-reference/directives/use-cache-remote); [Caching](https://nextjs.org/docs/app/getting-started/caching); [Vercel Runtime Cache](https://vercel.com/docs/caching/runtime-cache))
28. **RC-28** Tag every cached entry that a write or webhook must invalidate with `cacheTag(...)` inside its `'use cache'` scope (up to 128 tags per entry, 256 characters each, case-sensitive). *(Cache Components)* [stable in 16] ([cacheTag](https://nextjs.org/docs/app/api-reference/functions/cacheTag); [revalidateTag](https://nextjs.org/docs/app/api-reference/functions/revalidateTag); [Upgrading to Version 16](https://nextjs.org/docs/app/guides/upgrading/version-16))
29. **RC-29** Opt a `fetch` into the Data Cache explicitly with `cache: 'force-cache'` or `next: { revalidate: n }`, tag it with `next: { tags: [...] }`, and never combine `revalidate` with `cache: 'no-store'`. *(previous model)* [changed in 15] ([Caching and Revalidating, Previous Model](https://nextjs.org/docs/app/guides/caching-without-cache-components); [fetch](https://nextjs.org/docs/app/api-reference/functions/fetch); [Upgrading to Version 15](https://nextjs.org/docs/app/guides/upgrading/version-15))
30. **RC-30** Cache non-`fetch` work with `unstable_cache(fn, keyParts, { tags, revalidate })` only in repos without Cache Components, and prefer migrating it to `'use cache'`. *(previous model)* ([Caching and Revalidating, Previous Model](https://nextjs.org/docs/app/guides/caching-without-cache-components); [unstable_cache](https://nextjs.org/docs/app/api-reference/functions/unstable_cache); [Migrating to Cache Components](https://nextjs.org/docs/app/guides/migrating-to-cache-components))
31. **RC-31** Set route-level ISR with a literal `export const revalidate = <seconds>` (it must be statically analyzable) and treat `dynamic = 'force-dynamic'` and `'force-static'` as whole-route overrides; the lowest `revalidate` across a route's layouts, pages and fetches sets its frequency. *(previous model)* ([Caching and Revalidating, Previous Model](https://nextjs.org/docs/app/guides/caching-without-cache-components); [Incremental Static Regeneration](https://nextjs.org/docs/app/guides/incremental-static-regeneration))
32. **RC-32** Pass a profile as the second argument to every `revalidateTag` call: `'max'` for stale-while-revalidate, or `{ expire: 0 }` to stop serving stale data; the one-argument form is deprecated (a TypeScript error) and behaves like `{ expire: 0 }`. *(both models)* [changed in 16] ([revalidateTag](https://nextjs.org/docs/app/api-reference/functions/revalidateTag); [Upgrading to Version 16](https://nextjs.org/docs/app/guides/upgrading/version-16); [Next.js 16](https://nextjs.org/blog/next-16))
33. **RC-33** Call `updateTag` and `refresh` only inside Server Actions (`updateTag` throws anywhere else, and neither can be used in Route Handlers or Client Components); from a Route Handler or webhook use `revalidateTag(tag, 'max')` or `revalidateTag(tag, { expire: 0 })`, and call none of `revalidateTag`, `revalidatePath`, `updateTag` or `refresh` from a Client Component or Proxy. *(both models)* [new in 16] ([updateTag](https://nextjs.org/docs/app/api-reference/functions/updateTag); [refresh](https://nextjs.org/docs/app/api-reference/functions/refresh); [revalidateTag](https://nextjs.org/docs/app/api-reference/functions/revalidateTag); [revalidatePath](https://nextjs.org/docs/app/api-reference/functions/revalidatePath))
34. **RC-34** Call `updateTag(tag)` after a mutation whose result the same user must see next (read-your-own-writes), and run every invalidation before `redirect()`, which throws and skips the code after it. *(both models)* [new in 16] ([updateTag](https://nextjs.org/docs/app/api-reference/functions/updateTag); [Server Actions](https://nextjs.org/docs/app/guides/server-actions); [Migrating to Cache Components](https://nextjs.org/docs/app/guides/migrating-to-cache-components))
35. **RC-35** Prefer tag-based invalidation to `revalidatePath`; when you do use it, pass the route file path (the rewrite destination, never a `/page` or `/layout` suffix) and add `type` (`'page'` or `'layout'`) for a dynamic-segment pattern. *(both models)* ([Revalidating](https://nextjs.org/docs/app/getting-started/revalidating); [revalidatePath](https://nextjs.org/docs/app/api-reference/functions/revalidatePath); [How revalidation works](https://nextjs.org/docs/app/guides/how-revalidation-works))
36. **RC-36** Call `refresh()` in a Server Action when the action changed data that is not cached (not tag-addressable); it re-renders the current route without invalidating any cache entry. *(both models)* [new in 16] ([Server Actions](https://nextjs.org/docs/app/guides/server-actions); [refresh](https://nextjs.org/docs/app/api-reference/functions/refresh); [Next.js 16](https://nextjs.org/blog/next-16))
37. **RC-37** Configure a shared cache handler when self-hosting more than one instance: on-demand revalidation only reaches the instance that receives the call by default. *(both models)* ([How revalidation works](https://nextjs.org/docs/app/guides/how-revalidation-works); [Incremental Static Regeneration](https://nextjs.org/docs/app/guides/incremental-static-regeneration); hosting detail in [performance-and-vercel.md](performance-and-vercel.md))
38. **RC-38** Wrap each independently slow or request-time subtree in its own `<Suspense fallback={...}>` placed close to the access, so siblings stream in parallel; use `loading.tsx` only when nothing meaningful renders before the page's data. *(both models)* ([Streaming](https://nextjs.org/docs/app/guides/streaming); [loading.js](https://nextjs.org/docs/app/api-reference/file-conventions/loading); [Caching](https://nextjs.org/docs/app/getting-started/caching); [Next.js on Vercel](https://vercel.com/docs/frameworks/full-stack/nextjs))
39. **RC-39** Keep uncached or runtime reads out of a segment's `layout.tsx`, or wrap them in their own `<Suspense>`: `loading.tsx` wraps the page and nested layouts, not the layout in the same segment. *(both models)* ([loading.js](https://nextjs.org/docs/app/api-reference/file-conventions/loading))
40. **RC-40** Decide the HTTP status before streaming starts: call `notFound()` or `redirect()` before any `await` that may suspend and before any `<Suspense>` boundary, or run the check in Proxy; once the first chunk is sent the status is fixed at `200`. *(both models)* ([Streaming](https://nextjs.org/docs/app/guides/streaming); [loading.js](https://nextjs.org/docs/app/api-reference/file-conventions/loading))
41. **RC-41** Keep the LCP element outside and above Suspense boundaries, size fallbacks to the final content to avoid layout shift, and add no boundary you do not need (Core Web Vitals detail: [performance-and-vercel.md](performance-and-vercel.md)). *(both models)* ([Streaming](https://nextjs.org/docs/app/guides/streaming); [react.dev Suspense](https://react.dev/reference/react/Suspense))
42. **RC-42** Make sure everything the static shell depends on is also available at request time, because HTML-limited bots skip the shell and render the whole page dynamically. *(Cache Components)* ([Caching](https://nextjs.org/docs/app/getting-started/caching); [Streaming](https://nextjs.org/docs/app/guides/streaming))
43. **RC-43** Distinguish request memoization from caching: identical `GET` `fetch` calls are memoized for one render pass and `React.cache` dedupes non-`fetch` calls within one request, but neither persists across requests, so use `'use cache'` (or the previous model's options) for that (usage patterns: [data-fetching-and-mutations.md](data-fetching-and-mutations.md)). *(both models)* ([fetch](https://nextjs.org/docs/app/api-reference/functions/fetch); [Fetching Data](https://nextjs.org/docs/app/getting-started/fetching-data); [Glossary](https://nextjs.org/docs/app/glossary))
44. **RC-44** Avoid render waterfalls: never await independent slow data one after another in the same component; give each independent part its own `<Suspense>` boundary or start the requests together (`Promise.all` and preload patterns: [data-fetching-and-mutations.md](data-fetching-and-mutations.md)). *(both models)* ([Fetching Data](https://nextjs.org/docs/app/getting-started/fetching-data); [Streaming](https://nextjs.org/docs/app/guides/streaming))
45. **RC-45** Expect `GET` Route Handlers to prerender like pages under Cache Components, and put cached data access in a separate `'use cache'` helper that the handler calls, because the directive cannot go on the `GET` export itself (handler design: [route-handlers-and-apis.md](route-handlers-and-apis.md)). *(Cache Components)* ([Caching](https://nextjs.org/docs/app/getting-started/caching); [Migrating to Cache Components](https://nextjs.org/docs/app/guides/migrating-to-cache-components))
46. **RC-46** Reset UI state explicitly wherever code relied on unmounting: with Cache Components, navigation hides routes with React `<Activity>` instead of unmounting them, so state and form inputs survive back-and-forth navigation. *(Cache Components)* ([cacheComponents](https://nextjs.org/docs/app/api-reference/config/next-config-js/cacheComponents); [Migrating to Cache Components](https://nextjs.org/docs/app/guides/migrating-to-cache-components))
47. **RC-47** Adopt Cache Components incrementally with `export const instant = false` on the segments not yet converted, never by keeping the removed segment config; it does not clear synchronous-IO build errors. *(Cache Components)* ([Migrating to Cache Components](https://nextjs.org/docs/app/guides/migrating-to-cache-components); [instant](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/instant))

## Patterns

### Detect the caching model

```bash
grep -nE "cacheComponents[[:space:]]*:[[:space:]]*true" next.config.* 2>/dev/null
```

A hit means Cache Components (RC-1). No hit does not prove the previous model: read `next.config.*` for a flag set through a variable before you pick a model.

### Rendering strategies per model

| Strategy | Previous model | Cache Components |
| --- | --- | --- |
| Prerendered (static) | The default when the route reads no request-time API: a `fetch` with no `cache` option runs once during `next build` | Predictable work, `'use cache'` results and `<Suspense>` fallbacks form the static shell |
| Dynamic (request time) | A `cookies()`, `headers()` or `searchParams` read, `cache: 'no-store'`, `revalidate = 0`, `dynamic = 'force-dynamic'` or `connection()` | Everything not cached; it must sit under `<Suspense>` |
| ISR | `export const revalidate = n`, or `fetch` with `next.revalidate`, usually with `generateStaticParams` | `cacheLife` revalidate with `generateStaticParams`; unknown params get the App Shell first (with `partialPrefetching`), then the page upgrades |
| Partial Prerendering | Not available: the experimental flag was removed in 16 | The default: a static shell plus streamed dynamic holes in one response |

### Enable Cache Components

```ts
// next.config.ts
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  cacheComponents: true,
}

export default nextConfig
```

### Cache data with a lifetime and a tag

```ts
// app/lib/products.ts
import { cacheLife, cacheTag } from 'next/cache'
import { db } from '@/lib/db' // your data layer: a placeholder, not a Next.js API

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

### Static, cached and streaming in one page

```tsx
// app/blog/page.tsx
import { Suspense } from 'react'
import { cookies } from 'next/headers'
import { cacheLife, cacheTag } from 'next/cache'

export default function BlogPage() {
  return (
    <>
      <h1>Our Blog</h1> {/* static: prerendered into the shell */}
      <BlogPosts /> {/* cached: part of the shell */}
      <Suspense fallback={<p>Loading your preferences...</p>}>
        <UserPreferences /> {/* runtime: streams at request time */}
      </Suspense>
    </>
  )
}

type Post = { id: string; title: string }

async function BlogPosts() {
  'use cache'
  cacheLife('hours')
  cacheTag('posts')
  const res = await fetch('https://api.vercel.app/blog')
  const posts: Post[] = await res.json()
  return <ul>{posts.map((post) => <li key={post.id}>{post.title}</li>)}</ul>
}

async function UserPreferences() {
  const theme = (await cookies()).get('theme')?.value ?? 'light'
  return <p>Your theme: {theme}</p>
}
```

### Pass runtime values into a cache as arguments

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

### Push dynamic access down to widen the static shell

```tsx
// app/shop/[slug]/layout.tsx: not async, never awaits params
import { Suspense } from 'react'
import { Sidebar } from './sidebar'

export default function Layout({ children, params }: LayoutProps<'/shop/[slug]'>) {
  return (
    <div>
      <Sidebar />
      <Suspense fallback={<h1>Loading...</h1>}>
        {params.then(({ slug }) => (
          <SlugHeading slug={slug} />
        ))}
      </Suspense>
      {children}
    </div>
  )
}

function SlugHeading({ slug }: { slug: string }) {
  return <h1>{slug}</h1>
}
```

### Non-deterministic values

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
  await io() // below Next.js 16.3: await connection() from 'next/server'
  return <p>{new Date().toISOString()}</p>
}
```

### Server and Client composition

A Client Component takes server-rendered UI as `children` (RC-8):

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

A context provider is a `'use client'` wrapper rendered around `{children}` (RC-9):

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

### Invalidate after a write

| API | Call from | What it does to the cache | What the user sees | Use when |
| --- | --- | --- | --- | --- |
| `updateTag(tag)` | Server Actions only (throws elsewhere) | Expires the tag immediately; the next read waits for fresh data | The action's response carries the re-rendered current route with fresh data, in one roundtrip | Read-your-own-writes: forms and settings |
| `revalidateTag(tag, 'max')` | Server Actions and Route Handlers | Marks the tag stale (stale-while-revalidate); `{ expire: 0 }` expires it immediately | No re-render in the action response; stale content until a later request finishes revalidating | Content where a short delay is fine; webhooks |
| `revalidatePath(path, type?)` | Server Functions and Route Handlers | Invalidates cached data for that route path | From a Server Function the UI updates at once on that path (it also refreshes previously visited pages on their next visit, which the docs call temporary); from a Route Handler, on the next visit | One route is affected and tagging is overkill |
| `refresh()` | Server Actions only | Invalidates nothing; refetches the current route's RSC Payload | The current route re-rendered in the same roundtrip; cached parts unchanged | The action changed uncached data shown on the page |

Calling any of these from a Server Action clears the whole client router cache and bypasses `stale` ([cacheLife](https://nextjs.org/docs/app/api-reference/functions/cacheLife)).

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
  // validate formData first: see data-fetching-and-mutations.md
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

```ts
// app/api/revalidate/route.ts: a webhook cannot use updateTag
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

### Return a real 404 before streaming starts

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

Awaiting `params` at the top makes the page request-bound for params that `generateStaticParams` does not return ([Caching](https://nextjs.org/docs/app/getting-started/caching)). The alternative is to run the existence check in Proxy ([loading.js](https://nextjs.org/docs/app/api-reference/file-conventions/loading), Status Codes).

### Previous model: ISR with tagged fetch

```tsx
// app/blog/page.tsx: repo WITHOUT cacheComponents
export const revalidate = 3600 // regenerate at most hourly (a statically analyzable literal)

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

### Migrate from the previous model

| Previous model | Under Cache Components |
| --- | --- |
| `dynamic = 'force-dynamic'` | Remove it; dynamic is the default |
| `dynamic = 'force-static'` | Remove it; add `'use cache'` with `cacheLife('max')` near the data |
| `revalidate = n` | `'use cache'` with `cacheLife(profile)` |
| `fetchCache` | Remove it; fetches inside `'use cache'` are cached |
| `fetch(url, { cache: 'force-cache', next: { revalidate, tags } })` | A `'use cache'` function with `cacheLife` and `cacheTag` |
| `unstable_cache(fn, keys, { tags, revalidate })` | A `'use cache'` function with `cacheLife` and `cacheTag` |
| `unstable_noStore()` | Remove it; use `connection()` with `<Suspense>` if the work must run per request |
| `dynamicParams = false` | Delete it and call `notFound()` for unknown params |
| `generateStaticParams` returning `[]` | Return at least one param |
| `experimental_ppr` or `experimental.ppr` | Remove it and set `cacheComponents: true` |
| `runtime = 'edge'` | Remove it; the Node.js runtime is required |

## Anti-patterns

### Don't mark a whole page `'use client'` for one widget (RC-5)

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

**Do:** keep the page a Server Component; the directive lives only in `quantity-picker.tsx`.

```tsx
import { ProductDetails } from './product-details'
import { QuantityPicker } from './quantity-picker' // a 'use client' file

export default function ProductPage() {
  return (
    <main>
      <ProductDetails />
      <QuantityPicker />
    </main>
  )
}
```

### Don't pass a plain function from a Server Component (RC-7)

```tsx
// Server Component
import { Counter } from './counter'

export default function Page() {
  return <Counter onClick={() => console.log('clicked')} /> // throws: not serializable
}
```

**Do:** own the handler in the Client Component, or pass a `'use server'` Server Action.

```tsx
'use client'

import { useState } from 'react'

export function Counter() {
  const [count, setCount] = useState(0)
  return <button onClick={() => setCount(count + 1)}>{count}</button>
}
```

### Don't import a Server Component into a `'use client'` file (RC-8)

```tsx
'use client'
import { Cart } from './cart' // Cart joins the client bundle and runs in the browser

export function Modal() {
  return <div role="dialog"><Cart /></div>
}
```

**Do:** take it as `children`, as in Server and Client composition in Patterns.

```tsx
import { Modal } from './modal' // a 'use client' file that renders {children}
import { Cart } from './cart' // a Server Component

export default function Page() {
  return (
    <Modal title={<h2>Your cart</h2>}>
      <Cart />
    </Modal>
  )
}
```

### Don't read `cookies()` inside `'use cache'` (RC-23)

```tsx
import { cookies } from 'next/headers'

async function Recommendations() {
  'use cache'
  const userId = (await cookies()).get('uid')?.value // error: next-request-in-use-cache
  return <List items={await getRecommendations(userId)} />
}
```

**Do:** read the value outside the cache and pass it in; render `Recommendations` inside `<Suspense>`.

```tsx
import { cookies } from 'next/headers'
import { cacheLife } from 'next/cache'

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

### Don't await `cookies()` at the top of a layout under Cache Components (RC-16)

```tsx
import type { ReactNode } from 'react'
import { cookies } from 'next/headers'
import { Nav } from './nav' // your component

export default async function DashboardLayout({ children }: { children: ReactNode }) {
  const user = (await cookies()).get('user')?.value // the layout and its children leave the shell
  return <div><Nav user={user} />{children}</div>
}
```

**Do:** start the promise, and resolve it inside a boundary.

```tsx
import { Suspense, type ReactNode } from 'react'
import { cookies } from 'next/headers'
import { Nav } from './nav' // your component

export default function DashboardLayout({ children }: { children: ReactNode }) {
  const cookieStore = cookies() // start the work, do not await
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

async function UserMenu({ cookiePromise }: { cookiePromise: ReturnType<typeof cookies> }) {
  const user = (await cookiePromise).get('user')?.value ?? 'guest'
  return <span>{user}</span>
}
```

### Don't call `updateTag` or a one-argument `revalidateTag` in a Route Handler (RC-32, RC-33)

```ts
import { revalidateTag, updateTag } from 'next/cache'

export async function POST(): Promise<Response> {
  updateTag('posts') // throws: Server Actions only
  revalidateTag('posts') // deprecated one-argument form, behaves like { expire: 0 }
  return Response.json({ ok: true })
}
```

**Do:** pass a profile to `revalidateTag`.

```ts
import { revalidateTag } from 'next/cache'

export async function POST(): Promise<Response> {
  revalidateTag('posts', 'max')
  return Response.json({ ok: true })
}
```

### Don't decide "not found" after streaming started (RC-40)

```tsx
import { Suspense } from 'react'
import { notFound } from 'next/navigation'

export default function PostPage({ params }: PageProps<'/post/[slug]'>) {
  return (
    <Suspense fallback={<p>Loading...</p>}>
      <Post params={params} /> {/* notFound() in here: status 200 plus a noindex meta tag, not 404 */}
    </Suspense>
  )
}

async function Post({ params }: Pick<PageProps<'/post/[slug]'>, 'params'>) {
  const { slug } = await params
  if (!(await postExists(slug))) notFound()
  return <PostContent slug={slug} />
}
```

**Do:** check existence before any boundary.

```tsx
import { Suspense } from 'react'
import { notFound } from 'next/navigation'

export default async function PostPage({ params }: PageProps<'/post/[slug]'>) {
  const { slug } = await params
  if (!(await postExists(slug))) notFound()
  return <Suspense fallback={<p>Loading...</p>}><PostContent slug={slug} /></Suspense>
}
```

### Don't keep route segment caching config with `cacheComponents` on (RC-2)

```tsx
export const dynamic = 'force-static' // errors under Cache Components
export const revalidate = 3600

export default async function Page() {
  const data = await getData()
  return <div>{data.title}</div>
}
```

**Do:** cache with the directive and a lifetime.

```tsx
import { cacheLife } from 'next/cache'

export default async function Page() {
  'use cache'
  cacheLife('hours')
  const data = await getData()
  return <div>{data.title}</div>
}
```

### Don't nest a short-lived cache in `'use cache'` without an explicit `cacheLife` (RC-22)

```tsx
import { ShortLivedWidget } from '@/components/short-lived-widget' // calls cacheLife('seconds')

export default async function Page() {
  'use cache' // no cacheLife: the nested short-lived cache fails the build during prerender
  return <ShortLivedWidget />
}
```

**Do:** give the outer cache an explicit lifetime.

```tsx
import { cacheLife } from 'next/cache'
import { ShortLivedWidget } from '@/components/short-lived-widget'

export default async function Page() {
  'use cache'
  cacheLife('default') // explicit: the page stays prerendered
  return <ShortLivedWidget />
}
```

## Version notes

Changes to this topic in **Next.js 16** (16.0.0 to 16.3.x):

- 16.0.0 introduced `cacheComponents`, one flag that unifies `ppr`, `useCache` and `dynamicIO`; `experimental.ppr`, `experimental_ppr`, `experimental.dynamicIO` and `experimental.useCache` were removed ([cacheComponents](https://nextjs.org/docs/app/api-reference/config/next-config-js/cacheComponents); [Upgrading to Version 16](https://nextjs.org/docs/app/guides/upgrading/version-16); [Next.js 16](https://nextjs.org/blog/next-16)).
- 16.0.0 made Partial Prerendering the default with Cache Components, and it works differently from the Next.js 15 canary versions ([cacheComponents](https://nextjs.org/docs/app/api-reference/config/next-config-js/cacheComponents); [Upgrading to Version 16](https://nextjs.org/docs/app/guides/upgrading/version-16); [Next.js on Vercel](https://vercel.com/docs/frameworks/full-stack/nextjs)).
- 16.0.0 enabled `'use cache'` (experimental since 15.0.0) with Cache Components, together with `'use cache: private'` and `'use cache: remote'` ([use cache](https://nextjs.org/docs/app/api-reference/directives/use-cache); [use cache: private](https://nextjs.org/docs/app/api-reference/directives/use-cache-private); [use cache: remote](https://nextjs.org/docs/app/api-reference/directives/use-cache-remote)).
- 16.0.0 made `cacheLife` and `cacheTag` stable, so the `unstable_` prefix is no longer needed ([Upgrading to Version 16](https://nextjs.org/docs/app/guides/upgrading/version-16)).
- 16.0.0 made the second argument of `revalidateTag(tag, profile)` required and deprecated the one-argument form ([Upgrading to Version 16](https://nextjs.org/docs/app/guides/upgrading/version-16); [Next.js 16](https://nextjs.org/blog/next-16)).
- 16.0.0 added the Server-Actions-only `updateTag` and `refresh` ([Upgrading to Version 16](https://nextjs.org/docs/app/guides/upgrading/version-16); [Next.js 16](https://nextjs.org/blog/next-16)).
- 16.0.0 removed synchronous access to `cookies()`, `headers()`, `draftMode()`, `params` and `searchParams` ([Upgrading to Version 16](https://nextjs.org/docs/app/guides/upgrading/version-16)).
- 16.0.0 removed `dynamic`, `dynamicParams`, `revalidate` and `fetchCache` when Cache Components is enabled ([Route Segment Config](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config)).
- 16.0.0 replaced `unstable_cache` with `'use cache'` ([unstable_cache](https://nextjs.org/docs/app/api-reference/functions/unstable_cache)).
- With Cache Components, routes are preserved with React `<Activity>` across navigations instead of being unmounted ([cacheComponents](https://nextjs.org/docs/app/api-reference/config/next-config-js/cacheComponents)).
- 16.3.0 added `io()` ([io](https://nextjs.org/docs/app/api-reference/functions/io)).
- 16.3 added Partial Prefetching (`partialPrefetching`, which requires `cacheComponents`), Instant Insights, the Navigation Inspector, and ISR with Cache Components that serves the App Shell for unlisted params ([Next.js 16.3](https://nextjs.org/blog/next-16-3); [partialPrefetching](https://nextjs.org/docs/app/api-reference/config/next-config-js/partialPrefetching); [ISR with Cache Components](https://nextjs.org/docs/app/guides/incremental-static-regeneration-cache-components)).
- 16.x added the `instant` route segment export, which works only with Cache Components ([instant](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/instant)).

Earlier, as the upgrade guides state it:

- 15.0 stopped caching `fetch` requests and `GET` Route Handlers by default, stopped the Client Cache from reusing page segments on `<Link>` navigation, and made Request-time APIs async with temporary synchronous access ([Upgrading to Version 15](https://nextjs.org/docs/app/guides/upgrading/version-15)).
- 15.0.0 stabilized `connection()` and deprecated `unstable_noStore` in its favour ([connection](https://nextjs.org/docs/app/api-reference/functions/connection); [unstable_noStore](https://nextjs.org/docs/app/api-reference/functions/unstable_noStore)).

## Review checklist

- [ ] The caching model was read from `next.config` and every caching change follows that model (RC-1).
- [ ] No `dynamic`, `revalidate`, `fetchCache`, `dynamicParams`, `experimental_ppr` or `runtime = 'edge'` export in a Cache Components repo, and `generateStaticParams` returns at least one param (RC-2, RC-3, RC-4).
- [ ] `'use client'` sits only on interactive leaves, as the first line of the file (RC-5, RC-6).
- [ ] Props into Client Components are serializable, with no function props except Server Actions (RC-7).
- [ ] Server UI is nested through `children` or slots and never imported into a `'use client'` file (RC-8).
- [ ] Providers are `'use client'` wrappers around `{children}`, rendered as deep as possible (RC-9).
- [ ] Server-only modules import `server-only`, and no secret sits in a `NEXT_PUBLIC_` variable (RC-12).
- [ ] `cookies()`, `headers()`, `draftMode()`, `params` and `searchParams` are awaited (RC-13).
- [ ] Under Cache Components, runtime reads sit inside `<Suspense>` and not at the top of a layout or page (RC-15, RC-16).
- [ ] `Math.random()`, `Date.now()`, `new Date()` and `crypto.randomUUID()` sit behind `io()` or `connection()` plus `<Suspense>`, or inside `'use cache'` (RC-17).
- [ ] Every `'use cache'` scope has its own `cacheLife` call, and a `cacheTag` when a write must invalidate it (RC-20, RC-28).
- [ ] No `cookies()`, `headers()` or `searchParams` read, and no runtime promise, reaches a cached scope (RC-23).
- [ ] Short-lived caches sit under `<Suspense>`, and outer caches that nest them set an explicit `cacheLife` (RC-22).
- [ ] In the previous model, `fetch` caching is explicit and never combines `revalidate` with `no-store` (RC-29, RC-31).
- [ ] `revalidateTag` has a profile, `updateTag` and `refresh` run only in Server Actions, and invalidation comes before `redirect()` (RC-32, RC-33, RC-34).
- [ ] Each slow subtree has its own `<Suspense>` near the access, and no layout read hides behind `loading.tsx` (RC-38, RC-39).
- [ ] `notFound()` and `redirect()` calls that need a real status run before any suspending `await` or `<Suspense>`, and the LCP element sits outside boundaries (RC-40, RC-41).

## Not confirmed by the docs

- The path `https://nextjs.org/docs/app/getting-started/cache-components` is not a docs page: it returned the docs "Page Not Found" Markdown in 16.3.8 (as inline code, not a link). The Cache Components overview lives at [Caching](https://nextjs.org/docs/app/getting-started/caching), which this file cites instead.
- Which 16.x minor introduced the `instant` export, and whether it is stable: [instant](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/instant) lists `v16.x.x` and calls only the validation-level tuning experimental; [Migrating to Cache Components](https://nextjs.org/docs/app/guides/migrating-to-cache-components) and [Next.js 16.3](https://nextjs.org/blog/next-16-3) were checked too.
- Whether `'use cache: remote'` entries survive a redeploy on Vercel: [Vercel Runtime Cache](https://vercel.com/docs/caching/runtime-cache) says its data persists across deployments, while [use cache](https://nextjs.org/docs/app/api-reference/directives/use-cache) and [use cache: remote](https://nextjs.org/docs/app/api-reference/directives/use-cache-remote) say the cache key includes the build or deployment ID. This file states only the Next.js key behaviour (RC-27).
- Synchronous `searchParams` access: [page.js](https://nextjs.org/docs/app/api-reference/file-conventions/page) still says it works "in Next.js 15", while [Upgrading to Version 16](https://nextjs.org/docs/app/guides/upgrading/version-16) says it is removed. This file follows the upgrade guide (RC-13); [Next.js 16](https://nextjs.org/blog/next-16) was checked too.
- How `refresh()` differs from client-side `router.refresh()` beyond "complementary": not documented in detail in [refresh](https://nextjs.org/docs/app/api-reference/functions/refresh), [Server Actions](https://nextjs.org/docs/app/guides/server-actions) or [Next.js 16](https://nextjs.org/blog/next-16).

## Sources

- https://nextjs.org/blog/september-2026-security-release — names v16.3.8 as Active LTS, the as-of version
- https://nextjs.org/docs/app/getting-started/server-and-client-components — Server and Client Components
- https://nextjs.org/docs/app/guides/server-and-client-boundary — Server and Client Boundary
- https://nextjs.org/docs/app/api-reference/directives/use-client — `use client`
- https://nextjs.org/docs/app/getting-started/caching — Caching (Cache Components)
- https://nextjs.org/docs/app/api-reference/config/next-config-js/cacheComponents — `cacheComponents`
- https://nextjs.org/docs/app/api-reference/directives/use-cache — `use cache`
- https://nextjs.org/docs/app/api-reference/directives/use-cache-private — `use cache: private`
- https://nextjs.org/docs/app/api-reference/directives/use-cache-remote — `use cache: remote`
- https://nextjs.org/docs/app/api-reference/functions/cacheLife — `cacheLife`
- https://nextjs.org/docs/app/api-reference/functions/cacheTag — `cacheTag`
- https://nextjs.org/docs/app/getting-started/revalidating — Revalidating
- https://nextjs.org/docs/app/api-reference/functions/revalidateTag — `revalidateTag`
- https://nextjs.org/docs/app/api-reference/functions/updateTag — `updateTag`
- https://nextjs.org/docs/app/api-reference/functions/revalidatePath — `revalidatePath`
- https://nextjs.org/docs/app/api-reference/functions/refresh — `refresh`
- https://nextjs.org/docs/app/guides/server-actions — Server Actions guide
- https://nextjs.org/docs/app/guides/how-revalidation-works — How revalidation works
- https://nextjs.org/docs/app/guides/caching-without-cache-components — Caching and Revalidating (Previous Model)
- https://nextjs.org/docs/app/guides/migrating-to-cache-components — Migrating to Cache Components
- https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config — Route Segment Config
- https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/dynamicParams — `dynamicParams`
- https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/instant — `instant`
- https://nextjs.org/docs/app/api-reference/functions/connection — `connection`
- https://nextjs.org/docs/app/api-reference/functions/io — `io`
- https://nextjs.org/docs/app/api-reference/functions/cookies — `cookies`
- https://nextjs.org/docs/app/api-reference/functions/headers — `headers`
- https://nextjs.org/docs/app/api-reference/file-conventions/page — `page.js`
- https://nextjs.org/docs/app/api-reference/functions/fetch — `fetch`
- https://nextjs.org/docs/app/guides/streaming — Streaming
- https://nextjs.org/docs/app/api-reference/file-conventions/loading — `loading.js`
- https://nextjs.org/docs/app/getting-started/fetching-data — Fetching Data
- https://nextjs.org/docs/app/guides/incremental-static-regeneration — Incremental Static Regeneration
- https://nextjs.org/docs/app/guides/incremental-static-regeneration-cache-components — ISR with Cache Components
- https://nextjs.org/docs/app/api-reference/functions/unstable_cache — `unstable_cache`
- https://nextjs.org/docs/app/api-reference/functions/unstable_noStore — `unstable_noStore`
- https://nextjs.org/docs/app/api-reference/config/next-config-js/partialPrefetching — `partialPrefetching`
- https://nextjs.org/docs/app/glossary — Glossary
- https://nextjs.org/docs/app/guides/upgrading/version-16 — Upgrading to Version 16
- https://nextjs.org/docs/app/guides/upgrading/version-15 — Upgrading to Version 15
- https://nextjs.org/blog/next-16 — Next.js 16 release post
- https://nextjs.org/blog/next-16-3 — Next.js 16.3 release post
- https://vercel.com/docs/frameworks/full-stack/nextjs — Next.js on Vercel
- https://vercel.com/docs/caching/runtime-cache — Vercel Runtime Cache
- https://react.dev/reference/rsc/use-client — React `use client` directive
- https://react.dev/reference/react/Suspense — React `Suspense`
