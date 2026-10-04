# Sources verified: rendering-caching-and-streaming-ssr

Every URL in the `## Sources` section of `references/nextjs/rendering-and-caching.md`, with the date it was
fetched live and the rule ids it backs. All 46 pages were fetched on 2026-10-04: the nextjs.org and
vercel.com pages as Markdown (an `Accept: text/markdown` request on the canonical URL), the two react.dev pages
as HTML. The planner fetched them while writing the plan, and the coder fetched them again while writing the
file. Each nextjs.org docs page's front matter reads `version: 16.3.8`, which equals the as-of version.
Row 1 backs the as-of line (it names v16.3.8 as Active LTS), not a rule.

Columns: **Rules** are the `RC-` rules that cite the page; **Also cited in** are the other sections of the topic
file that link it (Patterns, Anti-patterns, Version notes, Review checklist, Not confirmed by the docs).

| # | URL | Fetched | Rules | Also cited in |
| --- | --- | --- | --- | --- |
| 1 | https://nextjs.org/blog/september-2026-security-release | 2026-10-04 | none | none |
| 2 | https://nextjs.org/docs/app/getting-started/server-and-client-components | 2026-10-04 | RC-5, RC-6, RC-7, RC-8, RC-9, RC-10, RC-12 | none |
| 3 | https://nextjs.org/docs/app/guides/server-and-client-boundary | 2026-10-04 | RC-5, RC-7, RC-8, RC-11 | none |
| 4 | https://nextjs.org/docs/app/api-reference/directives/use-client | 2026-10-04 | RC-6 | none |
| 5 | https://nextjs.org/docs/app/getting-started/caching | 2026-10-04 | RC-1, RC-15, RC-16, RC-17, RC-19, RC-20, RC-23, RC-27, RC-38, RC-42, RC-45 | Not confirmed by the docs, Patterns |
| 6 | https://nextjs.org/docs/app/api-reference/config/next-config-js/cacheComponents | 2026-10-04 | RC-3, RC-4, RC-46 | Version notes |
| 7 | https://nextjs.org/docs/app/api-reference/directives/use-cache | 2026-10-04 | RC-19, RC-23, RC-24, RC-25, RC-26, RC-27, RC-30 | Version notes |
| 8 | https://nextjs.org/docs/app/api-reference/directives/use-cache-private | 2026-10-04 | RC-24 | Version notes |
| 9 | https://nextjs.org/docs/app/api-reference/directives/use-cache-remote | 2026-10-04 | RC-27, RC-30 | Version notes |
| 10 | https://nextjs.org/docs/app/api-reference/functions/cacheLife | 2026-10-04 | RC-20, RC-21, RC-22 | Patterns |
| 11 | https://nextjs.org/docs/app/api-reference/functions/cacheTag | 2026-10-04 | RC-28 | none |
| 12 | https://nextjs.org/docs/app/getting-started/revalidating | 2026-10-04 | RC-19, RC-35 | none |
| 13 | https://nextjs.org/docs/app/api-reference/functions/revalidateTag | 2026-10-04 | RC-28, RC-32, RC-33 | none |
| 14 | https://nextjs.org/docs/app/api-reference/functions/updateTag | 2026-10-04 | RC-33, RC-34 | none |
| 15 | https://nextjs.org/docs/app/api-reference/functions/revalidatePath | 2026-10-04 | RC-33, RC-35 | none |
| 16 | https://nextjs.org/docs/app/api-reference/functions/refresh | 2026-10-04 | RC-33, RC-36 | Not confirmed by the docs |
| 17 | https://nextjs.org/docs/app/guides/server-actions | 2026-10-04 | RC-34, RC-36 | Not confirmed by the docs |
| 18 | https://nextjs.org/docs/app/guides/how-revalidation-works | 2026-10-04 | RC-35, RC-37 | none |
| 19 | https://nextjs.org/docs/app/guides/caching-without-cache-components | 2026-10-04 | RC-1, RC-29, RC-30, RC-31 | none |
| 20 | https://nextjs.org/docs/app/guides/migrating-to-cache-components | 2026-10-04 | RC-2, RC-4, RC-14, RC-18, RC-26, RC-30, RC-34, RC-45, RC-46, RC-47 | Not confirmed by the docs |
| 21 | https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config | 2026-10-04 | RC-2 | Version notes |
| 22 | https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/dynamicParams | 2026-10-04 | RC-2 | none |
| 23 | https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/instant | 2026-10-04 | RC-47 | Not confirmed by the docs, Version notes |
| 24 | https://nextjs.org/docs/app/api-reference/functions/connection | 2026-10-04 | RC-17, RC-18 | Version notes |
| 25 | https://nextjs.org/docs/app/api-reference/functions/io | 2026-10-04 | RC-17 | Version notes |
| 26 | https://nextjs.org/docs/app/api-reference/functions/cookies | 2026-10-04 | RC-13, RC-14, RC-15 | none |
| 27 | https://nextjs.org/docs/app/api-reference/functions/headers | 2026-10-04 | RC-13 | none |
| 28 | https://nextjs.org/docs/app/api-reference/file-conventions/page | 2026-10-04 | RC-14 | Not confirmed by the docs |
| 29 | https://nextjs.org/docs/app/api-reference/functions/fetch | 2026-10-04 | RC-29, RC-43 | none |
| 30 | https://nextjs.org/docs/app/guides/streaming | 2026-10-04 | RC-15, RC-16, RC-38, RC-40, RC-41, RC-42, RC-44 | none |
| 31 | https://nextjs.org/docs/app/api-reference/file-conventions/loading | 2026-10-04 | RC-38, RC-39, RC-40 | Patterns |
| 32 | https://nextjs.org/docs/app/getting-started/fetching-data | 2026-10-04 | RC-43, RC-44 | none |
| 33 | https://nextjs.org/docs/app/guides/incremental-static-regeneration | 2026-10-04 | RC-31, RC-37 | none |
| 34 | https://nextjs.org/docs/app/guides/incremental-static-regeneration-cache-components | 2026-10-04 | none | Version notes |
| 35 | https://nextjs.org/docs/app/api-reference/functions/unstable_cache | 2026-10-04 | RC-30 | Version notes |
| 36 | https://nextjs.org/docs/app/api-reference/functions/unstable_noStore | 2026-10-04 | RC-18 | Version notes |
| 37 | https://nextjs.org/docs/app/api-reference/config/next-config-js/partialPrefetching | 2026-10-04 | none | Version notes |
| 38 | https://nextjs.org/docs/app/glossary | 2026-10-04 | RC-43 | none |
| 39 | https://nextjs.org/docs/app/guides/upgrading/version-16 | 2026-10-04 | RC-3, RC-13, RC-28, RC-32 | Not confirmed by the docs, Version notes |
| 40 | https://nextjs.org/docs/app/guides/upgrading/version-15 | 2026-10-04 | RC-29 | Version notes |
| 41 | https://nextjs.org/blog/next-16 | 2026-10-04 | RC-32, RC-36 | Not confirmed by the docs, Version notes |
| 42 | https://nextjs.org/blog/next-16-3 | 2026-10-04 | none | Not confirmed by the docs, Version notes |
| 43 | https://vercel.com/docs/frameworks/full-stack/nextjs | 2026-10-04 | RC-38 | Version notes |
| 44 | https://vercel.com/docs/caching/runtime-cache | 2026-10-04 | RC-27, RC-30 | none |
| 45 | https://react.dev/reference/rsc/use-client | 2026-10-04 | RC-6, RC-7 | none |
| 46 | https://react.dev/reference/react/Suspense | 2026-10-04 | RC-41 | none |

