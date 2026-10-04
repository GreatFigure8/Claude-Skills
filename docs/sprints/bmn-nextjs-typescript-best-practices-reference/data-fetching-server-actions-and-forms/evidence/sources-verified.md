# Sources verified live: data-fetching-server-actions-and-forms

Every URL in `## Sources` of `references/nextjs/data-fetching-and-mutations.md`, fetched live on
2026-10-04 during this run (nextjs.org, vercel.com and react.dev as the `.md` rendering of the page,
zod.dev as HTML). All 40 pages returned HTTP 200, and the Next.js pages' front matter reads
`version: 16.3.8`. The "Backs" column lists the rule ids and sections that cite the page, then what the
page states. Quotes are limited to a few words. The `Fetched` column is `2026-10-04` for every row.

| URL | Fetched | Backs (rule ids, then what the page confirms) |
| --- | --- | --- |
| https://nextjs.org/docs/app/getting-started/fetching-data | 2026-10-04 | DF-1, DF-4, DF-5, DF-6, DF-7, DF-8: Server Components fetch with `fetch` or an ORM and keep credentials out of the client bundle; sequential `await`s stay sequential and `Promise.all` / `Promise.allSettled` fix it; `<Suspense>` around a dependent child; `React.cache` for non-`fetch` access, scoped to one request; preload by calling without `await`, with the preload helper next to the component; pass an un-awaited promise to a Client Component and read it with `use`. |
| https://nextjs.org/docs/app/getting-started/mutating-data | 2026-10-04 | DF-10, DF-11, DF-12, DF-16, DF-17, DF-18, DF-22, DF-24, Not confirmed by the docs, Scope: Server Function vs Server Action terms; `'use server'` at the top of an async function or file; Server Functions can't be defined in Client Components; `startTransition` runs automatically for `<form action>` and `formAction`; progressive enhancement in Server Component forms and queued submission in Client Component forms; direct POST warning; sequential dispatch note; `refresh`, `revalidatePath`, `redirect` (throws, nothing after it runs, revalidate first) and cookie examples. |
| https://nextjs.org/docs/app/getting-started/caching | 2026-10-04 | DF-5, Patterns intro, P1, P3, P4 (added in FIX①): under Cache Components a dynamic `params` (not from `generateStaticParams`) is runtime data and a layout that awaits it can't be prerendered; "Maximizing the static shell" passes the `params` promise down (`params.then(...)` inside `<Suspense>`, or the whole promise to a child) and awaits it there; the same applies to `cookies()`, `headers()`, `searchParams`; a runtime access outside `<Suspense>` surfaces the blocking-route insight. Front matter `version: 16.3.8`. |
| https://nextjs.org/docs/app/guides/server-actions | 2026-10-04 | DF-10, DF-12, DF-13, DF-15, DF-16, DF-17, DF-22, DF-26, DF-27, DF-28, Not confirmed by the docs: Sequential dispatch and "do not rely on `Promise.all`"; one response carries data and UI; `updateTag` / `revalidatePath` / `refresh` re-render in the same response and `revalidateTag` does not; security (authenticate and authorize, validate, constrain return values, ID plus the change); "Choosing a cache update"; `serverActions` config; "Failed to find Server Action" and the retry-path advice. |
| https://nextjs.org/docs/app/guides/forms | 2026-10-04 | DF-13, DF-18, DF-19, DF-20, DF-21, DF-23, Not confirmed by the docs: `action` receives `FormData`; `.bind(null, id)` and its progressive-enhancement support; hidden input values are not encoded; server-side validation with `safeParse`; `useActionState` signature with `prevState`; `pending` from `useActionState` and `useFormStatus` in a separate component; `useOptimistic` example. |
| https://nextjs.org/docs/app/api-reference/directives/use-server | 2026-10-04 | DF-11, DF-12, DF-15, Not confirmed by the docs: `use server` at file top or inline; Server Functions in Client Components come from a dedicated file; read authentication from cookies or headers, not token parameters; return only what the UI needs. |
| https://nextjs.org/docs/app/guides/data-security | 2026-10-04 | DF-2, DF-12, DF-15, DF-24, DF-27, Not confirmed by the docs: A DAL "for new projects" that only runs on the server, authorizes and returns minimal DTOs; `server-only`; a page-level check does not extend to the actions defined within it; closure variables are sent to the client and back, encrypted, and "we don't recommend relying on encryption alone"; mutations must not run during render; return values are serialized. |
| https://nextjs.org/docs/app/api-reference/functions/redirect | 2026-10-04 | DF-17: `redirect` throws (`NEXT_REDIRECT`) and belongs outside `try`; `push` is the default type in Server Actions; progressive-enhancement submissions get a 303. |
| https://nextjs.org/docs/app/api-reference/functions/revalidatePath | 2026-10-04 | DF-16: `revalidatePath` is callable in Server Functions and Route Handlers; invalidates by path. |
| https://nextjs.org/docs/app/api-reference/functions/updateTag | 2026-10-04 | DF-16: `updateTag(tag)` is Server Actions only, read-your-own-writes, and the example calls `updateTag` then `redirect`. |
| https://nextjs.org/docs/app/api-reference/functions/refresh | 2026-10-04 | DF-16: `refresh()` is Server Actions only and refreshes the client router. |
| https://nextjs.org/docs/app/api-reference/functions/revalidateTag | 2026-10-04 | DF-16, Version notes: `revalidateTag(tag, profile)`: `'max'` is recommended, the single-argument form is deprecated. |
| https://nextjs.org/docs/app/api-reference/functions/after | 2026-10-04 | DF-25, Version notes: `after` runs after the response, also on `redirect`; usable in Server Functions; request APIs must be read before `after` in Server Components; stable since v15.1.0. |
| https://nextjs.org/docs/app/api-reference/components/form | 2026-10-04 | DF-18: `next/form` with a string `action` is a GET form with prefetch and client-side navigation; a function `action` behaves like a React form. |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions | 2026-10-04 | DF-26: `bodySizeLimit` defaults to 1MB and sits under `experimental.serverActions`; 10-20 KB multipart overhead; `allowedOrigins` and the proxy / `x-forwarded-host` behaviour. |
| https://nextjs.org/docs/app/guides/client-side-data-fetching | 2026-10-04 | DF-9: Pass a promise and use `use()` for read-once data; a client library when Client Components need a shared browser cache; invalidate the cached server read after a mutation. |
| https://nextjs.org/docs/app/getting-started/error-handling | 2026-10-04 | DF-14, DF-21: Model expected errors as return values and avoid `try`/`catch` for them; `useActionState` shows them. |
| https://nextjs.org/docs/app/guides/interactive-apps | 2026-10-04 | DF-14, DF-22, DF-23: `useOptimistic` plus `useTransition` toggle; the optimistic value reverts to the server prop when the transition ends; a throw inside the transition reaches the nearest error boundary; updates after `await` need their own `startTransition`. |
| https://nextjs.org/docs/app/guides/backend-for-frontend | 2026-10-04 | DF-1, DF-3, DF-9, DF-10: Fetch in Server Components directly from the source, not via Route Handlers (build fails when prerendering, slower on demand); client fetching only for client-only Web APIs and polled data; Server Actions are queued, so not for fetching. |
| https://nextjs.org/docs/app/api-reference/functions/fetch | 2026-10-04 | DF-6: `GET` `fetch` with the same URL and options is memoized during a render pass, separate from persistent caching. |
| https://nextjs.org/docs/app/guides/upgrading/version-16 | 2026-10-04 | Version notes: `revalidateTag` second argument; `updateTag` and `refresh` are new; async Request APIs; no other change to the Server Action surface. |
| https://nextjs.org/docs/app/guides/upgrading/version-15 | 2026-10-04 | Version notes: `useFormState` replaced by `useActionState`; `useFormStatus` extra keys; `fetch` not cached by default. |
| https://nextjs.org/blog/next-16 | 2026-10-04 | Version notes: `updateTag()` and `refresh()` introduced; `revalidateTag()` needs a `cacheLife` profile. |
| https://nextjs.org/blog/next-16-2 | 2026-10-04 | Version notes: Dev-terminal logging of Server Function execution. |
| https://nextjs.org/blog/next-16-3 | 2026-10-04 | Version notes: `experimental.useOffline` keeps a Server Action pending offline and retries. |
| https://nextjs.org/docs/app/guides/offline-support | 2026-10-04 | Version notes: `experimental.useOffline` is experimental and not recommended for production. |
| https://nextjs.org/docs/app/guides/authentication | 2026-10-04 | DF-12, Patterns: The DAL `verifySession()` helper (cached, redirects when signed out, returns `userId`), callable from Server Actions; Zod 4 `{ error }` style. |
| https://vercel.com/docs/functions/functions-api-reference | 2026-10-04 | DF-25: With cancellation enabled, work that must complete goes in `waitUntil` or `after`. |
| https://react.dev/reference/react/useActionState | 2026-10-04 | DF-14, DF-20, DF-21, DF-22: Return known errors as state; a thrown error shows the nearest Error Boundary; `initialState` must be serializable with Server Functions; the dispatcher must be called from an Action; returns `pending`. |
| https://react.dev/reference/react/useOptimistic | 2026-10-04 | DF-23: `useOptimistic(value, reducer?)`; the setter must be called inside an Action; the value reverts to `value` after the Action. |
| https://react.dev/reference/react-dom/hooks/useFormStatus | 2026-10-04 | DF-20: `useFormStatus` reports only for a parent `<form>`. |
| https://react.dev/reference/react/use | 2026-10-04 | DF-8: `use` can't be called in `try`/`catch`; promises must be cached; a promise from a Server Component needs a serializable value. |
| https://react.dev/reference/react/cache | 2026-10-04 | DF-6: `cache` is for Server Components, is called outside components, each call makes a new function, errors are cached. |
| https://react.dev/reference/react/useTransition | 2026-10-04 | DF-22: `useTransition` and `startTransition` give `isPending` and run async Actions. |
| https://react.dev/reference/rsc/use-server | 2026-10-04 | DF-10, DF-11, DF-13, DF-19, Not confirmed by the docs: `'use server'` only on async functions and at module level for client imports; arguments are fully client-controlled; not recommended for data fetching. |
| https://react.dev/reference/rsc/server-functions | 2026-10-04 | DF-18, Not confirmed by the docs: Server Functions in forms and progressive enhancement through `useActionState`'s third argument. |
| https://react.dev/reference/react-dom/components/form | 2026-10-04 | DF-18, Not confirmed by the docs: Passing a Server Function to `<form action>` works without JavaScript or before it loads; the error-before-hydration requirements. |
| https://zod.dev/basics | 2026-10-04 | DF-13: `safeParse` returns a discriminated union; `import * as z from "zod"`. |
| https://zod.dev/error-formatting | 2026-10-04 | DF-13, Not confirmed by the docs: `z.flattenError(result.error)` returns `{ formErrors, fieldErrors }`. |
| https://zod.dev/v4/changelog | 2026-10-04 | DF-13, Not confirmed by the docs: `invalid_type_error` dropped, `error` param standardised, `.flatten()` deprecated, top-level `z.uuid()`. |

