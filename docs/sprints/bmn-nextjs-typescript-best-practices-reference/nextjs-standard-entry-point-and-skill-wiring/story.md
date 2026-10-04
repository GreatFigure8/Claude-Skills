# The Next.js + TypeScript standard has an entry point, an index of topic files, and is wired into every bmn TypeScript story

**Slug:** `nextjs-standard-entry-point-and-skill-wiring`
**Run:** `bmn-nextjs-typescript-best-practices-reference` · plugin `Skills/dev-bother-me-nope/`
**Role:** walking skeleton. Every topic story depends on this one.

## Story

**As** a dev-bother-me-nope planner, coder, reviewer or fixer working in a Next.js +
TypeScript repo,
**I want** one entry point, `references/nextjs.md`, that gives me the canonical folder layout,
the non-negotiable rules, an index that sends me to the right deep-topic file, and the
contract every topic file follows,
**so that** I read only what my story needs, cite rule ids in plans and findings, and never
work from memory on an API that changed in the latest major.

## Context

Paths are relative to the run worktree. `R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`.

- `R/nextjs.md` is Jonathan's 48-line draft: an H1 "NextJS Custom Skill" and a "Folder
  Structure" tree for new projects. The tree mixes box-drawing characters with ASCII `|`, and
  its last lines are misaligned (`| |`, `| └── tests/`, a bare `|`). Some nesting is
  ambiguous: `(dashboard)/` → `dashboard/` → `page.tsx` and `api/` → `webhooks/` → `route.ts`
  are drawn at the same depth. Jonathan wants this tree kept as the canonical layout and its
  formatting cleaned up, not replaced.
- `nextjs-fullstack-standards` isn't loadable on this machine (stack.md, Routing).
  `R/nextjs.md` becomes the repo-owned, dated standard. Agents read it with the Read tool, so
  it is always available.
- Wiring points:
  - `R/stack-routing.md`: the "TypeScript / Next.js repo" row of the Route table (build and
    review-lens cells), plus the intro saying routed skills load via `Skill(...)`.
  - `skills/dev-bother-me-nope/SKILL.md`: "### 0 · INTAKE" (stack classification and
    routing) and "### 6 · REVIEW①", which names `nextjs-fullstack-standards` for TypeScript.
    SKILL.md has no separate references list. It links reference files inline, and this
    story follows that pattern.
  - `R/briefs.md`: the `planner`, `coder`, `reviewer` and `fixer` brief code blocks. The
    reviewer already says to "add nextjs-fullstack-standards for any TypeScript in the diff".
    Plugin files are addressed as `${CLAUDE_PLUGIN_ROOT}/...`, and the orchestrator fills that
    in for workers (SKILL.md, "Orchestrator discipline").
  - `Skills/dev-bother-me-nope/.claude-plugin/plugin.json` is at `1.6.0`.
    `test_plugin_json_is_version_1_6_0` in
    `Skills/dev-bother-me-nope/assets/tests/test_skill_text_rules.py` pins it.
- Test gate:
  `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`.
  Lint: `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope`. The suite is
  offline: no test may touch the network.
- The nine topic files and their rule-id prefixes are fixed here, so topic stories can build
  in parallel without touching shared files:

  | File (`R/nextjs/`) | Prefix | Owning story |
  | --- | --- | --- |
  | `typescript.md` | `TS` | `typescript-config-and-typing-patterns` |
  | `routing-and-metadata.md` | `RT` | `app-router-routing-and-metadata` |
  | `rendering-and-caching.md` | `RC` | `rendering-caching-and-streaming-ssr` |
  | `data-fetching-and-mutations.md` | `DF` | `data-fetching-server-actions-and-forms` |
  | `route-handlers-and-apis.md` | `API` | `route-handlers-and-api-design` |
  | `sse-and-streaming.md` | `SSE` | `server-sent-events-and-streaming-responses` |
  | `proxy-auth-and-security.md` | `SEC` | `proxy-auth-and-security` |
  | `performance-and-vercel.md` | `PERF` | `performance-and-vercel-platform` |
  | `testing-and-observability.md` | `TEST` | `testing-errors-and-observability` |

## Acceptance criteria

