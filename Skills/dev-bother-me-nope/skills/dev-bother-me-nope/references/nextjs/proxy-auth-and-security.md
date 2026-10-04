# Proxy, auth and security

> As of Next.js 16.3.8, verified 2026-10-04.

## Scope

- Covers the `proxy.ts` file (name, export, runtime, matcher, what it may and may not do),
  sessions and cookies, optimistic versus secure checks, the Data Access Layer (DAL) and DTOs,
  `server-only` and the taint APIs, Server Action security (`allowedOrigins`, `bodySizeLimit`,
  closures), Route Handler authorisation, nonce-based CSP and security headers, `NEXT_PUBLIC_`
  exposure and secrets on Vercel, and patch levels.
- Form and action mechanics are in [data-fetching-and-mutations.md](data-fetching-and-mutations.md).
- CORS, webhooks and CSRF for handlers are in [route-handlers-and-apis.md](route-handlers-and-apis.md).
- Typing env vars is in [typescript.md](typescript.md); caching is in
  [rendering-and-caching.md](rendering-and-caching.md); image optimisation and platform limits are
  in [performance-and-vercel.md](performance-and-vercel.md); the entry point is
  [../nextjs.md](../nextjs.md).
- The docs' own model is an optimistic check in Proxy and a secure check at the data source.
- No auth library is mandated. The examples follow the authentication guide's library-agnostic
  pattern, and `@/lib/prisma` is the canonical tree's database client.
- This file owns the session-helper contract (SEC-46); other topic files import `@/lib/dal`.

## Rules