## Method

- Rules and snippets were written from the plan's verified rule sheet and re-checked against the fetched page
  text for the claims most likely to drift: the `revalidateTag` signature and its deprecated form, which
  invalidation APIs are Server-Actions-only, the `cacheLife` preset table and the short-lived thresholds, the
  `'use cache'` serialization lists, the HTTP status contract of streaming, the `io()` and `connection()`
  guidance, and the 16.3 additions.
- Every `ts` and `tsx` fence in the topic file was type-checked in strict mode against the published
  `next@16.3.8` and `react@19` types, with stand-in declarations for `PageProps`, `LayoutProps` and the
  application helpers (`db`, `auth` and the like). The only diagnostic is the deliberate one-argument
  `revalidateTag` call in the anti-pattern block, which confirms the documented TypeScript error.
- FIX① (2026-10-04) re-fetched as Markdown, each with front matter `version: 16.3.8`: `use cache`,
  `use cache: remote`, `unstable_cache`, Caching, Migrating to Cache Components, `cacheTag`, `revalidateTag`,
  `loading.js` and Caching and Revalidating (Previous Model), plus Vercel Runtime Cache. RC-30 and the
  migration table now carry the persistence difference those pages state; RC-28 carries the `cacheTag` limits
  as written; RC-40 sends Cache Components repos to the Proxy check in `loading.js` Status Codes. The former
  "Not confirmed" item on `'use cache: remote'` and redeploys was dropped: `use cache: remote` now says
  outright that remote entries do not persist across deploys. The 23 Do/Pattern fences were re-type-checked
  (validation.md, FIX①).
