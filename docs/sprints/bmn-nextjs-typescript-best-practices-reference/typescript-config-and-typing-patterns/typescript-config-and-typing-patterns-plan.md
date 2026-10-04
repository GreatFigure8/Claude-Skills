# Plan: typescript-config-and-typing-patterns

**Story:** [story.md](story.md) · **Run:** `bmn-nextjs-typescript-best-practices-reference` · **Deps:** `nextjs-standard-entry-point-and-skill-wiring` (merged first)
`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`. Research done live on 2026-10-04 (WebFetch/WebSearch + `npm view`).

## 1. Approach

1. No build skill is routed (stack.md, Routing: the repo is Markdown + Python tests; `nextjs-fullstack-standards` is not loadable and is never approximated). The guidance applied is the story's contract, the skeleton story's **Authoring contract**, and the global testing rule: tests first (RED), then content (GREEN).
2. TDD: write `test_nextjs_topic_typescript.py` first; it fails on the stub (`is_stub` true, no `TS-` rules, no blocks). Then replace the stub with `R/nextjs/typescript.md` built **only** from the Verified rule sheet below (§7). The coder adds no rule, API or version fact that is not in §7.
3. Grounding: every Next.js/Vercel claim cites the nextjs.org / vercel.com page it was read from; TypeScript-language claims cite typescriptlang.org; Zod facts cite zod.dev; Web API facts cite MDN. House rules carry `(convention)`. Anything I could not confirm is in §8 and goes to `## Not confirmed by the docs`, never into `## Rules`.
4. Currency: latest stable is **Next.js 16.3.8** (npm `latest` = 16.3.8; every docs page fetched reports `version: 16.3.8`; blog "Next.js 16.3", 2026-08-03). The file's as-of line is copied verbatim from `R/nextjs.md` (the skeleton reads it live); `## Version notes` names `Next.js 16`.
5. Expert depth inside the 800-line cap: ~34 one-line rules, 9 typed patterns, 7 Don't/Do pairs, ~16 checklist items. Doc examples that are unsafe under `strict` (forms guide `initialState: any`, Route Handler webhook `error.message` on an `unknown` catch variable, Zod 3 API in the forms guide, `baseUrl` on TS 6+) are called out as anti-patterns with the doc link, so agents don't copy them.

## 2. Files

| Path | Action | Purpose |
| --- | --- | --- |
| `R/nextjs/typescript.md` | replace stub entirely | The `TS` topic file: Scope, Rules (TS-1…TS-34), Patterns, Anti-patterns, Version notes, Review checklist, Not confirmed by the docs, Sources. ≤ 800 lines (target 550–700). |
| `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_typescript.py` | create | Topic-specific pytest (stdlib + `nextjs_doc_helpers` only, offline, ruff-clean). |
| `docs/sprints/bmn-nextjs-typescript-best-practices-reference/typescript-config-and-typing-patterns/evidence/sources-verified.md` | create | One row per `## Sources` URL: URL · fetched 2026-10-04 (live, this run) · rule ids it backs (table in §7.4). |

Nothing else changes (AC10). Shared files (`R/nextjs.md`, `nextjs_doc_helpers.py`, `test_nextjs_reference.py`, wiring) are read, never edited; a defect found there is logged in this story's `validation.md` Assumptions.

**Coder pre-flight (mandatory, before writing anything):** read the merged `R/nextjs.md` (`## Authoring contract`, as-of line, Sources bullet style), the stub `R/nextjs/typescript.md` (H1 and as-of line), `nextjs_doc_helpers.py` (exact signatures of `section`, `rule_items`, `code_blocks`, `has_block_with`, `missing_terms`, `as_of_version`, `is_stub`, `source_urls`) and `test_nextjs_reference.py` (how a "Don't" item, a rule item and Sources bullets are parsed). Where this plan's assumed format differs from the merged contract, the contract wins; log the difference in `validation.md`.

## 3. Test plan (written first)