## Claims reworded, added or dropped after the live read

The plan's rule sheet was checked page by page. Differences between the sheet and the file:

- DF-1: dropped "Don't fetch it in a Client Component effect". The pages state when client fetching is
  needed (client-only Web APIs, polled data, a shared browser cache) but never prohibit effects, so the rule
  now points at DF-9.
- DF-12: added that the check may live in the server-only DAL function the action calls (Data security,
  "Using a Data Access Layer for mutations"), and changed "session cookie" to "cookies or headers", which is
  the use-server page's wording.
- DF-16: `refresh(` is worded as the Server Actions page words it (refetch the current route without
  invalidating cached data).
- DF-18: split the progressive-enhancement claim as the pages do: Server Component forms submit before
  hydration, Client Component forms queue until JavaScript loads, and the error-before-hydration recipe needs
  a Client Component form, a Server Function and `useActionState`.
- DF-21: "keep schemas and `State` types outside the `'use server'` module" is tagged `(convention)`,
  because no page says a `'use server'` file may or may not export them (see Not confirmed).
- DF-24: dropped "or in a Route Handler"; the Data security page names Server Actions only.
- DF-25: the Vercel claim is scoped to request cancellation, which is where that page states it.
- DF-26: `allowedOrigins` is needed only when the proxy forwards its own host instead of the public one.
  The page says no entry is needed when `x-forwarded-host` carries the public host.
