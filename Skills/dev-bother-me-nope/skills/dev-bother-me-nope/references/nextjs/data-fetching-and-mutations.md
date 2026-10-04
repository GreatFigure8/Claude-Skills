# Data fetching, Server Actions and forms

> As of Next.js 16.3.8, verified 2026-10-04.

## Scope

This file covers reading data in Server Components (the Data Access Layer and DTOs, waterfalls,
deduplication and preload, streaming a promise to `use(`, and when to fetch on the client) and writing
it through Server Functions and Server Actions (forms, validation, pending and optimistic UI, where to
revalidate and redirect, `after(`, and `next/form`). In the docs' terms a Server Action is a Server
Function used for a mutation, and Server Function is the broader term
([Mutating data](https://nextjs.org/docs/app/getting-started/mutating-data)).

What each cache API does is in [rendering-and-caching.md](rendering-and-caching.md); this file says when
and where a mutation calls it. Session checks, the Data Access Layer and Server Action security settings
are in [proxy-auth-and-security.md](proxy-auth-and-security.md). Public HTTP APIs and webhooks are in
[route-handlers-and-apis.md](route-handlers-and-apis.md), error boundaries are in
[testing-and-observability.md](testing-and-observability.md), and generated route-prop types are in
[typescript.md](typescript.md). The entry point is [nextjs.md](../nextjs.md).

## Rules

### Reading data

1. **DF-1** Fetch server data in async Server Components with `await fetch(...)` or an ORM or database
   call, so credentials and query logic stay out of the client bundle. Fetch on the client only for the
   cases DF-9 lists.
   ([Fetching data](https://nextjs.org/docs/app/getting-started/fetching-data); [Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend))
2. **DF-2** Read and write through a `server-only` Data Access Layer that authorizes and returns minimal
   DTOs, and never pass a raw database row to a Client Component. Depth is in
   [proxy-auth-and-security.md](proxy-auth-and-security.md).
   ([Data security](https://nextjs.org/docs/app/guides/data-security))
3. **DF-3** Call the data source or the DAL directly from a Server Component, and never `fetch` your own
   Route Handler from one: prerendering fails at build time and on-demand rendering pays an extra HTTP
   round trip. Route Handler design is in [route-handlers-and-apis.md](route-handlers-and-apis.md).
   ([Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend))
4. **DF-4** Start independent requests before awaiting any of them, then await `Promise.all` (or
   `Promise.allSettled` when one failure is acceptable). Sequential `await`s of independent data create a
   waterfall.
   ([Fetching data](https://nextjs.org/docs/app/getting-started/fetching-data))
5. **DF-5** Keep a truly dependent request sequential, wrap the dependent child in `<Suspense>` so the
   rest of the page renders first, and make the blocking first request fast or cache it. Under Cache
   Components, `params`, `searchParams` and `cookies()` are runtime data too: pass the un-awaited promise into
   the `<Suspense>` child and await it there, never at the top of a page or layout (the previous model raises no
   blocking-route error). The request-time rules are in [rendering-and-caching.md](rendering-and-caching.md).
   ([Fetching data](https://nextjs.org/docs/app/getting-started/fetching-data); [Caching](https://nextjs.org/docs/app/getting-started/caching))
6. **DF-6** Wrap every non-`fetch` data function (ORM or database) in React `cache(` once, at module scope
   in a shared module, so all components in one request share one result, and use it in Server Components
   only. Rely on built-in `fetch` memoization (GET with the same URL and options) for `fetch`. Neither
   persists across requests; persistence is in [rendering-and-caching.md](rendering-and-caching.md).
   ([Fetching data](https://nextjs.org/docs/app/getting-started/fetching-data); [fetch](https://nextjs.org/docs/app/api-reference/functions/fetch);
   [cache](https://react.dev/reference/react/cache))
7. **DF-7** Preload by calling the deduplicated data function without `await` before other blocking work
   (`void getItem(id)`), and keep the `preload` helper next to the component that consumes the data. The
   function must deduplicate matching calls (DF-6), or the component can't reuse the request.
   ([Fetching data](https://nextjs.org/docs/app/getting-started/fetching-data))
8. **DF-8** Stream data to a Client Component by passing the un-awaited promise from a Server Component as
   a `Promise<T>` prop, and read it with `use(` inside a `<Suspense>` boundary. `T` must be serializable,
   and `use(` must not be called inside `try`/`catch`.
   ([Fetching data](https://nextjs.org/docs/app/getting-started/fetching-data); [use](https://react.dev/reference/react/use))
9. **DF-9** Reach for SWR or TanStack Query only when Client Components need a shared browser cache,
   polling, focus revalidation or client-only Web APIs. For read-once server data, pass a promise and call
   `use(`. When a library cache was seeded from a cached server read, invalidate that server read after a
   mutation too.
   ([Client-side data fetching](https://nextjs.org/docs/app/guides/client-side-data-fetching);
   [Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend))
10. **DF-10** Never use a Server Function to fetch data. The client currently dispatches Server Actions one
    at a time, so don't parallelize them with `Promise.all`. Read in a Server Component or a Route Handler,
    and do parallel work inside a single action.
    ([Server Actions](https://nextjs.org/docs/app/guides/server-actions); [Mutating data](https://nextjs.org/docs/app/getting-started/mutating-data);
    [Backend for Frontend](https://nextjs.org/docs/app/guides/backend-for-frontend); [use server](https://react.dev/reference/rsc/use-server))

### Mutating data

11. **DF-11** Put `'use server'` at the top of a dedicated module in `src/lib/actions/`, or as the first statement
    of an async function inside a Server Component. Never define a Server Function in a Client Component:
    import it from a `'use server'` module or receive it as a prop.
    ([Mutating data](https://nextjs.org/docs/app/getting-started/mutating-data); [use server directive](https://nextjs.org/docs/app/api-reference/directives/use-server);
    [use server](https://react.dev/reference/rsc/use-server))
12. **DF-12** Authenticate and authorize inside every Server Action before any write: call `verifySession()`
    from `@/lib/dal` (or `auth()`), then check ownership of the specific resource. A page-level check doesn't protect the
    actions defined within that page, because every action is reachable by direct POST. The check may live
    in the server-only DAL function the action calls, if it runs before the write. Read identity from
    cookies or headers, never from a token argument. Depth is in
    [proxy-auth-and-security.md](proxy-auth-and-security.md).
    ([Mutating data](https://nextjs.org/docs/app/getting-started/mutating-data); [Server Actions](https://nextjs.org/docs/app/guides/server-actions);
    [use server directive](https://nextjs.org/docs/app/api-reference/directives/use-server); [Data security](https://nextjs.org/docs/app/guides/data-security);
    [Authentication](https://nextjs.org/docs/app/guides/authentication))
13. **DF-13** Treat every action argument as untrusted: `FormData`, `.bind(`-ed arguments and plain values.
    Validate with a schema `safeParse` before use, accept an ID plus the change rather than a whole row, and
    re-read ownership from a trusted source, because a schema only checks shape. With Zod 4, build field
    errors with `z.flattenError(result.error)`, since `.flatten()` is deprecated.
    ([Server Actions](https://nextjs.org/docs/app/guides/server-actions); [Forms](https://nextjs.org/docs/app/guides/forms);
    [use server](https://react.dev/reference/rsc/use-server); [Zod basics](https://zod.dev/basics); [Zod error formatting](https://zod.dev/error-formatting);
    [Zod 4 changelog](https://zod.dev/v4/changelog))
14. **DF-14** Return expected errors as typed state. Validation failures, business-rule rejections and
    failed upstream calls go back as a serializable object that the form renders through `useActionState`;
    don't throw them or route them through `try`/`catch`. Throw only unexpected errors, which reach the
    nearest error boundary. A failed authorization or validation check returns that state too, never `void` or
    a bare `return`, which leaves the user without feedback.
    ([Error handling](https://nextjs.org/docs/app/getting-started/error-handling); [useActionState](https://react.dev/reference/react/useActionState);
    [Interactive apps](https://nextjs.org/docs/app/guides/interactive-apps))
15. **DF-15** Return only what the UI renders: a DTO, an `{ ok }` flag or field errors. Never return a raw
    database record, because return values are serialized to the client.
    ([Server Actions](https://nextjs.org/docs/app/guides/server-actions); [use server directive](https://nextjs.org/docs/app/api-reference/directives/use-server);
    [Data security](https://nextjs.org/docs/app/guides/data-security))
16. **DF-16** Invalidate inside the action, after the write succeeds. Use `updateTag(tag)` for
    read-your-own-writes (Server Actions only), `revalidatePath(path)` for one route,
    `revalidateTag(tag, 'max')` when stale data is acceptable (the second argument is required), and
    `refresh(` to refetch the current route without invalidating cached data (Server Actions only). What each one does is in
    [rendering-and-caching.md](rendering-and-caching.md).
    ([Server Actions](https://nextjs.org/docs/app/guides/server-actions); [Mutating data](https://nextjs.org/docs/app/getting-started/mutating-data);
    [revalidatePath](https://nextjs.org/docs/app/api-reference/functions/revalidatePath); [updateTag](https://nextjs.org/docs/app/api-reference/functions/updateTag);
    [refresh](https://nextjs.org/docs/app/api-reference/functions/refresh); [revalidateTag](https://nextjs.org/docs/app/api-reference/functions/revalidateTag))
17. **DF-17** Call `redirect(` outside any `try`/`catch` block and after revalidation. It throws a
    framework control-flow exception (`NEXT_REDIRECT`), so code after it never runs. In a Server Action it
    defaults to a `push` navigation, and it serves a 303 for a form submitted without JavaScript. The
    revalidation APIs don't throw, so an action can call them and still return a value.
    ([redirect](https://nextjs.org/docs/app/api-reference/functions/redirect); [Mutating data](https://nextjs.org/docs/app/getting-started/mutating-data);
    [Server Actions](https://nextjs.org/docs/app/guides/server-actions))
18. **DF-18** Submit mutations with `<form action={serverAction}>`, or `formAction` on a `<button>`, so React
    runs them in a transition and passes `FormData` automatically. A form rendered by a Server Component
    submits before hydration (progressive enhancement); a Client Component form queues the submission
    until JavaScript loads. Showing an error before hydration needs a Client Component form, a Server
    Function as the action and `useActionState`. Use `next/form`'s `<Form action="/path">` for GET forms
    that navigate with search params.
    ([Mutating data](https://nextjs.org/docs/app/getting-started/mutating-data); [Forms](https://nextjs.org/docs/app/guides/forms);
    [Form component](https://nextjs.org/docs/app/api-reference/components/form); [form](https://react.dev/reference/react-dom/components/form);
    [Server Functions](https://react.dev/reference/rsc/server-functions))
19. **DF-19** Pass non-field arguments with `serverAction.bind(null, id)`, not hidden inputs, which are
    rendered into the HTML unencoded. Re-authorize the bound value inside the action, because it is still
    client-controlled.
    ([Forms](https://nextjs.org/docs/app/guides/forms); [use server](https://react.dev/reference/rsc/use-server))
20. **DF-20** Show pending state with the third value of `useActionState` (`pending`), or with
    `useFormStatus().pending` in a separate child component rendered inside the `<form>`. Disable the
    submit button while pending.
    ([Forms](https://nextjs.org/docs/app/guides/forms); [useActionState](https://react.dev/reference/react/useActionState);
    [useFormStatus](https://react.dev/reference/react-dom/hooks/useFormStatus))
21. **DF-21** Type an action used with `useActionState` as
    `(prevState: State, formData: FormData) => Promise<State>`, with a serializable `initialState` of the
    same type. Keep schemas and `State` types in a module without `'use server'` (convention).
    ([Forms](https://nextjs.org/docs/app/guides/forms); [useActionState](https://react.dev/reference/react/useActionState);
    [Error handling](https://nextjs.org/docs/app/getting-started/error-handling))
22. **DF-22** Call an action from an event handler or `useEffect` inside `startTransition` (take
    `isPending` from `useTransition`), and wrap any state update made after an `await` in another
    `startTransition`. Call a `useActionState` dispatcher only from an Action.
    ([Mutating data](https://nextjs.org/docs/app/getting-started/mutating-data); [Server Actions](https://nextjs.org/docs/app/guides/server-actions);
    [Interactive apps](https://nextjs.org/docs/app/guides/interactive-apps); [useTransition](https://react.dev/reference/react/useTransition);
    [useActionState](https://react.dev/reference/react/useActionState))
23. **DF-23** Use `useOptimistic` for instant feedback. Call its setter inside the Action (a form action or
    `startTransition`) before awaiting the Server Action, and let the value revert to the server prop when
    the transition ends instead of clearing it by hand.
    ([Forms](https://nextjs.org/docs/app/guides/forms); [Interactive apps](https://nextjs.org/docs/app/guides/interactive-apps);
    [useOptimistic](https://react.dev/reference/react/useOptimistic))
24. **DF-24** Never mutate during render: no database write, cookie `set` or `delete`, or revalidation in a
    Server Component body. Mutate in a Server Action, where setting a cookie re-renders the current page
    with the new value.
    ([Data security](https://nextjs.org/docs/app/guides/data-security); [Mutating data](https://nextjs.org/docs/app/getting-started/mutating-data))
25. **DF-25** Put post-response work such as audit logs and analytics in `after(` from `next/server`. In a
    Server Component, read `cookies()` or `headers()` before `after` and pass the values in. On Vercel with
    request cancellation enabled, work that must finish after a client disconnect goes in `after` or
    `waitUntil`.
    ([after](https://nextjs.org/docs/app/api-reference/functions/after); [Vercel Functions API](https://vercel.com/docs/functions/functions-api-reference))
26. **DF-26** Keep action payloads under `serverActions.bodySizeLimit` (1MB by default). Raise it under
    `experimental.serverActions` only for real uploads, leaving 10-20 KB for multipart overhead. When a
    proxy or CDN makes the browser's host differ from the server's, list the browser's host in
    `allowedOrigins`. Depth is in [proxy-auth-and-security.md](proxy-auth-and-security.md).
    ([serverActions](https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions); [Server Actions](https://nextjs.org/docs/app/guides/server-actions))
27. **DF-27** Don't capture secrets in an inline action's closure. Closed-over values travel to the client
    and back, Next.js encrypts them, and the docs advise against relying on that encryption alone. For
    multi-instance self-hosting, set one stable `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY`. Depth is in
    [proxy-auth-and-security.md](proxy-auth-and-security.md).
    ([Data security](https://nextjs.org/docs/app/guides/data-security); [Server Actions](https://nextjs.org/docs/app/guides/server-actions))
28. **DF-28** Treat "Failed to find Server Action" after a deploy as a retry path in the UI, not a hard
    failure, and prefer rolling deployments, because action IDs change between builds.
    ([Server Actions](https://nextjs.org/docs/app/guides/server-actions))

## Patterns

Every `'use server'` example authenticates first, with paths in the `src/` layout of [nextjs.md](../nextjs.md) and
Server Actions in `src/lib/actions/`. `verifySession()` (redirects to `/login`, returns a `Session`) and `getSession()`
(returns `Session | null`, for Route Handlers) come from `@/lib/dal`, the `server-only` `src/lib/dal.ts` that
[proxy-auth-and-security.md](proxy-auth-and-security.md) defines after the
[Authentication guide](https://nextjs.org/docs/app/guides/authentication). Entity modules (`@/lib/dal/<entity>`) are illustrative.

Each heading names the caching model its pattern assumes. In the previous model (no `cacheComponents`) a page may await
`params` at the top. Under Cache Components a dynamic `params`, `searchParams` or `cookies()` is runtime data: pass the
un-awaited promise into a `<Suspense>` boundary and await it there ([Caching guide](https://nextjs.org/docs/app/getting-started/caching);
detection and request-time rules in [rendering-and-caching.md](rendering-and-caching.md)).

### P1 Parallel fetching with `params` awaited inside `<Suspense>` (DF-4, DF-5; both models)

```tsx
// src/app/artist/[username]/page.tsx
import { Suspense } from 'react'
import { getAlbums, getArtist } from '@/lib/dal/artists'
import Albums from './albums'

// Not async: under Cache Components a top-level `await params` would block the static shell.
export default function Page({ params }: PageProps<'/artist/[username]'>) {
  return (
    <Suspense fallback={<p>Loading artist…</p>}>
      <Artist params={params} />
    </Suspense>
  )
}

async function Artist({ params }: { params: PageProps<'/artist/[username]'>['params'] }) {
  const { username } = await params // awaited inside the boundary
  // Both requests start now; neither waits for the other.
  const artistPromise = getArtist(username)
  const albumsPromise = getAlbums(username)
  const [artist, albums] = await Promise.all([artistPromise, albumsPromise])

  return (
    <>
      <h1>{artist.name}</h1>
      <Albums list={albums} />
    </>
  )
}
```

### P2 Request-scoped deduplication with React `cache` in the DAL (DF-2, DF-6; both models)

```ts
// src/lib/dal/users.ts
import 'server-only'
import { cache } from 'react'
import { db, eq, users } from '@/lib/db'
import type { UserDTO } from '@/lib/dto'

// Module scope: every component in one request shares one call per id.
export const getUser = cache(async (id: string): Promise<UserDTO | null> => {
  const row = await db.query.users.findFirst({ where: eq(users.id, id) })
  if (!row) return null
  return { id: row.id, name: row.name } // DTO: only what the UI renders
})
```

### P3 Preload before blocking work (DF-7; previous model)

Under Cache Components, move the body of `Page` into a child inside `<Suspense>` that awaits the `params` promise, as P1 does.

```tsx
// src/app/item/[id]/page.tsx
import { checkIsAvailable, getItem } from '@/lib/dal/items' // getItem is wrapped in cache(), see P2

// Next to the component that consumes the data.
const preload = (id: string): void => {
  void getItem(id)
}

async function Item({ id }: { id: string }) {
  const item = await getItem(id)
  return <div>{item?.name}</div>
}

export default async function Page({ params }: PageProps<'/item/[id]'>) {
  const { id } = await params
  preload(id) // starts the item request now
  const isAvailable = await checkIsAvailable(id)
  return isAvailable ? <Item id={id} /> : null
}
```

### P4 Stream a promise to a Client Component with `use(` (DF-8; both models)

```tsx
// src/app/posts/[id]/page.tsx (Server Component)
import { Suspense } from 'react'
import { getComments } from '@/lib/dal/comments'
import { Comments } from './comments'

// Not async: `params` is read inside the boundary, and the comments request is not awaited.
export default function Page({ params }: PageProps<'/posts/[id]'>) {
  return (
    <Suspense fallback={<p>Loading comments…</p>}>
      {params.then(({ id }) => (
        <Comments comments={getComments(id)} />
      ))}
    </Suspense>
  )
}
```

```tsx
// src/app/posts/[id]/comments.tsx
'use client'

import { use } from 'react'
import type { CommentDTO } from '@/lib/dto'

export function Comments({ comments }: { comments: Promise<CommentDTO[]> }) {
  const list = use(comments)
  return (
    <ul>
      {list.map((comment) => (
        <li key={comment.id}>{comment.body}</li>
      ))}
    </ul>
  )
}
```

### P5 Validate `FormData`, return typed state, invalidate, then redirect (DF-12 to DF-17, DF-21; both models)

```ts
// src/features/posts/definitions.ts (no directive: shared by the action and the form)
import * as z from 'zod'

export const CreatePostSchema = z.object({
  title: z.string().min(1, { error: 'Title is required.' }),
  body: z.string().min(1, { error: 'Write something first.' }),
})

export type CreatePostState = {
  fieldErrors?: Partial<Record<'title' | 'body', string[]>>
  message?: string
}
```

```ts
// src/lib/actions/posts.ts
'use server'

import * as z from 'zod'
import { revalidatePath, updateTag } from 'next/cache'
import { redirect } from 'next/navigation'
import { verifySession } from '@/lib/dal'
import { createPost } from '@/lib/dal/posts'
import { CreatePostSchema, type CreatePostState } from '@/features/posts/definitions'

export async function createPostAction(
  _prev: CreatePostState,
  formData: FormData,
): Promise<CreatePostState> {
  const { userId } = await verifySession() // redirects to /login when signed out

  const parsed = CreatePostSchema.safeParse({
    title: formData.get('title'),
    body: formData.get('body'),
  })
  if (!parsed.success) {
    return { fieldErrors: z.flattenError(parsed.error).fieldErrors }
  }

  const post = await createPost(userId, parsed.data) // DAL: authz + write, returns { id } | null
  if (!post) return { message: 'Could not save the post. Try again.' }

  updateTag('posts') // read-your-own-writes for every page tagged 'posts'
  revalidatePath('/posts')
  redirect(`/posts/${post.id}`) // last: it throws, so nothing after it runs
}
```

### P6 Form bound to the action with pending and error state (DF-18, DF-20, DF-21; both models)

```tsx
// src/app/posts/new/create-post-form.tsx
'use client'

import { useActionState } from 'react'
import { useFormStatus } from 'react-dom'
import { createPostAction } from '@/lib/actions/posts'
import type { CreatePostState } from '@/features/posts/definitions'

const initialState: CreatePostState = {}

function SubmitButton() {
  const { pending } = useFormStatus() // reads the parent <form>
  return (
    <button type="submit" disabled={pending}>
      {pending ? 'Publishing…' : 'Publish'}
    </button>
  )
}

export function CreatePostForm() {
  const [state, formAction, pending] = useActionState(createPostAction, initialState)

  return (
    <form action={formAction} aria-busy={pending}>
      <label htmlFor="title">Title</label>
      <input id="title" name="title" required />
      {state.fieldErrors?.title && <p aria-live="polite">{state.fieldErrors.title[0]}</p>}
      <label htmlFor="body">Body</label>
      <textarea id="body" name="body" required />
      {state.fieldErrors?.body && <p aria-live="polite">{state.fieldErrors.body[0]}</p>}
      {state.message && <p aria-live="polite">{state.message}</p>}
      <SubmitButton />
    </form>
  )
}
```

### P7 Extra arguments with `.bind(` and typed failure state (DF-13, DF-14, DF-19; both models)

```tsx
// src/app/users/[id]/user-name-form.tsx
'use client'

import { useActionState } from 'react'
import { updateUserNameAction } from '@/lib/actions/users'
import type { UpdateNameState } from '@/features/users/definitions'

const initialState: UpdateNameState = {}

export function UserNameForm({ userId }: { userId: string }) {
  const [state, formAction] = useActionState(updateUserNameAction.bind(null, userId), initialState)
  return (
    <form action={formAction}>
      <input name="name" required />
      {state.message && <p aria-live="polite">{state.message}</p>}
      <button type="submit">Save</button>
    </form>
  )
}
```

```ts
// src/features/users/definitions.ts (no directive)
export type UpdateNameState = { message?: string }
```

```ts
// src/lib/actions/users.ts
'use server'

import * as z from 'zod'
import { revalidatePath } from 'next/cache'
import { verifySession } from '@/lib/dal'
import { updateUserName } from '@/lib/dal/users'
import type { UpdateNameState } from '@/features/users/definitions'

const Name = z.string().min(1).max(80)

export async function updateUserNameAction(
  userId: string, // bound with .bind(null, userId)
  _prev: UpdateNameState,
  formData: FormData,
): Promise<UpdateNameState> {
  const session = await verifySession()
  // The bound id is client-controlled: re-check it, and tell the user when it fails.
  if (session.userId !== userId) return { message: 'You can only edit your own name.' }
  const parsed = Name.safeParse(formData.get('name'))
  if (!parsed.success) return { message: 'Enter a name of 1 to 80 characters.' }
  await updateUserName(userId, parsed.data)
  revalidatePath(`/users/${userId}`)
  return { message: 'Saved.' }
}
```

### P8 Optimistic toggle from an event handler (DF-14, DF-16, DF-22, DF-23; both models)

```tsx
// src/app/posts/[id]/like-button.tsx
'use client'

import { useOptimistic, useState, useTransition } from 'react'
import { toggleLikeAction } from '@/lib/actions/likes'

export function LikeButton({ postId, liked }: { postId: string; liked: boolean }) {
  const [optimisticLiked, setOptimisticLiked] = useOptimistic(liked)
  const [error, setError] = useState<string | null>(null)
  const [isPending, startTransition] = useTransition()

  function handleClick() {
    startTransition(async () => {
      setOptimisticLiked(!optimisticLiked) // renders now, reverts to `liked` when the transition ends
      const result = await toggleLikeAction(postId)
      startTransition(() => setError(result.ok ? null : result.message)) // after an await: wrap again
    })
  }

  return (
    <>
      <button type="button" onClick={handleClick} aria-pressed={optimisticLiked} aria-busy={isPending}>
        {optimisticLiked ? 'Unlike' : 'Like'}
      </button>
      {error && <p role="alert">{error}</p>}
    </>
  )
}
```

```ts
// src/lib/actions/likes.ts
'use server'

import * as z from 'zod'
import { refresh } from 'next/cache'
import { verifySession } from '@/lib/dal'
import { toggleLike } from '@/lib/dal/likes'

export async function toggleLikeAction(
  postId: string,
): Promise<{ ok: true } | { ok: false; message: string }> {
  const { userId } = await verifySession()
  const id = z.uuid().safeParse(postId)
  if (!id.success) return { ok: false, message: 'That post id is not valid.' }
  await toggleLike(userId, id.data)
  refresh() // like counts are uncached: re-render the current route in this response
  return { ok: true }
}
```

### P9 Post-response work with `after(` in a Server Action (DF-15, DF-25; both models)

```ts
// src/lib/actions/archive-post.ts
'use server'

import * as z from 'zod'
import { after } from 'next/server'
import { revalidatePath } from 'next/cache'
import { verifySession } from '@/lib/dal'
import { archivePost } from '@/lib/dal/posts'
import { logAudit } from '@/lib/audit'

export async function archivePostAction(postId: string): Promise<{ ok: boolean }> {
  const { userId } = await verifySession()
  const id = z.uuid().safeParse(postId)
  if (!id.success) return { ok: false }
  const archived = await archivePost(userId, id.data) // the DAL checks ownership
  if (!archived) return { ok: false }
  revalidatePath('/posts')
  after(async () => {
    await logAudit({ userId, postId: id.data, event: 'post.archived' }) // runs after the response
  })
  return { ok: true }
}
```

## Anti-patterns

### Don't await independent requests one after another

This is the waterfall DF-4 forbids: `getAlbums` waits for `getArtist` for no reason.

**Don't:**

```tsx
const artist = await getArtist(username)
const albums = await getAlbums(username)
```

**Do:**

```tsx
const artistPromise = getArtist(username)
const albumsPromise = getAlbums(username)
const [artist, albums] = await Promise.all([artistPromise, albumsPromise])
```

### Don't fetch your own Route Handler from a Server Component

DF-3: the extra HTTP round trip is slower, and a prerendered page fails the build.

**Don't:**

```tsx
const res = await fetch('http://localhost:3000/api/posts')
const posts: PostDTO[] = await res.json()
```

**Do:**

```tsx
import { getPosts } from '@/lib/dal/posts'

const posts = await getPosts()
```

### Don't check the session only in the page

DF-12: the page-level check controls what renders, but the action is a separate POST entry point.

**Don't:**

```tsx
export default async function AdminPage() {
  await verifySession() // guards the page render only
  async function deleteAll() {
    'use server'
    await db.record.deleteMany() // the action has no check of its own
  }
  return <form action={deleteAll}>...</form>
}
```

**Do:**

```tsx
export default async function AdminPage() {
  await verifySession()
  async function deleteAll() {
    'use server'
    const { userId } = await verifySession() // the action checks for itself
    if (!(await canDeleteRecords(userId))) throw new Error('Forbidden')
    await db.record.deleteMany()
  }
  return <form action={deleteAll}>...</form>
}
```

### Don't call `redirect(` inside `try`/`catch`

DF-17 and DF-14: `redirect` throws `NEXT_REDIRECT`, so the `catch` swallows the navigation.

**Don't:**

```ts
try {
  const post = await createPost(userId, data)
  redirect(`/posts/${post.id}`) // throws, and the catch below returns instead
} catch {
  return { message: 'Failed' }
}
```

**Do:**

```ts
const post = await createPost(userId, data) // returns null for an expected failure
if (!post) return { message: 'Could not save the post.' }
revalidatePath('/posts')
redirect(`/posts/${post.id}`) // last, outside any try
```

If a `try`/`catch` is unavoidable (say, around a third-party SDK), keep `redirect(` after the block.

### Don't throw expected errors or return raw records

DF-14 and DF-15: expected failures are state, and the return value is serialized to the client.

**Don't:**

```ts
if (!parsed.success) throw new Error('Invalid')
return db.post.update({ where: { id }, data: parsed.data }) // the raw row
```

**Do:**

```ts
if (!parsed.success) return { fieldErrors: z.flattenError(parsed.error).fieldErrors }
await updatePost(userId, id, parsed.data) // DAL: authz + write
return { ok: true }
```

### Don't use a Server Action to fetch data

DF-10 and DF-8: actions are dispatched one at a time and are not designed for reads.

**Don't:**

```tsx
// In a Client Component: a Server Action used as a read
useEffect(() => {
  getPostsAction().then(setPosts)
}, [])
```

**Do:**

```tsx
// In a Server Component: start the read, don't await it, and stream it to `use(` (see P4)
<Suspense fallback={<p>Loading…</p>}>
  <Posts posts={getPosts()} />
</Suspense>
```

### Don't copy Zod 3 error APIs into Zod 4

DF-13: `invalid_type_error` was dropped and `.flatten()` is deprecated in Zod 4.

**Don't:**

```ts
const schema = z.object({ email: z.string({ invalid_type_error: 'Invalid Email' }) })
const errors = schema.safeParse(input).error?.flatten().fieldErrors
```

**Do:**

```ts
const schema = z.object({ email: z.string({ error: 'Invalid Email' }) })
const result = schema.safeParse(input)
const errors = result.success ? undefined : z.flattenError(result.error).fieldErrors
```

## Version notes

Next.js 16 changes that touch this topic, and what each means here.

- `updateTag(tag)` and `refresh()` are new in Next.js 16, and both are Server Actions-only APIs.
  `updateTag` gives read-your-writes semantics. `refresh` refreshes uncached data and doesn't touch the cache
  ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16);
  [Next.js 16](https://nextjs.org/blog/next-16)).
- `revalidateTag(tag, profile)` now requires a second argument. The single-argument form is deprecated and
  is a TypeScript error. Use `'max'` for stale-while-revalidate, or `updateTag` in a Server Action for
  immediate expiry ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16);
  [revalidateTag](https://nextjs.org/docs/app/api-reference/functions/revalidateTag)).
- Synchronous `cookies()`, `headers()`, `draftMode()`, `params` and `searchParams` access is removed in Next.js 16, so await them, including
  inside Server Actions ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16)).
- 16.2: the dev server logs each Server Function execution, with its name, arguments, duration and file ([Next.js 16.2](https://nextjs.org/blog/next-16-2)).
- 16.3: the experimental `experimental.useOffline` keeps a Server Action pending while the network is down
  and retries it on reconnect. It isn't for production
  ([Next.js 16.3](https://nextjs.org/blog/next-16-3);
  [offline support](https://nextjs.org/docs/app/guides/offline-support)).
- The version 16 upgrade guide lists no other change to `'use server'`, `useActionState`, `useFormStatus`, `next/form`, `after` or the
  `serverActions` config ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16)).
- Carried over from Next.js 15 and still current: `useActionState` replaces the deprecated `useFormState`,
  `useFormStatus` returns `data`, `method` and `action` as well as `pending`, and `fetch` requests are not
  cached by default ([upgrade guide to 15](https://nextjs.org/docs/app/guides/upgrading/version-15)).
  `after` has been stable since v15.1.0 ([after](https://nextjs.org/docs/app/api-reference/functions/after)).

## Review checklist

- [ ] No sequential `await` of independent requests; they start first and are awaited with `Promise.all` (DF-4).
- [ ] No Server Component `fetch`es its own Route Handler (DF-3).
- [ ] Non-`fetch` data functions are wrapped in React `cache(` at module scope (DF-6), and preload helpers sit next to the component that consumes them (DF-7).
- [ ] Promises passed to Client Components are created on the server, typed `Promise<T>` and read with `use(` under `<Suspense>` (DF-8).
- [ ] Under Cache Components, `params`, `searchParams` and `cookies()` are passed un-awaited into a `<Suspense>` child, and patterns labelled previous model aren't copied in (DF-5).
- [ ] No Server Action is used to read data, and no client code runs actions through `Promise.all` (DF-10).
- [ ] Every `'use server'` function authenticates and authorizes the specific resource before writing (DF-12).
- [ ] Every action input (`FormData`, bound arguments, plain values) goes through a schema `safeParse` (DF-13, DF-19).
- [ ] Expected errors and failed checks come back as typed state, never `void` or a bare `return`, and return values are DTOs (DF-14, DF-15).
- [ ] Each mutation invalidates inside the action with the right API: `updateTag`, `revalidatePath`, `revalidateTag(tag, 'max')` or `refresh(` (DF-16).
- [ ] `redirect(` sits outside `try`/`catch` and after revalidation (DF-17).
- [ ] Forms use `action={...}` or `formAction` with a Server Action, and GET search forms use `next/form` (DF-18).
- [ ] Pending UI uses the `useActionState` `pending` value or a child `useFormStatus`, and the action signature is `(prevState, formData)` with typed, serializable state (DF-20, DF-21).
- [ ] Event-handler calls go through `startTransition`, post-`await` state updates are wrapped, and optimistic setters are called inside the Action (DF-22, DF-23).
- [ ] No mutation, cookie write or revalidation happens during render, and post-response work uses `after(` (DF-24, DF-25).
- [ ] Any `bodySizeLimit` change is justified, no secret is captured in an inline-action closure, and the UI offers a retry for "Failed to find Server Action" (DF-26, DF-27, DF-28).

## Not confirmed by the docs

Nothing here is stated as a rule.

- Whether a client-side wrapper function passed to `action=` (one that calls an optimistic setter and then the Server Action) still
  submits before hydration, and whether a `.bind(`-ed Server Action passed to `useActionState` (P7) does. The pages document progressive
  enhancement only for a Server Action passed directly, `.bind(`-ed, or used through `useActionState`. Checked:
  [Mutating data](https://nextjs.org/docs/app/getting-started/mutating-data), [Forms](https://nextjs.org/docs/app/guides/forms),
  [form](https://react.dev/reference/react-dom/components/form), [Server Functions](https://react.dev/reference/rsc/server-functions).
- Whether `.bind(` arguments are encrypted like closure variables. The Forms guide says only that a hidden-input value is not encoded,
  and the Data security guide covers encryption for closures only. Checked: [Forms](https://nextjs.org/docs/app/guides/forms),
  [Data security](https://nextjs.org/docs/app/guides/data-security), [Server Actions](https://nextjs.org/docs/app/guides/server-actions).
- Whether a `'use server'` file may export types or constants. No page covers it, so the examples keep schemas and types in a separate
  module. Checked: [use server directive](https://nextjs.org/docs/app/api-reference/directives/use-server),
  [use server](https://react.dev/reference/rsc/use-server).
- Which Zod major the Next.js Forms guide targets. The page doesn't say, and its snippet uses Zod 3 APIs that zod.dev documents as
  dropped or deprecated in Zod 4, so this file follows zod.dev. Checked: [Forms](https://nextjs.org/docs/app/guides/forms),
  [Zod 4 changelog](https://zod.dev/v4/changelog), [Zod error formatting](https://zod.dev/error-formatting).

## Sources

- https://nextjs.org/docs/app/getting-started/fetching-data — fetching in Server Components, parallel, cache, preload, `use`
- https://nextjs.org/docs/app/getting-started/mutating-data — Server Functions, forms, revalidate, redirect, cookies
- https://nextjs.org/docs/app/getting-started/caching — Cache Components: runtime data and `<Suspense>`, passing the `params` promise down
- https://nextjs.org/docs/app/guides/server-actions — sequential dispatch, security, cache updates, deployment
- https://nextjs.org/docs/app/guides/forms — forms, validation, pending, optimistic, `.bind(`
- https://nextjs.org/docs/app/api-reference/directives/use-server — the `use server` directive
- https://nextjs.org/docs/app/guides/data-security — DAL, DTOs, Server Action security, closures
- https://nextjs.org/docs/app/api-reference/functions/redirect — `redirect`
- https://nextjs.org/docs/app/api-reference/functions/revalidatePath — `revalidatePath`
- https://nextjs.org/docs/app/api-reference/functions/updateTag — `updateTag`
- https://nextjs.org/docs/app/api-reference/functions/refresh — `refresh`
- https://nextjs.org/docs/app/api-reference/functions/revalidateTag — `revalidateTag`
- https://nextjs.org/docs/app/api-reference/functions/after — `after`
- https://nextjs.org/docs/app/api-reference/components/form — `next/form`
- https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions — `serverActions` config
- https://nextjs.org/docs/app/guides/client-side-data-fetching — client-side data fetching
- https://nextjs.org/docs/app/getting-started/error-handling — expected errors as return values
- https://nextjs.org/docs/app/guides/interactive-apps — transitions and optimistic UI
- https://nextjs.org/docs/app/guides/backend-for-frontend — Server Components, Route Handlers, Server Actions caveats
- https://nextjs.org/docs/app/api-reference/functions/fetch — `fetch` memoization
- https://nextjs.org/docs/app/guides/upgrading/version-16 — upgrade guide to version 16
- https://nextjs.org/docs/app/guides/upgrading/version-15 — upgrade guide to version 15
- https://nextjs.org/blog/next-16 — Next.js 16 release post
- https://nextjs.org/blog/next-16-2 — Next.js 16.2 release post
- https://nextjs.org/blog/next-16-3 — Next.js 16.3 release post
- https://nextjs.org/docs/app/guides/offline-support — offline support (experimental)
- https://nextjs.org/docs/app/guides/authentication — authentication and the `verifySession` DAL helper
- https://vercel.com/docs/functions/functions-api-reference — Vercel Functions API, `waitUntil`
- https://react.dev/reference/react/useActionState — `useActionState`
- https://react.dev/reference/react/useOptimistic — `useOptimistic`
- https://react.dev/reference/react-dom/hooks/useFormStatus — `useFormStatus`
- https://react.dev/reference/react/use — `use`
- https://react.dev/reference/react/cache — `cache`
- https://react.dev/reference/react/useTransition — `useTransition`
- https://react.dev/reference/rsc/use-server — `'use server'` in React
- https://react.dev/reference/rsc/server-functions — Server Functions in React
- https://react.dev/reference/react-dom/components/form — the React `<form>`
- https://zod.dev/basics — Zod `safeParse`
- https://zod.dev/error-formatting — `z.flattenError`
- https://zod.dev/v4/changelog — Zod 4 changelog
