# Testing, errors and observability

> As of Next.js 16.3.8, verified 2026-10-04.

## Scope

This file is the standard for the tests that gate every Next.js + TypeScript story, for error handling, and for observability. Rule ids are `TEST-<n>`.

- **Tests:** unit tests with Vitest (or Jest through `next/jest`), end-to-end tests with Playwright against a production build, and what cannot be unit-tested (async Server Components).
- **Errors:** expected errors as values, uncaught exceptions in `error.tsx` and `global-error.tsx`, and `not-found.tsx`.
- **Observability:** `instrumentation.ts`, `onRequestError`, OpenTelemetry, `instrumentation-client`, Web Vitals and logging.
- **Gates:** lint, typecheck, test, build and E2E commands, plus the debugging flags.

Read the Rules first, copy from Patterns, and check your work against the Review checklist. A rule tagged `(convention)` is bmn's own choice, not a docs requirement. A claim the docs do not confirm is listed under Not confirmed by the docs and is never stated as a rule.

Neighbouring topics own their detail: route conventions for `not-found` in [routing-and-metadata.md](routing-and-metadata.md); the Server Action typed-state pattern in [data-fetching-and-mutations.md](data-fetching-and-mutations.md); handler design in [route-handlers-and-apis.md](route-handlers-and-apis.md); Proxy in [proxy-auth-and-security.md](proxy-auth-and-security.md); Speed Insights in [performance-and-vercel.md](performance-and-vercel.md); tsconfig in [typescript.md](typescript.md); caching in [rendering-and-caching.md](rendering-and-caching.md). The standard's entry point is [nextjs.md](../nextjs.md).

## Rules

### Test surfaces and unit tools

