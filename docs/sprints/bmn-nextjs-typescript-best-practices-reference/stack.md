# Stack — bmn-nextjs-typescript-best-practices-reference

- **kind:** `library` (Claude Code skills repo: Markdown skill content + Python/shell helpers). No app, no UI.
- **ui:** false (`ui_screens: []`) — DESIGN skipped. **supabase:** false. **vercel:** false (no `vercel.json`, no `.vercel/`). **llm:** false.
- **dev_push_deploys:** false — no `.github/workflows`, no vercel.json, no supabase/ (only CI-like file is `Skills/dev-bother-me-nope/hooks/hooks.json`, a local PreToolUse guard).
- **Default branch:** `main`; `origin/dev` exists (dev_base `d8b709f`).
- **Tooling:** docker ✓, supabase CLI ✓, playwright ✓ (none needed for this run).

## Gates

| Gate | Command |
| --- | --- |
| test | `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q` (bare python3 has no pytest; ~476 tests, ~110 s) |
| lint | `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` (changed `.py`); `shellcheck` on changed `.sh`. No markdown lint / link checker exists. |
| types | none |

## Routing

- **Build skills:** none routed by stack-routing.md (the repo is Markdown; the python skill sets don't apply to prose).
- **`nextjs-fullstack-standards`:** NOT loadable — not in the session skill list, not under `~/.claude/plugins`, not in this repo (`docs/epics/18-mandate-nextjs-fullstack-standards/plan.md` calls it `anthropic-skills:nextjs-fullstack-standards`; no copy on disk). Never approximated from memory.
- **Review lenses:** `/code-review` at `high` on the Markdown + tests; factual claims are the main risk, so the reviewer spot-checks claims against the cited nextjs.org / vercel.com pages.

## Wiring points (from the scout)

- `references/stack-routing.md` — the TypeScript / Next.js row (build + review lens).
- `SKILL.md` — the REVIEW① step that names `nextjs-fullstack-standards` for TypeScript, and the references list.
- `references/briefs.md` — planner, coder, reviewer, fixer briefs.
- Version: `Skills/dev-bother-me-nope/.claude-plugin/plugin.json` (last runs bumped 1.4.0 → 1.5.0 → 1.6.0); `test_plugin_json_is_version_1_6_0` asserts the exact version and must move with a bump. No CHANGELOG; marketplace.json has no version.
- Tests: `Skills/dev-bother-me-nope/assets/tests/test_skill_text_rules.py` (text-presence tests; `OWNED_MARKDOWN` list excludes nextjs.md today).

## Assumptions (orchestrator)

1. `references/nextjs.md` stays where Jonathan put it and becomes the repo-owned Next.js + TypeScript standard that bmn's TypeScript routing **reads** (Read tool, not Skill tool). `nextjs-fullstack-standards` is still loaded too whenever a session has it; nextjs.md does not depend on it.
2. Jonathan's folder-structure section is kept (cleaned up, not replaced) as the canonical layout for new projects.
3. "Best on the planet" × the 800-line file cap ⇒ `nextjs.md` is the entry point (principles, the folder structure, a decision index) and deep topics live in `references/nextjs/<topic>.md`, each ≤ 800 lines.
4. Every factual/API claim is grounded in nextjs.org / vercel.com (react.dev and typescriptlang.org allowed for React/TS language facts), verified live by web search/fetch during this run, with a **Sources** list per file and an "as of" Next.js version + date (2026-10-04). Anything a doc doesn't confirm is left out, not guessed.
5. The plugin version bumps once (one story owns it) and its pinned test moves with it.
6. Jonathan's main checkout still holds the untracked draft `nextjs.md`; it is not touched. After this lands on `dev`, his `git pull` there will refuse to overwrite that untracked file until he deletes or moves it — called out in the report.