1. **SEC-1** Name the request-interception file `proxy.ts` (project root, or `src/` when you use
   it, level with `app/`) and export one function named `proxy`, as a named export or as a default
   export of a function named `proxy`; never create a new `middleware.ts`. A project has one
   `proxy.ts`, so split logic into imported modules. Changed in 16.
   ([proxy.js](https://nextjs.org/docs/app/api-reference/file-conventions/proxy), [Proxy guide](https://nextjs.org/docs/app/getting-started/proxy),
   [upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16))
2. **SEC-2** Leave the `runtime` segment option out of `proxy.ts`: Proxy runs on the Node.js
   runtime, the option is not available and setting it throws. Check that the session and auth
   libraries used there run on Node.js; the `edge` runtime is not supported in `proxy`, and the
   upgrade guide says to keep the deprecated `middleware` if you need it. Changed in 16.
   ([proxy.js](https://nextjs.org/docs/app/api-reference/file-conventions/proxy), [upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16),
   [authentication guide](https://nextjs.org/docs/app/guides/authentication))
3. **SEC-3** Export `config.matcher` with literal values only (variables are ignored), run it on
   every page route that needs auth, and exclude `_next/static`, `_next/image` and static files so
   auth redirects cannot block CSS, JS or images.
   ([proxy.js](https://nextjs.org/docs/app/api-reference/file-conventions/proxy), [authentication guide](https://nextjs.org/docs/app/guides/authentication))
4. **SEC-4** Keep auth in Proxy **optimistic**: read the session from the cookie only (for example
   `request.cookies.get('session')`, then decrypt), answer with `NextResponse.redirect` or
   `NextResponse.next()`, and never query a database or do slow fetches there. Proxy runs on every
   route, prefetches included, and is not a full session or authorisation solution. Use the DAL's
   `getSession` validity function (SEC-46), or a cookie Proxy accepts and the DAL rejects loops
   `/login` and `/dashboard` forever.
   ([authentication guide](https://nextjs.org/docs/app/guides/authentication), [Proxy guide](https://nextjs.org/docs/app/getting-started/proxy))
5. **SEC-5** Re-check authentication and authorisation where data is read or written, in the Data
   Access Layer, in every Server Action and in every Route Handler, and never let Proxy be the only
   line of defence. Server Functions are POSTs to the route that uses them, so a matcher that
   excludes a path skips them too, and a matcher change or refactor can silently remove coverage.
   Past bypasses (CVE-2025-29927, CVE-2026-64642) skipped Proxy checks entirely.
   ([authentication guide](https://nextjs.org/docs/app/guides/authentication), [proxy.js](https://nextjs.org/docs/app/api-reference/file-conventions/proxy),
   [backend for frontend](https://nextjs.org/docs/app/guides/backend-for-frontend), [postmortem](https://vercel.com/blog/postmortem-on-next-js-middleware-bypass),
   [July 2026 release](https://nextjs.org/blog/july-2026-security-release))
6. **SEC-6** Forward values to the app with `NextResponse.next({ request: { headers } })`, and never
   put session data or secrets in response headers (`NextResponse.next({ headers })`,
   `response.headers.set`), which reach the browser.
   ([proxy.js](https://nextjs.org/docs/app/api-reference/file-conventions/proxy), [backend for frontend](https://nextjs.org/docs/app/guides/backend-for-frontend))
7. **SEC-7** Set the session cookie only on the server, in a Server Action or Route Handler (or on
   a Proxy response), with `httpOnly: true`, `secure: true`, `sameSite: 'lax'` (or `'strict'`), an
   `expires` or `maxAge`, and `path: '/'`. Cookies cannot be set after streaming starts.
   ([authentication guide](https://nextjs.org/docs/app/guides/authentication), [cookies](https://nextjs.org/docs/app/api-reference/functions/cookies))
8. **SEC-8** Sign or encrypt the session with a secret read from an environment variable (for
   example `SESSION_SECRET`) through a session library, prefer an auth library over hand-rolled
   auth, and keep the payload to the minimum (user id, role), with no PII and no passwords. Read the
   secret inside the signing and verifying functions, never at module scope, so `next build` runs
   without it and a missing secret still throws at request time (convention).
   ([authentication guide](https://nextjs.org/docs/app/guides/authentication))
9. **SEC-9** Use database sessions, with the data in a table and only an encrypted session ID in the
   cookie, when you need server-side revocation such as logging out every device; otherwise
   stateless cookie sessions are acceptable.
   ([authentication guide](https://nextjs.org/docs/app/guides/authentication))
10. **SEC-10** Perform logout and every other mutation (cookie `set` or `delete`, database writes,
    revalidation) in a Server Action or Route Handler, never as a side effect of rendering.
    ([data security guide](https://nextjs.org/docs/app/guides/data-security), [cookies](https://nextjs.org/docs/app/api-reference/functions/cookies))
11. **SEC-11** Await `cookies()` and `headers()` everywhere auth code reads them; synchronous access
    is removed in Next.js 16. Changed in 16.
    ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16))
12. **SEC-12** Put every data read and its authorisation check in a Data Access Layer: a module that
    starts with `import 'server-only'`, whose session check is wrapped in React `cache(` and called
    by every DAL function.
    ([authentication guide](https://nextjs.org/docs/app/guides/authentication), [data security guide](https://nextjs.org/docs/app/guides/data-security), [React cache](https://react.dev/reference/react/cache))
13. **SEC-13** Return DTOs from the DAL: select explicit columns and apply per-field visibility
    rules, and never return whole records.
    ([authentication guide](https://nextjs.org/docs/app/guides/authentication), [data security guide](https://nextjs.org/docs/app/guides/data-security))
14. **SEC-14** Import database clients and read secret `process.env` values only inside the Data
    Access Layer.
    ([data security guide](https://nextjs.org/docs/app/guides/data-security))
15. **SEC-15** Start every module that holds secrets, session logic or database access with
    `import 'server-only'`, so a Client Component import fails the build.
    ([data security guide](https://nextjs.org/docs/app/guides/data-security), [Server and Client Components](https://nextjs.org/docs/app/getting-started/server-and-client-components))
16. **SEC-16** Give Client Components only the fields they render, with narrow prop types, never a
    whole user or database object.
    ([data security guide](https://nextjs.org/docs/app/guides/data-security))
17. **SEC-17** Check auth in the DAL, the page or the leaf component that renders protected data,
    not only in a layout, and never `return null` from a layout as access control: layouts do not
    re-render on navigation and do not stop nested segments or Server Actions.
    ([authentication guide](https://nextjs.org/docs/app/guides/authentication))
18. **SEC-18** Derive identity and role from the verified session on every request; never authorise
    from `searchParams`, `params`, form fields or headers, and validate bracketed route params.
    ([data security guide](https://nextjs.org/docs/app/guides/data-security))
19. **SEC-19** Treat the taint APIs (`experimental_taintObjectReference`,
    `experimental_taintUniqueValue`, enabled with `experimental.taint`) as an experimental extra
    layer, never the only guard: copies and derived values are not tracked.
    ([taint config](https://nextjs.org/docs/app/api-reference/config/next-config-js/taint), [data security guide](https://nextjs.org/docs/app/guides/data-security),
    [taintObjectReference](https://react.dev/reference/react/experimental_taintObjectReference), [taintUniqueValue](https://react.dev/reference/react/experimental_taintUniqueValue))
20. **SEC-20** With Cache Components, resolve the user in the exported getter and pass only the id to
    an unexported `'use cache'` function, and never read `cookies()` inside a plain `use cache`
    scope.
    ([authentication with Cache Components](https://nextjs.org/docs/app/guides/authentication-with-cache-components))
21. **SEC-21** Authenticate and authorise inside every Server Action as for a public POST endpoint,
    because a page-level check does not extend to the actions on that page, and check that the
    caller owns the target resource.
    ([data security guide](https://nextjs.org/docs/app/guides/data-security), [Server Actions guide](https://nextjs.org/docs/app/guides/server-actions),
    [authentication guide](https://nextjs.org/docs/app/guides/authentication), [React use server](https://react.dev/reference/rsc/use-server))
22. **SEC-22** Validate every Server Action argument at runtime (for example zod `safeParse`),
    because TypeScript annotations are not enforced, and accept an id plus the change, never the
    row or its ownership from the client.
    ([Server Actions guide](https://nextjs.org/docs/app/guides/server-actions), [security blog](https://nextjs.org/blog/security-nextjs-server-components-actions),
    [React use server](https://react.dev/reference/rsc/use-server), [zod basics](https://zod.dev/basics))
23. **SEC-23** Return only what the UI renders from a Server Action, because return values are
    serialised to the client, never raw database records.
    ([data security guide](https://nextjs.org/docs/app/guides/data-security), [use server](https://nextjs.org/docs/app/api-reference/directives/use-server))
24. **SEC-24** Read authentication from cookies or headers inside the action, and never accept
    tokens as Server Action parameters.
    ([use server](https://nextjs.org/docs/app/api-reference/directives/use-server))
25. **SEC-25** Keep secrets out of inline Server Action closures, and do not rely on closure
    encryption to hide them.
    ([data security guide](https://nextjs.org/docs/app/guides/data-security))
26. **SEC-26** Set one stable `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY` (base64, a 16-, 24- or 32-byte
    AES key, supplied at build) when you self-host more than one instance.
    ([data security guide](https://nextjs.org/docs/app/guides/data-security), [self-hosting](https://nextjs.org/docs/app/guides/self-hosting))
27. **SEC-27** Keep the built-in Origin/Host CSRF check: add `experimental.serverActions.allowedOrigins`
    entries only for the browser-visible host of a reverse proxy or CDN that does not forward
    `x-forwarded-host`, written as `host[:port]` with `*` and `**` wildcards only as documented.
    A request with no `Origin` header is allowed through with a warning.
    ([serverActions config](https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions), [data security guide](https://nextjs.org/docs/app/guides/data-security),
    [Server Actions guide](https://nextjs.org/docs/app/guides/server-actions))
28. **SEC-28** Keep `experimental.serverActions.bodySizeLimit` at its 1MB default and raise it only
    for a real upload, to the smallest value that fits plus 10 to 20 KB of multipart overhead.
    ([serverActions config](https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions), [Server Actions guide](https://nextjs.org/docs/app/guides/server-actions))
29. **SEC-29** Rate-limit expensive Server Actions and Route Handlers (sending email, writes) in code
    and turn on the host's rate-limiting features.
    ([data security guide](https://nextjs.org/docs/app/guides/data-security), [backend for frontend](https://nextjs.org/docs/app/guides/backend-for-frontend),
    [Vercel Firewall](https://vercel.com/docs/vercel-firewall))
30. **SEC-30** Authorise every Route Handler like a public API endpoint: `401` without a session,
    `403` without permission. CORS, CSRF and webhook verification are in
    [route-handlers-and-apis.md](route-handlers-and-apis.md).
    ([authentication guide](https://nextjs.org/docs/app/guides/authentication))
31. **SEC-31** For a strict CSP, generate a fresh nonce per request in `proxy.ts`, set the
    `Content-Security-Policy` header on both the forwarded request and the response, and pass the
    nonce as an `x-nonce` request header.
    ([CSP guide](https://nextjs.org/docs/app/guides/content-security-policy))
32. **SEC-32** Accept that a nonce CSP makes every page dynamically rendered (no static
    optimisation, ISR or default CDN caching, and Partial Prerendering is incompatible), or keep
    pages static with a no-nonce CSP in `next.config` `headers()` or the experimental SRI option.
    ([CSP guide](https://nextjs.org/docs/app/guides/content-security-policy))
33. **SEC-33** Add `'unsafe-eval'` to `script-src` only when `NODE_ENV === 'development'`, because
    neither React nor Next.js use `eval` in production by default.
    ([CSP guide](https://nextjs.org/docs/app/guides/content-security-policy))
34. **SEC-34** Read the nonce in a Server Component with `(await headers()).get('x-nonce')` and pass
    it to `<Script nonce>` and third-party script components.
    ([CSP guide](https://nextjs.org/docs/app/guides/content-security-policy))
35. **SEC-35** Skip prefetches and static assets in the CSP Proxy matcher with `missing` conditions
    on the `next-router-prefetch` and `purpose: prefetch` headers.
    ([CSP guide](https://nextjs.org/docs/app/guides/content-security-policy))
36. **SEC-36** Send baseline security headers from `next.config.ts` `headers()` for
    `source: '/(.*)'` (`Strict-Transport-Security`, `X-Content-Type-Options: nosniff`,
    `Referrer-Policy`, `Permissions-Policy`), and block framing with a CSP `frame-ancestors`
    directive (`Content-Security-Policy: frame-ancestors 'none'`) instead of the superseded
    `X-Frame-Options`.
    ([headers config](https://nextjs.org/docs/app/api-reference/config/next-config-js/headers), [CSP guide](https://nextjs.org/docs/app/guides/content-security-policy))
37. **SEC-37** Never prefix a secret with `NEXT_PUBLIC_`: the value is inlined into the client bundle
    at `next build`, while unprefixed variables stay server-only.
    ([environment variables](https://nextjs.org/docs/app/guides/environment-variables), [Server and Client Components](https://nextjs.org/docs/app/getting-started/server-and-client-components))
38. **SEC-38** Treat `NEXT_PUBLIC_` values as frozen at build time, and read per-environment runtime
    values on the server after `await connection()`; `serverRuntimeConfig` and
    `publicRuntimeConfig` are removed in Next.js 16. Changed in 16.
    ([environment variables](https://nextjs.org/docs/app/guides/environment-variables), [upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16))
39. **SEC-39** Commit no `.env*.local` file and no `.env` file holding secrets, and keep `.env*`
    files in the project root, not in `src/`.
    ([environment variables](https://nextjs.org/docs/app/guides/environment-variables))
40. **SEC-40** Store passwords, API keys and tokens on Vercel as **Secret**-type environment
    variables (formerly Sensitive; not readable after saving), and use **Config** only for
    non-sensitive values such as `NEXT_PUBLIC_` ones. Changed 2026-08 (Vercel).
    ([changelog](https://vercel.com/changelog/environment-variables-now-use-config-and-secret-types),
    [sensitive environment variables](https://vercel.com/docs/environment-variables/sensitive-environment-variables))
41. **SEC-41** Redeploy after changing or rotating a Vercel environment variable, and rotate by
    adding the new credential, redeploying, then invalidating the old one.
    ([environment variables](https://vercel.com/docs/environment-variables), [rotating secrets](https://vercel.com/docs/environment-variables/rotating-secrets))
42. **SEC-42** Keep `next` on the latest patched release of a supported line (16.3.8 or 15.5.27 as
    of the 2026-09-30 security release), follow the pre-announced security releases on the Next.js
    blog, and rotate secrets after patching an exploitable advisory.
    ([September 2026 release](https://nextjs.org/blog/september-2026-security-release), [security release program](https://nextjs.org/blog/next-security-release-program),
    [CVE-2025-66478](https://nextjs.org/blog/CVE-2025-66478), [July 2026 release](https://nextjs.org/blog/july-2026-security-release))
43. **SEC-43** Leave Vercel's block on deploying vulnerable Next.js versions on, and never set
    `DANGEROUSLY_DEPLOY_VULNERABLE_CVE_2025_66478`.
    ([Vercel changelog](https://vercel.com/changelog/new-deployments-of-vulnerable-next-js-applications-are-now-blocked-by))
44. **SEC-44** Enable Vercel Deployment Protection (Standard Protection, the recommended scope) so
    preview deployments are not public.
    ([Deployment Protection](https://vercel.com/docs/deployment-protection))
45. **SEC-45** Serve production only from a production build (`next build` and `next start`, or the
    platform), never `next dev`, and put a reverse proxy in front of a self-hosted server.
    ([security blog](https://nextjs.org/blog/security-nextjs-server-components-actions), [September 2026 release](https://nextjs.org/blog/september-2026-security-release),
    [self-hosting](https://nextjs.org/docs/app/guides/self-hosting))
46. **SEC-46** Keep one session-helper contract and import it, never redefine it: `src/lib/dal.ts`
    (`import 'server-only'`, imported as `@/lib/dal`) exports `getSession(): Promise<Session | null>`,
    which never redirects (Route Handlers, SSE routes and other APIs answer `401` themselves), and
    `verifySession(): Promise<Session>`, which redirects to `/login` (pages, layouts and Server
    Actions). `Session` carries `userId` and `role`. Server Actions live in `src/lib/actions/`, and
    snippets use the canonical `src/` layout. (convention, built on the
    [authentication guide](https://nextjs.org/docs/app/guides/authentication)'s `verifySession`)

## Patterns

### Session cookie

Implements SEC-7, SEC-8, SEC-15 and SEC-46; `decrypt` is the one validity rule Proxy and the DAL share.

```ts
// src/lib/session.ts — stateless session, server-only
import 'server-only'
import { cookies } from 'next/headers'
import { SignJWT, jwtVerify } from 'jose'

export type Session = { userId: string; role: 'admin' | 'user' }

const SESSION_TTL_MS = 7 * 24 * 60 * 60 * 1000

// Read lazily so `next build` runs without the secret; a missing secret still throws per request.
function getKey(): Uint8Array {
  const secret = process.env.SESSION_SECRET
  if (!secret) throw new Error('SESSION_SECRET is not set')
  return new TextEncoder().encode(secret)
}

const isRole = (value: unknown): value is Session['role'] => value === 'admin' || value === 'user'

export async function encrypt(session: Session): Promise<string> {
  return new SignJWT({ ...session })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('7d')
    .sign(getKey())
}

// The one validity rule: a good signature, not expired, a string userId and a known role.
export async function decrypt(token: string | undefined = ''): Promise<Session | null> {
  const key = getKey() // outside the try: a missing secret is a server error, not "signed out"
  try {
    const { payload } = await jwtVerify(token, key, { algorithms: ['HS256'] })
    const { userId, role } = payload
    return typeof userId === 'string' && isRole(role) ? { userId, role } : null
  } catch {
    return null // invalid or expired token: treated as "no session"
  }
}

export async function createSession(userId: string, role: Session['role']): Promise<void> {
  const expiresAt = new Date(Date.now() + SESSION_TTL_MS)
  const session = await encrypt({ userId, role })
  const cookieStore = await cookies()
  cookieStore.set('session', session, {
    httpOnly: true,
    secure: true,
    expires: expiresAt,
    sameSite: 'lax',
    path: '/',
  })
}

export async function deleteSession(): Promise<void> {
  const cookieStore = await cookies()
  cookieStore.delete('session')
}
```

The lazy secret read and the shared `decrypt` are `(convention)`; the rest mirrors the [authentication guide](https://nextjs.org/docs/app/guides/authentication).

### Data Access Layer

Implements SEC-12 to SEC-15 and SEC-46: the session-helper contract, with every read returning a DTO.

```ts
// src/lib/dal.ts — the session-helper contract (SEC-46): getSession() and verifySession()
import 'server-only'
import { cache } from 'react'
import { cookies } from 'next/headers'
import { redirect } from 'next/navigation'
import { decrypt, type Session } from '@/lib/session'
import { prisma } from '@/lib/prisma' // your DB client

export type { Session }
export type UserDTO = { id: string; name: string }

// Secure check, memoised per request, the same validity rule as Proxy. Never redirects, so
// Route Handlers can answer 401.
export const getSession = cache(
  async (): Promise<Session | null> => decrypt((await cookies()).get('session')?.value),
)

// Pages, layouts and Server Actions: redirect when there is no session.
export const verifySession = cache(async (): Promise<Session> => {
  const session = await getSession()
  if (!session) redirect('/login')
  return session
})

export const getCurrentUser = cache(async (): Promise<UserDTO | null> => {
  const { userId } = await verifySession()
  return prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, name: true }, // DTO: only what the UI renders
  })
})
```

### Optimistic Proxy

Implements SEC-1, SEC-3, SEC-4 and SEC-46: a valid session cookie, no database.

```ts
// src/proxy.ts — optimistic check only: a valid session cookie, no database
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'
import { decrypt } from '@/lib/session' // the validity rule getSession() uses (SEC-46)

const PROTECTED_PREFIXES = ['/dashboard']
const PUBLIC_ROUTES = ['/login', '/signup']

const isProtected = (pathname: string): boolean =>
  PROTECTED_PREFIXES.some((prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`))

export async function proxy(request: NextRequest): Promise<NextResponse> {
  const { pathname } = request.nextUrl
  const session = await decrypt(request.cookies.get('session')?.value)

  if (isProtected(pathname) && !session) {
    return NextResponse.redirect(new URL('/login', request.nextUrl))
  }
  if (PUBLIC_ROUTES.includes(pathname) && session) {
    return NextResponse.redirect(new URL('/dashboard', request.nextUrl))
  }
  return NextResponse.next()
}

export const config = {
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico|.*\\.png$).*)'],
}
```

`api` is excluded because every Route Handler authorises itself (SEC-30); Server Actions still pass
through because they POST to page routes (SEC-5).

### Server Action that authorises before it mutates

Implements SEC-21, SEC-22, SEC-23 and SEC-24: authenticate, validate, check ownership, then write.

```ts
// src/lib/actions/posts.ts
'use server'
import { revalidatePath } from 'next/cache'
import * as z from 'zod'
import { verifySession } from '@/lib/dal'
import { prisma } from '@/lib/prisma'

const PostId = z.string().min(1)

export type DeletePostResult = { ok: true } | { ok: false; error: 'invalid' | 'not-found' }

export async function deletePost(postId: string): Promise<DeletePostResult> {
  const { userId } = await verifySession() // 1. authenticate: identity from the cookie
  const parsed = PostId.safeParse(postId) // 2. validate: TS types are not enforced at runtime
  if (!parsed.success) return { ok: false, error: 'invalid' }
  const post = await prisma.post.findFirst({
    where: { id: parsed.data, authorId: userId }, // 3. authorise: caller owns the row
    select: { id: true },
  })
  if (!post) return { ok: false, error: 'not-found' }
  await prisma.post.delete({ where: { id: post.id } })
  revalidatePath('/posts')
  return { ok: true } // 4. minimal return value
}
```

### Route Handler

Implements SEC-30: `401` without a session, `403` without permission.

```ts
// src/app/api/reports/route.ts
import { getSession } from '@/lib/dal'
import { listReports } from '@/lib/reports' // DAL function returning DTOs

export async function GET(): Promise<Response> {
  const session = await getSession()
  if (!session) return new Response(null, { status: 401 })
  if (session.role !== 'admin') return new Response(null, { status: 403 })
  return Response.json(await listReports())
}
```

### Nonce CSP in Proxy

Implements SEC-31, SEC-32, SEC-33 and SEC-35.

```ts
// src/proxy.ts — nonce-based CSP (one proxy.ts per project: compose with the auth check above)
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function proxy(request: NextRequest): NextResponse {
  const nonce = Buffer.from(crypto.randomUUID()).toString('base64')
  const isDev = process.env.NODE_ENV === 'development'
  const csp = `
    default-src 'self';
    script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${isDev ? " 'unsafe-eval'" : ''};
    style-src 'self' 'nonce-${nonce}';
    img-src 'self' blob: data:;
    font-src 'self';
    object-src 'none';
    base-uri 'self';
    form-action 'self';
    frame-ancestors 'none';
    upgrade-insecure-requests;
  `.replace(/\s{2,}/g, ' ').trim()

  const requestHeaders = new Headers(request.headers)
  requestHeaders.set('x-nonce', nonce)
  requestHeaders.set('Content-Security-Policy', csp)

  const response = NextResponse.next({ request: { headers: requestHeaders } })
  response.headers.set('Content-Security-Policy', csp)
  return response
}

export const config = {
  matcher: [
    {
      source: '/((?!api|_next/static|_next/image|favicon.ico).*)',
      missing: [
        { type: 'header', key: 'next-router-prefetch' },
        { type: 'header', key: 'purpose', value: 'prefetch' },
      ],
    },
  ],
}
```

A project has one `proxy.ts` (SEC-1): put the auth check and the CSP in modules and call both from
the single `proxy` function ([Proxy guide](https://nextjs.org/docs/app/getting-started/proxy)).
Read the nonce with `(await headers()).get('x-nonce')` and pass it to `<Script nonce>` (SEC-34).
Pages need dynamic rendering, for example `await connection()`.

### Security headers and Server Action limits

Implements SEC-27, SEC-28 and SEC-36 in `next.config.ts`.

```ts
// next.config.ts
import type { NextConfig } from 'next'

const securityHeaders = [
  { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=(), browsing-topics=()' },
  // Clickjacking: CSP frame-ancestors supersedes X-Frame-Options (SEC-36)
  { key: 'Content-Security-Policy', value: "frame-ancestors 'none'" },
]

const nextConfig: NextConfig = {
  async headers() {
    return [{ source: '/(.*)', headers: securityHeaders }]
  },
  experimental: {
    serverActions: {
      allowedOrigins: ['shop.example.com'], // only if a proxy forwards its own host (SEC-27)
      bodySizeLimit: '2mb', // only if an upload needs more than the 1MB default (SEC-28)
    },
  },
}

export default nextConfig
```

Where `proxy.ts` also sets the nonce CSP (SEC-31), keep `frame-ancestors` identical in both or drop it here `(convention)`.

## Anti-patterns

### Don't make Proxy the only gate (SEC-4, SEC-5)

**Don't** — a database lookup on every route and prefetch, with pages that trust it. Bypasses
([postmortem](https://vercel.com/blog/postmortem-on-next-js-middleware-bypass), CVE-2025-29927;
[July 2026](https://nextjs.org/blog/july-2026-security-release), CVE-2026-64642) skipped it entirely.

```ts
// src/proxy.ts — DON'T: database lookup on every route and prefetch; pages below trust it
export async function proxy(request: NextRequest): Promise<NextResponse> {
  const token = request.cookies.get('session')?.value ?? ''
  const row = await prisma.session.findUnique({ where: { token } })
  if (!row) return NextResponse.redirect(new URL('/login', request.nextUrl))
  return NextResponse.next()
}
```

**Do** — an optimistic cookie read in Proxy, and the secure check in every page, action and handler.

```ts
const session = await decrypt(request.cookies.get('session')?.value) // proxy.ts: optimistic only
const { userId } = await verifySession() // every page, action and handler: the secure check
```

### Don't check auth only on the page (SEC-21)

**Don't** — gate the page and leave the inline action open; it can be POSTed to directly.

```tsx
// src/app/admin/page.tsx — DON'T: the page is gated, the inline action is not
export default async function AdminPage() {
  await verifySession() // gates the UI only
  async function purge(): Promise<void> {
    'use server'
    await prisma.record.deleteMany() // anyone who can POST to /admin runs this
  }
  return <form action={purge}><button>Delete records</button></form>
}
```

**Do** — authenticate and authorise inside the action itself.

```tsx
async function purge(): Promise<void> {
  'use server'
  const { role } = await verifySession() // the action is its own entry point
  if (role !== 'admin') throw new Error('Forbidden')
  await prisma.record.deleteMany()
}
```

### Don't trust the client's row (SEC-21, SEC-22)

**Don't** — authenticate but then act on a client-supplied row, so any item can be changed (IDOR).

```ts
'use server'
// DON'T: authenticated, but the client supplies the row and its owner, so any item can be changed
export async function completeItem(item: { id: string; ownerId: string }): Promise<void> {
  await verifySession()
  await prisma.item.update({ where: { id: item.id }, data: { completed: true } })
}
```

**Do** — take an id, validate it, and check ownership against the session.

```ts
'use server'
export async function completeItem(itemId: string): Promise<void> {
  const { userId } = await verifySession()
  const id = z.string().min(1).parse(itemId)
  const item = await prisma.item.findFirst({ where: { id, ownerId: userId }, select: { id: true } })
  if (!item) throw new Error('Forbidden')
  await prisma.item.update({ where: { id: item.id }, data: { completed: true } })
}
```

### Don't put a secret behind NEXT_PUBLIC_ (SEC-37)

**Don't** — a `NEXT_PUBLIC_` value is inlined into every client bundle at `next build`.

```bash
# .env — DON'T: inlined into every client bundle at next build
NEXT_PUBLIC_PAYMENTS_SECRET_KEY=replace-me
```

**Do** — read the secret only on the server, inside the DAL.

```ts
// src/lib/payments.ts — read the secret only on the server, inside the DAL
import 'server-only'
const secretKey = process.env.PAYMENTS_SECRET_KEY
```

### Don't return raw records to the client (SEC-13, SEC-16, SEC-23)

**Don't** — return the whole row from an action; it is serialised to the browser.

```ts
'use server'
// DON'T: returns the full row (password hash, internal flags) to the browser
export async function renameUser(formData: FormData) {
  const { userId } = await verifySession()
  return prisma.user.update({ where: { id: userId }, data: { name: String(formData.get('name')) } })
}
```

**Do** — validate the input and return only what the UI renders.

```ts
'use server'
export async function renameUser(formData: FormData): Promise<{ ok: true }> {
  const { userId } = await verifySession()
  const name = z.string().min(1).max(100).parse(formData.get('name'))
  await prisma.user.update({ where: { id: userId }, data: { name } })
  return { ok: true }
}
```

### Don't mutate cookies during render (SEC-10)

**Don't** — a GET with `?logout=1` deletes the cookie while rendering.

```tsx
// src/app/profile/page.tsx — DON'T: a GET with ?logout=1 deletes the cookie while rendering
export default async function Page({ searchParams }: { searchParams: Promise<{ logout?: string }> }) {
  if ((await searchParams).logout) (await cookies()).delete('session')
  return <Profile />
}
```

**Do** — log out through a Server Action.

```tsx
import { logout } from '@/lib/actions/auth' // a Server Action that calls deleteSession(), then redirects
export default function Page() {
  return <form action={logout}><button type="submit">Log out</button></form>
}
```

### Don't set secrets in Proxy response headers (SEC-6)

**Don't** — `NextResponse.next({ headers })` sends those headers to the browser.

```ts
// src/proxy.ts — DON'T: NextResponse.next({ headers }) sends these headers to the browser
const headers = new Headers(request.headers)
headers.set('x-session-token', token)
return NextResponse.next({ headers })
```

**Do** — pass them as request headers.

```ts
return NextResponse.next({ request: { headers } }) // visible to the app, not to the client
```

## Version notes

Changes in Next.js 16 and the security advisories of the 16.x line, as of 16.3.8.

- **`middleware` becomes `proxy` (Next.js 16.0).** The `middleware` file convention is deprecated and
  renamed to `proxy`: rename `middleware.ts` to `proxy.ts` and the exported function `middleware` to
  `proxy` (recommended even for a default export). Proxy runs on Node.js and the runtime cannot be
  configured; the docs say to keep the deprecated `middleware.ts` if you need `edge`, which the
  Next.js 16 post says "will be removed in a future version". Run
  `npx @next/codemod@latest middleware-to-proxy .`; it also renames `skipMiddlewareUrlNormalize` to
  `skipProxyUrlNormalize` and the matching `experimental` options (`middlewarePrefetch`,
  `middlewareClientMaxBodySize`, `externalMiddlewareRewritesResolve`) to their `proxy` names.
  Version history: "v16.0.0 Middleware is deprecated and renamed to Proxy".
  ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16), [proxy.js](https://nextjs.org/docs/app/api-reference/file-conventions/proxy),
  [Next.js 16](https://nextjs.org/blog/next-16), [codemods](https://nextjs.org/docs/app/guides/upgrading/codemods))
- **Async request APIs.** Synchronous `cookies()`, `headers()`, `draftMode()`, `params` and
  `searchParams` access is removed (SEC-11).
  ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16))
- **Runtime config removed.** `serverRuntimeConfig` and `publicRuntimeConfig` are removed; use env
  vars, `NEXT_PUBLIC_` for client values and `connection()` for runtime reads (SEC-38).
  ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16))
- **Image local-IP restriction.** Local IP optimisation is blocked by default; the detail is in
  [performance-and-vercel.md](performance-and-vercel.md).
  ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16))
- **No change.** The upgrade guide lists no change to Server Action security options or CSP and nonce
  handling, the CSP guide's version history ends at `v14.0.0`, and the
  [16.1](https://nextjs.org/blog/next-16-1), [16.2](https://nextjs.org/blog/next-16-2) and
  [16.3](https://nextjs.org/blog/next-16-3) posts list no change to this topic.
- **Security advisories in the 16.x line** (the patch-level floor behind SEC-42):
  - CVE-2025-66478 (React2Shell, RSC remote code execution, CVSS 10.0) is fixed in 16.0.7; rotate
    secrets if the app was exposed unpatched
    ([advisory](https://nextjs.org/blog/CVE-2025-66478)).
  - CVE-2025-55184 and CVE-2025-67779 (denial of service) and CVE-2025-55183 (Server Function source
    exposure) are fixed in 16.0.10
    ([December 2025 update](https://nextjs.org/blog/security-update-2025-12-11)).
  - July 2026, fixed in 16.2.11: CVE-2026-64642 (Proxy bypass with Turbopack and a single
    `i18n.locales` entry), CVE-2026-64641 (Server Actions denial of service), CVE-2026-64643 (Server
    Action and `use cache` endpoint ID disclosure), CVE-2026-64649 (SSRF through Server Actions on
    custom servers) and CVE-2026-64645 (SSRF in `rewrites()` and open redirect in `redirects()`)
    ([July 2026](https://nextjs.org/blog/july-2026-security-release)).
  - August 2026, fixed in 16.3.3: AVIF image optimisation RCE and a Windows-hosted RCE
    (CVE-2026-75604) ([August 2026](https://nextjs.org/blog/august-2026-security-release)).
  - 2026-09-22, fixed in 16.3.6: RCE in the Node.js `ImageResponse` of `next/og`
    ([update](https://nextjs.org/blog/nextjs-security-update-september-22-2026)).
  - 2026-09-30, fixed in 16.3.8: image optimisation SSRF (CVE-2026-94483), SSG and ISR cache
    poisoning (CVE-2026-94543, CVE-2026-94484), a nested `'use cache'` root-param leak, a Draft Mode
    `use cache` leak (CVE-2026-94544) and `next dev` MCP endpoint disclosure (CVE-2026-94486)
    ([September 2026](https://nextjs.org/blog/september-2026-security-release)).
  - Background, why SEC-5 exists: CVE-2025-29927, a Middleware bypass, is fixed in 15.2.3 and 14.2.25
    ([postmortem](https://vercel.com/blog/postmortem-on-next-js-middleware-bypass)).

## Review checklist

- [ ] SEC-1/SEC-2: the file is `proxy.ts` exporting `proxy`; no `runtime` option; no new `middleware.ts`.
- [ ] SEC-3: the matcher is literal and excludes `_next/static`, `_next/image` and static files.
- [ ] SEC-4: Proxy reads only the cookie; no database or slow fetch in `proxy.ts`.
- [ ] SEC-5/SEC-21: every Server Action authenticates, authorises and checks ownership itself.
- [ ] SEC-5/SEC-30: every Route Handler returns 401 or 403 from its own session check.
- [ ] SEC-6: no session data or secret in a response header set by Proxy.
- [ ] SEC-7: the session cookie is set server-side with `httpOnly`, `secure`, `sameSite`, expiry and path.
- [ ] SEC-8: the payload holds ids and roles only; the secret comes from an env var, read lazily.
- [ ] SEC-10: no cookie or data mutation during render.
- [ ] SEC-12/SEC-15: DAL modules start with `import 'server-only'` and use `cache(` for the session check.
- [ ] SEC-46: sessions come from `@/lib/dal` (`getSession` never redirects; `verifySession` does), Proxy
  and the DAL share one validity function, and Server Actions sit in `src/lib/actions/`.
- [ ] SEC-13/SEC-16/SEC-23: DTOs and action returns carry only rendered fields.
- [ ] SEC-14: no DB client or secret `process.env` read outside the DAL.
- [ ] SEC-17: no layout-only auth check; no `return null` as access control.
- [ ] SEC-18/SEC-22: params, `searchParams` and action arguments are validated at runtime.
- [ ] SEC-24/SEC-25: no tokens as action parameters; no secrets in inline action closures.
- [ ] SEC-27/SEC-28: `allowedOrigins` and `bodySizeLimit` are absent or justified.
- [ ] SEC-31/SEC-32/SEC-33: nonce CSP on request and response; pages dynamic; `unsafe-eval` dev-only.
- [ ] SEC-36: `next.config` `headers()` sends HSTS, `nosniff`, Referrer-Policy, Permissions-Policy
  and CSP `frame-ancestors`.
- [ ] SEC-37/SEC-39: no secret behind `NEXT_PUBLIC_`; no `.env*.local` committed.
- [ ] SEC-40/SEC-41: secrets are Secret-type on Vercel; rotation redeploys before invalidating.
- [ ] SEC-42/SEC-43: `next` is on the latest patched release; the vulnerable-deploy block is not disabled.

## Not confirmed by the docs

1. Whether a 16.x minor published the follow-up `edge` runtime instructions for Proxy that the
   [upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16) points to. Not found in
   [proxy.js](https://nextjs.org/docs/app/api-reference/file-conventions/proxy) or the
   [16.1](https://nextjs.org/blog/next-16-1), [16.2](https://nextjs.org/blog/next-16-2) and
   [16.3](https://nextjs.org/blog/next-16-3) posts.
2. Which release removes `middleware.ts`: the [Next.js 16 post](https://nextjs.org/blog/next-16)
   says only "a future version", and the upgrade guide names none.
3. Which codemod dist-tag is canonical: the [codemods page](https://nextjs.org/docs/app/guides/upgrading/codemods)
   uses `@latest`, while [proxy.js](https://nextjs.org/docs/app/api-reference/file-conventions/proxy) uses `@canary`.
4. Whether `serverActions` options are read outside `experimental`: the
   [serverActions config](https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions)
   and [Server Actions guide](https://nextjs.org/docs/app/guides/server-actions) call them
   `serverActions.*`, but every example nests them under `experimental`; this file follows the examples.
5. When Server Actions started letting a request with no `Origin` header through with a warning: the
   [serverActions config](https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions)
   states the current behaviour and has no version history entry for it.
6. Nonce CSP with Cache Components: the [CSP guide](https://nextjs.org/docs/app/guides/content-security-policy)
   says Partial Prerendering is incompatible with nonces, and neither it nor
   [authentication with Cache Components](https://nextjs.org/docs/app/guides/authentication-with-cache-components)
   addresses nonces under Cache Components.
7. The Vercel team policy for secrets: the [sensitive environment variables page](https://vercel.com/docs/environment-variables/sensitive-environment-variables)
   (updated 2026-08-28) and the [Config and Secret changelog](https://vercel.com/changelog/environment-variables-now-use-config-and-secret-types)
   (2026-08-24) were read and describe the policy differently; this file states only the Secret and Config types.
8. Vercel WAF rate-limit rule specifics: only the [Vercel Firewall](https://vercel.com/docs/vercel-firewall)
   overview was read, so the file says only that the WAF exists.

## Sources

- https://nextjs.org/docs/app/api-reference/file-conventions/proxy — proxy.js reference
- https://nextjs.org/docs/app/getting-started/proxy — Proxy getting started
- https://nextjs.org/docs/app/guides/upgrading/version-16 — upgrade guide to version 16
- https://nextjs.org/docs/app/guides/upgrading/codemods — codemods, including `middleware-to-proxy`
- https://nextjs.org/docs/app/guides/authentication — authentication guide
- https://nextjs.org/docs/app/guides/authentication-with-cache-components — authentication with Cache Components
- https://nextjs.org/docs/app/guides/data-security — data security guide
- https://nextjs.org/docs/app/guides/server-actions — Server Actions guide
- https://nextjs.org/docs/app/api-reference/directives/use-server — `use server` directive
- https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions — `serverActions` config
- https://nextjs.org/docs/app/guides/content-security-policy — Content Security Policy
- https://nextjs.org/docs/app/api-reference/config/next-config-js/headers — `headers` config
- https://nextjs.org/docs/app/api-reference/functions/cookies — `cookies`
- https://nextjs.org/docs/app/guides/environment-variables — environment variables
- https://nextjs.org/docs/app/getting-started/server-and-client-components — Server and Client Components
- https://nextjs.org/docs/app/api-reference/config/next-config-js/taint — `taint` config
- https://nextjs.org/docs/app/guides/self-hosting — self-hosting
- https://nextjs.org/docs/app/guides/backend-for-frontend — backend for frontend
- https://nextjs.org/blog/next-16 — Next.js 16 release post
- https://nextjs.org/blog/next-16-1 — Next.js 16.1 release post
- https://nextjs.org/blog/next-16-2 — Next.js 16.2 release post
- https://nextjs.org/blog/next-16-3 — Next.js 16.3 release post
- https://nextjs.org/blog/security-nextjs-server-components-actions — security of Server Components and Actions
- https://nextjs.org/blog/CVE-2025-66478 — CVE-2025-66478 advisory
- https://nextjs.org/blog/security-update-2025-12-11 — December 11, 2025 security update
- https://nextjs.org/blog/july-2026-security-release — July 2026 security release
- https://nextjs.org/blog/august-2026-security-release — August 2026 security release
- https://nextjs.org/blog/nextjs-security-update-september-22-2026 — September 22, 2026 security update
- https://nextjs.org/blog/september-2026-security-release — September 2026 security release
- https://nextjs.org/blog/next-security-release-program — security release program
- https://vercel.com/blog/postmortem-on-next-js-middleware-bypass — postmortem on the Middleware bypass
- https://vercel.com/docs/environment-variables — Vercel environment variables
- https://vercel.com/docs/environment-variables/sensitive-environment-variables — sensitive environment variables
- https://vercel.com/changelog/environment-variables-now-use-config-and-secret-types — Config and Secret types
- https://vercel.com/docs/environment-variables/rotating-secrets — rotating secrets
- https://vercel.com/changelog/new-deployments-of-vulnerable-next-js-applications-are-now-blocked-by — vulnerable deployments blocked
- https://vercel.com/docs/deployment-protection — Deployment Protection
- https://vercel.com/docs/vercel-firewall — Vercel Firewall
- https://react.dev/reference/react/cache — React `cache`
- https://react.dev/reference/react/experimental_taintObjectReference — React `experimental_taintObjectReference`
- https://react.dev/reference/react/experimental_taintUniqueValue — React `experimental_taintUniqueValue`
- https://react.dev/reference/rsc/use-server — React `'use server'`
- https://zod.dev/basics — zod basics, `safeParse`
