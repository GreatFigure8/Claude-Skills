// Controllable fake store for the route: live subscription plus a durable log.
export type FeedEvent = { id: string; type: string; payload: unknown }
type Listener = (event: FeedEvent) => void

export const store = {
  listeners: new Set<Listener>(),
  log: [] as FeedEvent[],
  replayGate: null as Promise<void> | null,
  snapshotAfterGate: false,
  unsubscribeDelayMs: 0,
  unsubscribed: 0,
  unsubscribedAt: 0,
}

export function reset(): void {
  store.listeners.clear()
  store.log = []
  store.replayGate = null
  store.snapshotAfterGate = false
  store.unsubscribeDelayMs = 0
  store.unsubscribed = 0
  store.unsubscribedAt = 0
}

export async function subscribe(userId: string, onEvent: Listener): Promise<() => Promise<void>> {
  void userId
  store.listeners.add(onEvent)
  return async () => {
    await new Promise((resolve) => setTimeout(resolve, store.unsubscribeDelayMs))
    store.listeners.delete(onEvent)
    store.unsubscribed += 1
    store.unsubscribedAt = performance.now()
  }
}

const newer = (lastEventId: string | null) => (event: FeedEvent) =>
  lastEventId === null || Number(event.id) > Number(lastEventId)

export async function replaySince(userId: string, lastEventId: string | null): Promise<FeedEvent[]> {
  void userId
  const early = store.log.filter(newer(lastEventId))
  if (store.replayGate) await store.replayGate
  return store.snapshotAfterGate ? store.log.filter(newer(lastEventId)) : early
}

/** Log-then-publish, as a real store does. */
export function publish(event: FeedEvent): void {
  store.log.push(event)
  for (const listener of store.listeners) listener(event)
}
