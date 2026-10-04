# Proxy, authentication and security

**Slug:** `proxy-auth-and-security`
**Run:** `bmn-nextjs-typescript-best-practices-reference` · plugin `Skills/dev-bother-me-nope/`
**Owns:** `R/nextjs/proxy-auth-and-security.md` (rule prefix `SEC`) and `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_proxy_auth_and_security.py`.
`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`.

## Story

**As** a dev-bother-me-nope planner, coder, reviewer or fixer working in a Next.js +
TypeScript repo,
**I want** sourced rules for the request proxy file (its current name and API), optimistic checks vs real authorisation, a Data Access Layer with DTOs, session cookies, Server Action security, Content Security Policy with nonces, secrets and `NEXT_PUBLIC_` exposure, `server-only` and taint APIs,
**so that** no secret reaches the client bundle, no data is returned without an authorisation check at the data layer, every Server Action is treated as the public endpoint it is, and the proxy file uses the name and runtime the current Next.js expects.

## Context

- The skeleton story `nextjs-standard-entry-point-and-skill-wiring` has merged first. `R/nextjs/proxy-auth-and-security.md` exists as a stub
  marked ``> Stub: pending story `proxy-auth-and-security`.``. `R/nextjs.md` holds the canonical folder
  structure, this file's index row (prefix `SEC`), the as-of version and the
  **Authoring contract**. Read the contract before writing anything.
  `Skills/dev-bother-me-nope/assets/tests/test_nextjs_reference.py` enforces the contract on
  every non-stub topic file. `Skills/dev-bother-me-nope/assets/tests/nextjs_doc_helpers.py`
  holds the parsing helpers this story's test imports.
