# Stack routing — which skills and references a story loads

The stack-scout classifies the target repo and the story (for a greenfield system, from
the story alone) and writes `stack.md`. Every planner, coder, reviewer and fixer loads
exactly the skills routed here — via `Skill({skill: "<name>"})` — and reads every reference
file routed here, **before** writing or judging code.

## Classify

| Signal | `kind` |
| --- | --- |
| HTTP routes, FastAPI/Flask/Django, server-rendered pages, SaaS, dashboard | `web-app` (has UI) or `api` (JSON only) |
| "MCP server", tools exposed to an LLM client, `mcp`/`fastmcp` dependency | `mcp-server` |
| Importable package, `pyproject.toml` with no server entrypoint, SDK, utility | `library` |
| Console entrypoint, `argparse`/`typer`/`click` | `cli` (library rules apply) |
| More than one of the above | `mixed` — route each story by the code it touches |

Also record: `ui` (serves HTML or has a frontend), `supabase` (`supabase/` dir,
`supabase-py`/`@supabase/*` dep, or the story says so), `vercel` (`vercel.json`, `.vercel/`,
Next.js on Vercel, or the story says so), `llm` (calls an LLM API).

Greenfield with no stated stack: Python 3.12+, `uv`, FastAPI for anything served,
pytest + pytest-playwright, ruff + mypy/pyright. Log it as an assumption.

## Route

| Kind | Build with | Review lenses (python-library-quality:*) | Read |
| --- | --- | --- | --- |
| `web-app` / `api` | `python-web-app:building-python-web-apps`, `python-web-app:wiring-application-config`; `python-web-app:rendering-untrusted-content` if it renders stored/user content | `auditing-python-security`, `rendering-untrusted-content`, `verifying-external-behavior`, `guarding-destructive-operations`, `designing-python-apis` (for the API surface) | — |
| `mcp-server` | `python-mcp-servers:building-python-mcp-servers`, `python-mcp-servers:wiring-application-config`, `python-mcp-servers:shipping-across-surfaces` | `auditing-python-security`, `verifying-external-behavior`, `guarding-destructive-operations`, `designing-python-apis` | — |
| `library` / `cli` | `python-library-quality:designing-python-apis`, `python-library-quality:deferring-heavy-dependencies` | `auditing-python-security`, `designing-python-apis`, `optimizing-python-performance`, `guarding-destructive-operations`, `keeping-git-repos-clean` | — |
| any + `llm` | add `python-llm-features:building-llm-backed-features`, `python-llm-features:reporting-derived-metrics`, `claude-api` | add `verifying-external-behavior` | — |
| any + CI workflows touched | add `python-library-quality:running-github-actions-efficiently` | same | — |
| TypeScript / Next.js repo | `nextjs-fullstack-standards`, when the session has it (the python skills don't apply to `.ts`/`.tsx`) | `nextjs-fullstack-standards` lens, when the session has it | `references/nextjs.md`, then the topic files its Topic index routes the story to; review findings cite its rule ids |

The scout maps the columns onto its JSON: **Build with** → `routed_build_skills[]` and
**Review lenses** → `routed_review_lenses[]`, both loaded with `Skill(...)`; **Read** →
`routed_references[]`, absolute paths read with the Read tool. A reference file never goes in
a skill list: `Skill(...)` takes a skill name, not a file path.

Reference files such as `references/nextjs.md` are read with the Read tool, not loaded with
`Skill(...)`. They ship inside this plugin, so they are always available. Workers get the
absolute path `${CLAUDE_PLUGIN_ROOT}/skills/dev-bother-me-nope/references/nextjs.md`.

`python-library-quality:keeping-git-repos-clean` is loaded by every merger — no `.env`,
build output or scratch DB ever lands on `dev`.

If a routed skill isn't in the session's skill list, say so in `stack.md` and continue with
the rest — never approximate a skill from memory.

## Gates — scoped per agent, full once per phase

The scout reports `gates{lint, types, related, test, build}`. Coders, planner-coders, fixers,
integrators and mergers run the **scoped gates**: lint, type-check, and `related` (the tests
for the files they touched or the merge changed). Only the tester runs `test` (the full suite,
with coverage) and `build`, once per TEST phase. Python default for `related`: pytest on the
test files of the touched modules (`pytest tests/test_<module>.py …`).

## Test surfaces (drives TEST)

| Condition | Surface | Tooling |
| --- | --- | --- |
| always | unit + integration | `pytest` (+ `pytest-cov`), or the repo's runner |
| `ui` | browser | `pytest-playwright`, headless Chromium, app started locally |
| `api` / `web-app` | HTTP black-box | `httpx` against the running server |
| `mcp-server` | MCP black-box | `mcp` client session over stdio: list tools, call each new/changed tool |
| `supabase` | DB | local `supabase start`; `supabase db reset` (local) applies migrations |
| TypeScript / Next.js repo (replaces the python tooling above) | unit + integration, browser, HTTP black-box, gates | unit + integration: the repo's runner (Vitest or Jest) with coverage; browser (`ui`): Playwright (`@playwright/test`) against `next build && next start` run locally; HTTP black-box: Playwright's `request` fixture against the same `webServer` (TEST-15); gates, in order: `next typegen && tsc --noEmit` (`next typegen` writes the route types and `next-env.d.ts` that `tsc` needs), then the repo's configured linter (`eslint .` with `eslint-config-next`, or `biome check .` in a repo that already uses Biome; `next lint` was removed in Next.js 16), then `next build` (TEST only: coder, fixer, integrator and merger gates stop after the linter plus `vitest related --run <files>` / `jest --findRelatedTests <files>`). Details: [nextjs/testing-and-observability.md](nextjs/testing-and-observability.md) |
