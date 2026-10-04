# Sources verified: proxy-auth-and-security

Every URL below was fetched live on **2026-10-04** by the planner (nextjs.org and vercel.com pages
as `Accept: text/markdown`, the raw page source; react.dev as its Markdown source; zod.dev as HTML).
Next.js docs pages report `version: 16.3.8` in their front matter. The npm registry dist-tag
`latest` for `next` is `16.3.8` (published 2026-09-30), matching the September 2026 security
release post.

This set must equal the `## Sources` list of
`Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/proxy-auth-and-security.md`
(one-off check recorded in `validation.md`). Rule ids follow the plan's Verified rule sheet; if the
coder renumbers a rule, this table is updated in the same commit.

| URL | Fetched | Page date | Backs |
| --- | --- | --- | --- |
| https://nextjs.org/docs/app/api-reference/file-conventions/proxy | 2026-10-04 | lastUpdated 2026-09-07 | SEC-1, SEC-2, SEC-3, SEC-5, SEC-6; Version notes |
| https://nextjs.org/docs/app/getting-started/proxy | 2026-10-04 | lastUpdated 2026-09-07 | SEC-1, SEC-4; Patterns (one proxy file per project) |
| https://nextjs.org/docs/app/guides/upgrading/version-16 | 2026-10-04 | lastUpdated 2026-08-25 | SEC-1, SEC-2, SEC-11, SEC-38; Version notes |
| https://nextjs.org/docs/app/guides/upgrading/codemods | 2026-10-04 | lastUpdated 2026-08-25 | Version notes (`middleware-to-proxy` codemod); Not confirmed |
| https://nextjs.org/docs/app/guides/authentication | 2026-10-04 | lastUpdated 2026-08-25 | SEC-3, SEC-4, SEC-5, SEC-7, SEC-8, SEC-9, SEC-12, SEC-13, SEC-17, SEC-21, SEC-30, SEC-46 (`verifySession` in the DAL) |
| https://nextjs.org/docs/app/guides/authentication-with-cache-components | 2026-10-04 | lastUpdated 2026-08-25 | SEC-20; Not confirmed |
| https://nextjs.org/docs/app/guides/data-security | 2026-10-04 | lastUpdated 2026-08-25 | SEC-10, SEC-12, SEC-13, SEC-14, SEC-15, SEC-16, SEC-18, SEC-19, SEC-21, SEC-23, SEC-25, SEC-26, SEC-27, SEC-29 |
| https://nextjs.org/docs/app/guides/server-actions | 2026-10-04 | lastUpdated 2026-06-17 | SEC-21, SEC-22, SEC-27, SEC-28 |
| https://nextjs.org/docs/app/api-reference/directives/use-server | 2026-10-04 | lastUpdated 2026-08-25 | SEC-23, SEC-24 |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions | 2026-10-04 | lastUpdated 2026-09-07 | SEC-27, SEC-28; Not confirmed |
| https://nextjs.org/docs/app/guides/content-security-policy | 2026-10-04 | lastUpdated 2026-03-20 | SEC-31, SEC-32, SEC-33, SEC-34, SEC-35, SEC-36 (`frame-ancestors`); Version notes; Not confirmed |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/headers | 2026-10-04 | lastUpdated 2026-06-30 | SEC-36 |
| https://nextjs.org/docs/app/api-reference/functions/cookies | 2026-10-04 | lastUpdated 2026-06-09 | SEC-7, SEC-10 |
| https://nextjs.org/docs/app/guides/environment-variables | 2026-10-04 | lastUpdated 2026-08-25 | SEC-37, SEC-38, SEC-39 |
| https://nextjs.org/docs/app/getting-started/server-and-client-components | 2026-10-04 | lastUpdated 2026-08-25 | SEC-15, SEC-37 |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/taint | 2026-10-04 | lastUpdated 2026-09-07 | SEC-19 |
| https://nextjs.org/docs/app/guides/self-hosting | 2026-10-04 | lastUpdated 2026-08-25 | SEC-26, SEC-45 |
| https://nextjs.org/docs/app/guides/backend-for-frontend | 2026-10-04 | lastUpdated 2026-06-25 | SEC-5, SEC-6, SEC-29 |
| https://nextjs.org/blog/next-16 | 2026-10-04 | published 2025-10-21 | SEC-1; Version notes; Not confirmed |
| https://nextjs.org/blog/next-16-1 | 2026-10-04 | published 2025-12-18 | Version notes (no change to this topic) |
| https://nextjs.org/blog/next-16-2 | 2026-10-04 | published 2026-03-18 | Version notes (no change to this topic) |
| https://nextjs.org/blog/next-16-3 | 2026-10-04 | published 2026-08-03 | Version notes (no change to this topic) |
| https://nextjs.org/blog/security-nextjs-server-components-actions | 2026-10-04 | published 2023-10-23 | SEC-22, SEC-45 |
| https://nextjs.org/blog/CVE-2025-66478 | 2026-10-04 | published 2025-12-03 | SEC-42; Version notes |
| https://nextjs.org/blog/security-update-2025-12-11 | 2026-10-04 | published 2025-12-11 | Version notes |
| https://nextjs.org/blog/july-2026-security-release | 2026-10-04 | published 2026-07-20 | SEC-5, SEC-42; Version notes |
| https://nextjs.org/blog/august-2026-security-release | 2026-10-04 | published 2026-08-25 | Version notes |
| https://nextjs.org/blog/nextjs-security-update-september-22-2026 | 2026-10-04 | published 2026-09-22 | Version notes |
| https://nextjs.org/blog/september-2026-security-release | 2026-10-04 | published 2026-09-30 | SEC-42, SEC-45; Version notes |
| https://nextjs.org/blog/next-security-release-program | 2026-10-04 | published 2026-07-13 | SEC-42 |
| https://vercel.com/blog/postmortem-on-next-js-middleware-bypass | 2026-10-04 | published 2025-03-25 | SEC-5; Anti-patterns (proxy as the only gate) |
| https://vercel.com/docs/environment-variables | 2026-10-04 | last_updated 2026-09-17 | SEC-41 |
| https://vercel.com/docs/environment-variables/sensitive-environment-variables | 2026-10-04 | last_updated 2026-08-28 | SEC-40; Not confirmed |
| https://vercel.com/changelog/environment-variables-now-use-config-and-secret-types | 2026-10-04 | published 2026-08-24 | SEC-40; Not confirmed |
| https://vercel.com/docs/environment-variables/rotating-secrets | 2026-10-04 | last_updated 2026-07-15 | SEC-41 |
| https://vercel.com/changelog/new-deployments-of-vulnerable-next-js-applications-are-now-blocked-by | 2026-10-04 | published 2025-12-05 | SEC-43 |
| https://vercel.com/docs/deployment-protection | 2026-10-04 | last_updated 2026-09-15 | SEC-44 |
| https://vercel.com/docs/vercel-firewall | 2026-10-04 | last_updated 2026-09-10 | SEC-29; Not confirmed |
| https://react.dev/reference/react/cache | 2026-10-04 | n/a | SEC-12 |
| https://react.dev/reference/react/experimental_taintObjectReference | 2026-10-04 | n/a | SEC-19 |
| https://react.dev/reference/react/experimental_taintUniqueValue | 2026-10-04 | n/a | SEC-19 |
| https://react.dev/reference/rsc/use-server | 2026-10-04 | n/a | SEC-21, SEC-22 |
| https://zod.dev/basics | 2026-10-04 | n/a | SEC-22 (`safeParse` result shape) |

