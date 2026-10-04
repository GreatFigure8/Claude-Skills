# Route Handlers and API design

> As of Next.js 16.3.8, verified 2026-10-04.

## Scope

How to build Route Handlers (`route.ts`) as real HTTP APIs, and how to choose between a Route Handler, a Server Action and a Server Component. A Route Handler is a publicly reachable endpoint, so each one validates its input, returns one error shape, checks authorization itself and states its caching, runtime and duration on purpose ([Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend)).

- Streaming responses and SSE: [sse-and-streaming.md](sse-and-streaming.md).
- Sessions, the DAL, `proxy.ts` and CSP: [proxy-auth-and-security.md](proxy-auth-and-security.md).
- Choosing `maxDuration`, regions and runtime trade-offs: [performance-and-vercel.md](performance-and-vercel.md).
- Server Action details: [data-fetching-and-mutations.md](data-fetching-and-mutations.md).
- The Cache Components model: [rendering-and-caching.md](rendering-and-caching.md).
- Testing handlers: [testing-and-observability.md](testing-and-observability.md).
- Back to the entry point: [../nextjs.md](../nextjs.md).

## Rules

1. **API-1** Put every endpoint in a `route.ts` file inside `app/`, never in the same route segment as a `page.tsx`: a `route.ts` and a `page.tsx` at one segment conflict, and each takes over every HTTP verb for its URL ([Route Handlers](https://nextjs.org/docs/app/getting-started/route-handlers)).
2. **API-2** Export one named function per HTTP method you serve (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS`). Next.js answers any other method with `405 Method Not Allowed`, and when you don't export `OPTIONS` it implements it and sets the `Allow` header for you ([Route Handlers](https://nextjs.org/docs/app/getting-started/route-handlers), [route.js](https://nextjs.org/docs/app/api-reference/file-conventions/route)).
3. **API-3** Type the first argument as `NextRequest` when you need `request.nextUrl` or `request.cookies`, and as the Web `Request` otherwise. Return `Response.json(body, { status, headers })` or `new Response(...)`, and use `NextResponse` only for its helpers (`redirect()`, `rewrite()`, response `cookies`): a `NextRequest` can go wherever a `Request` is expected, and a `NextResponse` wherever a `Response` is ([Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend), [NextRequest](https://nextjs.org/docs/app/api-reference/functions/next-request), [NextResponse](https://nextjs.org/docs/app/api-reference/functions/next-response), [MDN Response.json()](https://developer.mozilla.org/en-US/docs/Web/API/Response/json_static)).
4. **API-4** Type the context argument with the global `RouteContext<'/route/[param]'>` helper and `await ctx.params` before reading a segment. `params` is a Promise, Next.js 16 removed synchronous access, and `next dev`, `next build` or `next typegen` generate the helper, which needs no import ([route.js](https://nextjs.org/docs/app/api-reference/file-conventions/route), [Upgrading to 16](https://nextjs.org/docs/app/guides/upgrading/version-16)).
5. **API-5** Build public, third-party, webhook and callback endpoints, and non-UI responses (JSON, XML, files, `rss.xml`), as Route Handlers, and build the app's own UI mutations as Server Actions. Route Handlers are public HTTP endpoints any client can call, while a Server Action's primary purpose is to mutate data from your own frontend, and Server Actions are queued and dispatched sequentially, so parallel non-mutation requests belong in a Route Handler ([Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend), [Server Actions](https://nextjs.org/docs/app/guides/server-actions), [Mutating Data](https://nextjs.org/docs/app/getting-started/mutating-data)).
6. **API-6** Read data in a Server Component straight from its source (the DAL or a service function), never by `fetch`ing your own Route Handler: a Server Component prerendered at build time fails because no server is listening, and one rendered on demand pays an extra HTTP round trip ([Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend)).
7. **API-7** Name resources as plural nouns and let the method carry the verb: `app/api/projects/route.ts` serves `GET` (list) and `POST` (create), and `app/api/projects/[id]/route.ts` serves `GET`, `PATCH` and `DELETE` for one item. Put no verb in a path such as `/api/createProject` (convention); dynamic segments follow [route.js](https://nextjs.org/docs/app/api-reference/file-conventions/route).
8. **API-8** Validate every input at the boundary before using it: the body, `params`, `searchParams` and any header you act on. Call a schema's `safeParse` and pass only the parsed `data` onward, because folders in brackets are user input too ([Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend), [Data Security](https://nextjs.org/docs/app/guides/data-security), [Zod basics](https://zod.dev/basics)).
9. **API-9** Check `Content-Type` before reading a body and answer `415` when the endpoint doesn't accept it. Wrap `await request.json()` in `try`/`catch` and answer a parse failure with `400` and code `invalid_json`, because `request.json()` rejects with a `SyntaxError` on malformed JSON, which is the client's mistake and not a `500` ([Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend), [MDN Request.json()](https://developer.mozilla.org/en-US/docs/Web/API/Request/json), [MDN HTTP status codes](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status)).
10. **API-10** Return every error as the one `ApiErrorBody` envelope from Patterns, `{ error: { code, message, fieldErrors? } }`, through `Response.json(body, { status })`. Return every success as `{ data }` and let lists add `nextCursor`, so clients branch on `error.code` and never on message text (convention); `Response.json` is documented by [MDN Response.json()](https://developer.mozilla.org/en-US/docs/Web/API/Response/json_static).
11. **API-11** Pick the status by meaning: `200` read or update; `201` with a `Location` header after a create; `202` when work is queued; `204` with no body; `400` invalid input; `401` no valid credentials; `403` known caller without rights; `404` unknown resource; `409` state conflict; `415` unsupported media type; `429` rate limited; `500` unexpected failure ([MDN HTTP status codes](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status), [MDN 201 Created](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status/201)).
12. **API-12** Keep internal detail out of error responses: no `error.message`, stack trace, SQL or upstream body. Log it on the server and answer `500` with code `internal`, and strip sensitive or unneeded fields from responses and logs. The page's own snippets echo `reason.message`, so follow its prose and not those snippets ([Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend)).
13. **API-13** Authenticate and authorize inside every Route Handler that is not public by design: return `401` when there is no valid session and `403` when the caller lacks the role or permission. Mark an intentionally public handler with a `// public by design` comment (convention) ([Authentication](https://nextjs.org/docs/app/guides/authentication), [Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend)).
14. **API-14** Read the session with a function that returns `null` when unauthenticated (for example `getSession()` from [proxy-auth-and-security.md](proxy-auth-and-security.md)) and answer `401` JSON. Don't reuse a page-oriented helper that calls `redirect('/login')`, because `redirect()` answers with a `307` redirect and not an API error ([Authentication](https://nextjs.org/docs/app/guides/authentication), [redirect](https://nextjs.org/docs/app/api-reference/functions/redirect)).
15. **API-15** Authorize the specific resource and not only the user: scope every read and write by the session's user (for example `where: { id, ownerId }`) and answer `404` when the caller may not know the resource exists. Authentication alone leaves Insecure Direct Object Reference holes ([Data Security](https://nextjs.org/docs/app/guides/data-security), [MDN HTTP status codes](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status)).
16. **API-16** Never rely on `proxy.ts` alone to protect an API. Proxy checks are optimistic and not meant to be your only line of defense, the documented auth matcher excludes `api`, and the docs say to verify credentials before granting access, so re-check the session inside every protected handler ([Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend), [Authentication](https://nextjs.org/docs/app/guides/authentication)).
17. **API-17** Reject a cookie-authenticated `POST`, `PUT`, `PATCH` or `DELETE` with `403` when its `Origin` header is not your app's origin. Next.js documents its Origin-versus-Host check for Server Actions only and no Route Handler page describes one, so this check is yours to write (convention) ([Data Security](https://nextjs.org/docs/app/guides/data-security), [Server Actions](https://nextjs.org/docs/app/guides/server-actions)).
18. **API-18** Return `401` and `403` as explicit responses and don't call `forbidden()` in a Route Handler: it needs the experimental `authInterrupts` flag, which the docs say is not recommended for production ([forbidden](https://nextjs.org/docs/app/api-reference/functions/forbidden)).
19. **API-19** Rate-limit expensive or abuse-prone endpoints and answer `429` with the envelope. On Vercel, add a WAF rate-limit rule, or call `checkRateLimit('<rule id>', { request, rateLimitKey })` from `@vercel/firewall` against a rule you created in the dashboard. WAF rate limiting is on all plans with a fixed window keyed by IP or JA4 digest, and its counters are tracked per region ([Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend), [WAF rate limiting](https://vercel.com/docs/vercel-firewall/vercel-waf/rate-limiting), [Rate Limiting SDK](https://vercel.com/docs/vercel-firewall/vercel-waf/rate-limiting-sdk)).
20. **API-20** Paginate every list endpoint with a bounded `limit` (default 20, maximum 100) and an opaque `cursor`. Parse both from `request.nextUrl.searchParams` with `z.coerce` and return `{ data, nextCursor }`, never an unbounded result set (convention); the query is exposed by [NextRequest](https://nextjs.org/docs/app/api-reference/functions/next-request) and coercion by [Zod API](https://zod.dev/api).
21. **API-21** Keep `PUT` and `DELETE` idempotent, and make retried creates safe by accepting an `Idempotency-Key` header on `POST` and replaying the stored response for a repeated key (convention). `POST` and `PATCH` are not idempotent, so a client retry otherwise creates duplicates ([MDN Idempotent](https://developer.mozilla.org/en-US/docs/Glossary/Idempotent)).
22. **API-22** Send sensitive values such as location data in a `POST` body and not in a `GET` query string, because `GET` requests may be cached or logged ([Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend)).
23. **API-23** Treat Route Handlers as uncached unless you opt in, and only `GET` can be cached. Without Cache Components, opt in with `export const dynamic = 'force-static'`, which makes `cookies()` and `headers()` return empty values, so never read per-user data in such a handler. Other methods are never cached, even beside a cached `GET` ([Route Handlers](https://nextjs.org/docs/app/getting-started/route-handlers), [Caching without Cache Components](https://nextjs.org/docs/app/guides/caching-without-cache-components)).
24. **API-24** With `cacheComponents: true`, expect a `GET` handler that touches no runtime or uncached data to be prerendered at build time, and expect request properties, `cookies()`, `headers()`, `connection()`, a database or the network to make it run per request. Put `'use cache'` (with `cacheLife` and `cacheTag`) in a helper function and never in the handler body ([Route Handlers](https://nextjs.org/docs/app/getting-started/route-handlers), [revalidateTag](https://nextjs.org/docs/app/api-reference/functions/revalidateTag)).
25. **API-25** Don't export `dynamic`, `revalidate` or `fetchCache` from `route.ts` when Cache Components is enabled: Next.js 16 removed them under `cacheComponents`, and its version history also lists `dynamicParams` ([Route Segment Config](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config)).
26. **API-26** Put CDN cache headers only on responses that are identical for every caller. On a `GET`, set `Cache-Control: public, s-maxage=N, stale-while-revalidate=M` (or `CDN-Cache-Control` or `Vercel-CDN-Cache-Control`) and add a `Vary` header naming any request header the body depends on, such as `Accept` for content negotiation. Vercel doesn't cache a response with `set-cookie` or a `private`, `no-cache` or `no-store` directive, nor a request with an `Authorization` header, and its CDN cache is not the right fit for responses with sensitive user data ([Vercel CDN cache](https://vercel.com/docs/caching/cdn-cache), [Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend)).
27. **API-27** Invalidate cached data from a Route Handler with `revalidateTag(tag, 'max')` for stale-while-revalidate, or `revalidateTag(tag, { expire: 0 })` when a webhook needs the data gone now. Never call `updateTag`, which works only in Server Actions and throws in a Route Handler, and never use the deprecated one-argument `revalidateTag(tag)` ([revalidateTag](https://nextjs.org/docs/app/api-reference/functions/revalidateTag), [updateTag](https://nextjs.org/docs/app/api-reference/functions/updateTag)).
28. **API-28** Read cookies and headers with `await cookies()` and `await headers()` from `next/headers`, or with `request.cookies` and `request.headers`. The `headers()` instance is read-only, so set response headers on the `Response` you return. Set cookies with `(await cookies()).set()` or `response.cookies.set()` using `httpOnly`, `secure`, `sameSite`, `path` and an expiry, before any streaming starts, because HTTP does not allow setting cookies after streaming starts ([route.js](https://nextjs.org/docs/app/api-reference/file-conventions/route), [cookies](https://nextjs.org/docs/app/api-reference/functions/cookies), [Authentication](https://nextjs.org/docs/app/guides/authentication)).
29. **API-29** Never copy incoming request headers onto a response or forward them wholesale upstream. Build an allow-list of the few you need, because sensitive values on response headers are visible to clients ([Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend), [NextResponse](https://nextjs.org/docs/app/api-reference/functions/next-response)).
30. **API-30** Call `redirect()` outside any `try`/`catch`, because it throws and it answers `307` (`permanentRedirect()` answers `308`). Alternatively return `NextResponse.redirect(new URL(path, request.url))`, and answer `400` for a user-supplied redirect target whose origin differs from `request.nextUrl.origin`, to prevent open redirects ([redirect](https://nextjs.org/docs/app/api-reference/functions/redirect), [NextResponse](https://nextjs.org/docs/app/api-reference/functions/next-response), [Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend)).
31. **API-31** Add CORS only to endpoints that browsers call cross-origin. Allow-list origins, echo the matching `Origin` in `Access-Control-Allow-Origin` with `Vary: Origin`, and never answer `*` to a credentialed request. Export `OPTIONS` to answer the preflight with `Access-Control-Allow-Methods`, `Access-Control-Allow-Headers` and `Access-Control-Max-Age`, because the docs describe the generated `OPTIONS` only as setting `Allow`, and repeat the origin header on the actual response. Put CORS that many routes share in the `headers()` option of `next.config` or in `proxy.ts` ([route.js](https://nextjs.org/docs/app/api-reference/file-conventions/route), [next.config headers](https://nextjs.org/docs/app/api-reference/config/next-config-js/headers), [proxy.js](https://nextjs.org/docs/app/api-reference/file-conventions/proxy), [MDN CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS), [MDN OPTIONS](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Methods/OPTIONS)).
32. **API-32** Verify a webhook before trusting it: read the raw body once with `await request.text()`, compute the provider's signature over that exact string, compare with `crypto.timingSafeEqual` after a length check, and answer `401` on a mismatch. Only then `JSON.parse` the same string and `safeParse` the event, because re-serialized JSON is not the signed payload and a request body can be read only once ([route.js](https://nextjs.org/docs/app/api-reference/file-conventions/route), [Vercel request headers](https://vercel.com/docs/headers/request-headers), [raw body guide](https://vercel.com/kb/guide/how-do-i-get-the-raw-body-of-a-serverless-function), [Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend)).
33. **API-33** Acknowledge a webhook fast and idempotently. Return `2xx` well inside the sender's timeout (Vercel webhooks time out after 30 seconds and retry a non-`2xx` delivery for up to 24 hours with exponential backoff), dedupe on the event `id` and run follow-up work in `after()`. Hand work that must survive a crash to a durable job (convention) ([Vercel Webhooks API](https://vercel.com/docs/webhooks/webhooks-api), [Vercel Webhooks](https://vercel.com/docs/webhooks), [after](https://nextjs.org/docs/app/api-reference/functions/after)).
34. **API-34** Schedule post-response side effects (logging, analytics, notifications) with `after()` from `next/server`. The callback runs even when the handler throws or calls `redirect()`, it is bounded by the route's `maxDuration`, and inside a Route Handler it may call `cookies()` and `headers()`. On Vercel with Next.js 15.1 or later, prefer `after()` to `waitUntil()` ([after](https://nextjs.org/docs/app/api-reference/functions/after), [@vercel/functions](https://vercel.com/docs/functions/functions-api-reference/vercel-functions-package)).
35. **API-35** Remove `export const runtime = 'edge'` from route files, and don't add `preferredRegion`: the Edge runtime is deprecated, Node.js is the default and needs no replacement, Vercel recommends migrating to Node.js and states that `runtime = 'edge'` is no longer supported from Next.js 16.3, and the segment config table marks `preferredRegion` deprecated ([runtime](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/runtime), [Edge Runtime Deprecated](https://nextjs.org/docs/messages/edge-runtime-deprecated), [Route Segment Config](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config), [Vercel Functions API](https://vercel.com/docs/functions/functions-api-reference), [Vercel Edge runtime](https://vercel.com/docs/functions/runtimes/edge)).
36. **API-36** Export `maxDuration` (in seconds) only on a handler that legitimately runs long, and pick the value with [performance-and-vercel.md](performance-and-vercel.md). Platforms read it from the build output; on Vercel with Fluid compute the default is 300 seconds, the maximum is 300 on Hobby and 800 on Pro and Enterprise, and a function that runs past its duration ends with `504 FUNCTION_INVOCATION_TIMEOUT` ([maxDuration](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/maxDuration), [Vercel duration](https://vercel.com/docs/functions/configuring-functions/duration), [Vercel limits](https://vercel.com/docs/functions/limitations)).
37. **API-37** Keep request and response bodies under Vercel's 4.5 MB function payload limit, because a larger payload fails with `413 FUNCTION_PAYLOAD_TOO_LARGE`. Validate body size, and upload user files from the browser straight to a storage service and send only the resulting URL to the handler ([Vercel limits](https://vercel.com/docs/functions/limitations), [Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend)).
38. **API-38** Keep no per-request or per-user state in module scope and don't write to the local filesystem, because a host may deploy Route Handlers as lambda functions that can't share data between requests, may not support writing to the file system and may terminate long-running handlers on timeout ([Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend)).
39. **API-39** Proxy to another backend with `rewrites` in `next.config` or `NextResponse.rewrite()` in `proxy.ts` when no logic is needed. When a Route Handler must sit in between, validate before forwarding and pass `request.signal` to the upstream `fetch` so a client disconnect can cancel it, remembering that on Vercel cancellation is opt-in per path through `supportsCancellation` ([Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend), [Vercel Functions API](https://vercel.com/docs/functions/functions-api-reference)).

## Patterns

> The envelope below is this standard's single error shape (convention). `satisfies` checks each
> literal against it without widening ([TypeScript 4.9](https://www.typescriptlang.org/docs/handbook/release-notes/typescript-4-9.html)).
> Handlers get the session from `getSession()` (`Promise<Session | null>`), defined in
> [proxy-auth-and-security.md](proxy-auth-and-security.md). Field errors come from
> `z.flattenError` ([Zod error formatting](https://zod.dev/error-formatting)).

### The error envelope (convention)

Declared once. Every other block imports it.

```ts
// lib/api/errors.ts — the one response envelope every handler uses (convention)
export type ApiErrorCode =
  | 'invalid_json' // 400
  | 'validation_failed' // 400
  | 'unauthenticated' // 401
  | 'invalid_signature' // 401
  | 'forbidden' // 403
  | 'not_found' // 404
  | 'conflict' // 409
  | 'unsupported_media_type' // 415
  | 'rate_limited' // 429
  | 'internal' // 500

export type ApiErrorBody = {
  error: {
    code: ApiErrorCode
    message: string // safe for clients: no stack, SQL or upstream detail
    fieldErrors?: Partial<Record<string, string[]>>
  }
}

export type ApiData<T> = { data: T }
export type ApiPage<T> = { data: T[]; nextCursor: string | null }
```

### Validated POST (create)

Rules: API-8 to API-11 and API-13.

```ts
// app/api/projects/route.ts — POST /api/projects
import { z } from 'zod'
import { getSession } from '@/lib/auth/session'
import { createProject } from '@/lib/projects'
import type { ApiErrorBody } from '@/lib/api/errors'

const CreateProjectBody = z.strictObject({
  name: z.string().trim().min(1).max(100),
  visibility: z.enum(['private', 'team']),
})

export async function POST(request: Request) {
  const session = await getSession()
  if (!session) {
    return Response.json(
      { error: { code: 'unauthenticated', message: 'Sign in to create a project.' } } satisfies ApiErrorBody,
      { status: 401 },
    )
  }
  if (!request.headers.get('content-type')?.startsWith('application/json')) {
    return Response.json(
      { error: { code: 'unsupported_media_type', message: 'Send application/json.' } } satisfies ApiErrorBody,
      { status: 415 },
    )
  }
  let body: unknown
  try {
    body = await request.json()
  } catch {
    return Response.json(
      { error: { code: 'invalid_json', message: 'The body is not valid JSON.' } } satisfies ApiErrorBody,
      { status: 400 },
    )
  }
  const parsed = CreateProjectBody.safeParse(body)
  if (!parsed.success) {
    return Response.json(
      {
        error: {
          code: 'validation_failed',
          message: 'The body failed validation.',
          fieldErrors: z.flattenError(parsed.error).fieldErrors,
        },
      } satisfies ApiErrorBody,
      { status: 400 },
    )
  }
  const project = await createProject({ ...parsed.data, ownerId: session.userId })
  return Response.json(
    { data: project },
    { status: 201, headers: { Location: `/api/projects/${project.id}` } },
  )
}
```

### Paginated GET (list)

Rules: API-8 and API-20.

```ts
// app/api/projects/route.ts — GET /api/projects?limit=20&cursor=…
import type { NextRequest } from 'next/server'
import { z } from 'zod'
import { getSession } from '@/lib/auth/session'
import { listProjects, type Project } from '@/lib/projects'
import type { ApiErrorBody, ApiPage } from '@/lib/api/errors'

const ListQuery = z.object({
  limit: z.coerce.number().pipe(z.int().min(1).max(100)).default(20),
  cursor: z.string().min(1).optional(),
})

export async function GET(request: NextRequest) {
  const session = await getSession()
  if (!session) {
    return Response.json(
      { error: { code: 'unauthenticated', message: 'Sign in to list projects.' } } satisfies ApiErrorBody,
      { status: 401 },
    )
  }
  const query = ListQuery.safeParse(Object.fromEntries(request.nextUrl.searchParams))
  if (!query.success) {
    return Response.json(
      {
        error: {
          code: 'validation_failed',
          message: 'The query string failed validation.',
          fieldErrors: z.flattenError(query.error).fieldErrors,
        },
      } satisfies ApiErrorBody,
      { status: 400 },
    )
  }
  const page: ApiPage<Project> = await listProjects({ ownerId: session.userId, ...query.data })
  return Response.json(page)
}
```

### Dynamic segment with RouteContext

Rules: API-4 and API-15.

```ts
// app/api/projects/[id]/route.ts — GET and DELETE /api/projects/:id
import type { NextRequest } from 'next/server'
import { z } from 'zod'
import { getSession } from '@/lib/auth/session'
import { deleteProjectForOwner, findProjectForOwner } from '@/lib/projects'
import type { ApiErrorBody } from '@/lib/api/errors'

const ProjectId = z.uuid()

const unauthenticated = () =>
  Response.json(
    { error: { code: 'unauthenticated', message: 'Sign in first.' } } satisfies ApiErrorBody,
    { status: 401 },
  )
// Another user's project is indistinguishable from a missing one (API-15).
const projectNotFound = () =>
  Response.json(
    { error: { code: 'not_found', message: 'Project not found.' } } satisfies ApiErrorBody,
    { status: 404 },
  )

export async function GET(_request: NextRequest, ctx: RouteContext<'/api/projects/[id]'>) {
  const session = await getSession()
  if (!session) return unauthenticated()
  const { id } = await ctx.params
  const projectId = ProjectId.safeParse(id)
  if (!projectId.success) return projectNotFound()
  const project = await findProjectForOwner(projectId.data, session.userId)
  return project ? Response.json({ data: project }) : projectNotFound()
}

export async function DELETE(_request: NextRequest, ctx: RouteContext<'/api/projects/[id]'>) {
  const session = await getSession()
  if (!session) return unauthenticated()
  const { id } = await ctx.params
  const projectId = ProjectId.safeParse(id)
  if (!projectId.success) return projectNotFound()
  const deleted = await deleteProjectForOwner(projectId.data, session.userId)
  return deleted ? new Response(null, { status: 204 }) : projectNotFound()
}
```

### Webhook with signature verification on the raw body

Rules: API-32 to API-34. The block uses Vercel's documented `x-vercel-signature`, an HMAC-SHA1 of the raw body ([Vercel request headers](https://vercel.com/docs/headers/request-headers)). For another provider, use its documented algorithm and header and keep the same order of steps. It answers `401` on a bad signature like the Next.js webhook example ([Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend)), while Vercel's own sample answers `403`.

```ts
// app/api/webhooks/vercel/route.ts — no session: the signature is the credential
import crypto from 'crypto'
import { after } from 'next/server'
import { z } from 'zod'
import { handleVercelEvent, markEventReceived } from '@/lib/webhooks/vercel'
import type { ApiErrorBody } from '@/lib/api/errors'

const VercelEvent = z.object({
  id: z.string(),
  type: z.string(),
  createdAt: z.number(),
  payload: z.unknown(),
})

export async function POST(request: Request) {
  const secret = process.env.VERCEL_WEBHOOK_SECRET
  if (!secret) {
    return Response.json(
      { error: { code: 'internal', message: 'Webhook is not configured.' } } satisfies ApiErrorBody,
      { status: 500 },
    )
  }
  const signature = request.headers.get('x-vercel-signature')
  const rawBody = await request.text() // the exact signed bytes; a body can be read once
  const expected = crypto.createHmac('sha1', secret).update(rawBody).digest('hex')
  if (
    !signature ||
    signature.length !== expected.length ||
    !crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))
  ) {
    return Response.json(
      { error: { code: 'invalid_signature', message: 'Signature verification failed.' } } satisfies ApiErrorBody,
      { status: 401 },
    )
  }
  let json: unknown
  try {
    json = JSON.parse(rawBody)
  } catch {
    return Response.json(
      { error: { code: 'invalid_json', message: 'The body is not valid JSON.' } } satisfies ApiErrorBody,
      { status: 400 },
    )
  }
  const event = VercelEvent.safeParse(json)
  if (!event.success) {
    return Response.json(
      { error: { code: 'validation_failed', message: 'Unexpected event shape.' } } satisfies ApiErrorBody,
      { status: 400 },
    )
  }
  // Retries redeliver the same id: act on the first delivery only (API-33).
  if (await markEventReceived(event.data.id)) {
    after(() => handleVercelEvent(event.data))
  }
  return new Response(null, { status: 200 })
}
```

### CORS with preflight

Rule: API-31. The preflight answers `200` because some browsers mishandle `204` ([MDN OPTIONS](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Methods/OPTIONS)).

```ts
// app/api/public/status/route.ts — public by design, called from partner sites
import { getPublicStatus } from '@/lib/status'

const ALLOWED_ORIGINS = new Set(['https://partner.example.com', 'https://admin.example.com'])

function corsHeaders(origin: string | null): Headers {
  const headers = new Headers({ Vary: 'Origin' })
  if (origin && ALLOWED_ORIGINS.has(origin)) {
    headers.set('Access-Control-Allow-Origin', origin)
  }
  return headers
}

export function OPTIONS(request: Request) {
  const headers = corsHeaders(request.headers.get('origin'))
  headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS')
  headers.set('Access-Control-Allow-Headers', 'Content-Type')
  headers.set('Access-Control-Max-Age', '600')
  return new Response(null, { status: 200, headers })
}

export async function GET(request: Request) {
  const status = await getPublicStatus()
  return Response.json({ data: status }, { headers: corsHeaders(request.headers.get('origin')) })
}
```

### Rate-limited, origin-checked POST with after() and maxDuration

Rules: API-17, API-19, API-34 and API-36.

```ts
// app/api/exports/route.ts — POST queues an expensive export
import { checkRateLimit } from '@vercel/firewall'
import { after } from 'next/server'
import { getSession } from '@/lib/auth/session'
import { notifyExportQueued, queueExport } from '@/lib/exports'
import type { ApiErrorBody } from '@/lib/api/errors'

export const maxDuration = 30 // seconds; choose values with performance-and-vercel.md

const APP_ORIGIN = process.env.APP_ORIGIN // for example 'https://app.example.com'

export async function POST(request: Request) {
  if (!APP_ORIGIN || request.headers.get('origin') !== APP_ORIGIN) {
    return Response.json(
      { error: { code: 'forbidden', message: 'Cross-site request rejected.' } } satisfies ApiErrorBody,
      { status: 403 },
    )
  }
  const session = await getSession()
  if (!session) {
    return Response.json(
      { error: { code: 'unauthenticated', message: 'Sign in to export.' } } satisfies ApiErrorBody,
      { status: 401 },
    )
  }
  // Needs a Vercel WAF rule whose Rate limit ID is 'create-export'.
  const { rateLimited } = await checkRateLimit('create-export', { request, rateLimitKey: session.userId })
  if (rateLimited) {
    return Response.json(
      { error: { code: 'rate_limited', message: 'Too many exports. Try again later.' } } satisfies ApiErrorBody,
      { status: 429 },
    )
  }
  const job = await queueExport(session.userId)
  after(() => notifyExportQueued(job.id))
  return Response.json({ data: job }, { status: 202 })
}
```

### Cache Components: a cached public GET

Rules: API-24 and API-27. This applies with `cacheComponents: true`. A CMS webhook handler invalidates it with `revalidateTag('catalog', 'max')`. The previous model uses `export const dynamic = 'force-static'` instead (API-23).

```ts
// app/api/catalog/route.ts — public by design, identical for every caller
import { cacheLife, cacheTag } from 'next/cache'
import { listPublishedProducts } from '@/lib/catalog'

export async function GET() {
  return Response.json({ data: await getCatalog() })
}

async function getCatalog() {
  'use cache' // allowed in a helper, not in the handler body
  cacheLife('hours')
  cacheTag('catalog')
  return listPublishedProducts()
}
```

## Anti-patterns

### Don't fetch your own Route Handler from a Server Component

Breaks API-6: the build fails when the page is prerendered, and on demand it costs an extra HTTP round trip.

```tsx
// app/projects/page.tsx
export default async function ProjectsPage() {
  const res = await fetch('http://localhost:3000/api/projects')
  const projects: unknown = await res.json()
  return <pre>{JSON.stringify(projects)}</pre>
}
```

**Do** read from the data layer directly.

```tsx
// app/projects/page.tsx
import { listProjectsForCurrentUser } from '@/lib/projects'

export default async function ProjectsPage() {
  const projects = await listProjectsForCurrentUser()
  return <pre>{JSON.stringify(projects)}</pre>
}
```

### Don't read params synchronously

Breaks API-4: Next.js 16 removed synchronous `params`, and the context is untyped.

```ts
// Removed in Next.js 16
export async function GET(_req: Request, { params }: { params: { id: string } }) {
  return Response.json({ id: params.id })
}
```

**Do** type the context with `RouteContext` and await `params`.

```ts
// Add the session check from the Patterns above
export async function GET(_req: Request, ctx: RouteContext<'/api/projects/[id]'>) {
  const { id } = await ctx.params
  return Response.json({ id })
}
```

### Don't skip the session check because proxy.ts already runs

Breaks API-16: a matcher change silently removes the proxy's coverage.

```ts
// proxy.ts already checks the cookie, so this handler trusts every caller
export async function GET() {
  return Response.json({ data: await findFirstUser() })
}
```

**Do** check the session in the handler and answer `401` with the envelope.

```ts
export async function GET() {
  const session = await getSession()
  if (!session) {
    return Response.json(
      { error: { code: 'unauthenticated', message: 'Sign in first.' } } satisfies ApiErrorBody,
      { status: 401 },
    )
  }
  return Response.json({ data: await findUserById(session.userId) })
}
```

### Don't send error.message to the client

Breaks API-12: internal detail leaks to every caller.

```ts
async function create(input: ProjectInput): Promise<Response> {
  try {
    return Response.json({ data: await createProject(input) }, { status: 201 })
  } catch (error) {
    return new Response(error instanceof Error ? error.message : 'Error', { status: 500 })
  }
}
```

**Do** log the detail on the server and return a safe `internal` envelope.

```ts
async function create(input: ProjectInput): Promise<Response> {
  try {
    return Response.json({ data: await createProject(input) }, { status: 201 })
  } catch (error) {
    console.error('create project failed', error)
    return Response.json(
      { error: { code: 'internal', message: 'Something went wrong.' } } satisfies ApiErrorBody,
      { status: 500 },
    )
  }
}
```

### Don't verify a webhook over re-serialized JSON

Breaks API-32: `JSON.stringify` does not reproduce the bytes the sender signed, and the plain `===` compare leaks timing.

```ts
async function verify(request: Request, secret: string): Promise<boolean> {
  const payload: unknown = await request.json()
  const expected = sign(JSON.stringify(payload), secret)
  return request.headers.get('x-signature') === expected
}
```

**Do** sign the raw text, compare in constant time, then parse the same string.

```ts
async function readVerifiedEvent(request: Request, secret: string): Promise<unknown> {
  const signature = request.headers.get('x-signature') ?? ''
  const rawBody = await request.text()
  const expected = crypto.createHmac('sha1', secret).update(rawBody).digest('hex')
  const valid =
    signature.length === expected.length &&
    crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))
  if (!valid) throw new Error('invalid signature')
  return JSON.parse(rawBody)
}
```

### Don't combine a wildcard origin with credentials

Breaks API-31: browsers refuse a credentialed response that answers `*`.

```ts
const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Credentials': 'true',
}
```

**Do** echo an allow-listed origin and add `Vary: Origin`.

```ts
const ALLOWED_ORIGINS = new Set(['https://partner.example.com'])

function corsHeaders(origin: string | null): Headers {
  const headers = new Headers({ Vary: 'Origin' })
  if (origin && ALLOWED_ORIGINS.has(origin)) {
    headers.set('Access-Control-Allow-Origin', origin)
    headers.set('Access-Control-Allow-Credentials', 'true')
  }
  return headers
}
```

### Don't use the edge runtime or updateTag in a Route Handler

Breaks API-35 and API-27: the Edge runtime is deprecated, and `updateTag` throws outside a Server Action.

```ts
export const runtime = 'edge'

export async function GET() {
  updateTag('catalog')
  return Response.json({ ok: true })
}
```

**Do** drop the runtime export and revalidate with a profile.

```ts
import { revalidateTag } from 'next/cache'

export async function GET() {
  revalidateTag('catalog', 'max')
  return Response.json({ ok: true })
}
```

### Don't call redirect() inside try/catch

Breaks API-30: `redirect()` throws, and the catch block swallows the redirect.

```ts
export async function GET() {
  try {
    await signOut()
    redirect('/dashboard')
  } catch {
    return Response.json({ error: 'failed' }, { status: 500 })
  }
}
```

**Do** do the work in `try`, then redirect after the block.

```ts
export async function GET() {
  try {
    await signOut()
  } catch (error) {
    console.error('sign out failed', error)
    return Response.json(
      { error: { code: 'internal', message: 'Sign out failed.' } } satisfies ApiErrorBody,
      { status: 500 },
    )
  }
  redirect('/dashboard')
}
```

## Version notes

Changes in **Next.js 16** (16.0 to 16.3) that affect Route Handlers:

- **Async request APIs (breaking).** Next.js 16 removed synchronous access to `route.js` `params`, `cookies()`, `headers()` and `draftMode()`. `await` them, and type context with `RouteContext` from `next typegen`, which arrived in 15.5 ([Upgrading to 16](https://nextjs.org/docs/app/guides/upgrading/version-16), [Next.js 16](https://nextjs.org/blog/next-16)). Rules: API-4, API-28.
- **`middleware.ts` renamed `proxy.ts`.** The middleware filename is deprecated. Proxy runs on Node.js and its runtime can't be configured. Auth there is still only optimistic ([Upgrading to 16](https://nextjs.org/docs/app/guides/upgrading/version-16), [proxy.js](https://nextjs.org/docs/app/api-reference/file-conventions/proxy)). Rule: API-16.
- **Caching APIs.** `revalidateTag` now takes a `cacheLife` profile as its second argument, and the one-argument form is deprecated. The new `updateTag` is Server Actions-only and throws in a Route Handler ([Next.js 16](https://nextjs.org/blog/next-16), [updateTag](https://nextjs.org/docs/app/api-reference/functions/updateTag)). Rule: API-27.
- **Cache Components.** With `cacheComponents: true`, `GET` handlers follow the prerender model. It removes `dynamic`, `dynamicParams`, `revalidate` and `fetchCache`, and `experimental_ppr` is removed outright ([Route Segment Config](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config), [Route Handlers](https://nextjs.org/docs/app/getting-started/route-handlers)). Rules: API-24, API-25.
- **Edge runtime.** It is deprecated, and Vercel states `runtime = 'edge'` is not supported from 16.3 ([runtime](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/runtime), [Vercel Functions API](https://vercel.com/docs/functions/functions-api-reference)). Rule: API-35.
- **Root params (16.3).** `next/root-params` works in Server Components, and the release post plans Route Handler support for a future release. Read segments from `ctx.params` ([Next.js 16.3](https://nextjs.org/blog/next-16-3)). Rule: API-4.
- **Not new in 16** (agents often date these wrong): uncached `GET` handlers and `context.params` as a Promise both date from 15.0.0-RC, and `after()` has been stable since 15.1 ([route.js](https://nextjs.org/docs/app/api-reference/file-conventions/route), [after](https://nextjs.org/docs/app/api-reference/functions/after)).

## Review checklist

- [ ] Each endpoint is a `route.ts` with no `page.tsx` in the same segment (API-1)
- [ ] Only HTTP-method exports and segment config are exported (API-2)
- [ ] Dynamic handlers use `RouteContext<'/…'>` and `await ctx.params` (API-4)
- [ ] Public, third-party and webhook endpoints are Route Handlers; UI mutations are Server Actions (API-5)
- [ ] No Server Component fetches its own `/api` route (API-6)
- [ ] Body, params, query and headers are `safeParse`d before use (API-8)
- [ ] `Content-Type` is checked (415) and invalid JSON answers 400 (API-9)
- [ ] Every error is an `ApiErrorBody` with the status that matches its meaning (API-10, API-11)
- [ ] No `error.message`, stack or SQL in any response (API-12)
- [ ] Every non-public handler checks the session in the handler (401) and the role or ownership (403 or 404) (API-13, API-14, API-15, API-16)
- [ ] Cookie-authenticated mutating handlers check `Origin` (API-17)
- [ ] Abuse-prone endpoints are rate-limited with 429 (API-19)
- [ ] List endpoints are paginated with a bounded `limit` (API-20)
- [ ] Caching intent is explicit: no `s-maxage` on per-user responses, no `dynamic` or `revalidate` under Cache Components (API-23, API-24, API-25, API-26)
- [ ] No `updateTag` in Route Handlers, and `revalidateTag` has two arguments (API-27)
- [ ] CORS echoes allow-listed origins with `Vary: Origin` and an exported `OPTIONS` (API-31)
- [ ] Webhooks verify a signature on `request.text()` with a constant-time compare, dedupe by event id and return 2xx fast, and no route exports `runtime = 'edge'` (API-32, API-33, API-35)

## Not confirmed by the docs

Each item names the pages that were checked. None is stated as a rule.

- **A standard error envelope** such as problem+json. No page checked prescribes one, so `ApiErrorBody` is a convention. Checked: [Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend), [route.js](https://nextjs.org/docs/app/api-reference/file-conventions/route).
- **`Idempotency-Key` semantics.** MDN defines only method idempotency. Checked: [MDN Idempotent](https://developer.mozilla.org/en-US/docs/Glossary/Idempotent), [Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend).
- **Automatic `HEAD`.** The docs state only that `OPTIONS` is implemented for you. Whether `HEAD` is derived from `GET` is not stated. Checked: [route.js](https://nextjs.org/docs/app/api-reference/file-conventions/route), [Route Handlers](https://nextjs.org/docs/app/getting-started/route-handlers).
- **A request body size limit outside Vercel.** The 4.5 MB limit is Vercel's. Checked: [route.js](https://nextjs.org/docs/app/api-reference/file-conventions/route), [Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend), [Vercel limits](https://vercel.com/docs/functions/limitations).
- **Whether `dynamicParams` is still accepted under Cache Components.** The option table lists it, but its v16.0.0 history row says it was removed. Checked: [Route Segment Config](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config).
- **Whether `preferredRegion` still has effect on Vercel.** Next.js marks it deprecated, while Vercel's Functions API page still lists it as a route segment option. Checked: [Route Segment Config](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config), [Vercel Functions API](https://vercel.com/docs/functions/functions-api-reference).
- **Whether `maxDuration` must be a static literal.** The docs say this only for `revalidate`. Checked: [maxDuration](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/maxDuration), [Caching without Cache Components](https://nextjs.org/docs/app/guides/caching-without-cache-components).
- **Third-party signature schemes** such as Stripe or GitHub. Their docs are outside the allowed hosts, so the example uses Vercel's documented scheme. Checked: [Vercel request headers](https://vercel.com/docs/headers/request-headers), [Vercel Webhooks API](https://vercel.com/docs/webhooks/webhooks-api).
- **The Vercel Webhooks API validator exports `GET`**, while webhooks are delivered as POST requests. This file follows the request-headers page's `POST` example. Checked: [Vercel Webhooks API](https://vercel.com/docs/webhooks/webhooks-api), [Vercel Webhooks](https://vercel.com/docs/webhooks).
- **A built-in CSRF check for Route Handlers.** None is documented; only the Server Actions Origin check is, so API-17 is a convention. Checked: [Data Security](https://nextjs.org/docs/app/guides/data-security), [Server Actions](https://nextjs.org/docs/app/guides/server-actions), [route.js](https://nextjs.org/docs/app/api-reference/file-conventions/route), [Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend).
- **WebSockets in Route Handlers.** The Backend for Frontend page says they won't work on lambda-style hosts, while Vercel documents an `experimental_upgradeWebSocket` helper. This is out of scope and not a rule. Checked: [Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend), [@vercel/functions](https://vercel.com/docs/functions/functions-api-reference/vercel-functions-package).

## Sources

- https://nextjs.org/docs/app/getting-started/route-handlers
- https://nextjs.org/docs/app/api-reference/file-conventions/route
- https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config
- https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/runtime
- https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/maxDuration
- https://nextjs.org/docs/messages/edge-runtime-deprecated
- https://nextjs.org/docs/app/guides/backend-for-frontend
- https://nextjs.org/docs/app/api-reference/functions/after
- https://nextjs.org/docs/app/api-reference/functions/next-request
- https://nextjs.org/docs/app/api-reference/functions/next-response
- https://nextjs.org/docs/app/api-reference/functions/cookies
- https://nextjs.org/docs/app/api-reference/functions/redirect
- https://nextjs.org/docs/app/api-reference/functions/forbidden
- https://nextjs.org/docs/app/api-reference/functions/revalidateTag
- https://nextjs.org/docs/app/api-reference/functions/updateTag
- https://nextjs.org/docs/app/api-reference/config/next-config-js/headers
- https://nextjs.org/docs/app/api-reference/file-conventions/proxy
- https://nextjs.org/docs/app/guides/authentication
- https://nextjs.org/docs/app/guides/data-security
- https://nextjs.org/docs/app/guides/server-actions
- https://nextjs.org/docs/app/getting-started/mutating-data
- https://nextjs.org/docs/app/guides/caching-without-cache-components
- https://nextjs.org/docs/app/guides/upgrading/version-16
- https://nextjs.org/blog/next-16
- https://nextjs.org/blog/next-16-3
- https://vercel.com/docs/functions/functions-api-reference
- https://vercel.com/docs/functions/functions-api-reference/vercel-functions-package
- https://vercel.com/docs/functions/configuring-functions/duration
- https://vercel.com/docs/functions/limitations
- https://vercel.com/docs/functions/runtimes/edge
- https://vercel.com/docs/vercel-firewall/vercel-waf/rate-limiting
- https://vercel.com/docs/vercel-firewall/vercel-waf/rate-limiting-sdk
- https://vercel.com/docs/headers/request-headers
- https://vercel.com/docs/webhooks/webhooks-api
- https://vercel.com/docs/webhooks
- https://vercel.com/docs/caching/cdn-cache
- https://vercel.com/kb/guide/how-do-i-get-the-raw-body-of-a-serverless-function
- https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status
- https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status/201
- https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS
- https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Methods/OPTIONS
- https://developer.mozilla.org/en-US/docs/Glossary/Idempotent
- https://developer.mozilla.org/en-US/docs/Web/API/Response/json_static
- https://developer.mozilla.org/en-US/docs/Web/API/Request/json
- https://zod.dev/basics
- https://zod.dev/api
- https://zod.dev/error-formatting
- https://www.typescriptlang.org/docs/handbook/release-notes/typescript-4-9.html
