// Runs the sse-and-streaming.md snippets (extracted to out/<SSE_LABEL>) under Node and checks each
// REVIEW① finding. Usage: SSE_LABEL=before node --import ./loader.mjs harness.mjs
import assert from 'node:assert/strict'
import { getEventListeners } from 'node:events'
import { readFileSync } from 'node:fs'
import { join, matchesGlob } from 'node:path'
import { createElement } from 'react'
import TestRenderer, { act } from 'react-test-renderer'
import redirectError from 'next/dist/client/components/redirect-error.js'
import redirectHelpers from 'next/dist/client/components/redirect.js'
import { sessionBox } from './stubs/dal.ts'
import { afterTasks } from './stubs/next-server.ts'
import { publish, reset, store } from './stubs/realtime.ts'

const label = process.env.SSE_LABEL
const root = join(import.meta.dirname, 'out', label)
const SESSION = { userId: 'u1', role: 'user' }
const realSetTimeout = globalThis.setTimeout
const sleep = (ms) => new Promise((resolve) => realSetTimeout(resolve, ms))
const encoder = new TextEncoder()
const logged = []
console.error = (...args) => logged.push(args.map(String).join(' '))

const events = await import('@/app/api/events/route')
const chat = await import('@/app/api/chat/route')
const readSseModule = await import('@/shared/utils/read-sse')
const sseStream = await import('@/shared/utils/sse-stream')
const { useEventSource } = await import('@/shared/hooks/use-event-source')

async function until(condition, ms = 2000) {
  const start = performance.now()
  while (!condition()) {
    if (performance.now() - start > ms) throw new Error('timed out waiting')
    await sleep(1)
  }
}

/** What Next's app-route module does with a thrown redirect (module.js ~line 486): a 307 response. */
async function callRoute(run) {
  try {
    return await run()
  } catch (error) {
    if (!redirectError.isRedirectError(error)) throw error
    const location = redirectHelpers.getURLFromRedirectError(error)
    const status = redirectHelpers.getRedirectStatusCodeFromError(error)
    return new Response(null, { status, headers: { Location: location } })
  }
}

async function readAll(response) {
  return new Response(response.body).text()
}

const ev = (id, payload = { n: id }) => ({ id: String(id), type: 'feed', payload })
const ids = (text) => [...text.matchAll(/^id: (.+)$/gm)].map((match) => match[1])

/** Scale every setTimeout delay by 1/100 while `run` executes, so backoff tests take milliseconds. */
async function withFastTimers(run) {
  globalThis.setTimeout = (fn, ms, ...rest) => realSetTimeout(fn, (ms ?? 0) / 100, ...rest)
  try {
    return await run()
  } finally {
    globalThis.setTimeout = realSetTimeout
  }
}

const results = []
async function check(id, name, run) {
  try {
    results.push({ id, name, ok: true, detail: await run() })
  } catch (error) {
    results.push({ id, name, ok: false, detail: error.message.split('\n')[0] })
  }
}

// --- R1-C1 / R1-C9 -------------------------------------------------------------------------
await check('R1-C1', 'signed-out SSE GET and chat POST answer 401 (not a 307 to /login)', async () => {
  sessionBox.current = null
  try {
    const sse = await callRoute(() => events.GET(new Request('https://app.test/api/events')))
    const post = await callRoute(() =>
      chat.POST(new Request('https://app.test/api/chat', { method: 'POST', body: '{"prompt":"hi"}' })),
    )
    const describe = (r) => `${r.status}${r.headers.get('location') ? ` -> ${r.headers.get('location')}` : ''}`
    assert.ok(sse.status === 401 && post.status === 401, `GET ${describe(sse)}, POST ${describe(post)}`)
    return `GET ${describe(sse)}, POST ${describe(post)}`
  } finally {
    sessionBox.current = SESSION
  }
})

