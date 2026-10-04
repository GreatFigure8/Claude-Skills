# Performance and the Vercel platform

> As of Next.js 16.3.8, verified 2026-10-04.

## Scope

Images, fonts, third-party scripts, lazy loading, bundle analysis and size, the bundler and the
compiler, Web Vitals, and the Vercel function platform with its configuration. Every Vercel limit
below is quoted with the plan or condition it applies to and a vercel.com link read on 2026-10-04.
Vercel changes its limits, so re-check a number before relying on it. This file documents
configuration only: a Vercel deploy is Jonathan's call (PERF-43).

| Subject | Where it lives |
| --- | --- |
| Cache and rendering strategy | [rendering-and-caching.md](rendering-and-caching.md) |
| Handler code shape and its `runtime` exports | [route-handlers-and-apis.md](route-handlers-and-apis.md) |
| Streaming and SSE durations | [sse-and-streaming.md](sse-and-streaming.md) |
| Secrets, Proxy and environment exposure | [proxy-auth-and-security.md](proxy-auth-and-security.md) |
| Environment typing | [typescript.md](typescript.md) |
| Tests and observability | [testing-and-observability.md](testing-and-observability.md) |

Back to the [Next.js + TypeScript standard](../nextjs.md). The blocked deploy commands are in
[deploy-guards.md](../deploy-guards.md).

## Rules

### Images

