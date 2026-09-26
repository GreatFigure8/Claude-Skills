# Stack routing — which skills a story loads

The stack-scout classifies the target repo and the story (for a greenfield system, from
the story alone) and writes `stack.md`. Every planner, coder, reviewer and fixer loads
exactly the skills routed here — via `Skill({skill: "<name>"})` — **before** writing or
judging code.

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

| Kind | Build with | Review lenses (python-library-quality:*) |
| --- | --- | --- |
| `web-app` / `api` | `python-web-app:building-python-web-apps`, `python-web-app:wiring-application-config`; `python-web-app:rendering-untrusted-content` if it renders stored/user content | `auditing-python-security`, `rendering-untrusted-content`, `verifying-external-behavior`, `guarding-destructive-operations`, `designing-python-apis` (for the API surface) |
| `mcp-server` | `python-mcp-servers:building-python-mcp-servers`, `python-mcp-servers:wiring-application-config`, `python-mcp-servers:shipping-across-surfaces` | `auditing-python-security`, `verifying-external-behavior`, `guarding-destructive-operations`, `designing-python-apis` |
| `library` / `cli` | `python-library-quality:designing-python-apis`, `python-library-quality:deferring-heavy-dependencies` | `auditing-python-security`, `designing-python-apis`, `optimizing-python-performance`, `guarding-destructive-operations`, `keeping-git-repos-clean` |
| any + `llm` | add `python-llm-features:building-llm-backed-features`, `python-llm-features:reporting-derived-metrics`, `claude-api` | add `verifying-external-behavior` |
| any + CI workflows touched | add `python-library-quality:running-github-actions-efficiently` | same |
| TypeScript / Next.js repo | `nextjs-fullstack-standards` (the python skills don't apply to `.ts`/`.tsx`) | `nextjs-fullstack-standards` lens |

`python-library-quality:keeping-git-repos-clean` is loaded by every merger — no `.env`,
build output or scratch DB ever lands on `dev`.

If a routed skill isn't in the session's skill list, say so in `stack.md` and continue with
the rest — never approximate a skill from memory.

## Test surfaces (drives TEST)

| Condition | Surface | Tooling |
| --- | --- | --- |
| always | unit + integration | `pytest` (+ `pytest-cov`), or the repo's runner |
| `ui` | browser | `pytest-playwright`, headless Chromium, app started locally |
| `api` / `web-app` | HTTP black-box | `httpx` against the running server |
| `mcp-server` | MCP black-box | `mcp` client session over stdio: list tools, call each new/changed tool |
| `supabase` | DB | local `supabase start`; `supabase db reset` (local) applies migrations |
