# Validation: proxy-auth-and-security

Branch `wip/nextjs-typescript-best-practices-reference/proxy-auth-and-security`, from
`origin/feat/nextjs-typescript-best-practices-reference`. Checked 2026-10-04.

## Test run (TDD)

- RED, against the stub: `test_nextjs_topic_proxy_auth_and_security.py` gave **16 failed, 2 passed**.
  Every failure was the stub's absence of content (`is_stub`, rule count, terms, examples, version
  notes, checklist, anti-patterns, not-confirmed). The 2 passes were vacuous on a stub
  (`test_no_other_topic_rule_ids_are_used`, `test_ts_examples_never_use_any`).
- GREEN, with the topic file: the topic test file gives **18 passed**; with
  `test_nextjs_reference.py` it gives 147 passed, 56 skipped. All 56 skips are the other eight
  topics' stubs (7 generic tests each). Nothing skips for `proxy-auth-and-security.md`.
- Full suite: `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`
  gives **692 passed, 56 skipped**. Lint: `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope`
  gives "All checks passed!". Types: none (stack gate).
- `wc -l` of the topic file: 778 (cap 800).

## Acceptance criteria

| AC | Result | Evidence |
| --- | --- | --- |
| 1 Contract | pass | The generic tests in `test_nextjs_reference.py` run on the file with no skip and pass; `test_no_other_topic_rule_ids_are_used` passes. |
| 2 Not a stub, at least 18 rules | pass | `test_topic_file_is_not_a_stub`, `test_topic_has_at_least_18_sec_rules` (45 rules, SEC-1..SEC-45). |
| 3 Required concepts | pass | `test_required_terms_are_present`. Every term appears as a stated rule or pattern; none needed the Not-confirmed section. |
| 4 Examples | pass | `test_example_block_is_present` x5 and `test_ts_examples_never_use_any`. |
| 5 Optimistic Proxy and DAL | pass | `test_rules_keep_proxy_optimistic_and_recheck_in_the_dal`. |
| 6 Rename stated exactly | pass | `test_version_notes_state_the_middleware_to_proxy_rename`. File name, function name, runtime, codemod and renamed config keys are stated from the upgrade guide, proxy.js and the codemods page. The `edge`-runtime follow-up, the removal release and the codemod dist-tag are in Not confirmed. |
| 7 Auth before write | pass | `test_every_use_server_block_checks_auth_before_writing` (covers the Don't blocks too). |
| 8 Version notes | pass | `test_version_notes_name_the_major_and_link_nextjs_org`, `test_version_notes_list_the_topic_security_advisories`. |
| 9 Reviewer-ready | pass | `test_every_review_checklist_item_names_a_sec_rule` (21 items), `test_every_anti_pattern_dont_is_paired_with_a_do` (7 items). |
| 10 Evidence | pass | One-off check below. |
| 11 Scope and gates | pass | `git diff --name-only` below, plus the gates above. |

### AC10 one-off: Sources equals the evidence list

```text
sources: 43 evidence: 43
missing from evidence: []
extra in evidence: []
```

### AC11 one-off: changed files

```text
Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_proxy_auth_and_security.py
Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/proxy-auth-and-security.md
docs/sprints/bmn-nextjs-typescript-best-practices-reference/proxy-auth-and-security/validation.md
```

## Re-verification done by the coder (2026-10-04)

The brief asked for advisories and patched versions to be re-checked before writing. Fetched live and
matched against the plan's rule sheet; nothing was dropped:

- CVE-2025-66478: fixed in 16.0.7, CVSS 10.0, rotate secrets after patching and redeploying.
- CVE-2025-55184, CVE-2025-67779 and CVE-2025-55183: 16.0.10.
- July 2026: 16.2.11 (and 15.5.21); CVE-2026-64642, 64641, 64643, 64649 and 64645 as the plan lists. The
  post says 16.3.0 will include the fixes once stable, so the file says only "fixed in 16.2.11".
- August 2026: 16.3.3 (and 15.5.24); AVIF RCE (GHSA only) and the Windows-hosted RCE, which the page
  gives as CVE-2026-75604 (added to the file; it is on the cited page).
- 2026-09-22: 16.3.6 (and 15.5.26); the Node.js `ImageResponse` RCE, affects `>=16.2.0 <16.3.6`.
- 2026-09-30: 16.3.8 Active LTS and 15.5.27 Maintenance LTS; the five items the plan lists, with the
  CVE ids the post gives (added: CVE-2026-94483, 94543, 94484, 94544, 94486).
- Postmortem: CVE-2025-29927, fixed in 15.2.3 and 14.2.25; the "sole method of protecting routes" sentence.
- Also re-read: proxy.js (runtime, matcher, `next({ request: { headers } })` versus `next({ headers })`,
  execution-order note, version history, `@canary` codemod), the CSP guide (proxy example, `missing`
  matcher, `unsafe-eval`, PPR, version history ending at v14.0.0), serverActions config
  (`allowedOrigins`, `bodySizeLimit`, no-`Origin` behaviour), the Vercel Config and Secret changelog,
  Deployment Protection (Standard Protection) and the codemods page. All matched the sheet.

## Strict TypeScript check (extra, outside the repo)

The story says snippets are not compiled. They were compiled anyway in a scratch project
(`next@16.3.8`, `react@19`, `typescript@5`, `jose`, `zod`, `server-only`; `strict` and
`noUncheckedIndexedAccess`; a typed stub for `@/lib/prisma` and `@/lib/reports`). The 7 Patterns
files compile as written. The 13 anti-pattern fragments compile once a prelude of the imports a real
file would have is added. Nothing from the scratch project is committed.

## Assumptions

1. The skeleton's contract won over the plan on three points. (a) Anti-pattern items are `### Don't ...`
   H3 headings, each holding a why line and a fenced Don't block, then a `**Do**` marker and a fenced Do
   block; the plan's `**Don't**`-after-H3 guess was dropped, so the topic test reads the pairs through
   `anti_patterns()` and only `DO_MARKER` is used. (b) The H1 stays the stub's `# Proxy, auth and
   security`, because the skeleton owns the title; the plan's `Proxy, authentication and security` was
   not used. (c) `## Rules` is a flat numbered list: the contract allows H3s there, but the 800-line cap
   did not leave room for the group headings.
2. `section()` raises `LookupError` in the merged helpers, so the test's `_section` wrapper returns an
   empty string for a missing heading and the assertion reports the gap. No assertion was weakened.
3. `TOPICS` values are `(prefix, slug)` tuples, as the plan assumed.
4. Prose links carry no `#fragment`, so prose URLs equal the Sources bullets exactly (43 URLs).
5. The Not-confirmed items name pages by link rather than by the plan's short names, because the generic
   test requires a URL in each item. Item 7 (Vercel team secrets policy) is carried from the planner's
   reading of the sensitive-variables page; only the changelog half was re-fetched here.
6. SEC-42 says "pre-announced security releases" and drops the plan's "monthly": the July 2026 post
   confirms the pre-announced model, and the "roughly once a month" sentence was not re-fetched.
7. `authInterrupts` (`forbidden()`/`unauthorized()`) stays out, as the plan says.
8. No defect was found in the shared files (`nextjs.md`, `nextjs_doc_helpers.py`,
   `test_nextjs_reference.py`).
9. No deploy, no Supabase, no env vars or migrations. Env var names (`SESSION_SECRET`,
   `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY`, `DANGEROUSLY_DEPLOY_VULNERABLE_CVE_2025_66478`) appear only
   as documentation text. No `deploy_pending` entries.
