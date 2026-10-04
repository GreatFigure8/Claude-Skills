// Strict tsc over out/<label> with typescript.md P1's compilerOptions, next@16.3.8 types and
// declaration-only stubs for '@/lib/dal' (run contract), '@/lib/auth' (pre-fix name) and 'ai'.
// Usage: node typecheck.mjs <label> [lib...]
import { execFileSync } from 'node:child_process'
import { mkdirSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

const [, , label, ...libArg] = process.argv
const root = join(import.meta.dirname, 'out', label)
const lib = libArg.length ? libArg : ['ES2020', 'DOM', 'DOM.Iterable']
const tsc = process.env.TSC ?? join(import.meta.dirname, '..', 'node_modules', '.bin', 'tsc')

const files = {
  'tsconfig.json': JSON.stringify(
    {
      compilerOptions: {
        target: 'ES2020',
        lib,
        module: 'ESNext',
        moduleResolution: 'bundler',
        jsx: 'react-jsx',
        strict: true,
        noUncheckedIndexedAccess: true,
        noImplicitOverride: true,
        noFallthroughCasesInSwitch: true,
        isolatedModules: true,
        esModuleInterop: true,
        resolveJsonModule: true,
        skipLibCheck: true,
        forceConsistentCasingInFileNames: true,
        noEmit: true,
        paths: { '@/*': ['./src/*'] },
      },
      include: ['src/**/*.ts', 'src/**/*.tsx', 'types/*.d.ts'],
    },
    null,
    2,
  ),
  'src/lib/dal.ts': [
    "export type Session = { userId: string; role: 'admin' | 'user' }",
    'export declare function getSession(): Promise<Session | null>',
    'export declare function verifySession(): Promise<Session>',
    '',
  ].join('\n'),
  'src/lib/auth.ts': "export { verifySession } from '@/lib/dal'\n",
  'types/ai.d.ts': [
    "declare module 'ai' {",
    '  export function streamText(options: { model: string; prompt: string; abortSignal?: AbortSignal }): {',
    '    toTextStreamResponse(): Response',
    '  }',
    '}',
    '',
  ].join('\n'),
  'src/usage.ts': [
    "import { framesToStream, tokenFrames } from '@/shared/utils/sse-stream'",
    'declare const tokens: AsyncIterable<string>',
    'declare const request: Request',
    '// R1-C24: the prose pairs framesToStream with request.signal',
    'export const stream: ReadableStream<Uint8Array> = framesToStream(tokenFrames(tokens), request.signal)',
    '',
  ].join('\n'),
}
for (const [path, body] of Object.entries(files)) {
  mkdirSync(join(root, path, '..'), { recursive: true })
  writeFileSync(join(root, path), body)
}
try {
  execFileSync(tsc, ['-p', join(root, 'tsconfig.json')], { encoding: 'utf8' })
  console.log(`${label} [lib ${lib.join(',')}]: tsc --strict clean`)
} catch (error) {
  console.log(`${label} [lib ${lib.join(',')}]: tsc errors\n${error.stdout}`)
}