// --- R1-C2 ---------------------------------------------------------------------------------
async function replayRun(snapshotAfterGate) {
  reset()
  store.snapshotAfterGate = snapshotAfterGate
  store.log.push(ev(98), ev(99), ev(100))
  let openGate = () => {}
  store.replayGate = new Promise((resolve) => {
    openGate = resolve
  })
  const controller = new AbortController()
  const request = new Request('https://app.test/api/events', {
    headers: { 'Last-Event-ID': '97' },
    signal: controller.signal,
  })
  const response = await events.GET(request)
  const text = readAll(response)
  try {
    await until(() => store.listeners.size === 1)
    publish(ev(101)) // live event while replaySince is still pending
    openGate()
    await sleep(20)
  } finally {
    controller.abort()
  }
  return ids(await text)
}
await check('R1-C2', 'replayed ids precede live ids, each id once', async () => {
  const early = await replayRun(false)
  const late = await replayRun(true)
  const expected = ['98', '99', '100', '101']
  assert.ok(
    JSON.stringify(early) === JSON.stringify(expected) && JSON.stringify(late) === JSON.stringify(expected),
    `snapshot-before-live ${early.join(',')}; snapshot-after-live ${late.join(',')}; want ${expected.join(',')}`,
  )
  return `both orders ${early.join(',')}`
})

// --- R1-C10 --------------------------------------------------------------------------------
await check('R1-C10', 'a client that never reads cannot grow the queue without bound', async () => {
  reset()
  const controller = new AbortController()
  const response = await events.GET(new Request('https://app.test/api/events', { signal: controller.signal }))
  await until(() => store.listeners.size === 1)
  await sleep(5)
  const payload = { text: 'x'.repeat(200) }
  for (let id = 1; id <= 20_000; id += 1) publish(ev(id, payload))
  const selfClosed = store.unsubscribed > 0 || store.listeners.size === 0
  controller.abort()
  const text = await readAll(response)
  const bytes = encoder.encode(text).byteLength
  const delivered = ids(text)
  assert.ok(bytes <= 2 * 1024 * 1024, `${bytes} bytes queued for 20000 unread events (last id ${delivered.at(-1)})`)
  return `${bytes} bytes queued, stream ended itself=${selfClosed || store.unsubscribed > 0}, last id ${delivered.at(-1)}`
})

// --- R1-C11 --------------------------------------------------------------------------------
await check('R1-C11', 'unsubscribe runs inside a task registered with after()', async () => {
  await sleep(100) // let earlier checks' unsubscribes finish before counting this one
  reset()
  afterTasks.length = 0
  store.unsubscribeDelayMs = 50
  const controller = new AbortController()
  const response = await events.GET(new Request('https://app.test/api/events', { signal: controller.signal }))
  const text = readAll(response)
  await until(() => store.listeners.size === 1)
  const abortedAt = performance.now()
  controller.abort()
  await text
  assert.ok(afterTasks.length > 0, 'no after()/waitUntil task registered; unsubscribe() runs untracked')
  for (const task of afterTasks) await (typeof task === 'function' ? task() : task)
  assert.equal(store.unsubscribed, 1, `the after() task settled with unsubscribed=${store.unsubscribed}`)
  return `after() task settled once unsubscribe finished (${Math.round(store.unsubscribedAt - abortedAt)} ms after abort)`
})

// --- client hook: R1-C12, R1-C22 ------------------------------------------------------------
class FakeEventSource {
  static CONNECTING = 0
  static OPEN = 1
  static CLOSED = 2
  static instances = []
  constructor(url) {
    this.url = String(url)
    this.readyState = FakeEventSource.CONNECTING
    this.listeners = new Map()
    this.closed = false
    FakeEventSource.instances.push(this)
  }
  addEventListener(type, listener) {
    this.listeners.set(type, [...(this.listeners.get(type) ?? []), listener])
  }
  removeEventListener(type, listener) {
    this.listeners.set(type, (this.listeners.get(type) ?? []).filter((item) => item !== listener))
  }
  close() {
    this.readyState = FakeEventSource.CLOSED
    this.closed = true
  }
  emit(event) {
    for (const listener of this.listeners.get(event.type) ?? []) listener(event)
  }
}
globalThis.EventSource = FakeEventSource
globalThis.window = { location: { href: 'https://app.test/rooms' } }
globalThis.IS_REACT_ACT_ENVIRONMENT = true

