# Sources verified: `references/nextjs/routing-and-metadata.md`

Every URL below was fetched live on **2026-10-04** by the planner of
`app-router-routing-and-metadata`. nextjs.org and vercel.com pages were read through their
Markdown variant (`<url>.md`, HTTP 200, `text/markdown`). react.dev pages were checked for
HTTP 200, and only the React fact named in "Backs" is taken from them. The current stable
release was read from `https://nextjs.org/docs/llms.txt` (`@doc-version: 16.3.8`) and
matches the npm `latest` dist-tag (`16.3.8`). Most doc pages carry `version: 16.3.8` in
their front matter.

This set must equal the `## Sources` set of the topic file exactly. The coder drops a row
only when the topic file stops citing that URL. A URL is never added without a live fetch.

| # | URL | Fetched | Backs |
| --- | --- | --- | --- |
| 1 | https://nextjs.org/docs/app/getting-started/project-structure | 2026-10-04 | RT-1, RT-3, RT-5, RT-6, RT-10, canonical-layout pattern |
| 2 | https://nextjs.org/docs/app/getting-started/layouts-and-pages | 2026-10-04 | RT-12, RT-28 |
| 3 | https://nextjs.org/docs/app/getting-started/linking-and-navigating | 2026-10-04 | RT-8, RT-15, RT-23 |
| 4 | https://nextjs.org/docs/app/getting-started/metadata-and-og-images | 2026-10-04 | RT-34, RT-36, RT-38 |
| 5 | https://nextjs.org/docs/app/getting-started/route-handlers | 2026-10-04 | RT-3 (`route` and `page` can't share a segment) |
| 6 | https://nextjs.org/docs/app/api-reference/file-conventions/src-folder | 2026-10-04 | RT-1, RT-2 |
| 7 | https://nextjs.org/docs/app/api-reference/file-conventions/route-groups | 2026-10-04 | RT-5 |
| 8 | https://nextjs.org/docs/app/api-reference/file-conventions/layout | 2026-10-04 | RT-4, RT-26 |
| 9 | https://nextjs.org/docs/app/api-reference/file-conventions/page | 2026-10-04 | RT-11, RT-28 |
| 10 | https://nextjs.org/docs/app/api-reference/file-conventions/template | 2026-10-04 | RT-7 |
| 11 | https://nextjs.org/docs/app/api-reference/file-conventions/loading | 2026-10-04 | RT-8, RT-33 |
| 12 | https://nextjs.org/docs/app/api-reference/file-conventions/not-found | 2026-10-04 | RT-9 |
| 13 | https://nextjs.org/docs/app/api-reference/file-conventions/error | 2026-10-04 | RT-9 |
| 14 | https://nextjs.org/docs/app/api-reference/file-conventions/forbidden | 2026-10-04 | RT-9 |
| 15 | https://nextjs.org/docs/app/api-reference/file-conventions/unauthorized | 2026-10-04 | RT-9 |
| 16 | https://nextjs.org/docs/app/api-reference/file-conventions/default | 2026-10-04 | RT-19, Not confirmed #1 |
| 17 | https://nextjs.org/docs/app/api-reference/file-conventions/dynamic-routes | 2026-10-04 | RT-10, RT-13 |
| 18 | https://nextjs.org/docs/app/api-reference/file-conventions/parallel-routes | 2026-10-04 | RT-19, RT-20, RT-21, Not confirmed #1 |
| 19 | https://nextjs.org/docs/app/api-reference/file-conventions/intercepting-routes | 2026-10-04 | RT-21, Not confirmed #4 |
| 20 | https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config | 2026-10-04 | RT-17, Version notes |
| 21 | https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/dynamicParams | 2026-10-04 | RT-17 |
| 22 | https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/prefetch | 2026-10-04 | RT-25, Not confirmed #8 |
| 23 | https://nextjs.org/docs/app/api-reference/functions/generate-static-params | 2026-10-04 | RT-11, RT-15, RT-16, RT-18 |
| 24 | https://nextjs.org/docs/app/api-reference/functions/next-root-params | 2026-10-04 | RT-14, Version notes |
| 25 | https://nextjs.org/docs/app/api-reference/components/link | 2026-10-04 | RT-22, RT-23, RT-30, Version notes |
| 26 | https://nextjs.org/docs/app/api-reference/functions/use-router | 2026-10-04 | RT-22, RT-26 |
| 27 | https://nextjs.org/docs/app/api-reference/functions/use-pathname | 2026-10-04 | RT-27 |
| 28 | https://nextjs.org/docs/app/api-reference/functions/use-search-params | 2026-10-04 | RT-27 |
| 29 | https://nextjs.org/docs/app/api-reference/functions/use-params | 2026-10-04 | RT-27 |
| 30 | https://nextjs.org/docs/app/api-reference/functions/use-link-status | 2026-10-04 | RT-29 |
| 31 | https://nextjs.org/docs/app/api-reference/functions/redirect | 2026-10-04 | RT-31 |
| 32 | https://nextjs.org/docs/app/api-reference/functions/permanentRedirect | 2026-10-04 | RT-31 |
| 33 | https://nextjs.org/docs/app/api-reference/functions/not-found | 2026-10-04 | RT-33 |
| 34 | https://nextjs.org/docs/app/guides/redirecting | 2026-10-04 | RT-31, RT-32, Not confirmed #5 |
| 35 | https://nextjs.org/docs/app/guides/prefetching | 2026-10-04 | RT-23, RT-24 |
| 36 | https://nextjs.org/docs/app/guides/adopting-partial-prefetching | 2026-10-04 | RT-25 |
| 37 | https://nextjs.org/docs/app/api-reference/config/next-config-js/partialPrefetching | 2026-10-04 | RT-25, Version notes |
| 38 | https://nextjs.org/docs/app/api-reference/functions/generate-metadata | 2026-10-04 | RT-11, RT-34, RT-35, RT-36, RT-37 |
| 39 | https://nextjs.org/docs/app/api-reference/functions/generate-viewport | 2026-10-04 | RT-37, Not confirmed #2 |
| 40 | https://nextjs.org/docs/app/api-reference/file-conventions/metadata/sitemap | 2026-10-04 | RT-39, Not confirmed #6 |
| 41 | https://nextjs.org/docs/app/api-reference/functions/generate-sitemaps | 2026-10-04 | RT-39 |
| 42 | https://nextjs.org/docs/app/api-reference/file-conventions/metadata/robots | 2026-10-04 | RT-39, Version notes |
| 43 | https://nextjs.org/docs/app/api-reference/file-conventions/metadata/opengraph-image | 2026-10-04 | RT-38, RT-40 |
| 44 | https://nextjs.org/docs/app/api-reference/file-conventions/metadata/app-icons | 2026-10-04 | RT-38 |
| 45 | https://nextjs.org/docs/app/api-reference/functions/image-response | 2026-10-04 | RT-40 |
| 46 | https://nextjs.org/docs/app/api-reference/functions/generate-image-metadata | 2026-10-04 | RT-11, RT-40, Not confirmed #7 |
| 47 | https://nextjs.org/docs/app/api-reference/config/typescript | 2026-10-04 | RT-22 (typed links), Not confirmed #3 |
| 48 | https://nextjs.org/docs/app/guides/upgrading/version-16 | 2026-10-04 | RT-11, RT-19, RT-30, RT-39, RT-40, Version notes |
| 49 | https://nextjs.org/docs/app/guides/upgrading/version-15 | 2026-10-04 | RT-11 (`generateMetadata` params became a Promise), Version notes |
| 50 | https://nextjs.org/blog/next-16 | 2026-10-04 | RT-23, Version notes |
| 51 | https://nextjs.org/blog/next-16-2 | 2026-10-04 | RT-38, Version notes |
| 52 | https://nextjs.org/blog/next-16-3 | 2026-10-04 | RT-14, RT-25, Version notes |
| 53 | https://vercel.com/docs/og-image-generation | 2026-10-04 | RT-40 (1200x630 recommended size, 500 KB bundle, fonts) |
| 54 | https://vercel.com/docs/routing/redirects | 2026-10-04 | RT-32 (307/308 guidance, Bulk Redirects) |
| 55 | https://vercel.com/docs/routing/redirects/configuration-redirects | 2026-10-04 | Not confirmed #5 (2,048-redirect limit) |
| 56 | https://react.dev/reference/react/use | 2026-10-04 | RT-11 (`use()` unwraps a Promise in a Client Component) |
| 57 | https://react.dev/reference/react/Suspense | 2026-10-04 | RT-27 (`<Suspense>` fallback boundary) |
| 58 | https://react.dev/reference/react/cache | 2026-10-04 | RT-36 (`cache()` memoizes a server data function) |