File: `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_typescript.py` (type: unit, pytest). Module constants: `TOPIC = helpers.TOPICS_DIR / "typescript.md"`, `TEXT = helpers.read(TOPIC)` read once in a module-level fixture, `TERMS` tuple below. Import with `import nextjs_doc_helpers as helpers` (pytest's default `prepend` import mode puts the test dir on `sys.path`; existing tests use no package `__init__`).

| AC | Test name | Asserts |
| --- | --- | --- |
| 1 | (generic) every check in `test_nextjs_reference.py` | runs on `typescript.md` without skip and passes (as-of match, section order, rule format + citations, floors, Sources hosts, ≤800 lines, tagged fences, links resolve). Verified by running that file. |
| 1 | `test_typescript_topic_uses_only_ts_rule_ids` | every `rule_items(TEXT)` id starts with `TS-`; ids are `TS-1..TS-k` with no gap; no `\b(?:RT\|RC\|DF\|API\|SSE\|SEC\|PERF\|TEST)-\d+\b` anywhere in the file. |
| 2 | `test_typescript_topic_is_not_a_stub` | `helpers.is_stub(TEXT) is False`. |
| 2 | `test_typescript_topic_has_at_least_15_rules` | `len(rule_items(TEXT)) >= 15`. |
| 3 | `test_typescript_topic_mentions_every_required_term` | `helpers.missing_terms(TEXT, TERMS) == []`. |
| 4 | `test_typescript_topic_has_strict_tsconfig_json_block` | `has_block_with(TEXT, '"strict": true', langs=("json",))`. |
| 4 | `test_typescript_topic_has_typed_next_config_block` | `has_block_with(TEXT, "NextConfig", "typedRoutes")` (ts/tsx). |
| 4 | `test_typescript_topic_has_page_props_block_awaiting_params` | `has_block_with(TEXT, "PageProps<'/", "await")`. |
| 4 | `test_typescript_topic_has_route_context_handler_block` | `has_block_with(TEXT, "RouteContext<'/", "await")`. |
| 4 | `test_typescript_topic_has_safe_parse_boundary_block` | `has_block_with(TEXT, "safeParse")`. |
| 4 | `test_typescript_topic_examples_never_use_any` | no ts/tsx block body matches `r":\s*any\b\|<any>\|as any\b"` **except** blocks under `## Anti-patterns` that sit after a "Don't" marker (implementation: run on `code_blocks(section(TEXT, "Patterns"), ("ts","tsx"))` only). |
| 5 | `test_typescript_topic_awaits_search_params_in_tsx` | `has_block_with(TEXT, "searchParams", "await", langs=("tsx",))`. |
| 5 | `test_typescript_rules_say_how_route_helpers_are_generated` | `## Rules` section contains `next typegen`, `next dev` and `next build`, and contains `Promise`. |
| 6 | `test_typescript_rules_forbid_ignore_build_errors_and_ban_any` | `## Rules` section contains `ignoreBuildErrors`, `unknown` and `` `any` ``. |
| 7 | `test_typescript_version_notes_name_major_and_link_nextjs` | `section(TEXT, "Version notes")` is non-empty, contains `f"Next.js {major}"` where `major = as_of_version(TEXT).split(".")[0]`, and contains `https://nextjs.org/`. |
| 8 | `test_typescript_review_checklist_items_cite_rule_ids` | every line in the file starting with `- [ ]` contains `TS-`; at least 8 such lines. |
| 8 | `test_typescript_anti_patterns_pair_each_dont_with_a_do` | in `section(TEXT, "Anti-patterns")`, count of `**Don't**` markers == count of `**Do**` markers, both ≥ 3, and each marker is followed by a fenced block before the next marker (adapt marker strings to the merged contract's "Don't" format if it differs). |
| 9 | — (one-off, recorded in `validation.md`) | URL set of `evidence/sources-verified.md` == `source_urls(TEXT)`. Command: `python3 -c` one-liner that imports `nextjs_doc_helpers`, extracts both sets with the same URL regex and prints the symmetric difference (must be empty). Not a permanent test (tests never read run folders). |
| 10 | — (gate, recorded in `validation.md`) | `git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD` lists only the 3 files in §2 (+ this story folder); full suite + ruff clean. |

`TERMS = ('"strict": true', "noUncheckedIndexedAccess", "next-env.d.ts", "next.config.ts", "NextConfig", "typedRoutes", "next typegen", "PageProps", "LayoutProps", "RouteContext", "searchParams", "Promise<", "ignoreBuildErrors", "safeParse", "unknown", "satisfies", "server-only", "NEXT_PUBLIC_", "Metadata", "`any`")` — the last term keeps its backticks so the case-insensitive substring match can't be satisfied by words like "many" (assumption A3).

Test count: 16 new pytest functions. No browser tests (no UI).

## 4. Data

None. No models, migrations, Supabase or RLS.

## 5. Config / env / deploy_pending

None. No env vars, no config. `deploy_pending: []`.

## 6. Risks and gates

| Risk | Mitigation |
| --- | --- |
| Helper signatures / "Don't" format in the merged skeleton differ from what the story text implies (its plan is written in parallel). | Coder pre-flight (§2) reads the merged helpers and contract first and adapts the test; differences logged in `validation.md`. |
| A rule item spanning lines breaks `rule_items` parsing. | Each rule is **one physical line**: `N. **TS-N** <imperative> … [source](url)`. `N` equals the TS number. |
| Fragment links (`…/cli/next#next-typegen-options`) don't string-match the `## Sources` entry. | No `#anchor` in any link. Every prose link uses a URL exactly as listed in Sources. |
| Snippets are not compiled. | Every snippet uses only APIs shown on the cited page or typescriptlang.org/zod.dev; types are conservative (see notes per pattern). REVIEW① spot-checks against links. |
| Zod 3 vs Zod 4: the Next.js forms guide still shows `invalid_type_error` and `.flatten()` (removed / deprecated in Zod 4, npm `latest` 4.6.5). | Patterns use Zod 4 only (`z.flattenError`, `error` param, `z.email()`/`z.url()`); TS-21 tells agents to check the repo's major. |
| 800-line cap. | Budget: Scope 15 · Rules 40 · Patterns 230 · Anti-patterns 150 · Version notes 30 · Checklist 20 · Not confirmed 25 · Sources 45 ≈ 560 lines. |
| Overlap with sibling topics. | This file owns types + general boundary validation. It links (never cites ids of) `routing-and-metadata.md`, `data-fetching-and-mutations.md`, `route-handlers-and-apis.md`, `proxy-auth-and-security.md`, `rendering-and-caching.md`, `testing-and-observability.md` with relative links. |

Gate commands (run from the worktree):

```bash
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_typescript.py -q   # RED first, then GREEN
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests/test_nextjs_reference.py -q
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q
uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope
wc -l Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/typescript.md   # <= 800
git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD
```

## 7. Verified rule sheet (the only content the coder may state)

Version facts read live 2026-10-04: npm `next` latest **16.3.8**; npm `typescript` latest **7.0.2**; npm `zod` latest **4.6.5**. Tags: **[16]** changed in Next.js 16 · **[16.3]** added in 16.3 · **[15.5]** added in 15.5 (still current).

### 7.1 Source keys (use these exact URLs; no anchors)

| Key | URL | Page version / date seen |
| --- | --- | --- |
| N-TS | https://nextjs.org/docs/app/api-reference/config/typescript | 16.3.8, updated 2026-08-25 |
| N-TSCFG | https://nextjs.org/docs/app/api-reference/config/next-config-js/typescript | 16.3.8 |
| N-TR | https://nextjs.org/docs/app/api-reference/config/next-config-js/typedRoutes | 16.3.8 |
| N-TSCLI | https://nextjs.org/docs/app/api-reference/config/next-config-js/useTypeScriptCli | 16.3.8, 2026-08-03 |
| N-CLI | https://nextjs.org/docs/app/api-reference/cli/next | 16.3.8 |
| N-CFG | https://nextjs.org/docs/app/api-reference/config/next-config-js | 16.3.8 |
| N-PAGE | https://nextjs.org/docs/app/api-reference/file-conventions/page | 16.3.8 |
| N-LAYOUT | https://nextjs.org/docs/app/api-reference/file-conventions/layout | 16.3.8 |
| N-ROUTE | https://nextjs.org/docs/app/api-reference/file-conventions/route | 16.3.8 |
| N-META | https://nextjs.org/docs/app/api-reference/functions/generate-metadata | 16.3.8 |
| N-ENV | https://nextjs.org/docs/app/guides/environment-variables | 16.3.8 |
| N-SC | https://nextjs.org/docs/app/getting-started/server-and-client-components | 16.3.8 |
| N-SEC | https://nextjs.org/docs/app/guides/data-security | 16.3.8 |
| N-FORMS | https://nextjs.org/docs/app/guides/forms | 16.3.8 |
| N-USESERVER | https://nextjs.org/docs/app/api-reference/directives/use-server | 16.3.8 |
| N-VITE | https://nextjs.org/docs/app/guides/migrating/from-vite | 16.3.8, 2026-07-28 |
| N-INSTALL | https://nextjs.org/docs/app/getting-started/installation | 16.3.8 |
| N-SRC | https://nextjs.org/docs/app/api-reference/file-conventions/src-folder | 16.3.8 |
| N-ESLINT | https://nextjs.org/docs/app/api-reference/config/eslint | 16.3.8 |
| N-UP16 | https://nextjs.org/docs/app/guides/upgrading/version-16 | 16.3.8 |
| B-16 | https://nextjs.org/blog/next-16 | 2025-10-21 |
| B-155 | https://nextjs.org/blog/next-15-5 | 2025-08-18 |
| B-163 | https://nextjs.org/blog/next-16-3 | 2026-08-03 |
| V-SYSENV | https://vercel.com/docs/environment-variables/system-environment-variables | updated 2026-07-15 |
| R-USESERVER | https://react.dev/reference/rsc/use-server | — |
| T-TSCONFIG | https://www.typescriptlang.org/tsconfig/ | — |
| T-NUIA | https://www.typescriptlang.org/tsconfig/noUncheckedIndexedAccess.html | — |
| T-ISO | https://www.typescriptlang.org/tsconfig/isolatedModules.html | — |
| T-VMS | https://www.typescriptlang.org/tsconfig/verbatimModuleSyntax.html | — |
| T-60 | https://www.typescriptlang.org/docs/handbook/release-notes/typescript-6-0.html | — |
| T-49 | https://www.typescriptlang.org/docs/handbook/release-notes/typescript-4-9.html | — |
| T-39 | https://www.typescriptlang.org/docs/handbook/release-notes/typescript-3-9.html | — |
| T-NARROW | https://www.typescriptlang.org/docs/handbook/2/narrowing.html | — |
| T-OBJ | https://www.typescriptlang.org/docs/handbook/2/objects.html | — |
| T-FN | https://www.typescriptlang.org/docs/handbook/2/functions.html | — |
| T-EVERYDAY | https://www.typescriptlang.org/docs/handbook/2/everyday-types.html | — |
| T-DODONT | https://www.typescriptlang.org/docs/handbook/declaration-files/do-s-and-don-ts.html | — |
| Z-BASICS | https://zod.dev/basics | Zod 4 |
| Z-V4 | https://zod.dev/v4/changelog | Zod 4 |
| Z-ERR | https://zod.dev/error-formatting | Zod 4 |
| Z-API | https://zod.dev/api | Zod 4 |
| M-REQJSON | https://developer.mozilla.org/en-US/docs/Web/API/Request/json | — |

`T-VMS` and `N-CFG` are optional: keep them in Sources only if the file links them (every Sources URL must be cited somewhere and vice versa per the evidence check).

### 7.2 Rules (one physical line each in the file; rule text may be tightened, never broadened)

**tsconfig and toolchain**

- **TS-1** Set `"strict": true` in `tsconfig.json` and never switch off a strict-family flag. *Sources:* N-VITE (Next-compatible `tsconfig.json` with `"strict": true`), T-TSCONFIG (`strict` enables `alwaysStrict`, `strictNullChecks`, `strictBindCallApply`, `strictBuiltinIteratorReturn`, `strictFunctionTypes`, `strictPropertyInitialization`, `noImplicitAny`, `noImplicitThis`, `useUnknownInCatchVariables`), T-60 (TS 6.0 makes `strict` default `true`; relying on the old `false` default needs an explicit `"strict": false`).
- **TS-2** Add `noUncheckedIndexedAccess`, `noImplicitOverride` and `noFallthroughCasesInSwitch` on top of `strict` (convention); they are not part of the strict family. *Sources:* T-NUIA ("add `undefined` to any un-declared field in the type"), T-TSCONFIG (`noImplicitOverride` 4.3; `noFallthroughCasesInSwitch`: non-empty case must `break`/`return`/`throw`), N-VITE (shows `noFallthroughCasesInSwitch: true`).
- **TS-3** Keep `"plugins": [{ "name": "next" }]` in `compilerOptions` and select "Use Workspace Version" in the editor so the Next.js TypeScript plugin runs. *Sources:* N-VITE (step 4 adds the plugin entry), N-TS (plugin warns on invalid segment-config values, wrong `'use client'` usage, client hooks outside Client Components).
- **TS-4** Keep `next-env.d.ts` and `.next/types/**/*.ts` in `tsconfig.json` `include`, add `next-env.d.ts` to `.gitignore`, never edit it, and put custom declarations in your own `.d.ts` listed in `include`. *Source:* N-TS ("managed by Next.js… Add it to `.gitignore`… Do not edit this file manually"; must be in `include`; typed-links note adds `.next/types/**/*.ts`; "Custom type declarations" section shows `new-types.d.ts` in `include`).
- **TS-5** Run `next typegen` before any standalone type-check (`next typegen && tsc --noEmit` in CI and in a repo's `types` gate), because `PageProps`, `LayoutProps`, `RouteContext`, route types and `next-env.d.ts` are generated only by `next dev`, `next build` or `next typegen`. *Sources:* N-CLI ("Previously, route types were only generated during `next dev` or `next build`, which meant running `tsc --noEmit` directly wouldn't validate your route types"; output to `.next/dev/types` in dev, `.next/types` in production; `next typegen` loads `next.config.*` in the production build phase so variables the config needs must be present), N-TS. **[15.5]** `typegen` added in v15.5.0.
- **TS-6** Never set `typescript.ignoreBuildErrors: true` and never point `typescript.tsconfigPath` at a relaxed build config (convention). *Sources:* N-TSCFG (`next build` fails on TS errors; `ignoreBuildErrors` "completely skips the TypeScript type checking step… bypasses the check entirely"; "can be very dangerous"; if disabled, run type checks in the build/deploy process), N-TS (same; `tsconfigPath` exists for relaxed builds, which bmn does not use).
- **TS-7** Write `next.config.ts` as `import type { NextConfig } from 'next'`, a `const nextConfig: NextConfig` and `export default nextConfig`; use top-level `await` or dynamic `import()` in it only through Node's native TypeScript resolver (`next.config.mts` in a CommonJS project). *Sources:* N-TS (exact snippet; "Module resolution in `next.config.ts` is currently limited to CommonJS"; ESM available with Node's native resolver, detected via `process.features.typescript`, Node ≥ 22.10.0 opt-in, on by default ≥ 22.18.0; `.mts` recommended for CommonJS projects), N-CFG (`.cjs`/`.cts` config extensions not supported).
- **TS-8** Enable `typedRoutes: true` (top level, not `experimental.typedRoutes`) and type `href` props with `Route` or `Route<T>` from `next`; cast `as Route` only for non-literal strings. *Sources:* N-TR ("marked as stable, so you should use `typedRoutes` instead of `experimental.typedRoutes`"; requires TypeScript), N-TS (types `next/link` `href` and `next/navigation` `push`/`replace`/`prefetch`; literal and template-literal hrefs validated; non-literal needs `as Route`; generic `Card<T extends string>({ href }: { href: Route<T> \| URL })`), B-155 (stable in 15.5, works with Turbopack). **[15.5]**
- **TS-9** Map aliases with `paths` written relative to `tsconfig.json` (for example `"@/*": ["./src/*"]`) and no `baseUrl` on TypeScript 6 or later. *Sources:* T-60 ("`baseUrl` is deprecated and will no longer be considered a look-up root"; deprecations removed in TS 7.0; migration example rewrites `paths` to `./src/...`), T-TSCONFIG (`paths` resolve relative to `baseUrl` if set, otherwise to the tsconfig file), N-SRC ("update the `paths` object… to include `src/`"), N-INSTALL (Next.js supports both `paths` and `baseUrl`; its example still shows `baseUrl` — do not copy it on TS ≥ 6).
- **TS-10** Use `import type` / `export type` for type-only imports and re-exports and keep `"isolatedModules": true`, because Next.js compiles each file with SWC. *Sources:* N-TS (version table: v12 "SWC is now used by default to compile TypeScript and TSX"; every doc snippet uses `import type { NextConfig }`, `import type { Metadata }`, `import type { Route }`, `import type { NextRequest }`), N-VITE (`"isolatedModules": true`), T-ISO (single-file transpilers can't use type info; re-exporting a type without `export type` is an error).
- **TS-11** Keep `typescript` at 5.1.0 or later and upgrade `@types/react` and `@types/react-dom` with every Next.js upgrade; on TypeScript 7 leave `experimental.useTypeScriptCli` at its default. *Sources:* N-UP16 / B-16 (minimum TypeScript 5.1.0; "upgrade `@types/react` and `@types/react-dom`"), N-TS (async Server Components need TS ≥ 5.1.3 and `@types/react` ≥ 18.2.8), N-TSCLI (`next build` runs project-local `tsc` by default, supporting TS 6 and enabling TS 7; opting out with TS 7 makes `next build` exit; flag is experimental; diagnostics are raw `tsc`; whole tsconfig project checked incl. tests; `ignoreBuildErrors` skips it), B-163. **[16]** min TS; **[16.3]** TS 7 via CLI checker.
- **TS-12** Lint TypeScript with the ESLint CLI using `eslint-config-next/core-web-vitals` plus `eslint-config-next/typescript` in `eslint.config.mjs`; never call `next lint`. *Sources:* N-ESLINT (`eslint-config-next/typescript` "Adds TypeScript-specific linting rules from typescript-eslint", based on `plugin:@typescript-eslint/recommended`; flat-config example imports `nextVitals` and `nextTs`; `next lint` removed in 16), N-UP16 (`next build` no longer lints). **[16]**

**Route-aware types**

- **TS-13** Type every page with the global `PageProps<'/route'>` helper, passing the route literal exactly as its folder path (dynamic segments included), instead of a hand-written props type. *Source:* N-PAGE ("Page Props Helper": strongly typed `params` and `searchParams` from the route literal; globally available, no import; static routes resolve `params` to `{}`; generated by `next dev`/`next build`/`next typegen`). Verified snippet:
  ```tsx
  export default async function Page(props: PageProps<'/blog/[slug]'>) {
    const { slug } = await props.params
    const query = await props.searchParams
    return <h1>Blog Post: {slug}</h1>
  }
  ```
- **TS-14** Type every layout with `LayoutProps<'/route'>` so `children` and each `@slot` folder arrive typed; never hand-type parallel-route slot props. *Sources:* N-LAYOUT ("Layout Props Helper": typed `params` and named slots inferred from the directory structure; snippet `export default function Layout(props: LayoutProps<'/dashboard'>)` rendering `props.children`; layouts cannot read `searchParams`), B-155 (before/after example: manual `analytics: React.ReactNode` replaced by typed slots).
- **TS-15** Type every Route Handler's second argument with `RouteContext<'/route'>` and its request with `NextRequest` (or `Request`). *Source:* N-ROUTE ("Route Context Helper"; verified snippet `export async function GET(_req: NextRequest, ctx: RouteContext<'/users/[id]'>) { const { id } = await ctx.params; return Response.json({ id }) }`; `context.params` is a promise since v15.0.0-RC).
- **TS-16** Treat `params` and `searchParams` as `Promise`s: `await` them in async Server Components and read them with React `use()` in Client Components; never read them synchronously. *Sources:* N-PAGE / N-LAYOUT / N-ROUTE (props are promises; hand-written type is `params: Promise<{ slug: string }>`), N-UP16 ("Starting with Next.js 16, synchronous access is fully removed" for `params` in layout/page/route/default/OG/icon files, `searchParams` in page, plus `cookies`/`headers`/`draftMode`). **[16]**
- **TS-17** Treat `searchParams` values as `string | string[] | undefined` from a plain object (not `URLSearchParams`) and validate them before use, because the client controls them. *Sources:* N-PAGE (`searchParams: Promise<{ [key: string]: string \| string[] \| undefined }>`; "a plain JavaScript object, not a `URLSearchParams` instance"; using it opts into dynamic rendering), N-SEC ("always validate input from client… form data, URL parameters, headers, and searchParams"; audit: "Folders with brackets are user input. Are params validated?").
- **TS-18** Annotate static metadata as `Metadata` and `generateMetadata` as returning `Metadata` or `Promise<Metadata>`, typing its `parent` argument as `ResolvingMetadata`; detail lives in `routing-and-metadata.md`. *Source:* N-META ("Types" section: `import type { Metadata, ResolvingMetadata } from 'next'`; first argument may be typed with `PageProps<'/route'>` or `LayoutProps<'/route'>`; the built-in TS plugin infers it, explicit typing still allowed).

**Untyped boundaries**

- **TS-19** Type every value that crosses a trust boundary as `unknown` and narrow it with a schema's `safeParse` before use: `request.json()`, `request.formData()`, Server Function arguments, `params`, `searchParams`, `process.env` and third-party JSON. *Sources:* R-USESERVER ("Arguments to Server Functions are fully client-controlled… always treat them as untrusted input"), N-SEC (validate client input), M-REQJSON (`json()` resolves to "anything that can be represented by JSON"; throws `SyntaxError` on invalid JSON), N-FORMS (server-side validation with "a schema validation library like Zod or Valibot" using `safeParse`), N-ROUTE (FormData values are strings — suggests validating), Z-BASICS (`.safeParse()` returns `{ success: true; data }` or `{ success: false; error: ZodError }`; `.parse()` throws).
- **TS-20** Derive static types from schemas with `z.infer<typeof Schema>` (`z.input`/`z.output` when a schema transforms) instead of writing a parallel interface (convention). *Source:* Z-BASICS (`type Player = z.infer<typeof Player>`; `z.input`/`z.output`).
- **TS-21** Check the repo's `zod` major before writing schemas; on Zod 4 use the `error` param (not `invalid_type_error`/`required_error`), `z.flattenError()`/`z.treeifyError()` (not `.flatten()`/`.format()`) and top-level formats such as `z.email()` and `z.url()`. *Sources:* Z-V4 (`invalid_type_error`/`required_error` removed; `message` deprecated for `error`; `.format()`/`.flatten()` deprecated; string formats moved top-level; `z.coerce` input type is now `unknown`, and a missing key with a `z.coerce.*` field errors — use `.default()`), Z-ERR (`z.flattenError()` → `{ formErrors, fieldErrors }`, best for flat forms), N-FORMS (its example still uses Zod 3 `invalid_type_error` and `.flatten()` — don't copy on Zod 4). npm `zod` latest = 4.6.5.
- **TS-22** Type each Server Action explicitly — `(formData: FormData)` or, with `useActionState`, `(prevState: State, formData: FormData): Promise<State>` where `State` is a discriminated union — and return only the minimal serializable data the UI needs; detail lives in `data-fetching-and-mutations.md`. *Sources:* N-FORMS (action receives `FormData`; with `useActionState` the first parameter becomes `prevState`/`initialState` — the guide types it `any`, which this rule forbids), N-USESERVER (typed args `data: { name: string; email: string }`; "constrain return types to only what the caller needs"), N-SEC ("Server Action return values are serialized… Only return what the UI needs"), R-USESERVER (serializable parameter/return types list).
- **TS-23** Give Client Components props types that list only the fields they render, built from serializable values, never a full database-row type. *Sources:* N-SC ("Props passed to Client Components need to be serializable by React"), N-SEC ("BAD: This is a bad props interface because it accepts way more data than the Client Component needs"; audit: "Are the type signatures overly broad?"; functions and classes are blocked from crossing by default).

**Environment variables and the server/client boundary**

- **TS-24** Read server env through one `server-only` module that `safeParse`s `process.env` against a schema and exports a readonly typed result, reporting missing or invalid variable **names** only, never values (convention). *Sources:* N-SEC ("only the Data Access Layer should access `process.env`"), N-SC (`server-only` makes a client import a build-time error), Z-BASICS (`safeParse`), Z-ERR (`z.flattenError().fieldErrors` keyed by field name). Detail on which values may be public: `proxy-auth-and-security.md`.
- **TS-25** Reference every browser-exposed variable with a literal `process.env.NEXT_PUBLIC_NAME` member expression; never `process.env[name]` or a destructured or aliased `process.env` in client code, and treat the value as frozen at build. *Source:* N-ENV (`NEXT_PUBLIC_` values are inlined "at build time"; "dynamic lookups will *not* be inlined" — both `process.env[varName]` and `const env = process.env; env.NEXT_PUBLIC_…`; after build the app "will no longer respond to changes"; non-prefixed vars are server-only), N-SC (non-prefixed vars are replaced with an empty string in the client bundle).
- **TS-26** Treat `experimental.typedEnv` as editor IntelliSense only and never as validation. *Source:* N-TS ("Type IntelliSense for Environment Variables": opt-in `experimental.typedEnv`; generated from variables loaded at development runtime; excludes `.env.production*` unless `next dev` runs with `NODE_ENV=production`).
- **TS-27** Put `import 'server-only'` at the top of every module that reads secrets, the database or server-only APIs, and `import 'client-only'` in modules that touch `window` or other browser-only APIs. *Sources:* N-SC (build-time error on client import; `client-only` counterpart; installing the packages is optional; "Next.js also provides its own type declarations for `server-only` and `client-only`" for configs with `noUncheckedSideEffectImports`), N-SEC (DAL modules start with `import 'server-only'`), T-60 (`noUncheckedSideEffectImports` default `true` in TS 6.0).

**TypeScript language**

- **TS-28** Never write `any` (explicit or implicit): use `unknown` plus narrowing, a generic, or a precise type. *Sources:* T-DODONT ("Don't use `any` as a type unless you are in the process of migrating a JavaScript project to TypeScript… effectively… turn off type checking"; use `unknown` when you don't know the type), T-FN (`unknown` "is safer because it's not legal to do anything with an `unknown` value"), T-EVERYDAY (`any` disables type checking; `noImplicitAny` flags implicit `any`).
- **TS-29** Use `satisfies` to check an object literal (lookup tables, route or plan maps, config records) against a type while keeping its narrow inferred type. *Source:* T-49 (validates "that the type of an expression matches some type, without changing the resulting type"; palette example). Note in file: Next.js docs annotate config as `const nextConfig: NextConfig` — follow the docs there (TS-7).
- **TS-30** Model variant results and UI states as discriminated unions on a literal field (`status`, `kind`, `ok`) and end every `switch` over them with a `never` exhaustiveness check. *Source:* T-NARROW (discriminated unions on `kind`; `default: const _exhaustiveCheck: never = shape; return _exhaustiveCheck`), Z-API (`z.discriminatedUnion("status", [...])`).
- **TS-31** Declare data you pass around as `readonly` (`readonly` properties, `readonly T[]`, `as const` tables) and produce new objects instead of mutating; remember `readonly` is shallow and compile-time only (convention). *Sources:* T-OBJ (`readonly` prevents re-assignment, not deep immutability; `ReadonlyArray<T>` / `readonly T[]`; readonly tuples), T-EVERYDAY (`as const` gives literal types).
- **TS-32** Never use a type assertion (`as T`, non-null `!`) to stand in for validation; the only allowed assertions are `as const` and `as Route` on a computed `href`. *Sources:* T-EVERYDAY ("Type assertions are removed at compile-time… no runtime checking"), N-TS (`as Route` for non-literal hrefs), N-ENV (its `orm.config.ts` uses `process.env.DATABASE_URL!` — validate instead, per TS-24) (convention).
- **TS-33** Suppress a compiler error only with `// @ts-expect-error <reason>` and never with `// @ts-ignore` (convention). *Source:* T-39 (`@ts-expect-error` reports "Unused '@ts-expect-error' directive" once the error is gone; `@ts-ignore` stays silent).
- **TS-34** Treat every `catch` variable as `unknown` and narrow it with `instanceof Error` before reading `.message`. *Sources:* T-TSCONFIG (`useUnknownInCatchVariables` is on under `strict`), T-NARROW (`instanceof` narrowing), N-ROUTE (its webhook example reads `error.message` on the catch variable — a type error under `strict`; don't copy).

### 7.3 Patterns and anti-patterns (code the coder writes; keep APIs exactly as shown)

**Patterns** (`## Patterns`, each `### Pn <title> (TS-x, TS-y)` + one fenced block + ≤2 lines of prose):

P1 `tsconfig.json` — ```json```. Field set taken from N-VITE's Next-compatible `tsconfig.json` (minus Vite-only `useDefineForClassFields`, `allowImportingTsExtensions`, `noUnusedLocals`, `noUnusedParameters`) plus TS-2 flags and TS-9 `paths`. Prose: "drop `src/` from `paths` if the repo has no `src` directory; Next.js may add fields it needs when `next dev`/`next build` run (N-TSCLI: it applies its recommended `tsconfig` settings)".
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "isolatedModules": true,
    "esModuleInterop": true,
    "resolveJsonModule": true,
    "skipLibCheck": true,
    "allowJs": true,
    "forceConsistentCasingInFileNames": true,
    "noEmit": true,
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", ".next/types/**/*.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
```

P2 `next.config.ts` — ```ts``` (exact N-TS snippet):
```ts
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  typedRoutes: true,
}

export default nextConfig
```

P3 type-check scripts — ```json``` (`package.json`; N-CLI command, N-INSTALL lint scripts):
```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "typecheck": "next typegen && tsc --noEmit",
    "lint": "eslint"
  }
}
```

P4 Page with `PageProps` and validated `searchParams` — ```tsx``` (satisfies AC4 PageProps block and AC5 tsx searchParams+await block):
```tsx
import { z } from 'zod'

const Query = z.object({
  q: z.string().max(100).optional(),
  page: z.coerce.number().int().min(1).default(1),
})

export default async function Page(props: PageProps<'/blog/[slug]'>) {
  const { slug } = await props.params
  const parsed = Query.safeParse(await props.searchParams)
  const { q, page } = parsed.success ? parsed.data : { q: undefined, page: 1 }
  return (
    <h1>
      {slug}: page {page} {q ? `(search: ${q})` : null}
    </h1>
  )
}
```
Note: `?page=1&page=2` arrives as `string[]`; `z.coerce.number()` makes it `NaN`, so `safeParse` fails and the fallback applies (Z-V4 coerce input is `unknown`).

P5 Layout with typed slot — ```tsx``` (N-LAYOUT, B-155; N-UP16 for the `default.tsx` requirement):
```tsx
// app/dashboard/@analytics/ exists (with a default.tsx, required in Next.js 16),
// so LayoutProps<'/dashboard'> types props.analytics.
export default function Layout(props: LayoutProps<'/dashboard'>) {
  return (
    <section>
      {props.children}
      {props.analytics}
    </section>
  )
}
```

P6 Route Handler with `RouteContext` and validated JSON — ```ts``` (N-ROUTE + Zod 4):
```ts
import type { NextRequest } from 'next/server'
import { z } from 'zod'

const Rename = z.object({ name: z.string().min(1).max(100) })

export async function PATCH(request: NextRequest, ctx: RouteContext<'/users/[id]'>) {
  const { id } = await ctx.params
  const body: unknown = await request.json().catch(() => null)
  const parsed = Rename.safeParse(body)
  if (!parsed.success) {
    return Response.json({ errors: z.flattenError(parsed.error).fieldErrors }, { status: 400 })
  }
  return Response.json({ id, name: parsed.data.name })
}
```
Prose: status codes, auth and error envelopes live in `route-handlers-and-apis.md`.

P7 Server env module — ```ts``` (`src/lib/env.ts`; TS-24, convention + Z-BASICS/Z-ERR + V-SYSENV for `VERCEL_ENV` values "production, preview, or development", available at build and runtime when system env vars are enabled):
```ts
import 'server-only'
import { z } from 'zod'

const ServerEnvSchema = z.object({
  DATABASE_URL: z.url(),
  VERCEL_ENV: z.enum(['production', 'preview', 'development']).optional(),
})

export type ServerEnv = Readonly<z.infer<typeof ServerEnvSchema>>

export function readServerEnv(source: Readonly<Record<string, string | undefined>> = process.env): ServerEnv {
  const parsed = ServerEnvSchema.safeParse(source)
  if (!parsed.success) {
    const names = Object.keys(z.flattenError(parsed.error).fieldErrors).join(', ')
    throw new Error(`Invalid server environment variables: ${names}`)
  }
  return parsed.data
}
```

P8 Browser env — ```ts``` (TS-25; N-ENV literal access):
```ts
import { z } from 'zod'

const PublicEnvSchema = z.object({ NEXT_PUBLIC_ANALYTICS_ID: z.string().min(1) })

// Each variable is referenced literally so Next.js inlines it at build time.
export const publicEnv = PublicEnvSchema.parse({
  NEXT_PUBLIC_ANALYTICS_ID: process.env.NEXT_PUBLIC_ANALYTICS_ID,
})
```
Prose: `.parse()` throws a `ZodError` at module load if the value is missing (Z-BASICS).

P9 Server Action state as a discriminated union + exhaustive switch — two blocks: ```ts``` (`app/actions.ts`) and ```tsx``` (rendering):
```ts
'use server'

import { z } from 'zod'

const Signup = z.object({ email: z.email() })

export type SignupState =
  | { readonly status: 'idle' }
  | { readonly status: 'invalid'; readonly fieldErrors: Partial<Record<keyof z.infer<typeof Signup>, string[]>> }
  | { readonly status: 'ok' }

export async function signup(_prev: SignupState, formData: FormData): Promise<SignupState> {
  const parsed = Signup.safeParse({ email: formData.get('email') })
  if (!parsed.success) {
    return { status: 'invalid', fieldErrors: z.flattenError(parsed.error).fieldErrors }
  }
  // Authenticate, authorize and write through the server-only Data Access Layer here.
  return { status: 'ok' }
}
```
```tsx
import type { SignupState } from '@/app/actions'

export function SignupMessage({ state }: { state: SignupState }) {
  switch (state.status) {
    case 'idle':
      return null
    case 'invalid':
      return <p role="alert">{state.fieldErrors.email?.[0]}</p>
    case 'ok':
      return <p>Check your inbox.</p>
    default: {
      const _exhaustiveCheck: never = state
      return _exhaustiveCheck
    }
  }
}
```

P10 `satisfies` + `as const` lookup table — ```ts``` (T-49, T-EVERYDAY, T-OBJ):
```ts
type Plan = 'free' | 'pro'

export const PLAN_LIMITS = {
  free: { projects: 3 },
  pro: { projects: 50 },
} as const satisfies Record<Plan, { readonly projects: number }>
```

**Anti-patterns** (`## Anti-patterns`, ≥ 3 required; write all 7, each `### <title> (TS-x)` then `**Don't**` + fence, then `**Do**` + fence, adapting markers to the merged contract):

| # | Don't (fence) | Do (fence) | Rules |
| --- | --- | --- | --- |
| A1 | `export default function Page({ params }: { params: { slug: string } }) { return <h1>{params.slug}</h1> }` (sync, hand-typed; removed in 16) | `export default async function Page(props: PageProps<'/blog/[slug]'>) { const { slug } = await props.params; … }` | TS-13, TS-16 |
| A2 | `const user = (await request.json()) as User` | `const body: unknown = await request.json().catch(() => null); const parsed = UserSchema.safeParse(body); if (!parsed.success) return Response.json(…, { status: 400 })` | TS-19, TS-32 |
| A3 | `typescript: { ignoreBuildErrors: true }` in `next.config.ts` | fix the errors; CI runs `next typegen && tsc --noEmit` (json scripts block) | TS-5, TS-6 |
| A4 | `const id = process.env[\`NEXT_PUBLIC_${key}\`]` in a Client Component | `const id = process.env.NEXT_PUBLIC_ANALYTICS_ID` | TS-25 |
| A5 | `catch (error) { return new Response(\`Webhook error: ${error.message}\`, { status: 400 }) }` (copied from N-ROUTE; `error` is `unknown`) | `catch (error) { const message = error instanceof Error ? error.message : 'Unknown error'; … }` | TS-34 |
| A6 | `export async function createUser(initialState: any, formData: FormData)` (copied from N-FORMS) | `export async function createUser(prev: CreateUserState, formData: FormData): Promise<CreateUserState>` | TS-22, TS-28 |
| A7 | json `{ "compilerOptions": { "baseUrl": "src/", "paths": { "@/*": ["*"] } } }` (N-INSTALL style; deprecated TS 6, removed TS 7) | json `{ "compilerOptions": { "paths": { "@/*": ["./src/*"] } } }` | TS-9 |

Each Don't/Do line must cite its source link in one sentence above the pair (e.g. "The Route Handler reference's webhook example does this — [route.js](…)").

### 7.4 Version notes content (`## Version notes`, names **Next.js 16**)

1. **[16]** Synchronous access to `params` (page, layout, route, default, `opengraph-image`, `twitter-image`, `icon`, `apple-icon`), `searchParams`, `cookies()`, `headers()` and `draftMode()` is removed; codemod `npx @next/codemod@canary next-async-request-api .`; `npx next typegen` generates `PageProps`/`LayoutProps`/`RouteContext` for the migration. → N-UP16, B-16.
2. **[16]** Image-generating functions in `opengraph-image`/`twitter-image`/`icon`/`apple-icon` receive `params` and `id` as promises (`id` is `Promise<string>` with `generateImageMetadata`, which itself keeps synchronous `params`); `sitemap` receives `id` as a promise. → N-UP16. Detail: `routing-and-metadata.md`.
3. **[16]** Minimum TypeScript 5.1.0 (Node.js 20.9). → N-UP16, B-16.
4. **[16]** `next lint` and the `eslint` config option are removed; `next build` no longer lints; `@next/eslint-plugin-next` defaults to flat config. → N-UP16, N-ESLINT.
5. **[16]** `revalidateTag(tag)` without a `cacheLife` profile is deprecated "and will produce a TypeScript error". → N-UP16. Detail: `rendering-and-caching.md`.
6. **[16]** `serverRuntimeConfig` / `publicRuntimeConfig` are removed — use environment variables (TS-24, TS-25). → N-UP16.
7. **[16]** `middleware.ts` → `proxy.ts`, exported function `proxy`. → N-UP16. Detail: `proxy-auth-and-security.md`.
8. **[15.5, current]** `typedRoutes` stable at the top level (Turbopack supported), route props helpers, `next typegen`, and route export validation via `satisfies`. These predate 16; the 16 upgrade guide relies on them. → B-155, N-TR, N-CLI.
9. **[16.3]** `next build` type-checks with the project-local `tsc` CLI by default, enabling TypeScript 7 (whose JavaScript compiler API isn't available); the checker covers the whole `tsconfig` project and prints raw `tsc` diagnostics. → B-163, N-TSCLI, N-TS.

### 7.5 Review checklist content (`## Review checklist`, each `- [ ]` names its rule)

`tsconfig` has `"strict": true` and no strict flag off (TS-1) · `noUncheckedIndexedAccess`, `noImplicitOverride`, `noFallthroughCasesInSwitch` on (TS-2) · `next-env.d.ts` gitignored, unedited, included (TS-4) · type gate runs `next typegen` before `tsc --noEmit` (TS-5) · no `ignoreBuildErrors: true`, no relaxed `tsconfigPath` (TS-6) · `next.config.ts` typed with `NextConfig` (TS-7) · `typedRoutes` on, `as Route` only on computed hrefs (TS-8, TS-32) · no `baseUrl` on TS ≥ 6 (TS-9) · pages/layouts/handlers use `PageProps`/`LayoutProps`/`RouteContext` (TS-13, TS-14, TS-15) · `params`/`searchParams` awaited, never sync (TS-16) · every boundary value `unknown` + `safeParse` (TS-17, TS-19) · Zod API matches installed major (TS-21) · Server Action signatures/state typed, no `any` (TS-22) · Client props minimal and serializable (TS-23) · env read via validated `server-only` module, errors name variables only (TS-24) · `NEXT_PUBLIC_` read literally (TS-25) · secret-touching modules import `server-only` (TS-27) · no `any`, no `@ts-ignore` (TS-28, TS-33) · unions end in a `never` check (TS-30) · `catch` narrows with `instanceof Error` (TS-34).

### 7.6 Scope content (`## Scope`)

Owns: `tsconfig.json`, TS plugin, `next-env.d.ts`, `next typegen`, `next.config.ts` typing, typed routes, route-aware helper types, async `params`/`searchParams` typing, typing Server Actions and Route Handlers at the signature level, the general boundary-validation rule, env **typing/validation**, `server-only`/`client-only`, TypeScript-language rules. Links out (relative): `routing-and-metadata.md` (metadata objects, routes), `data-fetching-and-mutations.md` (Server Actions/forms in depth), `route-handlers-and-apis.md` (handler design), `proxy-auth-and-security.md` (which values may be public, secrets), `rendering-and-caching.md` (`connection()`, caching), `testing-and-observability.md` (test setup). Also link `../nextjs.md`.

## 8. Not confirmed by the docs (goes to `## Not confirmed by the docs` with URLs checked)

1. The exact `tsconfig.json` that `create-next-app` 16.3 writes (target, lib, `include` entries). Checked: N-TS, N-INSTALL, N-VITE. P1 is labelled "bmn's recommended file", not "the create-next-app default".
2. Whether `.next/dev/types/**/*.ts` belongs in `include`: N-CLI says `next typegen` writes `.next/dev/types` in development and N-TSCLI says the CLI checker checks it "when included", but no page tells you to add it. Checked: N-CLI, N-TSCLI, N-TS.
3. A nextjs.org example of `paths` without `baseUrl`: Next docs state support for both but only show `baseUrl`. TS-9 rests on typescriptlang.org (T-60, T-TSCONFIG). Checked: N-INSTALL, N-SRC.
4. Which `tsconfig` fields Next.js rewrites when it "applies its recommended tsconfig settings". Checked: N-TSCLI, N-TS.
5. Whether TS 6's default `"types": []` requires `"types": ["node"]` in a Next.js project for `process`/`process.env` typing. Checked: T-60, N-TS, N-ENV.
6. A Next.js- or Vercel-recommended env-validation library (e.g. `@t3-oss/env-nextjs`, npm 0.13.11): none found; TS-24 is a convention. Checked: N-ENV, N-SEC, V-SYSENV.
7. Typing `process.env` by declaration-merging `NodeJS.ProcessEnv`: not shown on any allowed-host page checked. Checked: N-ENV, N-TS.
8. The Next.js 16 blog's `--experimental-next-config-strip-types` flag vs the current docs' automatic `process.features.typescript` detection: current status of the flag not confirmed. Checked: B-16, N-TS.
9. Whether `Route` also types `redirect()`/`permanentRedirect()`: N-TS lists only `next/link` `href` and `push`/`replace`/`prefetch`. Checked: N-TS, N-TR.
10. Whether `eslint-config-next/typescript` errors on explicit `any`: N-ESLINT only says it uses `plugin:@typescript-eslint/recommended`; typescript-eslint.io is not an allowed host. Checked: N-ESLINT.
11. Whether `exactOptionalPropertyTypes` works cleanly with Next.js's generated types and `Metadata`: TS documents the flag; no Next page addresses it, so it is not required by TS-2. Checked: N-TS, N-META, https://www.typescriptlang.org/tsconfig/ (add `https://www.typescriptlang.org/tsconfig/exactOptionalPropertyTypes.html` to Sources only if linked).

## 9. Evidence file contents (`evidence/sources-verified.md`)

A table `URL | Fetched | Backs` with one row per URL in the final `## Sources`, Fetched = `2026-10-04 (live, this run)`, Backs = the TS rule ids / pattern ids / section from §7 (e.g. N-TS → TS-3, TS-4, TS-5, TS-7, TS-8, TS-10, TS-11, TS-26, TS-32, P2, Version note 9). Generate it **from the finished file's `## Sources`** so the sets match; validation runs the one-off equality check.

## Assumptions

- **A1** The as-of line, H1, Sources bullet format and "Don't" item format come from the merged skeleton; this plan's formats are defaults. If they differ, the contract wins and the difference is logged in `validation.md`.
- **A2** Latest stable Next.js is 16.3.8 (npm `latest`, docs `version: 16.3.8`, 2026-10-04). If `R/nextjs.md` records a different patch, the file copies `R/nextjs.md`'s line verbatim; the major (16) is unaffected.
- **A3** AC3's term written ```any``` is tested as `` `any` `` (with backticks). A bare `any` would match "many" and test nothing.
- **A4** Rules TS-2, TS-6 (second half), TS-20, TS-24, TS-31, TS-32, TS-33 are house rules. Each carries `(convention)` plus the link that backs the underlying language/library fact.
- **A5** Patterns use Zod 4, which is npm `latest` (4.6.5). The Next.js forms guide's Zod 3 snippet is cited as an anti-pattern on Zod 4, not as wrong Next.js behaviour.
- **A6** P1 keeps `allowJs: true` and `target`/`lib` `ES2020` from N-VITE rather than inventing newer values; whether create-next-app writes other values is item 1 of §8.
- **A7** `test_typescript_topic_examples_never_use_any` scans only `## Patterns` blocks; `## Anti-patterns` Don't blocks deliberately contain `any`.
- **A8** No new dependency or helper: Zod is the validator the Next.js forms guide names (with Valibot); `@t3-oss/env-nextjs` exists on npm but no allowed-host doc recommends it, so it is not suggested.