All tests live in the new `Skills/dev-bother-me-nope/assets/tests/test_nextjs_reference.py`
unless stated. Shared parsing helpers live in the new non-collected module
`Skills/dev-bother-me-nope/assets/tests/nextjs_doc_helpers.py`, which topic stories import.

1. **[unit]** **Helpers module.** `nextjs_doc_helpers.py` exposes at least the following.
   - Constants: `REFERENCES_DIR`, `NEXTJS_MD`, `TOPICS_DIR`, `TOPICS` (an ordered mapping of
     file name to `(prefix, owning slug)`, matching the table above exactly),
     `ALLOWED_SOURCE_HOSTS` and `AS_OF_DATE = "2026-10-04"`.
   - Functions: `read(path)`, `is_stub(text)`, `section(text, heading)`,
     `code_blocks(text, langs)`, `has_block_with(text, *needles, langs=("ts", "tsx"))`,
     `rule_items(text)` (returns `(rule_id, item_text)` pairs from `## Rules`),
     `source_urls(text)`, `all_urls(text)`, `as_of_version(text)` and
     `missing_terms(text, terms)`.
   - Matching rules: `code_blocks` returns `(lang, body)` pairs. `has_block_with` is an
     exact-substring match, true when one block holds every needle. `missing_terms` is a
     case-insensitive substring match over the whole file.

   Each has a unit test on inline sample text: a stub, a well-formed topic, a rule without a
   citation, a bare code fence and a disallowed host. It is stdlib-only, ruff-clean, and has
   no function over 50 lines.
2. **[unit]** **Entry point shape.** `R/nextjs.md` starts with the H1
   `# Next.js + TypeScript standard`. The next non-blank line is the as-of line,
   `> As of Next.js <version>, verified 2026-10-04.`, where `<version>` is the latest stable
   Next.js release read live from nextjs.org (docs version picker or blog) on 2026-10-04. Its
   H2 sections appear in this order: `How bmn agents use this`, `Non-negotiables`,
   `Folder structure`, `Topic index`, `Authoring contract`, `Version notes`, `Sources`.
   Nothing else is between the H1 and the as-of line.