## Notes

- FIX① (2026-10-04), R1-C16: re-fetched the headers config and CSP guide as `Accept: text/markdown`.
  The headers page says of `X-Frame-Options`: "This header has been superseded by CSP's
  `frame-ancestors` option" and points to the CSP guide. The CSP guide's "Without Nonces" example sets
  `Content-Security-Policy` (with `frame-ancestors 'none'`) from `next.config` `headers()`. SEC-36 and
  the `securityHeaders` pattern now send `Content-Security-Policy: frame-ancestors 'none'`.
- FIX① (2026-10-04), R1-C9: SEC-46 is a `(convention)` rule built on the authentication guide's
  `verifySession` DAL helper; the `getSession` / `verifySession` split, the `src/lib/dal.ts` path and
  `src/lib/actions/` are the run's decided contract, not nextjs.org text. The `src/` layout is the
  canonical one in `references/nextjs.md`.
- `nextjs.org/blog/cve-2025-29927` redirects to the vercel.com postmortem above; the vercel.com URL is
  the one cited.
- Checked and not cited: `nextjs.org/docs/app/api-reference/config/next-config-js/authInterrupts`
  (canary-only `forbidden()`/`unauthorized()`; left out to keep the file under 800 lines),
  `nextjs.org/docs/app/api-reference/functions/connection`, `.../functions/headers`,
  `.../functions/next-response`, `.../config/next-config-js/skipProxyUrlNormalize` (their facts are
  repeated on the cited guides).
