# App Router routing, navigation and metadata

> As of Next.js 16.3.8, verified 2026-10-04.

## Scope

This file covers:

- the App Router file conventions;
- dynamic, catch-all and optional catch-all segments;
- route groups and private folders;
- parallel routes and intercepting routes;
- `generateStaticParams` and `dynamicParams`;
- navigation with `<Link>`, the `next/navigation` hooks, `redirect()`, `permanentRedirect()` and `notFound()`, and prefetching;
- the Metadata API: static `metadata`, `generateMetadata`, `generateViewport`, and the file-based icons, Open Graph images, `sitemap.ts` and `robots.ts`.

It maps the canonical layout in [../nextjs.md](../nextjs.md) onto these conventions and never redefines that layout. Other topics own the following:

| Topic | File |
| --- | --- |
| Rendering, caching and Suspense semantics | [rendering-and-caching.md](rendering-and-caching.md) |
| Error-handling strategy (`error.tsx`, `global-error.tsx`) | [testing-and-observability.md](testing-and-observability.md) |
| `route.ts` internals | [route-handlers-and-apis.md](route-handlers-and-apis.md) |
| Proxy redirects and auth | [proxy-auth-and-security.md](proxy-auth-and-security.md) |
| Type generation and `typedRoutes` setup | [typescript.md](typescript.md) |
| Server Action mutations | [data-fetching-and-mutations.md](data-fetching-and-mutations.md) |

## Rules