- Snippets: `.trim()` removed from the Zod schemas, because the cited zod.dev pages don't show it. The
  `z.flattenError`, `{ error }`, `z.uuid()` and `safeParse` usage is on zod.dev.
- Patterns: P10 (the `next/form` search form) was dropped to stay under the 800-line cap. DF-18 still states the
  `next/form` rule and cites its page.
- Version notes: the "React 19.2" bullet was dropped because it isn't a change to this topic.
- FIX① (REVIEW① R1-B4, R1-B13, R1-B15): the Patterns intro now names the two caching models; P1 and P4 pass the
  `params` promise into `<Suspense>` (the shape the Caching page's "Maximizing the static shell" shows) and say
  "both models"; P3 awaits `params` at the top, says "previous model" and points at P1 for Cache Components. DF-5
  gained the Cache Components `params` sentence and links the Caching page. This is the added Caching row above.
  Both models were built in a scratch Next.js 16.3.8 project: see `validation.md`, FIX①.
- FIX① R1-B13: P7 and P8 return typed state instead of a bare `return`, and DF-14 says a failed check never returns
  `void`. P7 is now a `.bind(`-ed action under `useActionState`. The docs show `.bind(` with a plain form action and
  `useActionState` separately, never the two together, so that is added to "Not confirmed by the docs".
- FIX① R1-B15: the session helpers import from `@/lib/dal`, snippet paths use `src/`, and Server Actions sit in
  `src/lib/actions/` (the layout in `nextjs.md`).
- FIX① line cap: P3's two fences became one file (the `preload` helper sits in the same file as the component it
  serves, which DF-7 asks for), and the "Don't call `revalidateTag` with one argument" anti-pattern was dropped. The
  same claim stays in DF-16 and in the Version notes, and the compiler reports it (TS2554).
