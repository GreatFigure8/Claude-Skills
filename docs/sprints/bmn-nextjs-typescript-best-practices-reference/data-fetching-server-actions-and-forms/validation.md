# Validation — data-fetching-server-actions-and-forms

Branch `wip/nextjs-typescript-best-practices-reference/data-fetching-server-actions-and-forms`, cut from
`origin/feat/nextjs-typescript-best-practices-reference` (fetched first). Date: 2026-10-04.
Owned files: `references/nextjs/data-fetching-and-mutations.md` (`DF`),
`assets/tests/test_nextjs_topic_data_fetching_and_mutations.py`, and this folder.

## TDD record

| Step | Command | Result |
| --- | --- | --- |
| RED | `pytest .../test_nextjs_topic_data_fetching_and_mutations.py` against the stub | 18 collected, **18 failed**, 0 passed. Reasons: `is_stub` is true; `## Rules`, `## Patterns`, `## Anti-patterns`, `## Version notes` and `## Review checklist` don't exist (`LookupError: no heading` or empty tuples); no rules, terms, examples, checklist or Don't/Do pairs. Two tests first passed vacuously on empty input (no `any` found, no checklist ids), so they were tightened to assert that something is there, then failed too. |
| GREEN | same file plus `test_nextjs_reference.py` | topic file written: 147 passed, 56 skipped. The 56 are the 8 other stubs times 7 generic cases; nothing skips for `data-fetching-and-mutations.md`. |
| First GREEN attempt | same | 1 failure: the file was 845 lines against the 800 cap. Fixed by compacting citation lines, dropping pattern P10 and the React 19.2 version bullet, and simplifying two anti-pattern blocks (file is now 780 lines). |
| Full suite | `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q` | **692 passed, 56 skipped, 0 failed** (70 s). The skeleton's 667 passed + 63 skipped became 667 + 18 topic cases + 7 generic cases un-skipped = 692, and 63 - 7 = 56. |
| Lint | `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` | `All checks passed!` |
| Types | none (stack.md) | n/a |

## AC10 scope

`git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD` lists exactly:

```text
Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_data_fetching_and_mutations.py
Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/data-fetching-and-mutations.md
docs/sprints/bmn-nextjs-typescript-best-practices-reference/data-fetching-server-actions-and-forms/evidence/sources-verified.md
docs/sprints/bmn-nextjs-typescript-best-practices-reference/data-fetching-server-actions-and-forms/validation.md
```

No shared file (`nextjs.md`, helpers, `test_nextjs_reference.py`, wiring files) and no other topic file changed.

## AC9 grounding evidence

`evidence/sources-verified.md` lists the 39 URLs of the file's `## Sources`, each with fetch date 2026-10-04 and
the rule ids or sections that cite it. Every page was fetched live in this run (the `.md` rendering for
nextjs.org, vercel.com and react.dev; HTML for zod.dev) and every one returned HTTP 200. The one-off set check
(not a permanent test) compares `source_urls(topic)` with the URLs in the evidence file:

```text
cited: 39 listed: 39
only cited: []
only listed: []
table rows: 39 with 2026-10-04: 39
exit=0
```

The plan's own rule sheet was checked quote by quote against the fetched pages. The differences are listed at
the end of the evidence file ("Claims reworded, added or dropped after the live read").

## Gates not applicable

- Supabase: `supabase: false`, no migration files, no `supabase start` / `db reset` needed.
- Env vars: none created. `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY` appears only as documented guidance in DF-27.
- Browser tests: `ui: false`, no Playwright.
- shellcheck: no `.sh` file changed.
- Deploy: nothing to deploy (`deploy_pending: []`).

## Assumptions

1. **Contract wins over the plan's default syntax.** The skeleton contract defines an anti-pattern as a
   `### Don't <title>` H3 with at least one fenced block, so each of the 8 anti-patterns is one such H3. Inside it
   the Don't block follows a `**Don't:**` line and the Do block follows a `**Do:**` line, each followed directly by
   a `ts`/`tsx` fence. The topic test `test_every_dont_is_paired_with_a_do` enforces that shape and that each
   anti-pattern names a `DF-` rule. The plan's `- **Don't:**` bullet syntax was not used.
2. **Test count.** The plan said 14 test functions and 18 cases but its table listed 13 functions and 17 cases.
   The 14th is `test_redirect_rule_says_outside_try_and_after_revalidation`, which asserts one rule ties
   `redirect(` to `try`, revalidation and "outside" (a stronger form of AC6). Total: 14 functions, 18 cases.
3. **Rules in two H3 groups.** `## Rules` has `### Reading data` and `### Mutating data` H3s. The contract allows
   H3s inside a section, and rule numbers run 1 to 28 across both. The shared helpers append such a heading line to
   the preceding rule's item text, which no test is affected by.
4. **Pattern P10 dropped.** The `next/form` search-form example was removed to keep the file under the 800-line
   cap with headroom (780 lines). It was not one of the five required examples, and DF-18 still states the rule
   and cites its page.
5. **Snippet corrections against the live pages.** `.trim()` was removed from the Zod schemas, because zod.dev
   pages cited in Sources don't show it, and no cited page confirms how it combines with `.min()`. Everything
   else in the snippets follows the cited pages. Snippets are not compiled (no Next.js project here), and REVIEW
   spot-checks them against the links.
6. **Illustrative modules.** `verifySession` follows the Authentication guide's DAL helper. `@/lib/dal/*`,
   `@/lib/dto`, `@/lib/audit` and `canDeleteRecords` are placeholders, which the Patterns intro says.
7. **Rule changes from the plan sheet** (each recorded in the evidence file): DF-1 lost an unconfirmed
   "no Client Component effects" prohibition; DF-12 allows the check inside the DAL and says "cookies or headers";
   DF-16 words `refresh(` as the page does; DF-18 separates Server Component and Client Component progressive
   enhancement; DF-21 tags the separate-module advice `(convention)`; DF-24 dropped "or in a Route Handler"; DF-25
   scopes the Vercel claim to request cancellation; DF-26 says `allowedOrigins` matters only when the proxy
   doesn't forward the public host.
8. **Version notes.** The v16 upgrade guide lists no other Server Action change; the 16.1 post and the September
   2026 security release were also grepped and name none. Next.js 15 carry-overs are labelled as such.
9. **No defects found in shared files.** `test_nextjs_reference.py` and `nextjs_doc_helpers.py` accepted the file
   unchanged.