1. **RT-1** Keep `src/app/` a routing layer in new projects (route folders, special files and metadata files only). Put feature code in `src/features/<feature>/` and cross-feature code in `src/shared/`, as the canonical layout in [../nextjs.md](../nextjs.md) does (convention). This is the docs' "store project files outside of `app`" strategy, and the [`src` folder](https://nextjs.org/docs/app/api-reference/file-conventions/src-folder) is supported ([project structure](https://nextjs.org/docs/app/getting-started/project-structure)).
2. **RT-2** Keep `public/`, `package.json`, `next.config.ts`, `tsconfig.json` and `.env*` files at the project root. Put `proxy.ts` inside `src/`, and add `src/` to the `@/*` path alias ([src folder](https://nextjs.org/docs/app/api-reference/file-conventions/src-folder)).
3. **RT-3** Make a segment public only by adding `page.tsx` (UI) or `route.ts` (API), and never put both in the same segment. Other files colocated in `app/` are never routable ([project structure](https://nextjs.org/docs/app/getting-started/project-structure), [Route Handlers](https://nextjs.org/docs/app/getting-started/route-handlers)).
4. **RT-4** Define the required root layout `app/layout.tsx` with `<html>` and `<body>`. Never hand-write `<head>`, `<title>` or `<meta>` tags; use the Metadata API, which handles streaming and de-duplication of head elements ([layout.js](https://nextjs.org/docs/app/api-reference/file-conventions/layout)).
5. **RT-5** Use a route group `(name)` to share a layout across a subset of routes without changing URLs; `(auth)/login/page.tsx` serves `/login`. Never let two groups resolve to the same path. Define `/` inside a group when there is no top-level `layout.tsx`. Navigating between multiple root layouts is a full page load ([route groups](https://nextjs.org/docs/app/api-reference/file-conventions/route-groups)).
6. **RT-6** Prefix a folder with `_` (a private folder) when route-local helpers must live inside `app/` in an existing repo; this opts the folder and its subfolders out of routing. Use `%5F` to start a URL segment with an underscore ([project structure](https://nextjs.org/docs/app/getting-started/project-structure)).
7. **RT-7** Use `template.tsx` only when a segment's children must remount on navigation, to reset client state or re-run effects. Otherwise use `layout.tsx`, which keeps state. A template remounts when its own segment or its params change, not on search-param changes ([template.js](https://nextjs.org/docs/app/api-reference/file-conventions/template)).
8. **RT-8** Add `loading.tsx` to dynamic routes so navigation is immediate and the route can be partially prefetched. It doesn't cover uncached data the same segment's layout awaits (`cookies()`, `headers()`, uncached fetches). Wrap that data in its own `<Suspense>` or move it into the page; [rendering-and-caching.md](rendering-and-caching.md) has the details ([linking and navigating](https://nextjs.org/docs/app/getting-started/linking-and-navigating), [loading.js](https://nextjs.org/docs/app/api-reference/file-conventions/loading)).
9. **RT-9** Add `not-found.tsx` for `notFound()` UI; the root `app/not-found.tsx` also serves every unmatched URL. Place `error.tsx` and `global-error.tsx` following the strategy in [testing-and-observability.md](testing-and-observability.md); `global-error` must render its own `<html>` and `<body>`. Treat `forbidden.tsx` and `unauthorized.tsx` (behind `experimental.authInterrupts`) and `global-not-found.tsx` (behind `experimental.globalNotFound`) as experimental. The forbidden and unauthorized pages say they are not recommended for production ([not-found.js](https://nextjs.org/docs/app/api-reference/file-conventions/not-found), [error.js](https://nextjs.org/docs/app/api-reference/file-conventions/error), [forbidden.js](https://nextjs.org/docs/app/api-reference/file-conventions/forbidden), [unauthorized.js](https://nextjs.org/docs/app/api-reference/file-conventions/unauthorized)).
10. **RT-10** Name dynamic segments `[slug]` (one `string`), `[...slug]` (catch-all, `string[]`) and `[[...slug]]` (optional catch-all, `slug?: string[]`, which also matches the bare path), and type `params` to match ([dynamic routes](https://nextjs.org/docs/app/api-reference/file-conventions/dynamic-routes)).
11. **RT-11** Await `params` in pages, layouts, `route.ts`, `default.tsx` and the `opengraph-image`, `twitter-image`, `icon` and `apple-icon` files. Await `searchParams` in pages. Both are Promises, and Next.js 16 removed synchronous access ([version 16 upgrade](https://nextjs.org/docs/app/guides/upgrading/version-16), [page.js](https://nextjs.org/docs/app/api-reference/file-conventions/page)). `generateMetadata` awaits `params` too ([generateMetadata](https://nextjs.org/docs/app/api-reference/functions/generate-metadata)). In a Client Component page, unwrap them with React's [`use()`](https://react.dev/reference/react/use). Two documented exceptions take synchronous `params`: [`generateStaticParams`](https://nextjs.org/docs/app/api-reference/functions/generate-static-params) (the parent params) and [`generateImageMetadata`](https://nextjs.org/docs/app/api-reference/functions/generate-image-metadata).
12. **RT-12** Type route props with the generated global helpers `PageProps<'/route'>` and `LayoutProps<'/route'>`. They need no import, and they are generated by `next dev`, `next build` or `next typegen`; `LayoutProps` also types named slots ([layouts and pages](https://nextjs.org/docs/app/getting-started/layouts-and-pages)). Setup lives in [typescript.md](typescript.md).
13. **RT-13** Validate every `params` value at runtime before using it, because values arrive as `string`, `string[]` or `undefined` from any URL. Call `notFound()` on invalid values, narrowing with an assertion function ([dynamic routes](https://nextjs.org/docs/app/api-reference/file-conventions/dynamic-routes)).
14. **RT-14** Read root params, the dynamic segments above the root layout such as `app/[lang]/layout.tsx`, with the `next/root-params` getters (`await lang()`) in Server Components instead of prop drilling. They aren't available in Client Components, Server Actions or Route Handlers. Segment names must be valid JavaScript identifiers, so `[post-slug]` fails ([next/root-params](https://nextjs.org/docs/app/api-reference/functions/next-root-params), [Next.js 16.3](https://nextjs.org/blog/next-16-3)).
15. **RT-15** Export `generateStaticParams` from every dynamic segment whose values are known at build time (in a page, layout or `route.ts`), and always return an array. Omit it and the route renders dynamically at request time. Return `[]` to render every path on its first visit instead ([generateStaticParams](https://nextjs.org/docs/app/api-reference/functions/generate-static-params), [linking and navigating](https://nextjs.org/docs/app/getting-started/linking-and-navigating)).
16. **RT-16** Return at least one param from `generateStaticParams` when Cache Components (`cacheComponents: true`) is on, because an empty array is a build error. The documented escape hatch is a placeholder param handled with `notFound()`, and it weakens build-time validation ([generateStaticParams](https://nextjs.org/docs/app/api-reference/functions/generate-static-params)).
17. **RT-17** Export `dynamicParams = false` to 404 params that `generateStaticParams` did not return, but only while Cache Components is off. Next.js 16 removed `dynamicParams` (with `dynamic`, `revalidate` and `fetchCache`) when `cacheComponents` is enabled ([dynamicParams](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/dynamicParams), [route segment config](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config)).
18. **RT-18** Generate params for nested dynamic segments in one of two ways: bottom-up, where the leaf page returns every segment, or top-down, where the parent layout returns its own params and the child reads them from its synchronous `params` argument. A segment can generate params only for itself and the segments above it ([generateStaticParams](https://nextjs.org/docs/app/api-reference/functions/generate-static-params)).
19. **RT-19** Give every named `@slot` an explicit `default.tsx`, because Next.js 16 builds fail without one. Return `null` to render nothing, or call `notFound()` to keep the pre-16 404. Also add a `default.tsx` beside the slots for the implicit `children` slot. Without it, a hard navigation that can't recover the parent's active state renders a 404 ([version 16 upgrade](https://nextjs.org/docs/app/guides/upgrading/version-16), [default.js](https://nextjs.org/docs/app/api-reference/file-conventions/default), [parallel routes](https://nextjs.org/docs/app/api-reference/file-conventions/parallel-routes)).
20. **RT-20** Treat each `@slot` as a prop of the parent layout that never changes the URL. Authorize inside each slot's page or Data Access Layer, because every slot renders on the server even when the layout returns only one. Expect one dynamic slot to make every slot at its level dynamic ([parallel routes](https://nextjs.org/docs/app/api-reference/file-conventions/parallel-routes)).
21. **RT-21** Build URL-addressable modals by intercepting the real route inside a slot: `@modal/(.)photos/[id]/page.tsx` sits beside `photos/[id]/page.tsx`. The matchers are `(.)` same level, `(..)` one up, `(..)(..)` two up and `(...)` from the root `app`; they count route segments, so `@slot` folders don't count. Close the modal with `router.back()`, or with `<Link>` plus a slot `page.tsx` or `[...catchAll]/page.tsx` that returns `null`. A refresh or a shared URL renders the full page, not the modal ([intercepting routes](https://nextjs.org/docs/app/api-reference/file-conventions/intercepting-routes), [parallel routes](https://nextjs.org/docs/app/api-reference/file-conventions/parallel-routes)).
22. **RT-22** Navigate with `<Link href>` from `next/link`. Use `useRouter` only for programmatic navigation in Client Component event handlers. Never pass `router.push` or `router.replace` an untrusted or unsanitized URL, because a `javascript:` URL executes in the page. With `typedRoutes` on, cast non-literal hrefs with `as Route`; setup is in [typescript.md](typescript.md) ([Link](https://nextjs.org/docs/app/api-reference/components/link), [useRouter](https://nextjs.org/docs/app/api-reference/functions/use-router), [TypeScript](https://nextjs.org/docs/app/api-reference/config/typescript)).
23. **RT-23** Keep `<Link>`'s default prefetch (`"auto"` or `null`). It prefetches static routes in full and dynamic routes down to the nearest `loading.tsx`. Set `prefetch={false}` on large link lists such as infinite tables, or defer prefetching to hover. Judge prefetching only in production, because it is disabled in development. `<Link>` must hydrate before it can prefetch ([Link](https://nextjs.org/docs/app/api-reference/components/link), [linking and navigating](https://nextjs.org/docs/app/getting-started/linking-and-navigating), [prefetching](https://nextjs.org/docs/app/guides/prefetching)).
24. **RT-24** Keep layouts and pages free of side effects such as analytics calls, which can run when the route is prefetched rather than visited. Move them into a Client Component `useEffect` or a Server Action ([prefetching](https://nextjs.org/docs/app/guides/prefetching)).
25. **RT-25** Enable `partialPrefetching: true` only together with `cacheComponents: true`; without it, `next dev` and `next build` throw at config validation. Audit existing `<Link prefetch={true}>` links first, because their behavior changes. To opt in per segment, use `export const prefetch = 'partial'` or `'force-disabled'`; this needs Cache Components, and you never write `'auto'` explicitly ([partialPrefetching](https://nextjs.org/docs/app/api-reference/config/next-config-js/partialPrefetching), [adopting Partial Prefetching](https://nextjs.org/docs/app/guides/adopting-partial-prefetching), [prefetch segment config](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/prefetch), [Next.js 16.3](https://nextjs.org/blog/next-16-3)).
26. **RT-26** Import `useRouter`, `usePathname`, `useSearchParams` and `useParams` from `next/navigation`, never `next/router`, and read URL state in Client Components. Layouts do not re-render on navigation, so they can't read the pathname or the latest search params ([useRouter](https://nextjs.org/docs/app/api-reference/functions/use-router), [layout.js](https://nextjs.org/docs/app/api-reference/file-conventions/layout)).
27. **RT-27** Wrap every Client Component that calls `useSearchParams` in [`<Suspense>`](https://react.dev/reference/react/Suspense) on prerendered routes. Production builds fail without it, though development looks fine. With Cache Components, also wrap `usePathname` and `useParams` callers on routes whose params `generateStaticParams` doesn't cover ([useSearchParams](https://nextjs.org/docs/app/api-reference/functions/use-search-params), [usePathname](https://nextjs.org/docs/app/api-reference/functions/use-pathname), [useParams](https://nextjs.org/docs/app/api-reference/functions/use-params)).
28. **RT-28** Read `searchParams` from the page prop when the server needs them to load data. That prop is a plain object, not `URLSearchParams`, and it makes the page dynamic. Use `useSearchParams` only for state that exists only on the client ([layouts and pages](https://nextjs.org/docs/app/getting-started/layouts-and-pages), [page.js](https://nextjs.org/docs/app/api-reference/file-conventions/page)).
29. **RT-29** Call `useLinkStatus` only in a descendant of `<Link>`, to show a fixed-size pending hint while prefetching is off or incomplete. Treat it as a quick patch, and fix the cause with prefetching or `loading.tsx` ([useLinkStatus](https://nextjs.org/docs/app/api-reference/functions/use-link-status)).
30. **RT-30** Add `data-scroll-behavior="smooth"` to `<html>` only when the app sets a global `scroll-behavior: smooth` and wants Next.js to suspend it during navigation, because Next.js 16 no longer overrides it. Keep the scroll position with `scroll={false}` on `<Link>` or `{ scroll: false }` on `router.push` and `router.replace` ([version 16 upgrade](https://nextjs.org/docs/app/guides/upgrading/version-16), [Link](https://nextjs.org/docs/app/api-reference/components/link)).
31. **RT-31** Use `redirect()` for temporary redirects: 307, or 303 for a progressive-enhancement Server Action form post, and a client-side navigation when JavaScript is available. Use `permanentRedirect()` when an entity's canonical URL changes: 308. Call both outside `try`/`catch`, because they throw and are typed `never`, so `return redirect()` isn't needed. Never call `redirect()` from a Client Component event handler; use `router.push` there ([redirect](https://nextjs.org/docs/app/api-reference/functions/redirect), [permanentRedirect](https://nextjs.org/docs/app/api-reference/functions/permanentRedirect), [redirecting](https://nextjs.org/docs/app/guides/redirecting)).
32. **RT-32** Pick the redirect mechanism by when it runs: `redirects()` in `next.config.ts` for path maps known ahead of time (it runs before Proxy, and `permanent` selects 308 over 307), Proxy `NextResponse.redirect` for conditional redirects (see [proxy-auth-and-security.md](proxy-auth-and-security.md)), and for 1,000+ redirects the guide's Proxy-backed redirect map or Vercel [Bulk Redirects](https://vercel.com/docs/routing/redirects) ([redirecting](https://nextjs.org/docs/app/guides/redirecting)).
33. **RT-33** Call `notFound()` in the render path when a record is missing: in a component, a function it awaits, `generateMetadata` or a Route Handler. Never let a `try`/`catch` swallow it; let it through with `unstable_rethrow`. When the response must carry a real 404 status, run the existence check before any `<Suspense>` or `loading.tsx` streaming starts, because a streamed not-found is a `200` with `noindex` ([notFound](https://nextjs.org/docs/app/api-reference/functions/not-found), [loading.js](https://nextjs.org/docs/app/api-reference/file-conventions/loading)).
34. **RT-34** Export a static `metadata: Metadata` object unless metadata depends on request data or params. In that case, export `generateMetadata` instead. Never export both from one segment, and export them only from Server Components; move client logic into a child component ([generateMetadata](https://nextjs.org/docs/app/api-reference/functions/generate-metadata), [metadata and OG images](https://nextjs.org/docs/app/getting-started/metadata-and-og-images)).
35. **RT-35** Set `metadataBase` once in the root layout so relative URL fields (canonical, alternates, Open Graph images) resolve; relative URLs without it fail the build. Return it as a string from a `'use cache'` `generateMetadata`. Define `title.template` in layouts together with the required `title.default`, and use `title.absolute` to escape a parent template ([generateMetadata](https://nextjs.org/docs/app/api-reference/functions/generate-metadata)).
36. **RT-36** Fetch data that `generateMetadata` and the page share through one React [`cache()`](https://react.dev/reference/react/cache)-wrapped function. `fetch` is already memoized. Re-spread nested objects such as `openGraph` (or read `await parent`) when a child must keep the parent's fields: metadata merges shallowly, so a child's `openGraph` replaces the parent's ([metadata and OG images](https://nextjs.org/docs/app/getting-started/metadata-and-og-images), [generateMetadata](https://nextjs.org/docs/app/api-reference/functions/generate-metadata)).
37. **RT-37** Put `themeColor`, `colorScheme`, `width`, `initialScale` and the other viewport fields in `export const viewport: Viewport` or in `generateViewport`, never in `metadata`, where they have been deprecated since Next.js 14. Like metadata, these exports are Server-Component-only and you never export both from one segment ([generateViewport](https://nextjs.org/docs/app/api-reference/functions/generate-viewport), [generateMetadata](https://nextjs.org/docs/app/api-reference/functions/generate-metadata)).
38. **RT-38** Prefer file-based metadata to config. `favicon.ico` goes only at the root of `app/` and can't be generated. `icon`, `apple-icon`, `opengraph-image` and `twitter-image` (with `.alt.txt`) go in any segment. File-based metadata overrides `metadata` and `generateMetadata`, and a deeper `opengraph-image` takes precedence over one higher in the tree. Static OG images over 8 MB and Twitter images over 5 MB fail the build ([metadata and OG images](https://nextjs.org/docs/app/getting-started/metadata-and-og-images), [app icons](https://nextjs.org/docs/app/api-reference/file-conventions/metadata/app-icons), [opengraph-image](https://nextjs.org/docs/app/api-reference/file-conventions/metadata/opengraph-image), [Next.js 16.2](https://nextjs.org/blog/next-16-2)).
39. **RT-39** Generate `app/sitemap.ts` returning `MetadataRoute.Sitemap` and `app/robots.ts` returning `MetadataRoute.Robots`. These are special Route Handlers, cached unless they use a Request-time API. Split large sitemaps with nested `sitemap.ts` files or with `generateSitemaps`, and await its `id` prop, which is a `Promise<string>` in Next.js 16 ([sitemap](https://nextjs.org/docs/app/api-reference/file-conventions/metadata/sitemap), [robots](https://nextjs.org/docs/app/api-reference/file-conventions/metadata/robots), [generateSitemaps](https://nextjs.org/docs/app/api-reference/functions/generate-sitemaps), [version 16 upgrade](https://nextjs.org/docs/app/guides/upgrading/version-16)).
40. **RT-40** Generate dynamic Open Graph images in `opengraph-image.tsx` with `ImageResponse` from `next/og`. Export `alt`, `size` and `contentType`; Vercel recommends 1200x630. Await `params`, and `id` when you use `generateImageMetadata`. Stay within flexbox-only CSS, `ttf`, `otf` or `woff` fonts and the 500 KB bundle limit. Generated images are statically optimized unless they use Request-time APIs or uncached data ([opengraph-image](https://nextjs.org/docs/app/api-reference/file-conventions/metadata/opengraph-image), [ImageResponse](https://nextjs.org/docs/app/api-reference/functions/image-response), [generateImageMetadata](https://nextjs.org/docs/app/api-reference/functions/generate-image-metadata), [Vercel OG image generation](https://vercel.com/docs/og-image-generation)).

## Patterns

### Canonical layout mapped to routing conventions (RT-1, RT-2, RT-3, RT-5, RT-38, RT-39)

The layout below is canonical for new projects ([../nextjs.md](../nextjs.md)); an existing repo keeps its own.

| Canonical path | URL | Convention |
| --- | --- | --- |
| `src/app/layout.tsx` | wraps every route | root layout (RT-4) |
| `src/app/page.tsx` | `/` | page (RT-3) |
| `src/app/(auth)/layout.tsx` | none | route group layout: auth-only UI, URL unchanged (RT-5) |
| `src/app/(auth)/login/page.tsx` | `/login` | group omitted from the URL (RT-5) |
| `src/app/(dashboard)/dashboard/page.tsx` | `/dashboard` | group omitted from the URL (RT-5) |
| `src/app/api/webhooks/route.ts` | `/api/webhooks` | Route Handler; no `page.tsx` in the same segment (RT-3), see [route-handlers-and-apis.md](route-handlers-and-apis.md) |
| `src/proxy.ts` | none | Proxy lives inside `src/` (RT-2) |
| `public/`, `next.config.ts`, `tsconfig.json` | none | stay at the project root (RT-2) |

This topic adds these docs-confirmed files, which the tree doesn't show:

- `src/app/favicon.ico` (root only)
- `src/app/sitemap.ts`
- `src/app/robots.ts`
- `src/app/not-found.tsx`
- `loading.tsx` in dynamic segments
- `opengraph-image.tsx` per segment

### Dynamic segment with static params and a 404 for missing records (RT-11, RT-12, RT-15, RT-33)

```tsx
// src/app/blog/[slug]/page.tsx
import { notFound } from 'next/navigation'
import { getPost, getPublishedSlugs } from '@/features/blog/services/posts'

export async function generateStaticParams(): Promise<Array<{ slug: string }>> {
  const slugs = await getPublishedSlugs()
  return slugs.map((slug) => ({ slug }))
}

export default async function Page(props: PageProps<'/blog/[slug]'>) {
  const { slug } = await props.params
  const post = await getPost(slug)
  if (!post) {
    notFound()
  }
  return (
    <article>
      <h1>{post.title}</h1>
      <p>{post.body}</p>
    </article>
  )
}
```

`generateStaticParams` returns `{ slug }[]` for a single dynamic segment, `PageProps` and `await props.params` follow the layouts-and-pages guide, and `notFound()` without `return` narrows `post` because it is typed `never`.

### Shared, cached data and typed dynamic metadata (RT-34, RT-35, RT-36)

```ts
// src/features/blog/services/posts.ts (getPublishedSlugs and getPublishedPosts live here too)
import { cache } from 'react'
import { parsePost, type Post } from './post-schema'

export const getPost = cache(async (slug: string): Promise<Post | undefined> => {
  const res = await fetch(`https://api.example.com/posts/${encodeURIComponent(slug)}`)
  if (res.status === 404) return undefined
  if (!res.ok) throw new Error(`Failed to load post: ${res.status}`)
  const data: unknown = await res.json()
  return parsePost(data) // runtime validation: see typescript.md
})
```

```tsx
// src/app/blog/[slug]/page.tsx (add to the page above)
import type { Metadata } from 'next'

export async function generateMetadata(props: PageProps<'/blog/[slug]'>): Promise<Metadata> {
  const { slug } = await props.params
  const post = await getPost(slug) // same cache()d call as the page: fetched once
  if (!post) {
    notFound()
  }
  return {
    title: post.title, // rendered as "<title> | Acme" by the root title.template
    description: post.summary,
    alternates: { canonical: `/blog/${slug}` }, // resolved against metadataBase
  }
}
```

This follows the metadata guide's "Memoizing data requests", and the generateMetadata reference allows `notFound()` inside `generateMetadata`. `parsePost` and `Post` are local modules (convention); runtime validation is covered in [typescript.md](typescript.md).

### Root layout: metadataBase, title template and viewport (RT-4, RT-35, RT-37)

```tsx
// src/app/layout.tsx
import type { Metadata, Viewport } from 'next'
import './globals.css'

export const metadata: Metadata = {
  metadataBase: new URL('https://acme.com'),
  title: { template: '%s | Acme', default: 'Acme' },
  description: 'Acme app',
}

export const viewport: Viewport = {
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: 'white' },
    { media: '(prefers-color-scheme: dark)', color: 'black' },
  ],
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
```

### `sitemap.ts`, `robots.ts` and split sitemaps (RT-39)

```ts
// src/app/sitemap.ts
import type { MetadataRoute } from 'next'
import { getPublishedPosts } from '@/features/blog/services/posts'

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const posts = await getPublishedPosts()
  return [
    { url: 'https://acme.com', lastModified: new Date(), changeFrequency: 'yearly', priority: 1 },
    ...posts.map((post) => ({ url: `https://acme.com/blog/${post.slug}`, lastModified: post.updatedAt })),
  ]
}
```

```ts
// src/app/robots.ts
import type { MetadataRoute } from 'next'

export default function robots(): MetadataRoute.Robots {
  return {
    rules: { userAgent: '*', allow: '/', disallow: '/dashboard/' },
    sitemap: 'https://acme.com/sitemap.xml',
  }
}
```

```ts
// src/app/products/sitemap.ts (served at /products/sitemap/<id>.xml)
import type { MetadataRoute } from 'next'
import { getProductsPage } from '@/features/catalog/services/products'

const URLS_PER_SITEMAP = 50_000 // Google's per-sitemap limit, per the Next.js docs

export async function generateSitemaps(): Promise<Array<{ id: number }>> {
  return [{ id: 0 }, { id: 1 }]
}

export default async function sitemap(props: { id: Promise<string> }): Promise<MetadataRoute.Sitemap> {
  const page = Number(await props.id) // Next.js 16: id arrives as Promise<string>
  const products = await getProductsPage(page * URLS_PER_SITEMAP, URLS_PER_SITEMAP)
  return products.map((product) => ({
    url: `https://acme.com/products/${product.id}`,
    lastModified: product.updatedAt,
  }))
}
```

### Generated Open Graph image (RT-11, RT-40)

```tsx
// src/app/blog/[slug]/opengraph-image.tsx
import { ImageResponse } from 'next/og'
import { getPost } from '@/features/blog/services/posts'

export const alt = 'Acme blog post'
export const size = { width: 1200, height: 630 }
export const contentType = 'image/png'

export default async function Image({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const post = await getPost(slug)
  return new ImageResponse(
    (
      <div
        style={{
          fontSize: 64,
          background: 'white',
          width: '100%',
          height: '100%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {post?.title ?? 'Acme'}
      </div>
    ),
    { ...size }
  )
}
```

### Client Component reading and updating search params (RT-22, RT-26, RT-27, RT-28)

```tsx
// src/features/catalog/components/sort-select.tsx
'use client'

import { usePathname, useRouter, useSearchParams } from 'next/navigation'

const SORT_OPTIONS = ['newest', 'price-asc', 'price-desc'] as const
type SortOption = (typeof SORT_OPTIONS)[number]

function isSortOption(value: string): value is SortOption {
  return (SORT_OPTIONS as readonly string[]).includes(value)
}

export function SortSelect() {
  const router = useRouter()
  const pathname = usePathname()
  const searchParams = useSearchParams()
  const raw = searchParams.get('sort') ?? ''
  const current: SortOption = isSortOption(raw) ? raw : 'newest'

  function select(value: string) {
    if (!isSortOption(value)) return
    const next = new URLSearchParams(searchParams.toString())
    next.set('sort', value)
    router.replace(`${pathname}?${next.toString()}`, { scroll: false })
  }

  return (
    <select value={current} onChange={(event) => select(event.target.value)}>
      {SORT_OPTIONS.map((option) => (
        <option key={option} value={option}>
          {option}
        </option>
      ))}
    </select>
  )
}
```

```tsx
// src/app/products/page.tsx
import { Suspense } from 'react'
import { SortSelect } from '@/features/catalog/components/sort-select'

export default function Page() {
  return (
    <main>
      <Suspense fallback={<p>Loading filters…</p>}>
        <SortSelect />
      </Suspense>
      {/* Server-side filtering reads this page's searchParams prop instead (RT-28). */}
    </main>
  )
}
```

The update pattern follows the useSearchParams reference ("Updating searchParams") and the Suspense wrapper follows its "Prerendering" section. Under `typedRoutes`, the template-literal href needs `as Route` (RT-22).

### URL-addressable modal: parallel and intercepting routes (RT-19, RT-20, RT-21)

```text
src/app/(dashboard)/dashboard/
├── layout.tsx                  # renders {children} and {modal}
├── page.tsx                    # /dashboard
├── photos/[id]/page.tsx        # full page on refresh or a shared link
└── @modal/
    ├── default.tsx             # return null; required for every slot in Next.js 16
    ├── page.tsx                # return null; closes the modal on <Link> back to /dashboard
    ├── [...catchAll]/page.tsx  # return null; closes it on <Link> to any other sub-path
    └── (.)photos/[id]/page.tsx # soft navigation to /dashboard/photos/1 opens the modal
```

```tsx
// src/app/(dashboard)/dashboard/layout.tsx
export default function DashboardLayout({
  children,
  modal,
}: {
  children: React.ReactNode
  modal: React.ReactNode
}) {
  return (
    <section>
      {children}
      {modal}
    </section>
  )
}
```

```tsx
// src/app/(dashboard)/dashboard/@modal/(.)photos/[id]/page.tsx
import { Modal } from '@/shared/components/modal'
import { PhotoView } from '@/features/photos/components/photo-view'

export default async function PhotoModal({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  return (
    <Modal>
      <PhotoView id={id} />
    </Modal>
  )
}
```

```tsx
// src/shared/components/modal.tsx
'use client'

import { useRouter } from 'next/navigation'

export function Modal({ children }: { children: React.ReactNode }) {
  const router = useRouter()
  return (
    <div role="dialog" aria-modal="true">
      <button type="button" onClick={() => router.back()}>
        Close
      </button>
      {children}
    </div>
  )
}
```

```tsx
// src/app/(dashboard)/dashboard/@modal/default.tsx (page.tsx and [...catchAll]/page.tsx are the same)
export default function Default() {
  return null
}
```

The slot props, the `default` that returns `null`, the `@slot/page.tsx` and `[...catchAll]/page.tsx` that return `null`, and the `router.back()` Modal follow the parallel-routes "Modals" section. The interceptor uses `(.)` because `@modal` is a slot, not a segment. The interceptor and its target sit in the same `(dashboard)` group, because the docs don't say whether matchers count group folders. The layout types its slots explicitly rather than with `LayoutProps<'/dashboard'>`, because no page shows how a group path appears in a route literal. Both gaps are listed under "Not confirmed by the docs".

## Anti-patterns

### Don't read params synchronously (RT-11)

```tsx
export default function Page({ params }: { params: { slug: string } }) {
  return <h1>{params.slug}</h1> // Next.js 16: params is a Promise; sync access was removed
}
```

**Do:** await the Promise.

```tsx
export default async function Page(props: PageProps<'/blog/[slug]'>) {
  const { slug } = await props.params
  return <h1>{slug}</h1>
}
```

### Don't ship a parallel-route slot without default.tsx (RT-19)

```text
src/app/(dashboard)/dashboard/
├── layout.tsx
├── page.tsx
└── @analytics/
    └── page.tsx        # no default.tsx: next build fails in Next.js 16
```

**Do:** give the slot its fallback.

```text
src/app/(dashboard)/dashboard/
├── layout.tsx
├── page.tsx
└── @analytics/
    ├── page.tsx
    └── default.tsx     # return null, or call notFound() to keep the pre-16 404
```

### Don't call redirect() inside try (RT-31)

```ts
// src/lib/actions/projects.ts
'use server'
import { redirect } from 'next/navigation'
import { saveProject } from '@/features/projects/services/projects'

export async function createProject(formData: FormData) {
  try {
    const id = await saveProject(formData)
    redirect(`/dashboard/projects/${id}`) // throws NEXT_REDIRECT, which the catch swallows
  } catch {
    return { error: 'Could not create the project.' }
  }
}
```

**Do:** redirect after the try/catch.

```ts
// src/lib/actions/projects.ts
'use server'
import { redirect } from 'next/navigation'
import { saveProject } from '@/features/projects/services/projects'

export async function createProject(formData: FormData) {
  let id: string
  try {
    id = await saveProject(formData)
  } catch {
    return { error: 'Could not create the project.' }
  }
  redirect(`/dashboard/projects/${id}`)
}
```

Input validation of `formData` belongs to [data-fetching-and-mutations.md](data-fetching-and-mutations.md).

### Don't call useSearchParams outside a Suspense boundary (RT-27)

```tsx
// src/app/products/page.tsx (prerendered)
import { SortSelect } from '@/features/catalog/components/sort-select'

export default function Page() {
  return <SortSelect /> // next build: "Missing Suspense boundary with useSearchParams"
}
```

**Do:** wrap the caller in `<Suspense>`.

```tsx
import { Suspense } from 'react'
import { SortSelect } from '@/features/catalog/components/sort-select'

export default function Page() {
  return (
    <Suspense fallback={<p>Loading filters…</p>}>
      <SortSelect />
    </Suspense>
  )
}
```

### Don't hand-write head tags in the root layout (RT-4, RT-37)

```tsx
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        <title>Acme</title>
        <meta name="theme-color" content="black" />
      </head>
      <body>{children}</body>
    </html>
  )
}
```

**Do:** export metadata and viewport.

```tsx
import type { Metadata, Viewport } from 'next'

export const metadata: Metadata = { title: { template: '%s | Acme', default: 'Acme' } }
export const viewport: Viewport = { themeColor: 'black' }

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
```

### Don't push an unvalidated URL (RT-22)

```tsx
'use client'
import { useRouter, useSearchParams } from 'next/navigation'

export function ContinueButton() {
  const router = useRouter()
  const target = useSearchParams().get('next') ?? '/'
  return <button type="button" onClick={() => router.push(target)}>Continue</button> // ?next=javascript:... runs script
}
```

**Do:** allow only same-origin paths. The docs require sanitizing; this check is ours (convention).

```tsx
'use client'
import { useRouter, useSearchParams } from 'next/navigation'

function toSafePath(value: string | null): string {
  if (value === null || !value.startsWith('/') || value.startsWith('//') || value.startsWith('/\\')) {
    return '/'
  }
  return value
}

export function ContinueButton() {
  const router = useRouter()
  const target = toSafePath(useSearchParams().get('next'))
  return <button type="button" onClick={() => router.push(target)}>Continue</button>
}
```

The guard rejects protocol-relative `//host` and `/\host` paths as well as `javascript:`.

## Version notes

Changes to routing, navigation and metadata in **Next.js 16**, as confirmed by the upgrade guide and release posts.

- **Async `params` and `searchParams` only.** Next.js 15's temporary synchronous access is gone. `params` in `layout`, `page`, `route`, `default`, `opengraph-image`, `twitter-image`, `icon` and `apple-icon`, and `searchParams` in `page`, must be awaited (RT-11) ([version 16 upgrade](https://nextjs.org/docs/app/guides/upgrading/version-16)). `generateMetadata` `params` and `searchParams` became Promises in 15 ([version 15 upgrade](https://nextjs.org/docs/app/guides/upgrading/version-15)).
- **Metadata image functions.** The image function receives `params` and `id` as Promises, and `generateImageMetadata` keeps synchronous `params` (RT-40) ([version 16 upgrade](https://nextjs.org/docs/app/guides/upgrading/version-16)).
- **Sitemap `id`.** `sitemap` receives the `generateSitemaps` `id` as `Promise<string>` (RT-39) ([version 16 upgrade](https://nextjs.org/docs/app/guides/upgrading/version-16)).
- **Parallel routes need `default`.** Every slot needs an explicit `default` file, and the build fails without one (RT-19) ([version 16 upgrade](https://nextjs.org/docs/app/guides/upgrading/version-16)).
- **Prefetch cache rewrite.** Prefetching now uses layout deduplication and incremental prefetching, with no code changes: more requests, each much smaller (RT-23) ([Next.js 16](https://nextjs.org/blog/next-16)).
- **Scroll behavior.** Next.js no longer overrides `scroll-behavior: smooth`. Opt back in with `data-scroll-behavior="smooth"` (RT-30) ([version 16 upgrade](https://nextjs.org/docs/app/guides/upgrading/version-16)).
- **`middleware` renamed `proxy`.** The old filename is deprecated; see [proxy-auth-and-security.md](proxy-auth-and-security.md) ([version 16 upgrade](https://nextjs.org/docs/app/guides/upgrading/version-16)).
- **Root params.** `unstable_rootParams` was removed in 16.0, and `next/root-params` shipped in 16.3 (RT-14) ([next/root-params](https://nextjs.org/docs/app/api-reference/functions/next-root-params)).
- **Segment config under Cache Components.** `dynamicParams` (with `dynamic`, `revalidate` and `fetchCache`) is unavailable when `cacheComponents` is on (RT-17) ([route segment config](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config)).
- **16.2.** `<Link transitionTypes>`; multiple icon formats (`icon.png` plus `icon.svg`) emitted as separate `<link>` tags; a faster `ImageResponse` with Geist Sans as the default font; and the experimental `prefetchInlining` ([Next.js 16.2](https://nextjs.org/blog/next-16-2), [Link](https://nextjs.org/docs/app/api-reference/components/link)).
- **16.3.** Small prefetches are bundled automatically; opt-in Partial Prefetching (`partialPrefetching`, which needs `cacheComponents`) and the per-segment `prefetch` export (RT-25); and `robots` rules accept `other` for non-standard directives ([Next.js 16.3](https://nextjs.org/blog/next-16-3), [partialPrefetching](https://nextjs.org/docs/app/api-reference/config/next-config-js/partialPrefetching), [robots](https://nextjs.org/docs/app/api-reference/file-conventions/metadata/robots)).

Some reference pages, such as page.js, layout.js, default.js and dynamic routes, still say synchronous `params` works "in Next.js 15". For 16, the upgrade guide governs.

## Review checklist

- [ ] RT-1, RT-2: a new project keeps `src/app/` routing-only, with features in `src/features/`, shared code in `src/shared/` and `proxy.ts` in `src/`.
- [ ] RT-3: no segment has both `page.tsx` and `route.ts`.
- [ ] RT-4: the root layout has `<html>` and `<body>` and no hand-written `<head>` tags.
- [ ] RT-5: no two route groups resolve to the same URL.
- [ ] RT-11: every `params` and `searchParams` access is awaited, or unwrapped with `use()` in a Client Component.
- [ ] RT-13: `params` are validated, and invalid values call `notFound()`.
- [ ] RT-15, RT-16, RT-17: each prerenderable dynamic segment exports `generateStaticParams` returning an array (at least one entry under Cache Components), with no `dynamicParams` under Cache Components.
- [ ] RT-19: every `@slot` has a `default.tsx`.
- [ ] RT-20: each slot authorizes its own data.
- [ ] RT-22: navigation uses `<Link>`, and `router.push` and `router.replace` never receive unsanitized input.
- [ ] RT-24: no side effects run in layout or page render.
- [ ] RT-27: `useSearchParams` callers are wrapped in `<Suspense>` on prerendered routes.
- [ ] RT-31: `redirect()` and `permanentRedirect()` run outside `try`/`catch`, `redirect()` never runs in an event handler, and 308 is used only for canonical-URL changes.
- [ ] RT-33: `notFound()` is never swallowed by `try`/`catch`, and the real-404 check runs before streaming when the status matters.
- [ ] RT-34, RT-35: no segment exports both `metadata` and `generateMetadata`, `metadataBase` is set in the root layout, and every `title.template` has a `title.default`.
- [ ] RT-37: viewport fields live in `viewport` or `generateViewport`, not `metadata`.
- [ ] RT-39, RT-40: `sitemap.ts` and `robots.ts` are typed with `MetadataRoute`, and OG images export `alt`, `size` and `contentType` and await `params`.

## Not confirmed by the docs

Nothing here is a rule. Each item names what was checked and the pages that were read.

1. **Missing slot `default`: 404 or build failure?** The parallel-routes page still says a missing `default.js` renders a 404. The default.js page says named slots error, and the version 16 guide says builds fail. RT-19 follows the version 16 guide. Checked:
   - https://nextjs.org/docs/app/api-reference/file-conventions/parallel-routes
   - https://nextjs.org/docs/app/api-reference/file-conventions/default
   - https://nextjs.org/docs/app/guides/upgrading/version-16
2. **Synchronous `params` in `generateViewport`.** The version 16 removal list doesn't name `generateMetadata` or `generateViewport`. The generateMetadata page awaits `params`, so RT-11 covers it. The generateViewport page shows `generateViewport({ params })` with no await, and says only to type `params` with `PageProps` or `LayoutProps`. Checked:
   - https://nextjs.org/docs/app/api-reference/functions/generate-viewport
   - https://nextjs.org/docs/app/api-reference/functions/generate-metadata
   - https://nextjs.org/docs/app/guides/upgrading/version-16
3. **Route groups in route literals.** No page shows a route-group folder inside a `PageProps<'...'>` or `LayoutProps<'...'>` literal, so the examples avoid the helpers on grouped routes. Checked:
   - https://nextjs.org/docs/app/api-reference/file-conventions/page
   - https://nextjs.org/docs/app/api-reference/file-conventions/layout
   - https://nextjs.org/docs/app/getting-started/layouts-and-pages
   - https://nextjs.org/docs/app/api-reference/config/typescript
4. **Route groups and interception.** The interception matchers are documented to ignore `@slot` folders. Whether `(group)` folders count isn't stated, so keep an interceptor and its target inside the same group. Checked:
   - https://nextjs.org/docs/app/api-reference/file-conventions/intercepting-routes
5. **The `next.config` redirect limit on Vercel.** nextjs.org says 1,024 and vercel.com says 2,048. No number is stated as a rule. Checked:
   - https://nextjs.org/docs/app/guides/redirecting
   - https://vercel.com/docs/routing/redirects/configuration-redirects
6. **The sitemap reference example.** It multiplies the awaited `id`, which is a string, by a number. The version 16 guide converts with `Number(...)`, and the pattern here follows the guide. Checked:
   - https://nextjs.org/docs/app/api-reference/file-conventions/metadata/sitemap
   - https://nextjs.org/docs/app/api-reference/functions/generate-sitemaps
7. **The `generateImageMetadata` `id` type.** The version 16 guide says `Promise<string>`, and the reference page says it resolves to `string` or `number`. Checked:
   - https://nextjs.org/docs/app/guides/upgrading/version-16
   - https://nextjs.org/docs/app/api-reference/functions/generate-image-metadata
8. **The `prefetch` segment export's release.** Its history row reads `v16.x.x`, with no exact release stated. The 16.3 post describes Partial Prefetching. Checked:
   - https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/prefetch
   - https://nextjs.org/blog/next-16-3

## Sources

- https://nextjs.org/docs/app/getting-started/project-structure
- https://nextjs.org/docs/app/getting-started/layouts-and-pages
- https://nextjs.org/docs/app/getting-started/linking-and-navigating
- https://nextjs.org/docs/app/getting-started/metadata-and-og-images
- https://nextjs.org/docs/app/getting-started/route-handlers
- https://nextjs.org/docs/app/api-reference/file-conventions/src-folder
- https://nextjs.org/docs/app/api-reference/file-conventions/route-groups
- https://nextjs.org/docs/app/api-reference/file-conventions/layout
- https://nextjs.org/docs/app/api-reference/file-conventions/page
- https://nextjs.org/docs/app/api-reference/file-conventions/template
- https://nextjs.org/docs/app/api-reference/file-conventions/loading
- https://nextjs.org/docs/app/api-reference/file-conventions/not-found
- https://nextjs.org/docs/app/api-reference/file-conventions/error
- https://nextjs.org/docs/app/api-reference/file-conventions/forbidden
- https://nextjs.org/docs/app/api-reference/file-conventions/unauthorized
- https://nextjs.org/docs/app/api-reference/file-conventions/default
- https://nextjs.org/docs/app/api-reference/file-conventions/dynamic-routes
- https://nextjs.org/docs/app/api-reference/file-conventions/parallel-routes
- https://nextjs.org/docs/app/api-reference/file-conventions/intercepting-routes
- https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config
- https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/dynamicParams
- https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/prefetch
- https://nextjs.org/docs/app/api-reference/functions/generate-static-params
- https://nextjs.org/docs/app/api-reference/functions/next-root-params
- https://nextjs.org/docs/app/api-reference/components/link
- https://nextjs.org/docs/app/api-reference/functions/use-router
- https://nextjs.org/docs/app/api-reference/functions/use-pathname
- https://nextjs.org/docs/app/api-reference/functions/use-search-params
- https://nextjs.org/docs/app/api-reference/functions/use-params
- https://nextjs.org/docs/app/api-reference/functions/use-link-status
- https://nextjs.org/docs/app/api-reference/functions/redirect
- https://nextjs.org/docs/app/api-reference/functions/permanentRedirect
- https://nextjs.org/docs/app/api-reference/functions/not-found
- https://nextjs.org/docs/app/guides/redirecting
- https://nextjs.org/docs/app/guides/prefetching
- https://nextjs.org/docs/app/guides/adopting-partial-prefetching
- https://nextjs.org/docs/app/api-reference/config/next-config-js/partialPrefetching
- https://nextjs.org/docs/app/api-reference/functions/generate-metadata
- https://nextjs.org/docs/app/api-reference/functions/generate-viewport
- https://nextjs.org/docs/app/api-reference/file-conventions/metadata/sitemap
- https://nextjs.org/docs/app/api-reference/functions/generate-sitemaps
- https://nextjs.org/docs/app/api-reference/file-conventions/metadata/robots
- https://nextjs.org/docs/app/api-reference/file-conventions/metadata/opengraph-image
- https://nextjs.org/docs/app/api-reference/file-conventions/metadata/app-icons
- https://nextjs.org/docs/app/api-reference/functions/image-response
- https://nextjs.org/docs/app/api-reference/functions/generate-image-metadata
- https://nextjs.org/docs/app/api-reference/config/typescript
- https://nextjs.org/docs/app/guides/upgrading/version-16
- https://nextjs.org/docs/app/guides/upgrading/version-15
- https://nextjs.org/blog/next-16
- https://nextjs.org/blog/next-16-2
- https://nextjs.org/blog/next-16-3
- https://vercel.com/docs/og-image-generation
- https://vercel.com/docs/routing/redirects
- https://vercel.com/docs/routing/redirects/configuration-redirects
- https://react.dev/reference/react/use
- https://react.dev/reference/react/Suspense
- https://react.dev/reference/react/cache