let hookStatus = 'unset'
function Probe({ url, eventName = 'room.message' }) {
  hookStatus = useEventSource({ url, eventName, parse: (data) => JSON.parse(data), onEvent: () => {} })
  return null
}
const latestSource = () => FakeEventSource.instances.at(-1)
const message = (type, data, lastEventId) => new MessageEvent(type, { data, lastEventId })
async function openAndDeliver(source, lastEventId) {
  await act(async () => {
    source.readyState = FakeEventSource.OPEN
    source.emit(new Event('open'))
    source.emit(message('room.message', '{"n":1}', lastEventId))
  })
}

await check('R1-C12', 'switching url starts the new room fresh; same-url re-runs still resume', async () => {
  let renderer
  await act(async () => {
    renderer = TestRenderer.create(createElement(Probe, { url: '/api/rooms/a/events' }))
  })
  await openAndDeliver(latestSource(), '5')
  await act(async () => renderer.update(createElement(Probe, { url: '/api/rooms/b/events' })))
  const roomB = latestSource()
  const carried = new URL(roomB.url).searchParams.get('lastEventId')
  const statusAfterSwitch = hookStatus
  await openAndDeliver(roomB, '9')
  await act(async () => renderer.update(createElement(Probe, { url: '/api/rooms/b/events', eventName: 'x' })))
  const resumed = new URL(latestSource().url).searchParams.get('lastEventId')
  await act(async () => renderer.unmount())
  assert.ok(
    carried === null && statusAfterSwitch === 'connecting' && resumed === '9',
    `room b opened with lastEventId=${carried} and status '${statusAfterSwitch}'; same-url re-run resumed from ${resumed}`,
  )
  return `room b opened with no lastEventId, status '${statusAfterSwitch}'; same-url re-run resumed from ${resumed}`
})

await check('R1-C22', 'a stream-error frame closes the source and reports closed', async () => {
  let renderer
  await act(async () => {
    renderer = TestRenderer.create(createElement(Probe, { url: '/api/events' }))
  })
  const source = latestSource()
  await act(async () => {
    source.readyState = FakeEventSource.OPEN
    source.emit(new Event('open'))
    source.emit(message('stream-error', '{"message":"stream failed"}', ''))
  })
  const status = hookStatus
  const closed = source.closed
  await act(async () => renderer.unmount())
  assert.ok(closed && status === 'closed', `after stream-error: source.closed=${closed}, status '${status}'`)
  return `source closed, status '${status}'`
})

// --- fetch reader: R1-C13, R1-C14, R1-C20, R1-C21, R1-C23 -------------------------------------
const { readSse, readSseWithReconnect } = readSseModule

async function reconnectOutcome(status) {
  let opens = 0
  const controller = new AbortController()
  const run = readSseWithReconnect({
    open: async () => {
      opens += 1
      return new Response('nope', { status })
    },
    onMessage: () => {},
    signal: controller.signal,
  })
  const outcome = await withFastTimers(() =>
    Promise.race([
      run.then(
        () => 'resolved',
        (error) => `rejected (${error.message})`,
      ),
      sleep(300).then(() => 'still retrying'),
    ]),
  )
  controller.abort()
  await run.catch(() => {})
  return { outcome, opens }
}
await check('R1-C13', '401/403/400 stop the reconnect loop; 503 still retries', async () => {
  const final = await Promise.all([401, 403, 400].map(reconnectOutcome))
  const retry = await reconnectOutcome(503)
  const summary = `${[401, 403, 400].map((s, i) => `${s}: ${final[i].outcome} after ${final[i].opens} open(s)`).join('; ')}; 503: ${retry.outcome} after ${retry.opens} opens`
  assert.ok(final.every(({ outcome, opens }) => outcome.startsWith('rejected') && opens === 1) && retry.opens > 1, summary)
  return summary
})

await check('R1-C14', 'the chat route plain-text body reaches the UI', async () => {
  const response = await chat.POST(
    new Request('https://app.test/api/chat', { method: 'POST', body: JSON.stringify({ prompt: 'hi' }) }),
  )
  const textReader = await import('@/shared/utils/read-text-stream').catch(() => null)
  let text = ''
  if (textReader) {
    await textReader.readTextStream(response, (chunk) => {
      text += chunk
    })
  } else {
    await readSse(response, (sse) => {
      text += sse.data
    })
  }
  const via = textReader ? 'readTextStream' : 'readSse (no plain-text reader exists)'
  assert.equal(text, 'Hello, world', `${via} delivered ${JSON.stringify(text)}`)
  return `${via} delivered ${JSON.stringify(text)}`
})