1. **PERF-1** Render raster content images with `Image` from `next/image`.
   It gives size optimization (WebP), visual stability (no layout shift), lazy loading on viewport entry and on-demand
   resizing of remote images ([Images](https://nextjs.org/docs/app/getting-started/images);
   [Production checklist](https://nextjs.org/docs/app/guides/production-checklist)).
2. **PERF-2** Give every `Image` its intrinsic size.
   Import local files statically, so `width`, `height` and `blurDataURL` are automatic. Pass `width` and `height` for
   remote URLs. Use `fill` only when the size is unknown, and give its parent `position: "relative"`, `"fixed"` or
   `"absolute"` ([Images](https://nextjs.org/docs/app/getting-started/images);
   [Image API](https://nextjs.org/docs/app/api-reference/components/image)).
3. **PERF-3** Set `sizes` on every `Image` that uses `fill` or is made responsive with CSS.
   Without it the browser assumes the image is `100vw` wide, which can download oversized images, and Next.js generates
   only a limited `srcset` (1x, 2x) instead of a full width-based one
   ([Image API](https://nextjs.org/docs/app/api-reference/components/image)).
4. **PERF-4** Load the one above-the-fold (LCP) image with `loading="eager"` or `fetchPriority="high"`.
   Use `preload` instead only when the image is the LCP element at every viewport and must start loading in `<head>`;
   never combine it with `loading` or `fetchPriority`. Never write `priority`, which Next.js 16 deprecated in favour of
   `preload`. `loading` defaults to `lazy` ([Image API](https://nextjs.org/docs/app/api-reference/components/image)).
5. **PERF-5** Allow-list remote images with the narrowest `images.remotePatterns` entry.
   Set `protocol`, `hostname`, `port: ''`, `pathname` and `search: ''`: an omitted `protocol`, `port`, `pathname` or
   `search` implies the `**` wildcard, which the docs do not recommend. A URL that matches no pattern gets a `400`.
   Allow local images with query strings through `images.localPatterns`. Never use `images.domains`, deprecated since
   Next.js 14 ([Image API](https://nextjs.org/docs/app/api-reference/components/image);
   [Upgrade to 16](https://nextjs.org/docs/app/guides/upgrading/version-16)).
6. **PERF-6** Keep `images.qualities` an explicit allow-list and `images.formats` on the WebP default, without `image/avif`.
   `qualities` defaults to `[75]`, is required from Next.js 16, and coerces any other `quality` to the closest entry.
   The August 2026 security release reports an unauthenticated remote code execution in the Image Optimization API
   when Next.js optimizes an attacker-controlled AVIF image (a libheif flaw in `sharp`), and says its patched releases,
   v16.3.3 and v15.5.24, disable AVIF optimization until an upstream fix is propagated
   ([August 2026 security release](https://nextjs.org/blog/august-2026-security-release)). `minimumCacheTTL` defaults
   to 14400 (4 hours) and cached images cannot be invalidated, so prefer static imports, which are cached as
   `immutable` ([Image API](https://nextjs.org/docs/app/api-reference/components/image)).
7. **PERF-7** On Vercel, set `unoptimized` on images that gain nothing from optimization.
   Vercel lists icons and thumbnails under 10 KB, GIFs and other animated formats, SVGs, and frequently changing images.
   Transformations are billed for every cache MISS and STALE, a transformed image may be at most 10 MB, and a source
   image at most 8192 pixels wide or high ([Image Optimization](https://vercel.com/docs/image-optimization);
   [Image Optimization limits](https://vercel.com/docs/image-optimization/limits-and-pricing)).

### Fonts

8. **PERF-8** Load every web font through `next/font`, using `next/font/google` or `next/font/local`.
   Font files are downloaded at build time and self-hosted with the static assets, so the browser sends no requests to
   Google and the font loads without layout shift. `display` defaults to `'swap'`
   ([Font API](https://nextjs.org/docs/app/api-reference/components/font);
   [Fonts](https://nextjs.org/docs/app/getting-started/fonts)).
9. **PERF-9** Prefer variable fonts, and always pass `subsets` to a Google font.
   Pass `weight` only for a font that is not variable. `preload` defaults to `true`, and Next.js warns when it is on and
   no `subsets` are given ([Font API](https://nextjs.org/docs/app/api-reference/components/font)).
10. **PERF-10** Call each font loader once, in a shared font-definitions module, and import the font
    object where it is used.
    Every call to `localFont` or a Google font function hosts one more instance of that font. Apply site-wide fonts in
    the root layout and route-specific fonts in that route's page or layout, because fonts are preloaded for the routes
    where they are used. Use multiple fonts conservatively
    ([Font API](https://nextjs.org/docs/app/api-reference/components/font)).
11. **PERF-11** Expose fonts to CSS and Tailwind through the `variable` option.
    Name a `--font-*` CSS variable, put `font.variable` on `<html>`, and map it in Tailwind v4 with `@theme inline`
    (Tailwind v3 uses `theme.extend.fontFamily`)
    ([Font API](https://nextjs.org/docs/app/api-reference/components/font)).

### Third-party scripts

12. **PERF-12** Load third-party scripts with `Script` from `next/script`, in the narrowest layout or
    page that needs them.
    Next.js recommends this to limit the performance cost. A script in a layout loads once, even when the user navigates
    between routes in that layout ([Scripts guide](https://nextjs.org/docs/app/guides/scripts)).
13. **PERF-13** Choose `strategy` deliberately.
    `afterInteractive` is the default and suits tag managers and analytics. Use `lazyOnload` for chat plugins and social
    widgets. Use `beforeInteractive` only for critical scripts such as bot detectors and cookie-consent managers, and
    only inside the root layout. Never use `worker` in the App Router: it is not yet stable and does not work there
    ([Script API](https://nextjs.org/docs/app/api-reference/components/script)).
14. **PERF-14** Attach `onLoad`, `onReady` and `onError` only in Client Components (`'use client'`),
    and give every inline script an `id`.
    Never use `onLoad` or `onError` with `beforeInteractive`; use `onReady` instead of `onLoad`
    ([Script API](https://nextjs.org/docs/app/api-reference/components/script);
    [Scripts guide](https://nextjs.org/docs/app/guides/scripts)).
15. **PERF-15** For Google Tag Manager, Google Analytics, Google Maps embeds and YouTube embeds,
    consider `@next/third-parties/google`.
    Its components are `GoogleTagManager`, `GoogleAnalytics`, `GoogleMapsEmbed` and `YouTubeEmbed`. The docs call the
    library experimental. When Google Tag Manager is already present, configure Google Analytics through it instead of
    adding a second component ([Third-party libraries](https://nextjs.org/docs/app/guides/third-party-libraries)).

### Client bundle

16. **PERF-16** Put `'use client'` on the smallest interactive component, not on a whole layout or page.
    A `'use client'` module's imports and the components it renders directly join the client bundle
    ([Server and Client Components](https://nextjs.org/docs/app/getting-started/server-and-client-components)).
17. **PERF-17** Run data-to-UI work that needs no browser API in Server Components.
    Syntax highlighting, chart rendering and markdown parsing then never ship their library to the client
    ([Package bundling](https://nextjs.org/docs/app/guides/package-bundling)).
18. **PERF-18** Start every server-only module with `import 'server-only'`.
    Importing that module into a Client Component then fails at build time. `client-only` is the mirror for browser-only
    modules, and installing either package is optional
    ([Server and Client Components](https://nextjs.org/docs/app/getting-started/server-and-client-components)).
19. **PERF-19** Lazy-load Client Components and libraries that are not needed for first paint.
    Use `next/dynamic` (or `React.lazy` with `Suspense`) for components and `import()` inside the event handler for
    libraries. Pass `ssr: false` only inside a Client Component, because it errors in a Server Component. Server
    Components are already code split ([Lazy loading](https://nextjs.org/docs/app/guides/lazy-loading)).
20. **PERF-20** Measure the bundle before and after changing it.
    Use `next experimental-analyze` with Turbopack (v16.1 and later; `--output` writes to `.next/diagnostics/analyze`),
    or the `@next/bundle-analyzer` plugin with webpack (`ANALYZE=true`). `next build` no longer prints `size` or
    `First Load JS`, so judge route performance with Lighthouse or Vercel Analytics
    ([Package bundling](https://nextjs.org/docs/app/guides/package-bundling);
    [next CLI](https://nextjs.org/docs/app/api-reference/cli/next);
    [Upgrade to 16](https://nextjs.org/docs/app/guides/upgrading/version-16)).
21. **PERF-21** Treat `experimental.optimizePackageImports` as experimental.
    Check the built-in list first: it includes `lucide-react`, `date-fns`, `lodash-es`, `@mui/material`, `recharts`,
    `react-icons/*`, `antd`, `rxjs` and `effect`. Add a package only after the analyzer shows heavy barrel imports
    (convention). Its page calls it experimental and not recommended for production, while the bundling guide recommends
    it; see Not confirmed by the docs
    ([optimizePackageImports](https://nextjs.org/docs/app/api-reference/config/next-config-js/optimizePackageImports);
    [Package bundling](https://nextjs.org/docs/app/guides/package-bundling)).
22. **PERF-22** Add a dependency to `serverExternalPackages` only when it uses Node.js-specific features
    and is not on the built-in opt-out list.
    The list already includes `sharp`, `@prisma/client`, `prisma`, `pg`, `mongodb`, `bcrypt`, `shiki`, `playwright`,
    `puppeteer` and `@aws-sdk/client-s3`. The option is stable since v15.0.0, renamed from
    `serverComponentsExternalPackages`
    ([serverExternalPackages](https://nextjs.org/docs/app/api-reference/config/next-config-js/serverExternalPackages);
    [Package bundling](https://nextjs.org/docs/app/guides/package-bundling)).

### Bundler and compiler

23. **PERF-23** Build and develop with the default Turbopack.
    Do not add `--turbopack` flags, which are no longer necessary. Configure it under the top-level `turbopack` key, not
    `experimental.turbopack`. Do not add a `webpack()` config: with one, `next build` fails, and Turbopack does not
    support webpack plugins. Use `--webpack` only as a documented opt-out, because the docs recommend Turbopack for
    development and production ([Upgrade to 16](https://nextjs.org/docs/app/guides/upgrading/version-16);
    [Turbopack](https://nextjs.org/docs/app/api-reference/turbopack)).
24. **PERF-24** Restore `.next/cache` between CI builds so Turbopack's filesystem cache is reused.
    If the build environment never preserves it, set `experimental.turbopackFileSystemCacheForBuild: false`. The cache
    is on by default for `next dev` since v16.1.0 and for `next build` since v16.3.0
    ([Turbopack filesystem cache](https://nextjs.org/docs/app/api-reference/config/next-config-js/turbopackFileSystemCache)).
25. **PERF-25** Turn the React Compiler on only as a deliberate, measured change.
    Set the top-level `reactCompiler: true` and install `babel-plugin-react-compiler` as a dev dependency. It is off by
    default, and compile times go up. To opt in per component, use `compilationMode: 'annotation'` with `'use memo'`.
    The Rust port, `experimental.turbopackRustReactCompiler`, is experimental in 16.3
    ([reactCompiler](https://nextjs.org/docs/app/api-reference/config/next-config-js/reactCompiler);
    [Upgrade to 16](https://nextjs.org/docs/app/guides/upgrading/version-16);
    [Next.js 16.3](https://nextjs.org/blog/next-16-3)).

### Core Web Vitals

26. **PERF-26** Report Web Vitals from one small `'use client'` component that calls
    `useReportWebVitals` with a module-level callback, rendered from the root layout.
    This is the one place the component is defined; other topics link here. A callback reference that changes reports
    duplicate data. The metrics are TTFB, FCP, LCP, FID, CLS and INP. Send them to your own endpoint (`/api/vitals`
    below) with `navigator.sendBeacon`, falling back to `fetch` with `keepalive: true`
    ([useReportWebVitals](https://nextjs.org/docs/app/api-reference/functions/use-report-web-vitals)).
27. **PERF-27** On Vercel, add `<SpeedInsights />` from `@vercel/speed-insights/next` and
    `<Analytics />` from `@vercel/analytics/next` inside the root layout `<body>`.
    Web Analytics must first be enabled in the Vercel dashboard: list that under `deploy_pending`
    ([Speed Insights](https://vercel.com/docs/speed-insights/quickstart);
    [Web Analytics](https://vercel.com/docs/analytics/quickstart)).
28. **PERF-28** Before calling performance work done, run `next build` then `next start` locally and
    audit with Lighthouse in an incognito window.
    Pair the lab result with field data
    ([Production checklist](https://nextjs.org/docs/app/guides/production-checklist)).

### Vercel Functions

29. **PERF-29** Run server code on the Node.js runtime.
    Omit the `runtime` export, because `'nodejs'` is the default, and never export `runtime = 'edge'` from a page,
    layout or route file. The Next.js docs mark Edge deprecated and say to remove the export. Vercel recommends
    migrating from Edge to Node.js, both run on Fluid compute, and from Next.js 16.3 Vercel says setting
    `runtime = 'edge'` is no longer supported. Proxy runs only on Node.js
    ([runtime](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/runtime);
    [Edge Runtime deprecated](https://nextjs.org/docs/messages/edge-runtime-deprecated);
    [Edge runtime on Vercel](https://vercel.com/docs/functions/runtimes/edge);
    [Upgrade to 16](https://nextjs.org/docs/app/guides/upgrading/version-16)).
30. **PERF-30** Assume Fluid compute, and keep request-specific data out of module-level variables.
    Fluid compute is on by default for projects created from April 23, 2025; an older project opts in with
    `"fluid": true` in `vercel.json`. Multiple invocations can share one physical instance concurrently, while an unhandled error
    does not crash the other concurrent requests ([Fluid compute](https://vercel.com/docs/fluid-compute)).
31. **PERF-31** Export `maxDuration` from a page, layout or `route.ts` only when the route needs more
    than the platform default, and keep it within the plan maximum.
    With Fluid compute the default is 300 seconds on every plan. The maximum is 300 seconds on Hobby and 800 seconds on
    Pro and Enterprise. 1800 seconds (30 minutes) is a beta extended maximum for Pro and Enterprise, set per function on
    supported runtimes. A value in function code overrides `vercel.json` and the dashboard. Set it at page level to
    cover that page's Server Actions. A run past the limit returns a 504 (`FUNCTION_INVOCATION_TIMEOUT`)
    ([maxDuration](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/maxDuration);
    [Function duration](https://vercel.com/docs/functions/configuring-functions/duration);
    [Function limits](https://vercel.com/docs/functions/limitations);
    [Fluid compute](https://vercel.com/docs/fluid-compute)).
32. **PERF-32** Use `after()` from `next/server` for work that must not delay the response, such as
    logging and analytics.
    It schedules work after the response (or prerender) finishes and runs for the route's default or configured max
    duration. On Vercel it is built on `waitUntil` ([after](https://nextjs.org/docs/app/api-reference/functions/after)).
33. **PERF-33** Never put `memory` in `vercel.json`.
    Vercel warns at build time if you do. Pro and Enterprise set the default in the dashboard (Settings, Functions,
    Advanced Settings), and the change needs a new deployment, so record it as `deploy_pending`. Standard is 2 GB / 1
    vCPU (the default), Performance is 4 GB / 2 vCPUs, and Hobby is fixed at 2 GB / 1 vCPU
    ([Function memory](https://vercel.com/docs/functions/configuring-functions/memory)).
34. **PERF-34** Run functions in the region of their data.
    New projects default to `iad1`. Set the project's `regions` in `vercel.json` (or the dashboard) to the database's
    region, because functions far from the services they call add latency. Hobby is limited to a single region. Never
    export `preferredRegion`, which is deprecated
    ([Function regions](https://vercel.com/docs/functions/configuring-functions/region);
    [preferredRegion](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/preferredRegion);
    [Function runtimes](https://vercel.com/docs/functions/runtimes)).
35. **PERF-35** Keep each Vercel Function request body and response body under 4.5 MB.
    A larger payload returns a 413 (`FUNCTION_PAYLOAD_TOO_LARGE`). Upload large files from the browser straight to a
    media host instead of proxying them, and stream large responses. Server Actions also cap the request body at 1MB by
    default (`serverActions.bodySizeLimit`) ([Function limits](https://vercel.com/docs/functions/limitations);
    [Bypass the body size limit](https://vercel.com/kb/guide/how-to-bypass-vercel-body-size-limit-serverless-functions);
    [serverActions config](https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions)).
36. **PERF-36** Keep each function under the 250 MB uncompressed size limit, and pool connections.
    Use `outputFileTracingIncludes` in `next.config` to control traced files, because `vercel.json` `includeFiles` and
    `excludeFiles` are not supported in Next.js. A function has 1,024 file descriptors shared across all concurrent
    executions, so close connections and use connection pooling for databases
    ([Function limits](https://vercel.com/docs/functions/limitations)).

### Vercel caching and platform

37. **PERF-37** To cache a function response on Vercel's CDN, return `Cache-Control` with `s-maxage`
    (optionally with `stale-while-revalidate`).
    Use `CDN-Cache-Control` or `Vercel-CDN-Cache-Control` to set the CDN lifetime apart from the browser's; the latter
    is not returned to the browser. A response is not cached when the request is not `GET` or `HEAD` or carries
    `Authorization`, when the response sets `set-cookie`, is `private`, `no-cache` or `no-store`, or has `Vary: *` or
    `Vary: Cookie`, or when it is over 10MB (20MB streaming). The maximum cache time is 1 year. Set route headers in
    `next.config`, not `vercel.json`. Caching strategy is in [rendering-and-caching.md](rendering-and-caching.md)
    ([CDN cache](https://vercel.com/docs/caching/cdn-cache)).
38. **PERF-38** Know where each Vercel cache lives.
    The ISR cache is durable and scoped to a deployment: a new deployment does not reuse the previous one's, and entries
    unaccessed for 31 days are dropped. The Data Cache (Beta) is regional, persists across deployments, and does not
    cache items over 2 MB. Revalidation reaches all regions within 300ms
    ([Incremental Static Regeneration](https://vercel.com/docs/incremental-static-regeneration);
    [Data Cache](https://vercel.com/docs/caching/runtime-cache/data-cache)).
39. **PERF-39** Protect every cron route, and make the job idempotent.
    Return a 401 unless the `authorization` header is `Bearer` followed by the `CRON_SECRET` value, compared with
    `timingSafeEqual` from `node:crypto` on two `Buffer`s after a byte-length check, never with `!==` (convention).
    Crons call the production deployment with a GET, in UTC. There are no retries, a run can be missed or duplicated, and redirects are
    not followed. Hobby runs a cron once a day, and the limit is 100 cron jobs per project
    ([Managing cron jobs](https://vercel.com/docs/cron-jobs/manage-cron-jobs);
    [Cron jobs](https://vercel.com/docs/cron-jobs); [Vercel limits](https://vercel.com/docs/limits)).
40. **PERF-40** Scope each environment variable to the Vercel environments that need it (Production,
    Preview, Development).
    A change applies only to new deployments. All variables of a deployment share 64 KB. Use `vercel env pull` for local
    values. Adding or removing a live variable is Jonathan's step: record it as `deploy_pending`
    ([Environment variables](https://vercel.com/docs/environment-variables);
    [Environments](https://vercel.com/docs/deployments/environments)).
41. **PERF-41** Rely on Vercel Skew Protection instead of hand-rolled version pinning.
    It is available on Pro and Enterprise and is on by default for projects created after November 19, 2024. With
    Next.js 14.1.4 or newer built on Vercel it needs no extra configuration. Client `fetch()` calls to your own APIs are
    not pinned automatically ([Skew Protection](https://vercel.com/docs/skew-protection)).
42. **PERF-42** Keep Vercel project configuration in one file.
    Use `vercel.json` for static configuration, or `vercel.ts` (typed with `@vercel/config`) when configuration must be
    computed at build time. Vercel's guidance is to use only one of the two, and it also lists `vercel.toml` for static
    configuration ([Project configuration](https://vercel.com/docs/project-configuration);
    [vercel.ts](https://vercel.com/docs/project-configuration/vercel-ts)).
43. **PERF-43** Never run, script or recommend a Vercel deploy, promote, rollback or
    environment-change command (convention).
    Change configuration in code, and list what needs a deployment or a dashboard change under `deploy_pending` in the
    run report. The blocked commands are listed in [deploy-guards.md](../deploy-guards.md).

## Patterns

### Responsive card image (PERF-2, PERF-3)

`fill` needs a positioned parent and `sizes`.

```tsx
import Image from 'next/image'

export function CardImage({ src, alt }: { src: string; alt: string }) {
  return (
    <div style={{ position: 'relative', aspectRatio: '4 / 3' }}>
      <Image src={src} alt={alt} fill sizes="(max-width: 768px) 100vw, 33vw" style={{ objectFit: 'cover' }} />
    </div>
  )
}
```

### Remote allow-list and image config (PERF-5, PERF-6)

```ts
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 's3.amazonaws.com', port: '', pathname: '/my-bucket/**', search: '' },
    ],
    qualities: [75],
  },
}

export default nextConfig
```

### Self-hosted fonts, layout and Tailwind (PERF-8 to PERF-11)

Define the fonts once in `app/fonts.ts`.

```ts
import { Inter, Roboto_Mono } from 'next/font/google'

export const inter = Inter({ subsets: ['latin'], display: 'swap', variable: '--font-inter' })
export const robotoMono = Roboto_Mono({ subsets: ['latin'], display: 'swap', variable: '--font-roboto-mono' })
```

Apply the variables in `app/layout.tsx`, then map them in `app/globals.css` (Tailwind v4).

```tsx
import type { ReactNode } from 'react'
import { inter, robotoMono } from './fonts'

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" className={`${inter.variable} ${robotoMono.variable}`}>
      <body>{children}</body>
    </html>
  )
}
```

```css
@theme inline {
  --font-sans: var(--font-inter);
  --font-mono: var(--font-roboto-mono);
}
```

### Third-party scripts (PERF-12 to PERF-14)

Scope the script to the layout that needs it, with an explicit `strategy`.

```tsx
import type { ReactNode } from 'react'
import Script from 'next/script'

export default function DashboardLayout({ children }: { children: ReactNode }) {
  return (
    <>
      <section>{children}</section>
      <Script src="https://example.com/chat-widget.js" strategy="lazyOnload" />
    </>
  )
}
```

A handler needs an `id` and a Client Component.

```tsx
'use client'

import Script from 'next/script'

export function MapsSdk() {
  return <Script id="maps-sdk" src="https://example.com/maps.js" onReady={() => console.info('maps ready')} />
}
```

### Lazy client widget (PERF-19)

```tsx
'use client'

import { useState } from 'react'
import dynamic from 'next/dynamic'

const Chart = dynamic(() => import('./chart').then((mod) => mod.Chart), { ssr: false })

export function ReportPanel() {
  const [isOpen, setIsOpen] = useState(false)
  return (
    <section>
      <button onClick={() => setIsOpen(true)}>Show chart</button>
      {isOpen && <Chart />}
    </section>
  )
}
```

### Server-only module and server-side transform (PERF-17, PERF-18)

```ts
import 'server-only'

export async function getData(): Promise<unknown> {
  const apiKey = process.env.API_KEY
  if (!apiKey) throw new Error('API_KEY is not set')
  const res = await fetch('https://example.com/data', { headers: { authorization: apiKey } })
  if (!res.ok) throw new Error(`Data request failed with ${res.status}`)
  return res.json()
}
```

Highlighting in a Server Component keeps `shiki` out of the client bundle. `codeToHtml` returns a complete `<pre>`
element, so the wrapper is a `div`.

```tsx
import { codeToHtml } from 'shiki'

export default async function Page() {
  const html = await codeToHtml('export const answer = 42', { lang: 'tsx', theme: 'github-dark' })
  return <div dangerouslySetInnerHTML={{ __html: html }} />
}
```

### Compiler and bundling config (PERF-21, PERF-22, PERF-25)

The `optimizePackageImports` line is experimental: add it only after analyzer evidence.

```ts
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  reactCompiler: true,
  serverExternalPackages: ['@acme/native-addon'],
  experimental: { optimizePackageImports: ['icon-library'] },
}

export default nextConfig
```

### Web Vitals reporter (PERF-26)

```tsx
'use client'

import { useReportWebVitals } from 'next/web-vitals'

type ReportWebVitalsCallback = Parameters<typeof useReportWebVitals>[0]

const reportWebVitals: ReportWebVitalsCallback = (metric) => {
  const body = JSON.stringify(metric)
  const url = '/api/vitals'
  if (navigator.sendBeacon) {
    navigator.sendBeacon(url, body)
  } else {
    void fetch(url, { body, method: 'POST', keepalive: true })
  }
}

export function WebVitals(): null {
  useReportWebVitals(reportWebVitals)
  return null
}
```

### Per-route duration and post-response work (PERF-31, PERF-32)

```ts
import { after } from 'next/server'

export const maxDuration = 60 // must not exceed the plan maximum

export async function POST(request: Request): Promise<Response> {
  let input: unknown
  try {
    input = await request.json()
  } catch {
    return Response.json({ error: { code: 'invalid_json', message: 'The body is not valid JSON.' } }, { status: 400 })
  }
  const received = input !== null
  after(() => console.info('report received', received))
  return Response.json({ received })
}
```

### Cron route and `vercel.json` (PERF-34, PERF-39)

```ts
import { timingSafeEqual } from 'node:crypto'
import type { NextRequest } from 'next/server'

function isCronRequest(request: NextRequest): boolean {
  const cronSecret = process.env.CRON_SECRET
  if (!cronSecret) return false
  const received = Buffer.from(request.headers.get('authorization') ?? '')
  const expected = Buffer.from(`Bearer ${cronSecret}`)
  return received.length === expected.length && timingSafeEqual(received, expected) // equal byte lengths, or it throws
}

export function GET(request: NextRequest): Response {
  if (!isCronRequest(request)) return new Response('Unauthorized', { status: 401 })
  return Response.json({ success: true })
}
```

```json
{
  "regions": ["iad1"],
  "crons": [{ "path": "/api/cron", "schedule": "0 5 * * *" }]
}
```

## Anti-patterns

### Don't render a `fill` image without `sizes`, or use a raw `<img>` (PERF-1 to PERF-3)

```tsx
export const Banner = ({ src }: { src: string }) => <img src={src} alt="Banner" />
```

**Do** use `Image` with `fill`, a positioned parent and `sizes`.

```tsx
import Image from 'next/image'

export const Banner = ({ src }: { src: string }) => (
  <div style={{ position: 'relative', aspectRatio: '16 / 5' }}>
    <Image src={src} alt="Banner" fill sizes="100vw" />
  </div>
)
```

### Don't mark every image `priority`, or pair `preload` with `loading` (PERF-4)

```tsx
import Image from 'next/image'

export const Gallery = ({ urls }: { urls: string[] }) =>
  urls.map((url) => <Image key={url} src={url} alt="" width={800} height={600} priority />)
```

**Do** load the one LCP image eagerly and leave the rest lazy.

```tsx
import Image from 'next/image'

export const Gallery = ({ urls }: { urls: string[] }) =>
  urls.map((url, index) => (
    <Image key={url} src={url} alt="" width={800} height={600} loading={index === 0 ? 'eager' : 'lazy'} />
  ))
```

### Don't allow remote images with `domains` or a wildcard host (PERF-5)

```ts
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  images: { domains: ['cdn.example.com'], remotePatterns: [{ hostname: '**' }] },
}

export default nextConfig
```

**Do** write one narrow `remotePatterns` entry with `protocol`, `port`, `pathname` and `search: ''`.

```ts
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [{ protocol: 'https', hostname: 'cdn.example.com', port: '', pathname: '/assets/**', search: '' }],
  },
}

export default nextConfig
```

### Don't load fonts with a stylesheet link in the root layout (PERF-8, PERF-9)

```tsx
import type { ReactNode } from 'react'

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <head>
        <link href="https://fonts.googleapis.com/css2?family=Inter" rel="stylesheet" />
      </head>
      <body>{children}</body>
    </html>
  )
}
```

**Do** use `next/font/google` with `subsets` and a `variable`.

```tsx
import type { ReactNode } from 'react'
import { Inter } from 'next/font/google'

const inter = Inter({ subsets: ['latin'], variable: '--font-inter' })

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" className={inter.variable}>
      <body>{children}</body>
    </html>
  )
}
```

### Don't export `runtime = 'edge'` or `preferredRegion` from a route (PERF-29, PERF-34)

```ts
export const runtime = 'edge'
export const preferredRegion = 'home'
```

**Do** export neither, and set the regions in `vercel.json`.

```json
{ "regions": ["iad1"] }
```

### Don't leave a cron route open or non-idempotent (PERF-39)

```ts
let runs = 0

export function GET(): Response {
  runs += 1
  return Response.json({ runs })
}
```

**Do** check `CRON_SECRET` in constant time and make the job a "set", so a repeated run changes nothing.

```ts
import { timingSafeEqual } from 'node:crypto'
import type { NextRequest } from 'next/server'

export function GET(request: NextRequest): Response {
  const cronSecret = process.env.CRON_SECRET
  const received = Buffer.from(request.headers.get('authorization') ?? '')
  const expected = Buffer.from(`Bearer ${cronSecret ?? ''}`)
  if (!cronSecret || received.length !== expected.length || !timingSafeEqual(received, expected)) {
    return new Response('Unauthorized', { status: 401 })
  }
  return Response.json({ state: 'generated' }) // set the state; running twice has the same effect
}
```

## Version notes

Next.js 16, up to 16.3.

- Turbopack is stable and the default for `next dev` and `next build`. A custom `webpack` config fails
  `next build`, `--webpack` opts out, and `experimental.turbopack` moved to the top-level `turbopack`
  key ([Upgrade to 16](https://nextjs.org/docs/app/guides/upgrading/version-16);
  [Next.js 16](https://nextjs.org/blog/next-16);
  [Turbopack](https://nextjs.org/docs/app/api-reference/turbopack)).
- The Turbopack filesystem cache is on by default: for dev from 16.1 and for build from 16.3
  ([Turbopack filesystem cache](https://nextjs.org/docs/app/api-reference/config/next-config-js/turbopackFileSystemCache)).
- `next experimental-analyze` was added in 16.1, and `next build` dropped the `size` and
  `First Load JS` output in 16.0
  ([next CLI](https://nextjs.org/docs/app/api-reference/cli/next);
  [Upgrade to 16](https://nextjs.org/docs/app/guides/upgrading/version-16)).
- React Compiler support is stable and `reactCompiler` is a top-level option, off by default. An
  experimental Rust compiler arrived in 16.3
  ([Upgrade to 16](https://nextjs.org/docs/app/guides/upgrading/version-16);
  [Next.js 16](https://nextjs.org/blog/next-16);
  [Next.js 16.3](https://nextjs.org/blog/next-16-3)).
- `next/image` changes ([Upgrade to 16](https://nextjs.org/docs/app/guides/upgrading/version-16);
  [Image API](https://nextjs.org/docs/app/api-reference/components/image)):
  `priority` is deprecated and `preload` was added; `qualities` defaults to `[75]`; `16` was removed from the
  default `imageSizes`; `minimumCacheTTL` went from 60 seconds to 4 hours; a local `src` with a query string needs
  `localPatterns.search`; `dangerouslyAllowLocalIP` was added and local IPs are blocked by default;
  `maximumRedirects` defaults to 3; `images.domains` and `next/legacy/image` are deprecated.
- The Edge runtime and `preferredRegion` are deprecated in the current Next.js 16 docs, and Vercel says
  `runtime = 'edge'` is not supported from 16.3. Proxy runs only on Node.js
  ([runtime](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/runtime);
  [preferredRegion](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/preferredRegion);
  [Edge runtime on Vercel](https://vercel.com/docs/functions/runtimes/edge);
  [Upgrade to 16](https://nextjs.org/docs/app/guides/upgrading/version-16)).
- The Next.js 16 upgrade guide has no section on `next/font`, `next/script`, `next/dynamic`,
  `optimizePackageImports` or `serverExternalPackages`
  ([Upgrade to 16](https://nextjs.org/docs/app/guides/upgrading/version-16)).

## Review checklist

- [ ] PERF-1, PERF-2, PERF-3: every `Image` has its dimensions, or `fill` with a positioned parent and `sizes`.
- [ ] PERF-4: no `priority`, and one eager LCP image that does not combine `preload` with `loading`.
- [ ] PERF-5: remote images use a narrow `remotePatterns` entry, never `domains` or a wildcard host.
- [ ] PERF-6, PERF-7: `qualities` is an explicit list, `formats` has no `image/avif`, and tiny, animated and vector images are `unoptimized`.
- [ ] PERF-8 to PERF-11: fonts come from `next/font`, are defined once and reach CSS through `variable`.
- [ ] PERF-12, PERF-13, PERF-14: `next/script` is scoped narrowly with an explicit `strategy`, and handlers live in client files.
- [ ] PERF-16, PERF-17, PERF-18: `'use client'` sits on leaves, heavy transforms stay on the server, and server modules import `server-only`.
- [ ] PERF-19: heavy widgets are lazy, and `ssr: false` appears only in client files.
- [ ] PERF-20, PERF-21, PERF-22: analyzer evidence backs any bundling change, and package lists are not duplicated.
- [ ] PERF-23, PERF-25: there is no `webpack()` config or `--turbopack` flag, and the compiler is a deliberate change.
- [ ] PERF-26, PERF-27: the Web Vitals reporter has a module-level callback.
- [ ] PERF-29, PERF-30, PERF-34: no route exports `runtime = 'edge'` or `preferredRegion`, and no request data is held in module scope.
- [ ] PERF-31, PERF-35: `maxDuration` is within the plan maximum, and large uploads bypass the function.
- [ ] PERF-37, PERF-39: cacheable responses set no cookie, and cron routes compare `CRON_SECRET` in constant time and are idempotent.
- [ ] PERF-40, PERF-43: env and platform changes are listed as `deploy_pending`, and no deploy command is run.

## Not confirmed by the docs

Nothing here is stated as a rule.

- Pro multi-region count: the region page says Pro gets "5 regions" while the Fluid compute page says
  "Up to 3", so no number is given. Both agree Hobby is a single region
  (https://vercel.com/docs/functions/configuring-functions/region;
  https://vercel.com/docs/fluid-compute).
- Remote image TTL on Vercel: the Image Optimization page gives a `minimumCacheTTL` default of `3600`
  for remote images, while the Next.js image reference and upgrade guide give `14400` for Next.js 16.
  Only the Next.js value is stated (https://vercel.com/docs/image-optimization;
  https://nextjs.org/docs/app/api-reference/components/image;
  https://nextjs.org/docs/app/guides/upgrading/version-16).
- `optimizePackageImports` in production: the bundling guide recommends it for packages with many
  exports, while its own page says it is experimental and not recommended for production. It is stated
  as experimental only (https://nextjs.org/docs/app/guides/package-bundling;
  https://nextjs.org/docs/app/api-reference/config/next-config-js/optimizePackageImports).
- Edge on Next.js 16.3, warning or error: the Next.js pages say "deprecated" and the Vercel page says
  "no longer supported" from 16.3. Neither says whether the export warns or fails the build, and the
  16.3 release post does not mention it
  (https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/runtime;
  https://nextjs.org/docs/messages/edge-runtime-deprecated;
  https://vercel.com/docs/functions/runtimes/edge; https://nextjs.org/blog/next-16-3).
- A general Route Handler request body limit in Next.js: no page found documents one. Only the Server
  Actions limit and Proxy's buffered-body cap `proxyClientMaxBodySize` are documented, and the latter
  is experimental (https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions;
  https://nextjs.org/docs/app/api-reference/config/next-config-js/proxyClientMaxBodySize).
- A Speed Insights dashboard-enable step: its quickstart shows none, while the Web Analytics quickstart
  does, so the step is stated only for Web Analytics (https://vercel.com/docs/speed-insights/quickstart;
  https://vercel.com/docs/analytics/quickstart).
- AVIF after the August 2026 release: the post says the patched releases disable AVIF optimization until an upstream fix
  is propagated. Neither the September 2026 release post nor the Image API page says it came back, and that page still
  documents `image/avif` in `formats` with no caveat, so the file says to leave it out
  (https://nextjs.org/blog/august-2026-security-release; https://nextjs.org/blog/september-2026-security-release;
  https://nextjs.org/docs/app/api-reference/components/image).

## Sources

- https://nextjs.org/docs/app/getting-started/images — Images guide
- https://nextjs.org/docs/app/api-reference/components/image — `Image` component reference
- https://nextjs.org/docs/app/getting-started/fonts — Fonts guide
- https://nextjs.org/docs/app/api-reference/components/font — `next/font` reference
- https://nextjs.org/docs/app/guides/scripts — Scripts guide
- https://nextjs.org/docs/app/api-reference/components/script — `Script` component reference
- https://nextjs.org/docs/app/guides/third-party-libraries — `@next/third-parties`
- https://nextjs.org/docs/app/guides/lazy-loading — lazy loading and `next/dynamic`
- https://nextjs.org/docs/app/guides/package-bundling — bundle analysis and package bundling
- https://nextjs.org/docs/app/api-reference/config/next-config-js/optimizePackageImports — `optimizePackageImports`
- https://nextjs.org/docs/app/api-reference/config/next-config-js/serverExternalPackages — `serverExternalPackages`
- https://nextjs.org/docs/app/getting-started/server-and-client-components — Server and Client Components
- https://nextjs.org/docs/app/api-reference/turbopack — Turbopack
- https://nextjs.org/docs/app/api-reference/config/next-config-js/turbopackFileSystemCache — Turbopack filesystem cache
- https://nextjs.org/docs/app/api-reference/cli/next — `next` CLI
- https://nextjs.org/docs/app/api-reference/config/next-config-js/reactCompiler — `reactCompiler`
- https://nextjs.org/docs/app/api-reference/functions/use-report-web-vitals — `useReportWebVitals`
- https://nextjs.org/docs/app/guides/production-checklist — production checklist
- https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/runtime — `runtime` segment config
- https://nextjs.org/docs/messages/edge-runtime-deprecated — Edge Runtime deprecated
- https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/preferredRegion — `preferredRegion`
- https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/maxDuration — `maxDuration`
- https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions — `serverActions` config
- https://nextjs.org/docs/app/api-reference/config/next-config-js/proxyClientMaxBodySize — `proxyClientMaxBodySize`
- https://nextjs.org/docs/app/api-reference/functions/after — `after`
- https://nextjs.org/docs/app/guides/upgrading/version-16 — upgrade guide to version 16
- https://nextjs.org/blog/next-16 — Next.js 16 release post
- https://nextjs.org/blog/next-16-3 — Next.js 16.3 release post
- https://nextjs.org/blog/august-2026-security-release — August 2026 security release (AVIF optimization disabled)
- https://nextjs.org/blog/september-2026-security-release — September 2026 security release
- https://vercel.com/docs/functions/runtimes — Vercel Function runtimes
- https://vercel.com/docs/functions/runtimes/edge — Edge runtime on Vercel
- https://vercel.com/docs/fluid-compute — Fluid compute
- https://vercel.com/docs/functions/limitations — function limits
- https://vercel.com/docs/functions/configuring-functions/duration — function duration
- https://vercel.com/docs/functions/configuring-functions/memory — function memory and CPU
- https://vercel.com/docs/functions/configuring-functions/region — function regions
- https://vercel.com/docs/caching/cdn-cache — CDN cache
- https://vercel.com/docs/caching/runtime-cache/data-cache — Data Cache
- https://vercel.com/docs/incremental-static-regeneration — Incremental Static Regeneration
- https://vercel.com/docs/image-optimization — Image Optimization on Vercel
- https://vercel.com/docs/image-optimization/limits-and-pricing — Image Optimization limits
- https://vercel.com/docs/cron-jobs — cron jobs
- https://vercel.com/docs/cron-jobs/manage-cron-jobs — managing cron jobs
- https://vercel.com/docs/limits — Vercel limits
- https://vercel.com/docs/environment-variables — environment variables
- https://vercel.com/docs/deployments/environments — deployment environments
- https://vercel.com/docs/skew-protection — Skew Protection
- https://vercel.com/docs/project-configuration — project configuration
- https://vercel.com/docs/project-configuration/vercel-ts — `vercel.ts`
- https://vercel.com/docs/speed-insights/quickstart — Speed Insights quickstart
- https://vercel.com/docs/analytics/quickstart — Web Analytics quickstart
- https://vercel.com/kb/guide/how-to-bypass-vercel-body-size-limit-serverless-functions — body size limit guide
