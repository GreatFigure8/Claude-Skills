// Resolve '@/…' into out/<SSE_LABEL>/src and swap side-effecting modules for stubs.
import { registerHooks } from 'node:module'
import { join } from 'node:path'
import { pathToFileURL } from 'node:url'

const base = import.meta.dirname
const label = process.env.SSE_LABEL
const STUBS = {
  '@/lib/dal': 'stubs/dal.ts',
  '@/lib/auth': 'stubs/auth.ts',
  '@/lib/realtime': 'stubs/realtime.ts',
  'next/server': 'stubs/next-server.ts',
  ai: 'stubs/ai.ts',
}
const file = (path) => ({ url: pathToFileURL(join(base, path)).href, shortCircuit: true })

registerHooks({
  resolve(specifier, context, nextResolve) {
    if (STUBS[specifier]) return file(STUBS[specifier])
    if (specifier.startsWith('@/')) return file(join('out', label, 'src', `${specifier.slice(2)}.ts`))
    return nextResolve(specifier, context)
  },
})
