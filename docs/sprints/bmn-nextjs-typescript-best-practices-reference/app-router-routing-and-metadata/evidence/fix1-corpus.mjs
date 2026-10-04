// Run the documented toSafePath guard (extracted verbatim from the Markdown fence) against a
// hostile corpus, then resolve each result the way App Router's router.push does:
// new URL(addBasePath(href), location.href), cross-origin when url.origin !== location.origin.
// Usage: node corpus.mjs <routing-and-metadata.md> <label>
import { readFileSync, writeFileSync } from 'node:fs'
import { pathToFileURL } from 'node:url'
import { dirname, join } from 'node:path'

const [mdPath, label] = process.argv.slice(2)
const md = readFileSync(mdPath, 'utf8')
const fences = [...md.matchAll(/^```tsx?\n([\s\S]*?)^```/gm)].map((m) => m[1])
const fence = fences.filter((body) => body.includes('function toSafePath')).at(-1)
if (!fence) throw new Error('no fence defines toSafePath')
const lines = fence.split('\n')
const start = lines.findLastIndex((line) => line.startsWith('import ')) + 1
const end = lines.findIndex((line) => line.startsWith('export function ContinueButton'))
const guard = lines.slice(start, end).join('\n')
const out = join(dirname(new URL(import.meta.url).pathname), `guard-${label}.mts`)
writeFileSync(out, `type Route = string\n${guard}\nexport { toSafePath }\n`)
const { toSafePath } = await import(pathToFileURL(out).href)

const APP = 'https://app.example.com'
const CURRENT = `${APP}/login`
const corpus = [
  ['/%09/evil.com', 'hostile'],
  ['/\t/evil.com', 'hostile'],
  ['/\n/evil.com', 'hostile'],
  ['/\\evil.com', 'hostile'],
  ['/\t\\evil.com', 'hostile'],
  ['//evil.com', 'hostile'],
  ['https://evil.com', 'hostile'],
  ['/%5Cevil.com', 'hostile'],
  ['/.//evil.com', 'hostile'],
  ['/a/..//evil.com', 'hostile'],
  ['javascript:alert(1)', 'hostile'],
  ['https://[', 'hostile'],
  ['/ok?x=1', 'benign'],
  ['/dashboard', 'benign'],
]

// Each value is tried as the string toSafePath receives, and as the raw ?next= query value
// that useSearchParams().get('next') decodes (so /%09/ arrives as a real tab).
const rows = []
for (const [raw, kind] of corpus) {
  for (const [via, value] of [['as-is', raw], ['?next=', new URLSearchParams(`next=${raw}`).get('next')]]) {
    const result = toSafePath(value)
    const target = new URL(result, CURRENT)
    const crossOrigin = target.origin !== APP
    const ok = kind === 'hostile' ? !crossOrigin : result === new URL(value, APP).pathname + new URL(value, APP).search
    rows.push({ via, input: JSON.stringify(value), kind, result: JSON.stringify(result), navigatesTo: target.href, crossOrigin, ok })
  }
}
console.log(`guard (${label}):\n${guard.trim()}\n`)
console.table(rows)
const bad = rows.filter((row) => !row.ok)
console.log(`${label}: ${rows.length - bad.length}/${rows.length} ok; ${bad.filter((r) => r.crossOrigin).length} cross-origin navigation(s)`)
process.exit(bad.length === 0 ? 0 : 1)