await check('R1-C20', 'readSse cancels the body on a non-OK status and when onMessage throws', async () => {
  const tracked = (chunk) => {
    const state = { cancelled: false }
    const body = new ReadableStream({
      start(controller) {
        controller.enqueue(encoder.encode(chunk))
      },
      cancel() {
        state.cancelled = true
      },
    })
    return { body, state }
  }
  const failing = tracked('oops')
  await readSse(new Response(failing.body, { status: 500 }), () => {}).catch(() => {})
  const throwing = tracked('data: a\n\n')
  await readSse(new Response(throwing.body), () => {
    throw new Error('bad payload')
  }).catch(() => {})
  const summary = `500 body cancelled=${failing.state.cancelled}; onMessage-throws body cancelled=${throwing.state.cancelled}`
  assert.ok(failing.state.cancelled && throwing.state.cancelled, summary)
  return summary
})

await check('R1-C21', 'an id-only block moves the resume id', async () => {
  const sent = []
  const controller = new AbortController()
  await withFastTimers(() =>
    readSseWithReconnect({
      open: async (lastEventId) => {
        sent.push(lastEventId)
        return sent.length === 1 ? new Response('id: 1\ndata: a\n\nid: 7\n\n') : new Response(null, { status: 204 })
      },
      onMessage: () => {},
      signal: controller.signal,
    }),
  )
  assert.equal(sent[1], '7', `reconnected with Last-Event-ID ${sent[1]} after an id-only block "id: 7"`)
  return `reconnected with ${sent[1]}`
})

await check('R1-C23', 'backoff waits leave no abort listeners behind', async () => {
  const counts = []
  const controller = new AbortController()
  await withFastTimers(() =>
    readSseWithReconnect({
      open: async (_lastEventId, signal) => {
        counts.push(getEventListeners(signal, 'abort').length)
        if (counts.length === 6) controller.abort()
        throw new TypeError('network down')
      },
      onMessage: () => {},
      signal: controller.signal,
    }),
  )
  assert.ok(Math.max(...counts) === 0, `abort listeners at each reconnect: ${counts.join(',')}`)
  return `abort listeners at each reconnect: ${counts.join(',')}`
})

// --- R1-C24 --------------------------------------------------------------------------------
await check('R1-C24', 'aborting the signal passed to framesToStream closes the generator', async () => {
  let finalized = false
  async function* frames() {
    try {
      yield 'a'
      yield 'b'
      yield 'c'
    } finally {
      finalized = true
    }
  }
  const controller = new AbortController()
  const reader = sseStream.framesToStream(frames(), controller.signal).getReader()
  await reader.read()
  controller.abort()
  await sleep(10)
  const arity = sseStream.framesToStream.length
  assert.ok(finalized, `framesToStream takes ${arity} parameter(s); abort left the generator open`)
  return `generator finally ran on abort (framesToStream takes ${arity} parameters)`
})

// --- R1-C3 ---------------------------------------------------------------------------------
await check('R1-C3', 'vercel.json functions keys match the src/app route files', async () => {
  const { functions } = JSON.parse(readFileSync(join(root, 'vercel-1.json'), 'utf8'))
  const keys = Object.keys(functions)
  const routes = ['src/app/api/events/route.ts', 'src/app/api/chat/route.ts']
  const unmatched = routes.filter((route) => !keys.some((key) => matchesGlob(route, key)))
  assert.deepEqual(unmatched, [], `keys ${keys.join(', ')} match none of ${unmatched.join(', ')}`)
  return `keys ${keys.join(', ')} match both route files`
})

const failed = results.filter((result) => !result.ok)
for (const { id, ok, name, detail } of results) {
  process.stdout.write(`${ok ? 'PASS' : 'FAIL'} ${id} ${name} :: ${detail}\n`)
}
process.stdout.write(`${label}: ${results.length - failed.length} pass, ${failed.length} fail\n`)
process.exit(0)
