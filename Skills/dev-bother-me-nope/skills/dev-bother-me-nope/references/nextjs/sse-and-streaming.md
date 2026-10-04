# Server-Sent Events and streaming responses

> As of Next.js 16.3.8, verified 2026-10-04.

## Scope

Covers streaming a Route Handler response: the Server-Sent Events (SSE) wire format and headers, a `ReadableStream` with abort and cleanup,
heartbeats, resuming with `Last-Event-ID`, closing before `maxDuration`, the client side (`EventSource`, or `fetch` with a reader for POST or
custom headers) and the Vercel streaming and duration limits that bound a stream. Points elsewhere: streaming HTML with `Suspense` or
`loading.tsx` in [rendering-and-caching.md](rendering-and-caching.md); validation, auth checks and the error shape in
[route-handlers-and-apis.md](route-handlers-and-apis.md); other function configuration in
[performance-and-vercel.md](performance-and-vercel.md); Proxy and sessions in [proxy-auth-and-security.md](proxy-auth-and-security.md). The
entry point and folder layout are in [../nextjs.md](../nextjs.md).

## Rules

1. **SSE-1** Choose SSE for one-way server-to-client updates such as live feeds, job progress and AI token streams. Choose WebSockets only
    when the client also pushes a continuous stream, and poll or fetch on demand when a few seconds of staleness is fine
    ([WebSockets guide](https://vercel.com/kb/guide/do-vercel-serverless-functions-support-websocket-connections)). On Vercel, WebSockets
    are in public beta on Fluid compute, and Next.js needs `experimental_upgradeWebSocket()` from `@vercel/functions` in a `GET` Route
    Handler ([Vercel WebSockets](https://vercel.com/docs/functions/websockets)). Hosts that run Route Handlers as lambda functions may not
    support WebSockets at all ([BFF guide](https://nextjs.org/docs/app/guides/backend-for-frontend)).
2. **SSE-2** Return `new Response(stream)` from a `route.ts` handler, where `stream` is a Web `ReadableStream` you build. Next.js documents
    raw streaming from Route Handlers with the Web Streams API and calls it useful for Server-Sent Events
    ([route.js](https://nextjs.org/docs/app/api-reference/file-conventions/route),
    [Streaming guide](https://nextjs.org/docs/app/guides/streaming)).
3. **SSE-3** Set `Content-Type: text/event-stream` exactly. `EventSource` fails the connection, and never reconnects, when the status isn't
    200 or the type is anything else ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events),
    [WHATWG](https://html.spec.whatwg.org/multipage/server-sent-events.html)).
4. **SSE-4** Send `Cache-Control: no-cache, no-transform`. MDN's SSE server example sends `no-cache`, and `no-transform` tells every
    intermediary not to transform the body
    ([MDN Cache-Control](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cache-Control)) (convention).
5. **SSE-5** Never set `Connection` or `Keep-Alive` response headers. HTTP/2 and HTTP/3 prohibit them, and Safari doesn't load an HTTP/2
    response that carries them ([MDN Connection](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Connection)).
6. **SSE-6** Authenticate and authorize before you construct the stream, and return 401 or 403 as a plain response, because you cannot
    change the status code or headers once streaming starts ([Auth guide](https://nextjs.org/docs/app/guides/authentication),
    [Streaming guide](https://nextjs.org/docs/app/guides/streaming)). `EventSource` doesn't retry a non-200 answer (SSE-3). Implement the
    session check as described in [route-handlers-and-apis.md](route-handlers-and-apis.md).
7. **SSE-7** Authenticate `EventSource` with cookies: `withCredentials` is its only option, so it can't send an `Authorization` header. A
    same-origin request sends cookies by default. A cross-origin one needs `withCredentials: true`, an explicit
    `Access-Control-Allow-Origin` (never `*`) and `Access-Control-Allow-Credentials: true`
    ([WHATWG](https://html.spec.whatwg.org/multipage/server-sent-events.html),
    [WHATWG fetching](https://html.spec.whatwg.org/multipage/urls-and-fetching.html),
    [MDN EventSource()](https://developer.mozilla.org/en-US/docs/Web/API/EventSource/EventSource),
    [MDN CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS)).
8. **SSE-8** Keep the SSE `GET` handler request-time:
    - read runtime data (`cookies()`, `headers()`, `request.headers`) or `await connection()` before streaming;
    - never export `dynamic = 'force-static'`;
    - with Cache Components on, don't wrap those reads in a `try/catch` that swallows the prerender bail-out, because the bail-out is
      thrown.

    Sources: [Route Handlers](https://nextjs.org/docs/app/getting-started/route-handlers),
    [connection](https://nextjs.org/docs/app/api-reference/functions/connection),
    [Migrating to Cache Components](https://nextjs.org/docs/app/guides/migrating-to-cache-components).
9. **SSE-9** Run SSE routes on the default Node.js runtime and don't export `runtime = 'edge'`. nextjs.org marks the Edge Runtime
    deprecated, Cache Components requires Node.js, Vercel's request cancellation is Node.js-only, and Vercel's Functions API reference says
    that starting in Next.js 16.3 `runtime = 'edge'` is no longer supported. Sources:
    [runtime](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/runtime),
    [Edge Runtime deprecated](https://nextjs.org/docs/messages/edge-runtime-deprecated),
    [cacheComponents](https://nextjs.org/docs/app/api-reference/config/next-config-js/cacheComponents),
    [Functions API reference](https://vercel.com/docs/functions/functions-api-reference),
    [Vercel Edge runtime](https://vercel.com/docs/functions/runtimes/edge).
10. **SSE-10** Write each event as `id:`, `event:` and `data:` lines, each ended by LF, followed by one blank line. Split multi-line data
    into one `data:` line per line, keep CR and LF out of `id` and `event`, and never put NULL in `id`
    ([WHATWG](https://html.spec.whatwg.org/multipage/server-sent-events.html)).
11. **SSE-11** Enqueue bytes, not strings. Encode every frame with one module-level `TextEncoder`, as the Next.js examples do, or pipe a
    string stream through `TextEncoderStream` ([route.js](https://nextjs.org/docs/app/api-reference/file-conventions/route),
    [MDN TextEncoderStream](https://developer.mozilla.org/en-US/docs/Web/API/TextEncoderStream)).
12. **SSE-12** Send `retry: <ms>` once at the start of the stream to set the client's reconnection delay. The value must be ASCII digits
    only, otherwise the client ignores the field ([WHATWG](https://html.spec.whatwg.org/multipage/server-sent-events.html)).
13. **SSE-13** Send a comment heartbeat (`: heartbeat`) about every 15 seconds while the stream is idle. The spec suggests it for proxies
    that drop idle connections, and Vercel says HTTP/1.1 clients and intermediaries may still close idle long-running responses
    ([WHATWG](https://html.spec.whatwg.org/multipage/server-sent-events.html),
    [Vercel duration](https://vercel.com/docs/functions/configuring-functions/duration)).
14. **SSE-14** Report a failure that happens after streaming has started as an `event: stream-error` frame, then close, because the HTTP
    status can no longer change. Don't name the frame `error`: `EventSource` fires its own `error` event for connection failures, and the
    spec accepts any event name ([Streaming guide](https://nextjs.org/docs/app/guides/streaming),
    [WHATWG](https://html.spec.whatwg.org/multipage/server-sent-events.html),
    [MDN EventSource](https://developer.mozilla.org/en-US/docs/Web/API/EventSource)) (convention).
15. **SSE-15** Release every timer, subscription and upstream request in one idempotent `release()`. Run it on `request.signal`'s `abort`
    event **and** in the stream's `cancel()`, and stop calling `controller.enqueue` once released, because it throws a `TypeError` on a
    closed or cancelled stream ([MDN Request.signal](https://developer.mozilla.org/en-US/docs/Web/API/Request/signal),
    [MDN ReadableStream()](https://developer.mozilla.org/en-US/docs/Web/API/ReadableStream/ReadableStream),
    [MDN enqueue](https://developer.mozilla.org/en-US/docs/Web/API/ReadableStreamDefaultController/enqueue)).
16. **SSE-16** On Vercel, opt each SSE route into `"supportsCancellation": true` in `vercel.json`, so `request.signal` fires when the client
    disconnects. Put anything that must still finish in `after()` or `waitUntil()`, because work outside them is lost on cancellation
    ([Functions API reference](https://vercel.com/docs/functions/functions-api-reference),
    [vercel.json](https://vercel.com/docs/project-configuration/vercel-json),
    [after](https://nextjs.org/docs/app/api-reference/functions/after),
    [per-path cancellation](https://vercel.com/changelog/node-js-vercel-functions-now-support-per-path-request-cancellation)).
17. **SSE-17** Pass `request.signal` to every upstream `fetch` and to the AI SDK's `abortSignal`, so a disconnect stops upstream work too
    ([Functions API reference](https://vercel.com/docs/functions/functions-api-reference),
    [cancellation changelog](https://vercel.com/changelog/node-js-vercel-functions-now-support-request-cancellation)).
18. **SSE-18** Bound every stream with your own timer that calls `controller.close()` a few seconds before `maxDuration`. A cleanly ended
    stream makes `EventSource` reconnect with `Last-Event-ID` (SSE-23), while Vercel terminates a function that overruns, and that includes
    time spent streaming ([Vercel limits](https://vercel.com/docs/functions/limitations),
    [Vercel duration](https://vercel.com/docs/functions/configuring-functions/duration)) (convention).
19. **SSE-19** Produce data in `pull()` when the source can wait, such as async iterators, LLM tokens or paged queries. The stream then asks
    for more only as the consumer reads, which is backpressure. For push sources, check `controller.desiredSize` before enqueueing, because
    zero or negative means the queue is full ([Vercel backpressure guide](https://vercel.com/kb/guide/handling-backpressure),
    [MDN desiredSize](https://developer.mozilla.org/en-US/docs/Web/API/ReadableStreamDefaultController/desiredSize),
    [MDN AsyncGenerator.return()](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/AsyncGenerator/return)).
20. **SSE-20** Give every event a monotonic `id:` and resume from it:
    - read `Last-Event-ID`, which `EventSource` sends on automatic reconnects;
    - fall back to a `lastEventId` query parameter, because a brand-new `EventSource` starts with an empty last event ID;
    - replay newer events from a durable log;
    - make client handling idempotent by id.

    Sources: [WHATWG](https://html.spec.whatwg.org/multipage/server-sent-events.html),
    [realtime pub/sub guide](https://vercel.com/kb/guide/publish-and-subscribe-to-realtime-data-on-vercel).
21. **SSE-21** Keep subscriptions and history in an external store, for example Redis from the Vercel Marketplace, never in module-level
    variables. Share one upstream subscription per function instance rather than one per client, because Route Handlers can't share data
    between requests and instances don't share memory ([BFF guide](https://nextjs.org/docs/app/guides/backend-for-frontend),
    [Vercel limits](https://vercel.com/docs/functions/limitations)).
22. **SSE-22** Export `maxDuration` from the SSE route file and keep it within your plan's maximum. With Fluid compute that's 300 s on Hobby
    and 800 s on Pro and Enterprise (1800 s extended, beta). See the table in Patterns
    ([maxDuration](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/maxDuration),
    [Vercel duration](https://vercel.com/docs/functions/configuring-functions/duration),
    [Fluid compute](https://vercel.com/docs/fluid-compute)).
23. **SSE-23** Design every client to reconnect:
    - `EventSource` reconnects on its own after the `retry:` delay and sends `Last-Event-ID`;
    - a `fetch` reader must reconnect itself, with backoff, and send the last id it saw.

    Sources: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events),
    [WHATWG](https://html.spec.whatwg.org/multipage/server-sent-events.html).
24. **SSE-24** Open `EventSource` in a Client Component's `useEffect` and return `() => source.close()`. Read callbacks through
    `useEffectEvent`, so new props don't reconnect. Expect two things:
    - in Strict Mode, an extra connect and close during development only;
    - a close and reopen when Cache Components hides a route with `<Activity>`.

    Sources: [useEffect](https://react.dev/reference/react/useEffect), [useEffectEvent](https://react.dev/reference/react/useEffectEvent),
    [Preserving UI state](https://nextjs.org/docs/app/guides/preserving-ui-state),
    [upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16).
25. **SSE-25** Listen for named events with `addEventListener(name, …)`, because `onmessage` only receives events without an `event:` field.
    Validate each `data` payload before use ([MDN EventSource](https://developer.mozilla.org/en-US/docs/Web/API/EventSource)).
26. **SSE-26** Share one `EventSource` per stream URL per tab, for example through a provider in a shared layout. Without HTTP/2, browsers
    allow only 6 connections per browser and domain
    ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events)).
27. **SSE-27** Use `fetch` plus `response.body.getReader()` when you need POST, a request body or custom headers, because `EventSource` can
    only make a GET with `withCredentials` as its one option (SSE-7). Decode with `TextDecoder` and `{ stream: true }`, and split frames on
    blank lines ([MDN reader.read()](https://developer.mozilla.org/en-US/docs/Web/API/ReadableStreamDefaultReader/read),
    [MDN TextDecoder.decode()](https://developer.mozilla.org/en-US/docs/Web/API/TextDecoder/decode)).
28. **SSE-28** End a stream for good by calling `source.close()` on the client, or by answering the reconnect with `204 No Content`. A
    server-side `controller.close()` on its own only triggers a reconnect
    ([WHATWG](https://html.spec.whatwg.org/multipage/server-sent-events.html)).
29. **SSE-29** Stream LLM output with the AI SDK, as Vercel recommends. Forward `request.signal` as `abortSignal`, export `maxDuration`, and
    read the response with `fetch` plus `getReader()`, not `EventSource`, because chat routes take a `POST` body
    ([Vercel streaming](https://vercel.com/docs/functions/streaming-functions),
    [AI Gateway and AI SDK guide](https://vercel.com/kb/guide/ai-gateway-and-ai-sdk)).

## Patterns

Paths follow the canonical layout in [../nextjs.md](../nextjs.md): `@/` is `src/`.

### Wire format

One event per block: `id:`, `event:` and `data:` lines, then a blank line (SSE-10). A line that starts with a colon is a comment the client
ignores, which makes it a safe heartbeat (SSE-13). A `retry:` block with no `data:` dispatches nothing (SSE-12).

```text
retry: 3000

: heartbeat

id: 42
event: order.updated
data: {"orderId":"o_1","status":"shipped"}

```

### Frame encoder

Keep the wire format in one module, so no route writes frames by hand (SSE-10, SSE-12, SSE-13).

```ts
// src/shared/utils/sse.ts — encode frames in the WHATWG event-stream format
export type SseEvent = { data: string; event?: string; id?: string }

const LINE_BREAK = /\r\n|\r|\n/
const NOT_ALLOWED_IN_FIELD = /[\r\n\0]/

function assertSingleLine(label: string, value: string): void {
  if (NOT_ALLOWED_IN_FIELD.test(value)) {
    throw new Error(`SSE ${label} must be one line without NULL`)
  }
}

export function sseEvent({ data, event, id }: SseEvent): string {
  if (id !== undefined) assertSingleLine('id', id)
  if (event !== undefined) assertSingleLine('event', event)
  const lines = [
    ...(id === undefined ? [] : [`id: ${id}`]),
    ...(event === undefined ? [] : [`event: ${event}`]),
    ...data.split(LINE_BREAK).map((line) => `data: ${line}`),
  ]
  return `${lines.join('\n')}\n\n`
}

export function sseRetry(milliseconds: number): string {
  if (!Number.isInteger(milliseconds) || milliseconds < 0) {
    throw new RangeError('SSE retry must be a non-negative integer')
  }
  return `retry: ${milliseconds}\n\n`
}

export function sseComment(text: string): string {
  assertSingleLine('comment', text)
  return `: ${text}\n\n`
}
```

### Store contract

The route needs a live subscription and a durable log (SSE-20, SSE-21). Back both with an external store such as Redis, never with module
state. This file is a contract only.

```ts
// src/lib/realtime.ts — contract only; back it with an external store such as Redis
export type FeedEvent = { id: string; type: string; payload: unknown }

/** Subscribe to live events; resolves to an unsubscribe function. One upstream subscription per instance. */
export declare function subscribe(
  userId: string,
  onEvent: (event: FeedEvent) => void,
): Promise<() => Promise<void>>

/** Events newer than `lastEventId` from the durable log (all recent events when it is null). */
export declare function replaySince(userId: string, lastEventId: string | null): Promise<FeedEvent[]>
```

### The SSE Route Handler

Auth: `verifySession()` follows [route-handlers-and-apis.md](route-handlers-and-apis.md). "Complete" means this file plus the encoder it
imports.

```ts
// src/app/api/events/route.ts
import { verifySession } from '@/lib/auth' // returns { userId: string } | null; see route-handlers-and-apis.md
import { replaySince, subscribe, type FeedEvent } from '@/lib/realtime'
import { sseComment, sseEvent, sseRetry } from '@/shared/utils/sse'

export const maxDuration = 300 // seconds; never above your plan's maximum

const HEARTBEAT_MS = 15_000
const RETRY_MS = 3_000
const END_EARLY_MS = 10_000
const encoder = new TextEncoder()

export async function GET(request: Request): Promise<Response> {
  const session = await verifySession() // reads cookies(): request-time, never prerendered
  if (!session) return new Response(null, { status: 401 })

  const lastEventId =
    request.headers.get('Last-Event-ID') ?? new URL(request.url).searchParams.get('lastEventId')

  let isReleased = false
  let heartbeat: ReturnType<typeof setInterval> | undefined
  let deadline: ReturnType<typeof setTimeout> | undefined
  let unsubscribe: (() => Promise<void>) | undefined

  // One idempotent release, shared by abort, cancel(), the deadline and failures.
  const release = (): void => {
    if (isReleased) return
    isReleased = true
    clearInterval(heartbeat)
    clearTimeout(deadline)
    unsubscribe?.().catch((error: unknown) => console.error('SSE unsubscribe failed', error))
  }

  const stream = new ReadableStream<Uint8Array>({
    async start(controller) {
      const send = (chunk: string): void => {
        if (!isReleased) controller.enqueue(encoder.encode(chunk))
      }
      const write = (event: FeedEvent): void =>
        send(sseEvent({ id: event.id, event: event.type, data: JSON.stringify(event.payload) }))
      const end = (): void => {
        if (isReleased) return
        release()
        controller.close() // clean end: EventSource reconnects with Last-Event-ID
      }

      if (request.signal.aborted) return end()
      request.signal.addEventListener('abort', end, { once: true })
      send(sseRetry(RETRY_MS))
      heartbeat = setInterval(() => send(sseComment('heartbeat')), HEARTBEAT_MS)
      deadline = setTimeout(end, maxDuration * 1_000 - END_EARLY_MS)

      try {
        const stop = await subscribe(session.userId, write) // subscribe first: no gap before replay
        if (isReleased) {
          await stop() // the client left while we were subscribing
          return
        }
        unsubscribe = stop
        for (const event of await replaySince(session.userId, lastEventId)) write(event)
      } catch (error: unknown) {
        console.error('SSE stream failed', error)
        send(sseEvent({ event: 'stream-error', data: JSON.stringify({ message: 'stream failed' }) }))
        end()
      }
    },
    cancel() {
      release()
    },
  })

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      'X-Accel-Buffering': 'no', // nginx-style proxies when self-hosting
    },
  })
}
```

How it meets the rules:

- Cookies are read through `verifySession()` before anything streams, so the route is request-time and a missing session is a plain 401,
  with no `runtime` or `dynamic` export (SSE-6, SSE-8, SSE-9).
- `release()` runs from the `abort` listener, `cancel()`, the deadline and the failure path. It is idempotent, and `send()` checks
  `isReleased`, so nothing enqueues afterwards (SSE-15).
- The deadline closes the stream ten seconds before `maxDuration`, so the client reconnects with `Last-Event-ID` before Vercel terminates
  the function (SSE-18, SSE-22).
- It subscribes before it replays, so no event falls into a gap. A live event can arrive during the replay, so clients must be idempotent by
  id (SSE-20).
- A failure after the first byte becomes a `stream-error` frame, not a status change (SSE-14).
- `X-Accel-Buffering: no` is the header the [Streaming guide](https://nextjs.org/docs/app/guides/streaming) gives for buffering reverse
  proxies. Behaviour on a self-hosted disconnect is unconfirmed (Not confirmed by the docs, item 1), which is why the deadline and both
  release hooks exist.

### Pull-based generated streams

When the source can wait, such as LLM tokens or paged queries, produce the next frame only when the consumer pulls it (SSE-11, SSE-19). This
is the typed form of the `iteratorToStream` example in the [route.js reference](https://nextjs.org/docs/app/api-reference/file-conventions/route),
which types its `iterator` as `any`. Pair it with `request.signal` (SSE-15), because the runtime may not call `cancel()` (Not confirmed by the docs, item 1).

```ts
// src/shared/utils/sse-stream.ts — produce the next frame only when the consumer pulls
import { sseEvent } from '@/shared/utils/sse'

const encoder = new TextEncoder()

export function framesToStream(frames: AsyncGenerator<string, void>): ReadableStream<Uint8Array> {
  return new ReadableStream<Uint8Array>({
    async pull(controller) {
      const { value, done } = await frames.next()
      if (done) {
        controller.close()
      } else {
        controller.enqueue(encoder.encode(value))
      }
    },
    async cancel() {
      await frames.return() // runs the generator's finally blocks
    },
  })
}

export async function* tokenFrames(tokens: AsyncIterable<string>): AsyncGenerator<string, void> {
  let index = 0
  for await (const token of tokens) {
    yield sseEvent({ id: String(index), event: 'token', data: token })
    index += 1
  }
  yield sseEvent({ event: 'done', data: '' })
}
```

### Vercel configuration and limits

Enable cancellation per path (SSE-16). Keys are globs over function source paths, and the
[duration page](https://vercel.com/docs/functions/configuring-functions/duration) shows `app/api/**/*` for the App Router. For a `src/app`
layout, see Not confirmed by the docs, item 9.

```json
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "functions": {
    "app/api/events/**/*": { "supportsCancellation": true },
    "app/api/chat/**/*": { "supportsCancellation": true }
  }
}
```

Function limits as vercel.com shows them on 2026-10-04 (SSE-18, SSE-22):

| Setup on Vercel | Default | Maximum |
| --- | --- | --- |
| Fluid compute (on by default for projects created from April 23, 2025), Hobby | 300s | 300s |
| Fluid compute, Pro | 300s | 800s; 1800s extended max (beta, per function, supported Node.js/Bun/Python runtimes) |
| Fluid compute, Enterprise | 300s | 800s; 1800s extended max (beta) |
| Not using Fluid compute (existing project deployed before April 23, 2025), Hobby | 10s | 60s |
| Not using Fluid compute, Pro | 15s | 300s |
| Not using Fluid compute, Enterprise | 15s | 900s |
| Edge runtime (deprecated in Next.js) | must begin sending a response within 25s | may stream up to 300s |

- The Fluid rows come from the duration page above, the [limits page](https://vercel.com/docs/functions/limitations) and
  [Fluid compute](https://vercel.com/docs/fluid-compute). Values above 800s must be set per function, in code or `vercel.json`. The
  non-Fluid rows come from the [limits overview](https://vercel.com/docs/limits), and the Edge row from the limits page. Function code sets
  `maxDuration` first, then `vercel.json`, then the dashboard, then the Fluid defaults.
- Vercel supports streaming natively ([Streaming guide](https://nextjs.org/docs/app/guides/streaming)). Maximum durations can be configured
  for Node.js functions to enable streaming responses for longer periods
  ([Vercel streaming](https://vercel.com/docs/functions/streaming-functions)).
- The limit includes streamed responses. A function that doesn't complete in time returns 504 `FUNCTION_INVOCATION_TIMEOUT`
  ([504 page](https://vercel.com/docs/errors/function_invocation_timeout)). SSE streams are bounded by the maximum duration, but the browser
  handles reconnection for you
  ([WebSockets guide](https://vercel.com/kb/guide/do-vercel-serverless-functions-support-websocket-connections)).
- Cost: on Fluid compute, an idle connection bills Provisioned Memory but not Active CPU
  ([realtime pub/sub guide](https://vercel.com/kb/guide/publish-and-subscribe-to-realtime-data-on-vercel)).

### Client hook

Open one `EventSource` per URL inside `useEffect` and close it on cleanup (SSE-20, SSE-23 to SSE-26). The browser supplies the `retry:`
delay, automatic reconnection and `Last-Event-ID`. The hook only adds a `lastEventId` query parameter for when React re-runs the effect,
which creates a fresh `EventSource` with an empty last event ID.

```ts
// src/shared/hooks/use-event-source.ts
'use client'

import { useEffect, useEffectEvent, useRef, useState } from 'react'

export type StreamStatus = 'connecting' | 'open' | 'closed'

type Options<T> = {
  url: string
  eventName: string
  parse: (data: string) => T // validate here: JSON.parse plus your schema; throw on bad input
  onEvent: (value: T, eventId: string) => void // idempotent by eventId
}

export function useEventSource<T>({ url, eventName, parse, onEvent }: Options<T>): StreamStatus {
  const [status, setStatus] = useState<StreamStatus>('connecting')
  const lastIdRef = useRef<string | null>(null)

  const handleMessage = useEffectEvent((message: MessageEvent<string>) => {
    try {
      onEvent(parse(message.data), message.lastEventId)
      lastIdRef.current = message.lastEventId || lastIdRef.current
    } catch (error: unknown) {
      console.error(`Rejected "${eventName}" event`, error)
    }
  })

  useEffect(() => {
    // A new EventSource sends no Last-Event-ID, so resume through the query string.
    const target = new URL(url, window.location.href)
    if (lastIdRef.current) target.searchParams.set('lastEventId', lastIdRef.current)
    const source = new EventSource(target)
    source.addEventListener('open', () => setStatus('open'))
    source.addEventListener('error', () => {
      setStatus(source.readyState === EventSource.CLOSED ? 'closed' : 'connecting')
    })
    source.addEventListener(eventName, (message) => handleMessage(message))
    return () => source.close()
  }, [url, eventName])

  return status
}
```

- `'closed'` means the connection failed for good (a non-200 status, the wrong content type or a fatal error), and the browser won't
  reconnect (SSE-3). Offer a retry or a sign-in.
- The effect body sets no state. Status changes come only from events, which keeps it clear of the React hooks lint rule against synchronous
  `setState` in an effect.
- `useEffectEvent` functions are called from inside Effects, here from a listener the Effect creates, and stay out of the dependency list.

### fetch reader for POST or custom headers

Use `fetch` plus `getReader()` when you need a body or headers `EventSource` can't send (SSE-23, SSE-27, SSE-28). `readSse` parses one
response. `readSseWithReconnect` reopens it with backoff and sends the last id it saw. The reader ignores `retry:`, so it keeps its own
delay.

```ts
// src/shared/utils/read-sse.ts — POST, request body or custom headers: fetch + getReader()
export type SseMessage = { event: string; data: string; id: string | undefined }

const NO_CONTENT = 204
const BACKOFF_START_MS = 1_000
const BACKOFF_MAX_MS = 30_000

function parseBlock(block: string): SseMessage | null {
  const fields = block
    .split('\n') // our encoder emits LF only
    .filter((line) => line !== '' && !line.startsWith(':'))
    .map((line): [string, string] => {
      const colon = line.indexOf(':')
      if (colon === -1) return [line, '']
      const value = line.slice(colon + 1)
      return [line.slice(0, colon), value.startsWith(' ') ? value.slice(1) : value]
    })
  const data = fields.filter(([name]) => name === 'data').map(([, value]) => value)
  if (data.length === 0) return null
  const last = (name: string): string | undefined =>
    fields.filter(([field]) => field === name).at(-1)?.[1]
  return { event: last('event') || 'message', data: data.join('\n'), id: last('id') }
}

/** Resolves 'ended' when the server closes the stream, 'stopped' on 204 No Content. */
export async function readSse(
  response: Response,
  onMessage: (message: SseMessage) => void,
): Promise<'ended' | 'stopped'> {
  if (response.status === NO_CONTENT) return 'stopped'
  if (!response.ok || !response.body) throw new Error(`SSE request failed: ${response.status}`)
  const reader = response.body.getReader()
  const decoder = new TextDecoder()
  let buffer = ''
  for (;;) {
    const { value, done } = await reader.read()
    if (done) return 'ended'
    const blocks = (buffer + decoder.decode(value, { stream: true })).split('\n\n')
    buffer = blocks.pop() ?? ''
    for (const block of blocks) {
      const message = parseBlock(block)
      if (message) onMessage(message)
    }
  }
}

type ReconnectOptions = {
  open: (lastEventId: string | undefined, signal: AbortSignal) => Promise<Response>
  onMessage: (message: SseMessage) => void
  signal: AbortSignal
}

function wait(milliseconds: number, signal: AbortSignal): Promise<void> {
  return new Promise((resolve) => {
    const timer = setTimeout(resolve, milliseconds)
    signal.addEventListener('abort', () => { clearTimeout(timer); resolve() }, { once: true })
  })
}

export async function readSseWithReconnect({ open, onMessage, signal }: ReconnectOptions): Promise<void> {
  let lastEventId: string | undefined
  let delay = BACKOFF_START_MS
  while (!signal.aborted) {
    try {
      const response = await open(lastEventId, signal) // POST body or custom headers go here
      const outcome = await readSse(response, (message) => {
        delay = BACKOFF_START_MS
        if (message.id !== undefined) lastEventId = message.id
        onMessage(message)
      })
      if (outcome === 'stopped') return
    } catch (error: unknown) {
      if (signal.aborted) return
      console.error('SSE read failed; reconnecting', error)
    }
    await wait(delay, signal)
    delay = Math.min(delay * 2, BACKOFF_MAX_MS)
  }
}
```

- `parseBlock` mirrors the WHATWG field rules: comment lines are ignored, one leading space is stripped, data lines are joined with LF, the
  type defaults to `message`, and a block with no data dispatches nothing. A partial block left in the buffer when the stream ends is
  dropped, as the spec drops an incomplete event ([WHATWG](https://html.spec.whatwg.org/multipage/server-sent-events.html)).
- The backoff starts at one second, doubles and caps at 30 seconds, the shape the WebSockets guide uses for its reconnecting client (SSE-23).
- Abort the `signal` when the component unmounts or the user stops. The loop exits, and on Vercel with cancellation enabled the server sees
  `request.signal` fire (SSE-15, SSE-16).

### AI SDK on Vercel

Vercel recommends the AI SDK for LLM streams (SSE-29). The names below are as vercel.com shows them, and they differ by AI SDK major, so
match your installed `ai` version (Not confirmed by the docs, item 8). `toTextStreamResponse()` returns text chunks. Read them with `fetch`
plus `getReader()`, as in the previous section, and don't use `EventSource`, because the route takes a POST.

```ts
// src/app/api/chat/route.ts
import { streamText } from 'ai'
import { verifySession } from '@/lib/auth'

export const maxDuration = 300

function readPrompt(body: unknown): string | null {
  if (typeof body !== 'object' || body === null || !('prompt' in body)) return null
  return typeof body.prompt === 'string' && body.prompt.length > 0 ? body.prompt : null
}

export async function POST(request: Request): Promise<Response> {
  if (!(await verifySession())) return new Response(null, { status: 401 })
  const prompt = readPrompt(await request.json().catch(() => null))
  if (prompt === null) return Response.json({ error: 'prompt is required' }, { status: 400 })

  const result = streamText({
    model: 'openai/gpt-4o-mini',
    prompt,
    abortSignal: request.signal, // stop generating when the client disconnects
  })
  return result.toTextStreamResponse()
}
```

Fuller input validation (a schema) belongs to [route-handlers-and-apis.md](route-handlers-and-apis.md).

## Anti-patterns

### Don't start a heartbeat or subscription with no release path (SSE-15)

```ts
start(controller) {
  setInterval(() => controller.enqueue(ping), 15_000) // never cleared: leaks after the client leaves
},
```

**Do** run one `release()` from both `request.signal` `abort` and `cancel()`, and clear every timer in it.

```ts
const release = (): void => {
  if (isReleased) return
  isReleased = true
  clearInterval(heartbeat)
  unsubscribe?.().catch((error: unknown) => console.error('unsubscribe failed', error))
}
request.signal.addEventListener('abort', release, { once: true }) // and cancel() { release() }
```

### Don't fan out through a module-level listener set (SSE-21)

```ts
export const listeners = new Set<(event: FeedEvent) => void>() // each instance has its own copy
```

**Do** subscribe to the external store, one upstream subscription per instance.

```ts
const stop = await subscribe(session.userId, write) // src/lib/realtime.ts, backed by Redis
```

### Don't pass headers to `EventSource` or put a bearer token in its URL (SSE-7)

```ts
// EventSourceInit only has withCredentials; a token in the URL also lands in logs (convention)
new EventSource(`/api/events?token=${token}`)
```

**Do** use the session cookie. Same-origin needs no option, and cross-origin needs `withCredentials`
plus explicit CORS headers on the server.

```ts
const sameOrigin = new EventSource('/api/events')
const crossOrigin = new EventSource('https://api.example.com/events', { withCredentials: true })
```

### Don't decide the status after the stream has started, or throw mid-stream (SSE-6, SSE-14)

```ts
const response = new Response(stream)
if (!session) controller.error(new Error('unauthorized')) // too late: the status is already 200
```

**Do** return 401 before building the stream, and report later failures as a frame, then close.

```ts
if (!session) return new Response(null, { status: 401 })
send(sseEvent({ event: 'stream-error', data: JSON.stringify({ message: 'stream failed' }) }))
controller.close()
```

## Version notes

Next.js 16 (this file is verified against 16.3.8). Each bullet links its source.

- **Route Handler streaming is unchanged in Next.js 16.** The route.js version history has no 16.x entry. The latest rows are v15.0.0-RC:
  `GET` handlers changed from static to dynamic by default, and `context.params` became a promise. The v16 upgrade guide lists no Route
  Handler streaming change ([route.js](https://nextjs.org/docs/app/api-reference/file-conventions/route),
  [upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16)).
- **Cache Components arrive in Next.js 16.** Dynamic code runs at request time by default ([Next.js 16](https://nextjs.org/blog/next-16)).
  With the flag on, `GET` handlers can be prerendered when they read no runtime data, and route segment configs such as `dynamic`,
  `revalidate` and `fetchCache` give way to `use cache` and `cacheLife`, so a route that still exports them errors
  ([Migrating to Cache Components](https://nextjs.org/docs/app/guides/migrating-to-cache-components),
  [route segment config](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config)) (SSE-8).
- **Edge Runtime is deprecated.** The 16.3.8 docs mark `runtime = 'edge'` deprecated, and Proxy doesn't support Edge
  ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16)) (SSE-9).
- **React 19.2 in the App Router.** `useEffectEvent` and `<Activity>` arrive
  ([upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16)). With Cache Components, routes are hidden with Activity, and
  Effects clean up and re-run (SSE-24).
- **Vercel platform, not versioned with Next.js.** Fluid compute has been on by default for new projects since April 23, 2025, and per-path
  request cancellation was announced on September 26, 2025 ([Fluid compute](https://vercel.com/docs/fluid-compute),
  [changelog](https://vercel.com/changelog/node-js-vercel-functions-now-support-per-path-request-cancellation)). WebSockets entered public
  beta on June 22, 2026.

## Review checklist

- [ ] Auth runs before the stream exists, and failures return 401 or 403 (SSE-6, SSE-7).
- [ ] Headers are exactly `text/event-stream` and `Cache-Control: no-cache, no-transform`, with no `Connection` or `Keep-Alive` (SSE-3, SSE-4, SSE-5).
- [ ] No `runtime = 'edge'` and no `force-static`, and the handler reads runtime data (SSE-8, SSE-9).
- [ ] Frames are `id:`/`event:`/`data:` lines plus a blank line, with single-line ids and event names, written as bytes through `TextEncoder` (SSE-10, SSE-11).
- [ ] `retry:` is sent once and a heartbeat comment goes out about every 15 s (SSE-12, SSE-13).
- [ ] Failures after the first byte go out as a named frame, not `error`, and then the stream closes (SSE-14).
- [ ] One idempotent `release()` runs from `abort` and `cancel()`, with no `enqueue` after release (SSE-15).
- [ ] On Vercel, `supportsCancellation` is set and must-finish work sits in `after` or `waitUntil` (SSE-16).
- [ ] `request.signal` is forwarded to upstream `fetch` and to `abortSignal` (SSE-17, SSE-29).
- [ ] `maxDuration` is exported within the plan maximum, and the stream closes itself before it (SSE-18, SSE-22).
- [ ] Pausable producers use `pull()`, and push sources respect `desiredSize` (SSE-19).
- [ ] Every event has an id, and the server resumes from `Last-Event-ID` or `lastEventId` (SSE-20).
- [ ] No module-level pub/sub, and one upstream subscription per instance (SSE-21).
- [ ] The client opens `EventSource` in `useEffect` with `close()` cleanup, named listeners, validated payloads and one source per URL per tab (SSE-24, SSE-25, SSE-26).
- [ ] POST or custom-header streams use `fetch` plus `getReader()` with an `AbortController` and reconnect logic, and a stream that should stop for good ends with `close()` or 204 (SSE-23, SSE-27, SSE-28).

## Not confirmed by the docs

Each item names what was checked and the URL checked. Nothing here is stated as a rule.

1. **Self-hosted disconnects.** No nextjs.org page says whether `request.signal` aborts, or whether Next.js calls the response stream's
    `cancel()`, when the client disconnects under `next start` or `next dev`. Checked:
    [route.js](https://nextjs.org/docs/app/api-reference/file-conventions/route),
    [Route Handlers](https://nextjs.org/docs/app/getting-started/route-handlers),
    [Streaming guide](https://nextjs.org/docs/app/guides/streaming), [Self-hosting](https://nextjs.org/docs/app/guides/self-hosting).
    vercel.com documents the abort only on Vercel with `supportsCancellation`
    ([Functions API reference](https://vercel.com/docs/functions/functions-api-reference)), so the examples wire both hooks.
2. **What the client sees at max duration.** No page says what arrives when Vercel ends a stream that already sent 200: a dropped
    connection, or bytes. The 504 is documented for functions that don't complete. Checked: [limits page](https://vercel.com/docs/functions/limitations),
    [duration page](https://vercel.com/docs/functions/configuring-functions/duration).
3. **`maxDuration` under `next start`.** The page only says deployment platforms can use it. Checked: [maxDuration](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/maxDuration).
4. **Compression and `text/event-stream`.** The docs don't say whether Next.js's built-in gzip buffers an event stream under `next start`,
    only that compression can buffer chunks. Checked: [compress](https://nextjs.org/docs/app/api-reference/config/next-config-js/compress).
5. **Safari's 1024-byte buffer and `EventSource`.** The Streaming guide says Safari and WebKit buffer streaming responses until 1024 bytes
    have arrived. It doesn't say whether that applies to an `EventSource` connection, so a very small first event may be delayed there.
    Checked: [Streaming guide](https://nextjs.org/docs/app/guides/streaming).
6. **`charset` on the Content-Type.** It's unconfirmed whether `text/event-stream; charset=utf-8` passes the `EventSource` type check. The
    spec text compares against `text/event-stream`, so the examples use the bare value. Checked: [WHATWG](https://html.spec.whatwg.org/multipage/server-sent-events.html).
7. **`no-transform` on Vercel's CDN.** No page says what it changes there. Checked: [Vercel streaming](https://vercel.com/docs/functions/streaming-functions).
8. **The AI text stream body.** vercel.com's example labels `toTextStreamResponse()` output `text/event-stream`, but no allowed page says
    the body is SSE-framed, and route.js still shows `StreamingTextResponse`, so the chat route is read with `fetch`. Which API matches a
    given `ai` major isn't confirmed either. Checked: [Vercel streaming](https://vercel.com/docs/functions/streaming-functions),
    [AI Gateway and AI SDK guide](https://vercel.com/kb/guide/ai-gateway-and-ai-sdk).
9. **`vercel.json` keys for a `src/app` layout.** The duration page says a project that uses a `src` directory must prefix function routes
    with `/src/`, and shows `app/api/**/*` for the App Router, but gives no complete `src/app` key. Checked:
    [vercel.json](https://vercel.com/docs/project-configuration/vercel-json).
10. **When Edge was deprecated.** nextjs.org marks `'edge'` deprecated without naming the release, while vercel.com says it's no longer
    supported from Next.js 16.3, and the docs don't reconcile the two words. This file only says to remove it. Checked:
    [runtime](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/runtime),
    [Edge Runtime deprecated](https://nextjs.org/docs/messages/edge-runtime-deprecated).
11. **`after()` and streams.** It isn't stated whether an `after()` callback runs when a streamed body finishes or when the handler returns.
    The page says after the response is finished. Checked: [after](https://nextjs.org/docs/app/api-reference/functions/after).

## Sources

- https://nextjs.org/docs/app/api-reference/file-conventions/route — route.js reference, Streaming section
- https://nextjs.org/docs/app/getting-started/route-handlers — Route Handlers, caching and Cache Components
- https://nextjs.org/docs/app/guides/streaming — streaming guide, Route Handlers, HTTP contract, buffering
- https://nextjs.org/docs/app/guides/self-hosting — self-hosting guide
- https://nextjs.org/docs/app/guides/backend-for-frontend — Route Handlers as a backend, deployment caveats
- https://nextjs.org/docs/app/guides/authentication — authentication, Route Handlers section
- https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config — route segment config
- https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/runtime — runtime option
- https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/maxDuration — maxDuration option
- https://nextjs.org/docs/app/api-reference/functions/connection — connection()
- https://nextjs.org/docs/app/api-reference/config/next-config-js/cacheComponents — cacheComponents option
- https://nextjs.org/docs/app/guides/migrating-to-cache-components — migrating to Cache Components
- https://nextjs.org/docs/app/guides/preserving-ui-state — preserving UI state with Activity
- https://nextjs.org/docs/app/api-reference/functions/after — after()
- https://nextjs.org/docs/app/api-reference/config/next-config-js/compress — compress option
- https://nextjs.org/docs/app/guides/upgrading/version-16 — upgrade guide to version 16
- https://nextjs.org/docs/messages/edge-runtime-deprecated — Edge Runtime deprecated
- https://nextjs.org/blog/next-16 — Next.js 16 release post
- https://vercel.com/docs/functions/streaming-functions — Vercel streaming
- https://vercel.com/docs/functions/configuring-functions/duration — maximum duration
- https://vercel.com/docs/functions/limitations — Vercel Functions limits
- https://vercel.com/docs/limits — Vercel limits overview, non-Fluid durations
- https://vercel.com/docs/fluid-compute — Fluid compute
- https://vercel.com/docs/errors/function_invocation_timeout — 504 FUNCTION_INVOCATION_TIMEOUT
- https://vercel.com/docs/functions/functions-api-reference — Functions API reference, cancel requests
- https://vercel.com/docs/project-configuration/vercel-json — vercel.json functions
- https://vercel.com/docs/functions/runtimes/edge — Vercel Edge runtime
- https://vercel.com/docs/functions/websockets — Vercel WebSockets
- https://vercel.com/kb/guide/do-vercel-serverless-functions-support-websocket-connections — WebSockets guide
- https://vercel.com/kb/guide/publish-and-subscribe-to-realtime-data-on-vercel — realtime pub/sub guide
- https://vercel.com/kb/guide/handling-backpressure — handling backpressure
- https://vercel.com/changelog/node-js-vercel-functions-now-support-request-cancellation — request cancellation changelog
- https://vercel.com/changelog/node-js-vercel-functions-now-support-per-path-request-cancellation — per-path cancellation changelog
- https://vercel.com/kb/guide/ai-gateway-and-ai-sdk — AI Gateway and AI SDK guide
- https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events — using server-sent events
- https://developer.mozilla.org/en-US/docs/Web/API/EventSource — EventSource
- https://developer.mozilla.org/en-US/docs/Web/API/EventSource/EventSource — EventSource() constructor
- https://developer.mozilla.org/en-US/docs/Web/API/ReadableStream/ReadableStream — ReadableStream() constructor
- https://developer.mozilla.org/en-US/docs/Web/API/ReadableStreamDefaultController/enqueue — controller enqueue()
- https://developer.mozilla.org/en-US/docs/Web/API/ReadableStreamDefaultController/desiredSize — controller desiredSize
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/AsyncGenerator/return — AsyncGenerator return()
- https://developer.mozilla.org/en-US/docs/Web/API/Request/signal — Request signal
- https://developer.mozilla.org/en-US/docs/Web/API/TextEncoderStream — TextEncoderStream
- https://developer.mozilla.org/en-US/docs/Web/API/TextDecoder/decode — TextDecoder decode()
- https://developer.mozilla.org/en-US/docs/Web/API/ReadableStreamDefaultReader/read — reader read()
- https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cache-Control — Cache-Control header
- https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Connection — Connection header
- https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS — CORS
- https://html.spec.whatwg.org/multipage/server-sent-events.html — WHATWG server-sent events
- https://html.spec.whatwg.org/multipage/urls-and-fetching.html — WHATWG URLs and fetching
- https://react.dev/reference/react/useEffect — useEffect
- https://react.dev/reference/react/useEffectEvent — useEffectEvent
