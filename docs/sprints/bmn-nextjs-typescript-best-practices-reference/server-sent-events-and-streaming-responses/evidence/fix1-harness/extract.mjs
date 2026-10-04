// Extract the path-commented ts/tsx/json fences of sse-and-streaming.md into out/<label>/.
// Usage: node extract.mjs <path-to-md> <label>
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'

const [, , mdPath, label] = process.argv
const root = join(import.meta.dirname, 'out', label)
rmSync(root, { recursive: true, force: true })
mkdirSync(root, { recursive: true })

const text = readFileSync(mdPath, 'utf8')
const fence = /^```(ts|tsx|json)\n([\s\S]*?)^```$/gm
const written = []
let json = 0
for (const match of text.matchAll(fence)) {
  const [, lang, body] = match
  if (lang === 'json') {
    json += 1
    writeFileSync(join(root, `vercel-${json}.json`), body, { flag: 'w' })
    continue
  }
  const first = body.split('\n')[0]
  const path = /^\/\/ (src\/\S+\.tsx?)/.exec(first)?.[1]
  if (!path) continue
  const target = join(root, path)
  mkdirSync(dirname(target), { recursive: true })
  writeFileSync(target, body)
  written.push(path)
}
console.log(JSON.stringify({ label, written, json }))