3. **[unit]** **Folder structure kept and cleaned.** The tree sits in one ```` ```text ````
   fence under `## Folder structure`. It keeps every entry from Jonathan's draft: `my-app/`,
   `src/`, `app/`, `(auth)/`, `login/`, `page.tsx`, `layout.tsx`, `(dashboard)/`,
   `dashboard/`, `api/`, `webhooks/`, `route.ts`, `globals.css`, `features/`, `auth/`,
   `components/`, `hooks/`, `services/`, `tests/`, `billing/`, `shared/`, `utils/`, `types/`,
   `lib/`, `prisma.ts`, `actions/`, `auth.ts`, `public/`, `next.config.ts` and
   `tsconfig.json`. Each keeps its draft comment meaning.
   - Every non-blank tree line below the root either matches
     `^(?:│   |    )*(?:├── |└── )\S` or is a spacer made only of `│` and spaces. The tree
     uses box-drawing characters only, no ASCII `|` connector, and every comment is
     introduced by ` # `.
   - The page and the handler are nested: `(dashboard)/dashboard/page.tsx` and
     `api/webhooks/route.ts`. `tests/` for pages and routes sits directly under `src/`.
   - Next.js special files whose location the docs confirm may be added, such as
     `src/proxy.ts` and `src/instrumentation.ts`. Each one is marked `# added:` with its doc
     link listed in Sources. No draft entry is moved or removed.
   - A `### Placement rules` list follows the tree. Each item is either a docs fact with a
     link (for example, route groups don't affect the URL) or tagged `(convention)`. It says
     the layout is canonical for **new** projects, and that an existing repo keeps its
     established layout.
4. **[unit]** **Topic index.** `## Topic index` is a table with one row per topic file, in
   the order of `TOPICS`. Its columns are `File`, `Prefix`, `Covers` and `Read when`. Each
   row links the file with a relative link `nextjs/<file>`. A test asserts:
   - the rows match `TOPICS` exactly (file, prefix, order);
   - every `.md` file in `R/nextjs/` has a row (no orphans);
   - every linked file exists.
5. **[unit]** **Topic stubs.** This story creates all nine files in `R/nextjs/`, each as a
   stub. A stub holds:
   - the topic H1;
   - the same as-of line as `R/nextjs.md`;
   - the marker line ``> Stub: pending story `<owning slug>`.``;
   - a `## Sources` section with the nextjs.org URL used to read the version.

   `is_stub` detects the marker. A test asserts each stub names its owning slug from
   `TOPICS`. Topic stories replace the whole stub, so this story never writes topic content.
6. **[unit]** **Authoring contract.** `## Authoring contract` in `R/nextjs.md` defines the
   contract below, and the generic tests enforce it for every non-stub topic file. A stub is
   skipped with a reason, and nothing else is skipped.
   - **Sections, in order:** H1, then the as-of line, then these H2 sections: `Scope`,
     `Rules`, `Patterns`, `Anti-patterns`, `Version notes`, `Review checklist`, an optional
     `Not confirmed by the docs`, and `Sources` last.
   - **Rule format:** each rule is a numbered item
     `N. **<PREFIX>-<n>** <imperative sentence> …`. The prefix is the file's own, ids are
     unique across all topic files and start at 1 with no gaps, and the first word after the
     id isn't a subject word (`The`, `This`, `It`, `You`, `We`, `There`, `A`, `An`).
   - **Citations:** every rule item contains either a link to an `ALLOWED_SOURCE_HOSTS` URL
     or the literal tag `(convention)`. Placing that link or tag in the item's text is
     enough. A file cites only its own rule ids, and refers to
     another topic by linking its file.
   - **Floors:** at least 12 rules; at least 4 ```` ```ts ````/```` ```tsx ```` fences;
     `## Anti-patterns` has at least 3 "Don't" items, each with a fenced block;
     `## Review checklist` has at least 8 `- [ ]` items.
   - **Version notes:** `## Version notes` names `Next.js <major>`, where `<major>` comes from
     the as-of version.
   - **Not confirmed by the docs:** this section lists what was checked and not confirmed,
     with the URLs checked. Nothing in it is stated as a rule.
7. **[unit]** **Sources and grounding.** These checks apply to `R/nextjs.md` and all nine
   topic files, stubs included:
   - `## Sources` is a bullet list of unique `https://` URLs;
   - every URL's host is in `ALLOWED_SOURCE_HOSTS`;
   - every URL in the file's prose also appears in `## Sources`. Prose here means everything
     outside fenced code blocks and inline code spans, so placeholder URLs such as
     `https://example.com` inside code are exempt.

   `ALLOWED_SOURCE_HOSTS` is exactly: `nextjs.org`, `vercel.com`, `react.dev`,
   `typescriptlang.org`, `www.typescriptlang.org`, `developer.mozilla.org`,
   `html.spec.whatwg.org`, `zod.dev`, `vitest.dev` and `playwright.dev`. `R/nextjs.md` and
   every non-stub topic file cite at least 3 URLs on `nextjs.org` or `vercel.com`. The
   contract says only nextjs.org or vercel.com may back a Next.js or Vercel behaviour claim.
   The other hosts are for the React, TypeScript, web-platform or library facts they own.
8. **[unit]** **As-of consistency.** Every topic file's as-of line parses with
   `as_of_version`, and its version equals the one in `R/nextjs.md`. The date is
   `2026-10-04` everywhere.
9. **[unit]** **File hygiene.** These checks apply to all ten files:
   - each file is at most 800 lines;
   - every code fence opener has a language tag, so there's no bare ```` ``` ````;
   - every relative Markdown link resolves to an existing file (the anchor part is ignored);
   - no file contains `TODO` or `TBD`.
10. **[unit]** **Entry point content.**
    - `## Non-negotiables` has at most 15 numbered items. Each links at least one
      `nextjs/<file>` and carries a source link or `(convention)`.
    - `## How bmn agents use this` covers how each agent reads the file:
      - the planner reads `nextjs.md` plus the topic files the index routes the story to, and
        lists the rule ids it applies in the plan;
      - the coder follows those rules;
      - the reviewer cites the violated rule id in each finding;
      - the fixer names the rule id its fix restores.
    - The same section states precedence: `nextjs.md` wins over `nextjs-fullstack-standards`
      on a conflict, and the repo's own established conventions win for an existing repo's
      layout.
    - `## Version notes` lists the headline changes of the latest major. Each item has a
      source link and points to the topic file that owns the detail.
11. **[unit]** **stack-routing.md.** In the `TypeScript / Next.js repo` row:
    - the "Build with" cell and the review-lens cell each name `references/nextjs.md`;
    - `nextjs-fullstack-standards` stays named, "when the session has it".

    A sentence under the table says reference files are read with the Read tool, not loaded
    with `Skill(...)`. The "never approximate a skill from memory" sentence is unchanged.
12. **[unit]** **SKILL.md.** These sections each link
    `[references/nextjs.md](references/nextjs.md)` for TypeScript:
    - "### 0 · INTAKE", at the stack-routing step;
    - "### 6 · REVIEW①", next to `nextjs-fullstack-standards`.

    The frontmatter description is unchanged.
13. **[unit]** **briefs.md.** The planner, coder, reviewer and fixer brief code blocks each
    contain `${CLAUDE_PLUGIN_ROOT}/skills/dev-bother-me-nope/references/nextjs.md`, scoped to
    TypeScript/Next.js stories.
    - The planner and reviewer blocks contain `rule id`.
    - The reviewer block still contains `nextjs-fullstack-standards`.

    No other brief changes. `test_squash_is_only_ever_forbidden` and
    `test_every_helper_invocation_uses_the_plugin_root_form` still pass.
14. **[unit]** **Version bump.** `plugin.json` is `1.7.0`.
    `test_plugin_json_is_version_1_6_0` is renamed `test_plugin_json_is_version_1_7_0` and
    asserts `1.7.0`. Nothing else in `plugin.json` changes.
15. **[unit]** **Grounding evidence.** `docs/sprints/bmn-nextjs-typescript-best-practices-reference/nextjs-standard-entry-point-and-skill-wiring/evidence/sources-verified.md`
    lists every URL in the Sources of `R/nextjs.md` and of the stubs. For each URL it records
    the fetch date (2026-10-04, fetched live this run) and what the URL backs. That includes
    where the `<version>` string was read. Validation checks that this URL set equals the
    Sources set with a one-off command recorded in `validation.md`. It is not a permanent
    pytest, because tests never read run folders.
16. **[unit]** **Gates.** The full suite passes, with all pre-existing tests unchanged apart
    from the renamed version test. `ruff check Skills/dev-bother-me-nope` is clean.

## Out of scope

- Any topic content in `R/nextjs/*.md` beyond the stub, which the nine topic stories own.
- Topic-specific tests (`test_nextjs_topic_*.py`), owned by each topic story.
- `plugin.json` description, SKILL.md frontmatter description, `marketplace.json`, the
  deploy guard, `bmn-worker.md`.
- Type-checking snippets by compiling them. Correctness is grounded in the cited docs and
  checked at review.
- Jonathan's untracked draft in his main checkout. It stays untouched, and the report covers
  it (stack.md assumption 6).

## Deps

None. This is the skeleton, and every topic story depends on it.

## Assumptions

- Grounding outranks every other criterion. If the docs don't confirm a placement rule,
  non-negotiable or version-note item this story would state, it is left out or tagged
  `(convention)` when it is a house rule. It is never stated as a docs fact.
- The generic contract tests skip stub files, and each topic story's own test asserts its
  file is no longer a stub. That lets this story merge green before any topic exists, and
  shows any topic that never landed.
- The allowed-host list goes beyond nextjs.org and vercel.com, but only for facts those
  sites don't own:
  - SSE wire format and `EventSource` reconnection: MDN and WHATWG;
  - React hooks: react.dev;
  - TypeScript compiler options: typescriptlang.org;
  - Zod, Vitest and Playwright APIs: their own docs.

  Any claim about Next.js or Vercel behaviour still needs nextjs.org or vercel.com.
- A per-rule citation, or `(convention)` for a house rule, is how "nothing a doc doesn't
  confirm is stated" becomes checkable. Reviewers spot-check cited claims against the linked
  page.
- `nextjs.md` wins over `nextjs-fullstack-standards` on a conflict, because it is dated and
  verified live. The folder layout is canonical for new projects only.
- Where the draft's nesting was ambiguous, the obvious reading is used:
  `(dashboard)/dashboard/page.tsx`, `api/webhooks/route.ts`, `src/tests/`.
- Briefs use `${CLAUDE_PLUGIN_ROOT}/…` paths because workers run in other repos. The
  orchestrator already fills that variable for workers.