1. **TEST-1** Map every acceptance criterion onto bmn's test surfaces in [stack-routing.md](../stack-routing.md) (convention): the unit surface (Vitest or Jest) covers pure functions, schema parsing, hooks, Client Components, synchronous Server Components and the logic behind Server Actions and Route Handlers; the browser surface (Playwright) covers async Server Components, full user flows, error boundaries and not-found UI; the HTTP surface covers Route Handlers through Playwright's `request` fixture. The [testing guide](https://nextjs.org/docs/app/guides/testing) defines unit, component, integration, E2E and snapshot tests.
2. **TEST-2** Test async Server Components end to end with Playwright, never with a Vitest or Jest render, and unit-test only synchronous Server Components and Client Components. The docs say Vitest and Jest currently do not support async Server Components and recommend E2E tests for them ([testing guide](https://nextjs.org/docs/app/guides/testing), [Vitest guide](https://nextjs.org/docs/app/guides/testing/vitest), [Jest guide](https://nextjs.org/docs/app/guides/testing/jest)).
3. **TEST-3** Keep a repo's existing test runners (convention). On a repo with none, add Vitest for unit tests and Playwright for E2E, which both have official Next.js setup guides ([Vitest guide](https://nextjs.org/docs/app/guides/testing/vitest), [Playwright guide](https://nextjs.org/docs/app/guides/testing/playwright)). Where Cypress is already used, keep it and run it after `npm run build && npm run start`; its Component Testing does not support async Server Components either ([Cypress guide](https://nextjs.org/docs/app/guides/testing/cypress)).
4. **TEST-4** Set up Vitest the way the Next.js guide does: install `vitest @vitejs/plugin-react jsdom @testing-library/react @testing-library/dom vite-tsconfig-paths` as dev dependencies, and write `vitest.config.mts` with `defineConfig` from `vitest/config`, `plugins: [tsconfigPaths(), react()]` and `test.environment: 'jsdom'` ([Vitest guide](https://nextjs.org/docs/app/guides/testing/vitest)). Vitest's `environment` defaults to `'node'`, and `jsdom` gives a browser-like one ([environment option](https://vitest.dev/config/environment)).
5. **TEST-5** Configure Jest only through `next/jest`: `nextJest({ dir: './' })`, then `testEnvironment: 'jsdom'` and `coverageProvider: 'v8'`, and `export default createJestConfig(config)` so that `next/jest` can load the async Next.js config; add `moduleNameMapper` entries for path aliases. `next/jest` sets up the Next.js Compiler transform, auto-mocks stylesheets, images and `next/font`, loads `.env` files and ignores `node_modules` and `.next` ([Jest guide](https://nextjs.org/docs/app/guides/testing/jest)).
6. **TEST-6** Run unit tests once in gates with `vitest run` (or `jest`), because the `vitest` script watches for changes by default ([Vitest guide](https://nextjs.org/docs/app/guides/testing/vitest), [Vitest getting started](https://vitest.dev/guide/)).
7. **TEST-7** Write each test before its code (RED, then GREEN) and hold unit coverage at 80% or more; both are Jonathan's bmn rules (convention), not docs requirements. In Vitest, enforce the floor through `coverage.thresholds` with the v8 provider (`@vitest/coverage-v8`) and set `coverage.include` so files no test imports still count ([coverage options](https://vitest.dev/config/coverage), [coverage guide](https://vitest.dev/guide/coverage)). The Next.js Jest guide sets only `coverageProvider: 'v8'` ([Jest guide](https://nextjs.org/docs/app/guides/testing/jest)).
8. **TEST-8** Commit test defaults in `.env.test` and never depend on `.env.local` in tests, because Next.js does not load `.env.local` in the `test` environment. In Vitest, load env vars the way Next.js does, with `loadEnvConfig(process.cwd())` from `@next/env` in a setup file; `next/jest` already loads `.env` files ([environment variables](https://nextjs.org/docs/app/guides/environment-variables), [Jest guide](https://nextjs.org/docs/app/guides/testing/jest)).
9. **TEST-9** Unit-test a Route Handler as a plain function (convention): import its exported `GET` or `POST`, call it with a Web `Request`, and assert on the returned `Response`. Run those files with `// @vitest-environment node`. Route Handlers use the Web Request and Response APIs ([route.js](https://nextjs.org/docs/app/api-reference/file-conventions/route)), and Vitest accepts a per-file environment comment ([environment option](https://vitest.dev/config/environment)).
10. **TEST-10** Move Server Action logic into plain functions that take parsed input and return a typed result, and unit-test those (convention). Cover the `'use server'` action itself end to end, because Request-time APIs such as `cookies()` and `headers()` must run inside a request scope ([error message](https://nextjs.org/docs/messages/next-dynamic-api-wrong-context)) and `redirect()` throws a `NEXT_REDIRECT` error ([redirect](https://nextjs.org/docs/app/api-reference/functions/redirect)).
11. **TEST-11** Unit-test `proxy.ts` matching and rewrites with the experimental helpers `unstable_doesProxyMatch`, `isRewrite` and `getRewrittenUrl` from `next/experimental/testing/server`, which the docs label experimental ([proxy.js](https://nextjs.org/docs/app/api-reference/file-conventions/proxy)). Detail lives in [proxy-auth-and-security.md](proxy-auth-and-security.md).

### End-to-end tests

12. **TEST-12** Run Playwright E2E against a production build, as the Next.js guide recommends, and let Playwright's `webServer` start it ([Playwright guide](https://nextjs.org/docs/app/guides/testing/playwright)). Set `command: 'npm run build && npm run start'` (`next build`, then `next start`; joining the two documented steps in one command is a convention), `url`, `reuseExistingServer: !process.env.CI` and `use.baseURL`, and raise `webServer.timeout` above its 60000 ms default when the build needs longer ([webServer docs](https://playwright.dev/docs/test-webserver)).
13. **TEST-13** Give each worktree's E2E run its own port: pass `next start -p <port>` and point `webServer.url` and `baseURL` at it, so `reuseExistingServer` never attaches to another checkout's server (convention). `next start` takes `-p` or `--port` ([CLI reference](https://nextjs.org/docs/app/api-reference/cli/next)), and `reuseExistingServer: true` re-uses a server already on the port or url ([webServer docs](https://playwright.dev/docs/test-webserver)).
14. **TEST-14** Use visibility-aware locators in E2E: `getByRole`, `getByLabel`, `getByPlaceholder`, or `.filter({ visible: true })` after `locator()`. Cache Components keeps preserved routes in the DOM as hidden Activity content with `display: none`, so a bare `locator()` can match hidden elements ([preserving UI state](https://nextjs.org/docs/app/guides/preserving-ui-state)).
15. **TEST-15** Cover a Route Handler's HTTP contract with Playwright's `request` fixture against the same `webServer`, which respects `use.baseURL` ([API testing](https://playwright.dev/docs/api-testing)). It is bmn's HTTP black-box surface for a Next.js repo (convention).
16. **TEST-16** Assert a promised instant navigation under Cache Components with `instant()` from `@next/playwright`. Run it against `next dev`, or against `next start` with `experimental.exposeTestingApiInProductionBuild: true` ([instant navigation](https://nextjs.org/docs/app/guides/instant-navigation), [Next.js 16.3](https://nextjs.org/blog/next-16-3)). 16.x change: the helper is new in 16.3.
17. **TEST-17** Give every error and not-found path an E2E test (convention): force the failure, assert that the `error.tsx` fallback renders and that `retry()` recovers, then request a missing resource and assert the `not-found.tsx` UI. The docs recommend E2E for async components, and `retry()` re-fetches and re-renders the boundary's children ([testing guide](https://nextjs.org/docs/app/guides/testing), [error.js](https://nextjs.org/docs/app/api-reference/file-conventions/error)).

### Error handling

18. **TEST-18** Return expected errors (validation failures, failed requests) as values instead of throwing them: in a Server Function return state that `useActionState` reads, and in a Server Component render the error or call `redirect()` ([error handling](https://nextjs.org/docs/app/getting-started/error-handling)). The typed-state pattern lives in [data-fetching-and-mutations.md](data-fetching-and-mutations.md).
19. **TEST-19** Throw for uncaught exceptions (bugs) and let error boundaries catch them: add an `error.tsx` to each route segment that needs its own fallback, and errors bubble up to the nearest parent boundary. `error.tsx` does not wrap the `layout.tsx` or `template.tsx` of its own segment ([error handling](https://nextjs.org/docs/app/getting-started/error-handling), [error.js](https://nextjs.org/docs/app/api-reference/file-conventions/error)).
20. **TEST-20** Start every `error.tsx` and `global-error.tsx` with `'use client'`, type the props `{ error: Error & { digest?: string }; retry: () => void }`, and recover with `retry()`, which re-fetches and re-renders the boundary's children; use `reset()` only to clear error state without re-fetching ([error.js](https://nextjs.org/docs/app/api-reference/file-conventions/error)). 16.x change: `retry` became stable in 16.3, and `unstable_retry` arrived in 16.2.
21. **TEST-21** Show a generic message in error UI and correlate through `error.digest`; never present a Server Component error's `error.message` as detail, because production forwards a generic message plus the digest ([error.js](https://nextjs.org/docs/app/api-reference/file-conventions/error)). Handing the user the digest as a reference id is a convention, and Vercel advises returning an error id instead of raw messages or stacks ([structured logs guide](https://vercel.com/kb/guide/add-structured-application-logs-to-vercel-functions)).
22. **TEST-22** Add `app/global-error.tsx`: it must render its own `<html>` and `<body>`, define the global styles and fonts it needs, and set the page title with React `<title>`, because `metadata` and `generateMetadata` exports are not supported there. It replaces the root layout while active ([error.js, Global Error](https://nextjs.org/docs/app/api-reference/file-conventions/error), [production checklist](https://nextjs.org/docs/app/guides/production-checklist)).
23. **TEST-23** Call `redirect()`, `permanentRedirect()`, `notFound()` and `forbidden()` outside any `try` block, because each works by throwing and a `try/catch` suppresses it ([redirect](https://nextjs.org/docs/app/api-reference/functions/redirect), [permanentRedirect](https://nextjs.org/docs/app/api-reference/functions/permanentRedirect), [notFound](https://nextjs.org/docs/app/api-reference/functions/not-found), [forbidden](https://nextjs.org/docs/app/api-reference/functions/forbidden), experimental). Where a `catch` cannot be avoided, call `unstable_rethrow(err)` first in it; it is unstable and not recommended for production, so prefer moving the call out of the `try` ([unstable_rethrow](https://nextjs.org/docs/app/api-reference/functions/unstable_rethrow)).
24. **TEST-24** Build component-level error boundaries with `catchError` from `next/error` instead of a hand-rolled React class boundary: it lets `redirect()` and `notFound()` pass through, its `retry()` re-fetches and re-renders Server Components, and its error state clears on client navigation. Do not wrap an `error.tsx` export in it ([catchError](https://nextjs.org/docs/app/api-reference/functions/catchError)). 16.x change: stable since 16.3, after `unstable_catchError` in 16.2 ([Next.js 16.3](https://nextjs.org/blog/next-16-3)).
25. **TEST-25** Catch errors from event handlers and async callbacks yourself and keep them in `useState` or `useReducer`, because error boundaries only catch errors during rendering. Unhandled errors inside `startTransition` do bubble to the nearest boundary ([error handling](https://nextjs.org/docs/app/getting-started/error-handling)).
26. **TEST-26** Pair every `notFound()` call with a `not-found.tsx` that renders the 404 UI ([error handling](https://nextjs.org/docs/app/getting-started/error-handling)). The root `app/not-found.tsx` also handles unmatched URLs, takes no props, is a Server Component by default and may be `async`. A streamed response returns `200` and a non-streamed one returns `404` ([not-found.js](https://nextjs.org/docs/app/api-reference/file-conventions/not-found), [notFound](https://nextjs.org/docs/app/api-reference/functions/not-found)). Route-level conventions live in [routing-and-metadata.md](routing-and-metadata.md).

### Observability

27. **TEST-27** Put `instrumentation.ts` in the project root (or in `src/` when one is used), never inside `app/`, and export `register()`, which runs once per server instance and completes before requests are served. Do side-effect imports inside `register`, and import Node-only SDKs only when `process.env.NEXT_RUNTIME === 'nodejs'`, because `register` runs in all environments ([instrumentation guide](https://nextjs.org/docs/app/guides/instrumentation), [instrumentation.js](https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation)).
28. **TEST-28** Export `onRequestError`, typed `Instrumentation.onRequestError` from `next`, to report server errors with route context: `await` all async work inside it, narrow `err: unknown` before reading `message` or `digest`, and report `request.path`, `request.method`, `context.routePath` and `context.routeType` rather than the raw headers (convention, because headers can carry cookies and tokens) ([instrumentation.js](https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation)).
29. **TEST-29** Use `@vercel/otel` for OpenTelemetry: call `registerOTel({ serviceName })` inside `register()`. Configure `NodeSDK` by hand only in a Node-only module such as `instrumentation.node.ts`, because it is not compatible with the Edge runtime and Edge support needs `@vercel/otel`. Set `NEXT_OTEL_VERBOSE=1` for more spans, and `NEXT_OTEL_FETCH_DISABLED=1` when a custom fetch instrumentation replaces the built-in fetch span ([OpenTelemetry guide](https://nextjs.org/docs/app/guides/open-telemetry), [Vercel instrumentation](https://vercel.com/docs/tracing/instrumentation)).
30. **TEST-30** Add custom spans with `@opentelemetry/api` (`trace.getTracer(...).startActiveSpan(...)`) and always end the span in `finally`. Vercel does not support custom spans from functions that use the Edge runtime ([OpenTelemetry guide](https://nextjs.org/docs/app/guides/open-telemetry), [Vercel instrumentation](https://vercel.com/docs/tracing/instrumentation)).
31. **TEST-31** Put client-side error tracking and analytics that must start before hydration in `instrumentation-client.ts` (project root or `src/`). Keep it synchronous and light, because development warns when it takes over 16 ms and asynchronous work is not awaited; wrap tracking code in `try/catch`; export `onRouterTransitionStart(url, navigationType)` for navigation breadcrumbs ([instrumentation-client](https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation-client)).
32. **TEST-32** Report Web Vitals with `useReportWebVitals` from `next/web-vitals`: call it in a small `'use client'` `WebVitals` component that the root layout renders, pass a module-level callback so its reference never changes and nothing is reported twice, and send with `navigator.sendBeacon`, falling back to `fetch` with `keepalive: true` ([useReportWebVitals](https://nextjs.org/docs/app/api-reference/functions/use-report-web-vitals), [analytics](https://nextjs.org/docs/app/guides/analytics)). On Vercel, `<SpeedInsights />` from `@vercel/speed-insights/next` in the root layout is the managed option ([Speed Insights quickstart](https://vercel.com/docs/speed-insights/quickstart)); detail lives in [performance-and-vercel.md](performance-and-vercel.md).
33. **TEST-33** Treat the `logging` option in `next.config.ts` as development-terminal configuration only: its keys are `fetches`, `serverFunctions`, `incomingRequests` and `browserToTerminal`, and the reference describes each as a development-mode setting ([logging](https://nextjs.org/docs/app/api-reference/config/next-config-js/logging), [structured logs guide](https://vercel.com/kb/guide/add-structured-application-logs-to-vercel-functions)).
34. **TEST-34** Write production logs as one JSON object per `console.*` call and use `console.error` for errors, because stderr is the Error level in Vercel Runtime Logs. Stay within 256 log lines, 256 KB per line and 1 MB per request ([Runtime Logs](https://vercel.com/docs/logs/runtime), [structured logs guide](https://vercel.com/kb/guide/add-structured-application-logs-to-vercel-functions)).
35. **TEST-35** Strip secrets and PII before anything reaches `console.*` or an error reporter, and return an error id (or the `digest`) to the client instead of raw messages or stacks ([structured logs guide](https://vercel.com/kb/guide/add-structured-application-logs-to-vercel-functions)).

### Debugging and gates

36. **TEST-36** Debug with the documented flags: `next dev --inspect` (16.1+) and `next start --inspect` (16.2+); `NODE_OPTIONS=--inspect-brk next dev` to break on start; `next build --debug-prerender` for prerender errors, and never deploy that build; `next build --debug` for verbose build output; React DevTools to toggle error boundaries while testing error states ([debugging guide](https://nextjs.org/docs/app/guides/debugging), [CLI reference](https://nextjs.org/docs/app/api-reference/cli/next), [Next.js 16.1](https://nextjs.org/blog/next-16-1), [Next.js 16.2](https://nextjs.org/blog/next-16-2), [error.js](https://nextjs.org/docs/app/api-reference/file-conventions/error)).
37. **TEST-37** Gate a Next.js repo with, in order (convention): `eslint .` (the ESLint CLI with the `eslint-config-next` flat config), `next typegen && tsc --noEmit`, `vitest run --coverage` (or the Jest equivalent), `next build`, then `playwright test` ([ESLint reference](https://nextjs.org/docs/app/api-reference/config/eslint), [CLI reference](https://nextjs.org/docs/app/api-reference/cli/next)). Never use `next lint`: it was removed in Next.js 16 and `next build` no longer lints ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16)). Never set `typescript.ignoreBuildErrors: true`, which skips the type check entirely ([typescript option](https://nextjs.org/docs/app/api-reference/config/next-config-js/typescript)). tsconfig detail lives in [typescript.md](typescript.md).
38. **TEST-38** Never run two `next build` or two `next dev` processes in the same project directory at once, because a lockfile blocks it; `next dev` writes to `.next/dev`, so one dev server and one build can run side by side ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16)).

## Patterns

Snippets are typed for strict TypeScript and use only APIs the cited pages show. Endpoints such as `https://errors.example.com/report` and `/api/vitals` are placeholders.

### vitest.config.mts (TEST-4, TEST-7)

The guide's config, plus the 80% coverage floor.

```ts
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import tsconfigPaths from 'vite-tsconfig-paths'

export default defineConfig({
  plugins: [tsconfigPaths(), react()],
  test: {
    environment: 'jsdom',
    coverage: {
      provider: 'v8',
      include: ['src/**/*.{ts,tsx}'],
      // 80% floor: bmn convention (TEST-7)
      thresholds: { lines: 80, functions: 80, branches: 80, statements: 80 },
    },
  },
})
```

### Route Handler unit test (TEST-9)

The handler in `app/api/hello/route.ts`, then its test beside it.

```ts
export async function GET(request: Request): Promise<Response> {
  const name = new URL(request.url).searchParams.get('name') ?? 'world'
  return Response.json({ message: `Hello ${name}` })
}
```

```ts
// @vitest-environment node
import { expect, test } from 'vitest'
import { GET } from './route'

test('GET greets the caller by name', async () => {
  const response = await GET(new Request('http://localhost/api/hello?name=Ada'))
  expect(response.status).toBe(200)
  expect(await response.json()).toEqual({ message: 'Hello Ada' })
})
```

### Server Action logic as a pure function (TEST-10, TEST-18)

The service returns an expected error as a value, and its test needs no request scope.

```ts
export type ValidationResult =
  | { ok: true; value: { title: string } }
  | { ok: false; message: string }

export function validatePost(formData: FormData): ValidationResult {
  const title = formData.get('title')
  if (typeof title !== 'string' || title.trim() === '') {
    return { ok: false, message: 'Title is required.' }
  }
  return { ok: true, value: { title: title.trim() } }
}
```

```ts
import { expect, test } from 'vitest'
import { validatePost } from './validate-post'

test('a blank title comes back as an expected error', () => {
  const formData = new FormData()
  formData.set('title', '   ')
  expect(validatePost(formData)).toEqual({ ok: false, message: 'Title is required.' })
})
```

### playwright.config.ts (TEST-12, TEST-13)

A production build on its own port, started by Playwright.

```ts
import { defineConfig } from '@playwright/test'

const PORT = Number(process.env.E2E_PORT ?? 3100)
const baseURL = `http://localhost:${PORT}`

export default defineConfig({
  webServer: {
    command: `npm run build && npm run start -- -p ${PORT}`,
    url: baseURL,
    reuseExistingServer: !process.env.CI,
    timeout: 180_000,
  },
  use: { baseURL },
})
```

### E2E specs (TEST-2, TEST-14, TEST-15, TEST-17)

An async Server Component page, a not-found path and a Route Handler, all against the running server.

```ts
import { expect, test } from '@playwright/test'

test('the dashboard renders its heading', async ({ page }) => {
  await page.goto('/dashboard')
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible()
})

test('a missing post renders the not-found UI', async ({ page }) => {
  await page.goto('/blog/does-not-exist')
  await expect(page.getByRole('heading', { name: 'Post not found' })).toBeVisible()
})

test('GET /api/hello returns the greeting', async ({ request }) => {
  const response = await request.get('/api/hello?name=Ada')
  expect(response.ok()).toBeTruthy()
  expect(await response.json()).toEqual({ message: 'Hello Ada' })
})
```

### instrumentation.ts (TEST-27, TEST-28, TEST-29, TEST-35)

OpenTelemetry in `register`, and `onRequestError` reporting chosen fields only.

```ts
import { registerOTel } from '@vercel/otel'
import { type Instrumentation } from 'next'

export function register(): void {
  registerOTel({ serviceName: 'next-app' })
}

export const onRequestError: Instrumentation.onRequestError = async (err, request, context) => {
  const message = err instanceof Error ? err.message : String(err)
  const digest =
    typeof err === 'object' && err !== null && 'digest' in err ? String(err.digest) : undefined

  // Headers can carry cookies and tokens, so send chosen fields only (TEST-28, TEST-35).
  await fetch('https://errors.example.com/report', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      message,
      digest,
      path: request.path,
      method: request.method,
      routePath: context.routePath,
      routeType: context.routeType,
    }),
  })
}
```

### Custom span (TEST-30)

The span always ends in `finally`.

```ts
import { trace } from '@opentelemetry/api'
import { loadDashboard } from '@/features/dashboard/services/load-dashboard'

export async function loadDashboardTraced() {
  return trace.getTracer('app').startActiveSpan('loadDashboard', async (span) => {
    try {
      return await loadDashboard()
    } finally {
      span.end()
    }
  })
}
```

### app/dashboard/error.tsx (TEST-20, TEST-21)

A segment boundary typed with `error.digest` and `retry`. It renders no `<html>`.

```tsx
'use client'

import { useEffect } from 'react'

export default function ErrorPage({
  error,
  retry,
}: {
  error: Error & { digest?: string }
  retry: () => void
}) {
  useEffect(() => {
    console.error(error)
  }, [error])

  return (
    <div role="alert">
      <h2>Something went wrong.</h2>
      {error.digest ? <p>Reference: {error.digest}</p> : null}
      <button type="button" onClick={() => retry()}>
        Try again
      </button>
    </div>
  )
}
```

### app/global-error.tsx (TEST-22)

The root boundary renders the whole document.

```tsx
'use client'

import './globals.css'

export default function GlobalError({
  error,
  retry,
}: {
  error: Error & { digest?: string }
  retry: () => void
}) {
  return (
    <html lang="en">
      <body>
        <title>Something went wrong</title>
        <h2>Something went wrong.</h2>
        {error.digest ? <p>Reference: {error.digest}</p> : null}
        <button type="button" onClick={() => retry()}>
          Try again
        </button>
      </body>
    </html>
  )
}
```

### unstable_rethrow when a catch is unavoidable (TEST-23)

The framework interrupt passes through; every other error is handled.

```tsx
import { notFound, unstable_rethrow } from 'next/navigation'

async function loadPost(): Promise<unknown> {
  const res = await fetch('https://api.example.com/posts/1')
  if (res.status === 404) notFound()
  if (!res.ok) throw new Error(res.statusText)
  return res.json()
}

export default async function Page() {
  try {
    await loadPost()
  } catch (err: unknown) {
    unstable_rethrow(err)
    console.error(err)
  }
  return <p>The post is unavailable.</p>
}
```

### catchError boundary (TEST-24)

A component-level boundary that `redirect()` and `notFound()` pass through.

```tsx
'use client'

import { catchError, type ErrorInfo } from 'next/error'

function ErrorFallback(props: { title: string }, { retry }: ErrorInfo) {
  return (
    <div role="alert">
      <h2>{props.title}</h2>
      <button type="button" onClick={() => retry()}>
        Try again
      </button>
    </div>
  )
}

export default catchError(ErrorFallback)
```

### instrumentation-client.ts (TEST-31)

Synchronous, light and wrapped in `try/catch`.

```ts
try {
  performance.mark('app-init')
  window.addEventListener('error', (event: ErrorEvent) => {
    navigator.sendBeacon('/api/client-errors', JSON.stringify({ message: event.message }))
  })
} catch (err: unknown) {
  console.error(err)
}

export function onRouterTransitionStart(
  url: string,
  navigationType: 'push' | 'replace' | 'traverse',
): void {
  performance.mark(`nav-start-${url}`)
}
```

### WebVitals component (TEST-32)

Rendered by the root layout. The callback is module-level, so its reference is stable.

```tsx
'use client'

import { useReportWebVitals } from 'next/web-vitals'

type ReportWebVitalsCallback = Parameters<typeof useReportWebVitals>[0]

const reportWebVitals: ReportWebVitalsCallback = (metric) => {
  const body = JSON.stringify(metric)
  if (navigator.sendBeacon) {
    navigator.sendBeacon('/api/vitals', body)
  } else {
    void fetch('/api/vitals', { body, method: 'POST', keepalive: true })
  }
}

export function WebVitals(): null {
  useReportWebVitals(reportWebVitals)
  return null
}
```

### Structured error logger (TEST-34, TEST-35)

One JSON line per call on `console.error`. It returns the error id for the client.

```ts
type LogFields = Record<string, string | number | boolean | null>

export function logError(message: string, err: unknown, fields: LogFields = {}): string {
  const errorId = crypto.randomUUID()
  console.error(
    JSON.stringify({
      level: 'error',
      message,
      errorId,
      errorType: err instanceof Error ? err.name : typeof err,
      ...fields,
    }),
  )
  return errorId
}
```

### Gate scripts (TEST-6, TEST-37)

```json
{
  "scripts": {
    "lint": "eslint .",
    "typecheck": "next typegen && tsc --noEmit",
    "test": "vitest",
    "test:ci": "vitest run --coverage",
    "build": "next build",
    "start": "next start",
    "e2e": "playwright test"
  }
}
```

## Anti-patterns

### Don't: unit-render an async Server Component (TEST-2)

```tsx
import { render } from '@testing-library/react'
import { test } from 'vitest'
import Page from '../app/dashboard/page'

test('dashboard', async () => {
  render(await Page())
})
```

**Do:** cover the page end to end with Playwright and a visibility-aware locator.

```ts
import { expect, test } from '@playwright/test'

test('dashboard', async ({ page }) => {
  await page.goto('/dashboard')
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible()
})
```

### Don't: call redirect() inside try (TEST-23)

```ts
'use server'

import { redirect } from 'next/navigation'
import { savePost } from '@/features/posts/services/save-post'

export async function createPost(formData: FormData): Promise<void> {
  try {
    await savePost(formData)
    redirect('/posts')
  } catch (err: unknown) {
    console.error(err)
  }
}
```

**Do:** call it after the work, outside any `try`, and return expected errors as values (TEST-18).

```ts
'use server'

import { redirect } from 'next/navigation'
import { savePost } from '@/features/posts/services/save-post'

export async function createPost(formData: FormData): Promise<void> {
  await savePost(formData)
  redirect('/posts')
}
```

### Don't: throw for a validation failure (TEST-18)

```ts
'use server'

export async function createPost(formData: FormData): Promise<void> {
  const title = formData.get('title')
  if (typeof title !== 'string' || title === '') {
    throw new Error('Title is required')
  }
}
```

**Do:** return the expected error as state for `useActionState`; the full pattern is in [data-fetching-and-mutations.md](data-fetching-and-mutations.md).

```ts
'use server'

export type PostState = { message: string }

export async function createPost(_prevState: PostState, formData: FormData): Promise<PostState> {
  const title = formData.get('title')
  if (typeof title !== 'string' || title === '') {
    return { message: 'Title is required.' }
  }
  return { message: '' }
}
```

### Don't: write a server-style error boundary (TEST-20, TEST-21)

```tsx
export default function ErrorPage({ error, reset }: { error: Error; reset: () => void }) {
  return (
    <div>
      <p>{error.message}</p>
      <button type="button" onClick={() => reset()}>
        Try again
      </button>
    </div>
  )
}
```

**Do:** use `'use client'`, type `error.digest`, show a generic message and recover with `retry()`.

```tsx
'use client'

export default function ErrorPage({
  error,
  retry,
}: {
  error: Error & { digest?: string }
  retry: () => void
}) {
  return (
    <div role="alert">
      <p>Something went wrong. Reference: {error.digest}</p>
      <button type="button" onClick={() => retry()}>
        Try again
      </button>
    </div>
  )
}
```

### Don't: return a div from global-error (TEST-22)

```tsx
'use client'

export default function GlobalError() {
  return <div>Something went wrong.</div>
}
```

**Do:** render the whole document, because `global-error.tsx` replaces the root layout.

```tsx
'use client'

export default function GlobalError({ retry }: { retry: () => void }) {
  return (
    <html lang="en">
      <body>
        <h2>Something went wrong.</h2>
        <button type="button" onClick={() => retry()}>
          Try again
        </button>
      </body>
    </html>
  )
}
```

### Don't: run E2E against the dev server (TEST-12)

```ts
import { defineConfig } from '@playwright/test'

export default defineConfig({
  webServer: { command: 'npm run dev', url: 'http://localhost:3000' },
})
```

**Do:** build and start on its own port, and point `baseURL` at it.

```ts
import { defineConfig } from '@playwright/test'

export default defineConfig({
  webServer: {
    command: 'npm run build && npm run start -- -p 3100',
    url: 'http://localhost:3100',
    reuseExistingServer: !process.env.CI,
  },
  use: { baseURL: 'http://localhost:3100' },
})
```

### Don't: lint with next lint (TEST-37)

```json
{ "scripts": { "lint": "next lint" } }
```

**Do:** call the ESLint CLI, because `next lint` was removed in Next.js 16.

```json
{ "scripts": { "lint": "eslint ." } }
```

## Version notes

Changes in Next.js 16 that touch this topic, up to 16.3. Each item was confirmed on the page it links.

- **16.0**
  - `next lint` and the `eslint` config option were removed, and `next build` no longer lints; the upgrade guide gives the codemod `npx @next/codemod@canary next-lint-to-eslint-cli .`. `@next/eslint-plugin-next` defaults to flat config ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16), [ESLint reference](https://nextjs.org/docs/app/api-reference/config/eslint), [Next.js 16](https://nextjs.org/blog/next-16)).
  - Turbopack is the default for `next dev` and `next build` (`--webpack` opts out). The minimums are Node.js 20.9 and TypeScript 5.1 ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16)).
  - `next dev` writes to `.next/dev`, and a lockfile blocks concurrent instances ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16)).
  - Development request logs gain Compile and Render timing, and build steps print their durations ([Next.js 16](https://nextjs.org/blog/next-16)).
  - Next.js DevTools MCP (`next-devtools-mcp`) gives coding agents dev-server errors and logs ([MCP guide](https://nextjs.org/docs/app/guides/mcp), [Next.js 16](https://nextjs.org/blog/next-16)).
- **16.1:** `next dev --inspect` ([Next.js 16.1](https://nextjs.org/blog/next-16-1)).
- **16.2** ([Next.js 16.2](https://nextjs.org/blog/next-16-2)):
  - `next start --inspect`;
  - Server Function logging in development, through `logging.serverFunctions`;
  - `logging.browserToTerminal`, moved from `experimental.browserDebugInfoInTerminal` ([logging](https://nextjs.org/docs/app/api-reference/config/next-config-js/logging));
  - a redesigned default error page, and `Error.cause` chains in the dev overlay;
  - `unstable_retry` and `unstable_catchError` added.
- **16.3:**
  - the `retry` prop and `catchError` became stable ([error.js](https://nextjs.org/docs/app/api-reference/file-conventions/error), [catchError](https://nextjs.org/docs/app/api-reference/functions/catchError), [Next.js 16.3](https://nextjs.org/blog/next-16-3));
  - the `@next/playwright` `instant()` helper ([Next.js 16.3](https://nextjs.org/blog/next-16-3), [instant navigation](https://nextjs.org/docs/app/guides/instant-navigation));
  - an experimental router transition start event in `instrumentation-client` ([instrumentation-client](https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation-client));
  - `next build` runs the project-local `tsc` by default, which enables TypeScript 7; the option page marks it experimental ([useTypeScriptCli](https://nextjs.org/docs/app/api-reference/config/next-config-js/useTypeScriptCli), [Next.js 16.3](https://nextjs.org/blog/next-16-3)).
- **Unchanged in Next.js 16:** `register` and `onRequestError` (since v15.0.0) and `instrumentation-client` (since v15.3). Their version histories list no 16.x change apart from the 16.3 experimental event ([instrumentation.js](https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation), [instrumentation-client](https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation-client)). The upgrade guide lists no change to testing setup ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16)).

## Review checklist

- [ ] TEST-1, TEST-2: every acceptance criterion maps to a test surface, and async Server Components have Playwright coverage rather than a Vitest or Jest render.
- [ ] TEST-4, TEST-5: the runner config matches the Next.js guide (`vitest.config.mts` with `jsdom`, or Jest through `next/jest`).
- [ ] TEST-6, TEST-7: the gate runs unit tests once, with coverage at 80% or more and `coverage.include` set.
- [ ] TEST-9, TEST-10: Route Handler and action logic is unit-tested as plain functions, and request-scope paths are covered end to end.
- [ ] TEST-12, TEST-13: E2E runs against a production build on its own port, with `reuseExistingServer: !process.env.CI`.
- [ ] TEST-14: E2E locators are visibility-aware (`getByRole`, `getByLabel`, `.filter({ visible: true })`).
- [ ] TEST-15: Route Handler contracts are covered with Playwright's `request` fixture.
- [ ] TEST-17: every error and not-found path has an E2E test.
- [ ] TEST-18: expected errors are returned as values, never thrown.
- [ ] TEST-19: bugs throw, and the nearest `error.tsx` covers the segment.
- [ ] TEST-20: each boundary starts with `'use client'` and is typed with `digest` and `retry`.
- [ ] TEST-21: no Server Component `error.message` is shown to the user.
- [ ] TEST-22: `global-error.tsx` renders `<html>` and `<body>` and exports no `metadata`.
- [ ] TEST-23: no `redirect()`, `notFound()`, `permanentRedirect()` or `forbidden()` sits inside a `try`.
- [ ] TEST-25: event-handler and async errors go to state, not to a boundary.
- [ ] TEST-26: every `notFound()` has a `not-found.tsx`.
- [ ] TEST-27, TEST-28: `instrumentation.ts` sits at the root or in `src/`, gates Node-only imports on `NEXT_RUNTIME`, awaits `onRequestError` and narrows `unknown`.
- [ ] TEST-31, TEST-32: client instrumentation is synchronous and light, and the Web Vitals callback has a stable reference.
- [ ] TEST-34, TEST-35: logs are JSON, errors use `console.error`, and no PII or raw headers are logged.
- [ ] TEST-37, TEST-38: gates are `eslint .`, `next typegen && tsc --noEmit`, `next build` and `playwright test`, with no `next lint` and no `ignoreBuildErrors`.

## Not confirmed by the docs

Nothing here is stated as a rule. Each item lists the page checked.

- Calling a `'use server'` action or a Route Handler export directly from a unit test. This is why TEST-9 and TEST-10 are tagged convention. Checked: https://nextjs.org/docs/app/guides/testing/vitest, https://nextjs.org/docs/app/guides/testing/jest, https://nextjs.org/docs/app/guides/testing/playwright, https://nextjs.org/docs/app/guides/testing/cypress, https://nextjs.org/docs/app/getting-started/mutating-data and https://nextjs.org/docs/app/api-reference/file-conventions/route.
- Mocking `next/navigation`, `next/headers` or `server-only` inside Vitest or Jest. Checked: https://nextjs.org/docs/app/guides/testing/vitest and https://nextjs.org/docs/app/guides/testing/jest.
- The `next/experimental/testmode/playwright` fetch-mocking test mode. The Playwright guide does not mention it. Checked: https://nextjs.org/docs/app/guides/testing/playwright.
- Enforcing a coverage floor in Jest. The Jest guide sets only `coverageProvider: 'v8'`. Checked: https://nextjs.org/docs/app/guides/testing/jest.
- Any coverage percentage. No Next.js page sets one, so the 80% floor is Jonathan's convention. Checked: https://nextjs.org/docs/app/guides/testing, https://nextjs.org/docs/app/guides/testing/vitest and https://nextjs.org/docs/app/guides/testing/jest.
- `@testing-library/jest-dom` matchers under Vitest. The Next.js Vitest guide does not set them up. Checked: https://nextjs.org/docs/app/guides/testing/vitest.
- That `webServer` should run a production build. The Playwright guide says `webServer` starts the development server and, separately, recommends testing production code; TEST-12 joins the two and labels that. Checked: https://nextjs.org/docs/app/guides/testing/playwright and https://playwright.dev/docs/test-webserver.
- Whether `unstable_retry` still works as an alias in 16.3. The version history records only that `retry` became stable. Checked: https://nextjs.org/docs/app/api-reference/file-conventions/error.
- Whether `ErrorInfo` from `next/error` is the documented prop type for an `error.tsx` default export in 16.3. The 16.2 post used it with `unstable_retry`, but the 16.3 reference types the props inline, so the Patterns use the inline type. Checked: https://nextjs.org/docs/app/api-reference/file-conventions/error, https://nextjs.org/docs/app/api-reference/functions/catchError and https://nextjs.org/blog/next-16-2.
- Whether `import './globals.css'` is the documented way to give `global-error.tsx` its styles. The error.js page says it must define its own global styles but shows no import; the not-found.js page imports `./globals.css` in `global-not-found.tsx`. Checked: https://nextjs.org/docs/app/api-reference/file-conventions/error and https://nextjs.org/docs/app/api-reference/file-conventions/not-found.
- The exact `message` of the error thrown by `redirect()` or `notFound()`. Tests must not assert on it. Checked: https://nextjs.org/docs/app/api-reference/functions/redirect and https://nextjs.org/docs/app/api-reference/functions/not-found.
- Whether `onRequestError`'s `routeType: 'proxy'` replaced a `'middleware'` value in 16. No version history entry says so. Checked: https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation and https://nextjs.org/docs/app/guides/upgrading/version-16.

## Sources

- https://nextjs.org/docs/app/guides/testing — testing overview and the async Server Component limit
- https://nextjs.org/docs/app/guides/testing/vitest — Vitest setup
- https://nextjs.org/docs/app/guides/testing/jest — Jest setup through next/jest
- https://nextjs.org/docs/app/guides/testing/playwright — Playwright setup
- https://nextjs.org/docs/app/guides/testing/cypress — Cypress setup
- https://nextjs.org/docs/app/guides/preserving-ui-state — Activity and testing hidden content
- https://nextjs.org/docs/app/guides/instant-navigation — the instant() helper
- https://nextjs.org/docs/app/guides/environment-variables — test environment variables
- https://nextjs.org/docs/app/guides/production-checklist — global error UI
- https://nextjs.org/docs/app/guides/instrumentation — instrumentation guide
- https://nextjs.org/docs/app/guides/open-telemetry — OpenTelemetry guide
- https://nextjs.org/docs/app/guides/analytics — analytics and Web Vitals
- https://nextjs.org/docs/app/guides/debugging — debugging guide
- https://nextjs.org/docs/app/guides/mcp — Next.js DevTools MCP
- https://nextjs.org/docs/app/guides/upgrading/version-16 — upgrade guide to version 16
- https://nextjs.org/docs/app/getting-started/error-handling — expected errors and uncaught exceptions
- https://nextjs.org/docs/app/getting-started/mutating-data — Server Functions and mutations
- https://nextjs.org/docs/app/api-reference/file-conventions/route — route.js reference
- https://nextjs.org/docs/app/api-reference/file-conventions/proxy — proxy.js reference and unit testing
- https://nextjs.org/docs/app/api-reference/file-conventions/error — error.js and global-error
- https://nextjs.org/docs/app/api-reference/file-conventions/not-found — not-found.js reference
- https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation — instrumentation.js reference
- https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation-client — instrumentation-client reference
- https://nextjs.org/docs/app/api-reference/functions/catchError — catchError reference
- https://nextjs.org/docs/app/api-reference/functions/redirect — redirect reference
- https://nextjs.org/docs/app/api-reference/functions/permanentRedirect — permanentRedirect reference
- https://nextjs.org/docs/app/api-reference/functions/not-found — notFound reference
- https://nextjs.org/docs/app/api-reference/functions/forbidden — forbidden reference
- https://nextjs.org/docs/app/api-reference/functions/unstable_rethrow — unstable_rethrow reference
- https://nextjs.org/docs/app/api-reference/functions/use-report-web-vitals — useReportWebVitals reference
- https://nextjs.org/docs/app/api-reference/config/next-config-js/logging — logging option
- https://nextjs.org/docs/app/api-reference/config/next-config-js/typescript — typescript option
- https://nextjs.org/docs/app/api-reference/config/next-config-js/useTypeScriptCli — useTypeScriptCli option
- https://nextjs.org/docs/app/api-reference/config/eslint — ESLint setup
- https://nextjs.org/docs/app/api-reference/cli/next — next CLI reference
- https://nextjs.org/docs/messages/next-dynamic-api-wrong-context — Request-time API outside a request
- https://nextjs.org/blog/next-16 — Next.js 16 release post
- https://nextjs.org/blog/next-16-1 — Next.js 16.1 release post
- https://nextjs.org/blog/next-16-2 — Next.js 16.2 release post
- https://nextjs.org/blog/next-16-3 — Next.js 16.3 release post
- https://vercel.com/docs/tracing/instrumentation — Vercel OpenTelemetry instrumentation
- https://vercel.com/docs/logs/runtime — Vercel Runtime Logs
- https://vercel.com/docs/speed-insights/quickstart — Speed Insights quickstart
- https://vercel.com/kb/guide/add-structured-application-logs-to-vercel-functions — structured application logs
- https://vitest.dev/config/environment — Vitest environment option
- https://vitest.dev/config/coverage — Vitest coverage options
- https://vitest.dev/guide/coverage — Vitest coverage guide
- https://vitest.dev/guide/ — Vitest getting started
- https://playwright.dev/docs/test-webserver — Playwright webServer
- https://playwright.dev/docs/api-testing — Playwright API testing