- Grounding is the hard requirement (input.md: "Don't assume or lie. ground all your findings
  in NextJS and Vercel documentation"). Fetch every page live on 2026-10-04 with
  WebFetch/WebSearch. Every Next.js or Vercel behaviour claim cites nextjs.org or vercel.com.
  react.dev, typescriptlang.org, MDN/WHATWG, zod.dev, vitest.dev and playwright.dev back only
  the facts they own.
- Starting points to verify live (hints, not sources until fetched):
  - https://nextjs.org/docs/app/api-reference/file-conventions/proxy
  - https://nextjs.org/docs/app/guides/authentication
  - https://nextjs.org/docs/app/guides/data-security
  - https://nextjs.org/docs/app/guides/content-security-policy
  - https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions
  - https://nextjs.org/docs/app/guides/environment-variables
  - https://nextjs.org/docs/app/guides/upgrading/version-16
- The reader is an agent. Write imperative, checkable rules with short, correct, typed
  examples and Don't/Do pairs, not essays.

## Acceptance criteria

1. **[unit]** **Contract.** `R/nextjs/proxy-auth-and-security.md` replaces the stub entirely. Every generic check in `test_nextjs_reference.py` runs on it with no skip and passes:
   - an as-of line whose version matches `R/nextjs.md`;
   - the section order;
   - the rule format and citations;
   - the floors and Sources;
   - at most 800 lines;
   - tagged code fences and resolving links.

   It uses only `SEC-` rule ids.
2. **[unit]** **Not a stub, deep enough.** `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_proxy_auth_and_security.py` imports `nextjs_doc_helpers` and asserts that `is_stub` is false. It also asserts the file has at least 18 `SEC-` rules.
3. **[unit]** **Required concepts.** The test asserts `missing_terms(text, TERMS) == []`. TERMS: `proxy.ts`, `middleware.ts`, `matcher`, `NextResponse.redirect`, `NextResponse.next`, `optimistic`, `Data Access Layer`, `DTO`, `server-only`, `cache(`, `httpOnly`, `secure`, `sameSite`, `'use server'`, `allowedOrigins`, `bodySizeLimit`, `nonce`, `Content-Security-Policy`, `NEXT_PUBLIC_`, `taint`, `headers()`. A cited doc must confirm each concept before it is stated as a rule or pattern. Anything unconfirmed goes under `## Not confirmed by the docs` with the URLs checked.
4. **[unit]** **Examples.** The test asserts, through `has_block_with`, that the file has:
   - a `ts`/`tsx` block containing `proxy`, `matcher`: the proxy file with a matcher;
   - a `ts`/`tsx` block containing `import 'server-only'`, `cache(`: a Data Access Layer session check;
   - a `ts`/`tsx` block containing `'use server'`: a Server Action that authorises before it mutates;
   - a `ts`/`tsx` block containing `Content-Security-Policy`, `nonce`: a nonce-based CSP;
   - a `ts`/`tsx` block containing `httpOnly`: setting the session cookie;

   Each example is short, uses only APIs the cited pages show, and is TypeScript-typed (no `any`).
5. **[unit]** `## Rules` says the proxy does only optimistic (cookie-presence) checks. Authorisation is re-checked where data is read or written: the Data Access Layer, every Server Action and every Route Handler. A test asserts `## Rules` contains `optimistic` and `Data Access Layer`.
6. **[unit]** The middleware-to-proxy change is stated exactly as the docs give it, with the link: the file name, the exported function name, the runtime and any codemod. If the docs don't confirm a detail, it goes to `## Not confirmed by the docs`. A test asserts `## Version notes` contains both `middleware` and `proxy`.
7. **[unit]** Every `ts` block containing `'use server'` calls a session or auth check (`(?i)(session|auth)\w*\(`) before any write. A test asserts this per block.
8. **[unit]** **Version notes.** `## Version notes` names `Next.js <major>`, using the major from the as-of line. It lists every change to this topic in that major that the upgrade guide or release post confirms, each with its link. Candidates to check (verify, never assume): `middleware` renamed to `proxy` (file, export, runtime); Server Action security defaults; any CSP/nonce or env change in the latest major. If the guide lists no change for this topic, the section says so with the link. A test asserts the section is non-empty and links nextjs.org.
9. **[unit]** **Reviewer-ready.** Every `## Review checklist` item names the `SEC-<n>` rule it checks. Every `## Anti-patterns` item pairs a Don't block with the Do it should be. A test asserts every `- [ ]` line contains `SEC-`.
10. **[unit]** **Grounding evidence.** `docs/sprints/bmn-nextjs-typescript-best-practices-reference/proxy-auth-and-security/evidence/sources-verified.md` lists every URL in the file's `## Sources`. For each URL it gives the fetch date (2026-10-04, fetched live this run) and the rule ids it backs. Validation records a one-off check that the two URL sets are equal in `validation.md`. It is not a permanent test.
11. **[unit]** **Scope and gates.** `git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD` lists only `R/nextjs/proxy-auth-and-security.md`, `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_proxy_auth_and_security.py` and files under `docs/sprints/bmn-nextjs-typescript-best-practices-reference/proxy-auth-and-security/`. The full suite (`uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`) passes, and `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` is clean.

## Out of scope

- `R/nextjs.md` (index, contract, non-negotiables, version notes) and the wiring files (`stack-routing.md`, `SKILL.md`, `briefs.md`, `plugin.json`, `test_skill_text_rules.py`, `test_nextjs_reference.py`, `nextjs_doc_helpers.py`): owned by `nextjs-standard-entry-point-and-skill-wiring`.
- Every other `R/nextjs/*.md` file, each owned by its own topic story.
- Env *typing* is `typescript.md`; this file owns exposure and secret handling.
- CORS and webhook signature verification are `route-handlers-and-apis.md`.
- Form/action mechanics are `data-fetching-and-mutations.md`; this file owns their security rules.

## Deps

- `nextjs-standard-entry-point-and-skill-wiring`

## Assumptions

- Grounding outranks every other criterion. If an acceptance criterion asks this file to state something the cited docs don't confirm, it goes under `## Not confirmed by the docs` with the URLs checked. That criterion's test then checks that section instead of `## Rules`, and validation.md records why.
- The starting URLs in Context are hints written before any fetch. Each is fetched live; a moved or 404 page is found again by searching nextjs.org or vercel.com, never assumed.
- A required term the docs don't confirm still appears in the file, but only in `## Not confirmed by the docs` with the URLs checked. The term test then passes without anything unconfirmed being stated as a rule.
- Snippets aren't compiled, because no Next.js project exists in this repo. Their API usage must match the cited page. REVIEW① spot-checks them against the links.
- This story never edits shared files: `nextjs.md`, the wiring files, `test_nextjs_reference.py` and `nextjs_doc_helpers.py`. A defect found there is recorded under Assumptions in this story's `validation.md` for REVIEW① to pick up. That keeps parallel topic stories conflict-free.
- Version facts in this file use the same latest major as `nextjs.md`'s as-of line, which the skeleton story read live.
- No auth library is mandated. Examples follow the Next.js authentication guide's library-agnostic session pattern, and Jonathan's tree reserves `src/lib/auth.ts` for library config.
