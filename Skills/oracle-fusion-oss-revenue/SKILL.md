---
name: oracle-fusion-oss-revenue
description: Expert knowledge for building, debugging, and reasoning about Oracle Fusion Subscription Management (OSS) revenue reporting via the Revenue Management (VRM) schema — especially BIP subscription revenue waterfall reports. Covers the OSS→VRM→XLA→GL data flow, the canonical table relationships, and the hard-won quirks (348-way OSS_PRODUCTS fan-out, version-skew POL drops, catch-up accounting dates, cross-currency T/F handling, satisfaction-event projection math). Use this whenever the user works with OSS subscriptions, VRM_ tables (VRM_SOURCE_DOCUMENTS, VRM_PERF_OBLIGATION_LINES, VRM_PERF_OBLIGATION_LIN_DISTS, VRM_POL_SATISFACTION_EVENTS, VRM_SOURCE_DOC_LINES, VRM_BILLING_LINE_DETAILS), revenue waterfalls, recognized/unrecognized revenue, TCV, subscription revenue projection, FUSION_OSS source documents, or any subscription-revenue SQL against Oracle Fusion. Trigger even when the user only mentions "the waterfall report," "OSS," "perf obligations," "POL," "POLD," or "subscription revenue" without naming tables.
---

# Oracle Fusion OSS Revenue Reporting

This skill captures everything learned building the **Subscription Waterfall Report** — a BIP data model that produces a month-by-month projection of recognized and unrecognized revenue per subscription performance-obligation line, sourced from Oracle Subscription Management (OSS) through the Revenue Management (VRM) engine.

It exists because OSS→VRM revenue reporting is full of non-obvious traps. Several of them silently produce *wrong numbers that look plausible* (dropped lines, currency mislabels, 6-years-of-revenue-in-one-month) rather than erroring out. The reference files below encode the specific diagnostics and fixes that took many live-data iterations to discover.

## When to use this skill

Use it for any task touching subscription revenue in Oracle Fusion: writing or debugging waterfall/revenue-recognition SQL, explaining where a number comes from, reconciling recognized vs. unrecognized vs. TCV, handling cross-currency contracts, or interpreting the OSS/VRM/XLA table graph. The user is a Hackett consultant (Jonathan) who builds these for end customers; the original end user of the waterfall report is **Jay Surface**.

## How to navigate this skill

Start here, then read the reference file(s) matching the task. Each is self-contained — read the whole relevant file before writing SQL, because the gotchas are interdependent (e.g. the version-skew fix and the header-TCV dedup must be understood together).

| Reference file | Read it when... |
|---|---|
| `references/data-model.md` | You need the table graph: what each OSS/VRM/XLA/GL table holds, the canonical join keys, grain at each level, and the OSS→VRM bridge. **Read this first for any new query.** |
| `references/gotchas-and-fixes.md` | You're debugging wrong/missing/duplicated rows, or want the catalog of known traps (fan-out, version skew, catch-up dates, currency mismatch, recognition-math bug) with the exact diagnostic queries and fixes. **The highest-value file.** |
| `references/waterfall-report.md` | You're working on the waterfall report specifically: its CTE architecture, bucket math, all column mappings, the audit invariants (Recog+Unrecog=TCV etc.), and the RTF layout. |
| `references/currency-tf.md` | Anything involving currency: the (T)/(F) convention, transaction vs. contract vs. functional currency, FX rate sourcing, the at-or-before date semantics, multi-functional-currency ledgers. |
| `references/recognition-and-projection.md` | You need the revenue-recognition model: POLD as engine-truth for past periods, satisfaction events for future projection, measurement models, terminations/modifications, catch-up bookings. |
| `references/environment-and-tooling.md` | You're connecting via the `hackett-fusion` MCP server, validating against live data, or need tenant-specific values (Imagine COA, application IDs, conversion-type IDs). |
| `references/sql-style.md` | You're writing SQL output for this user — the mandatory Oracle WHERE-join / formatting conventions. |
| `assets/waterfall_oss_aligned_reference.sql` | The full, working, validated data-model SQL (~1490 lines). The authoritative implementation that every reference file describes. Open it to see any pattern in full context. |

## Bedrock facts (true across everything below)

- **Scope filter**: OSS subscription revenue lives under `VRM_SOURCE_DOCUMENTS.DOCUMENT_TYPE_CODE = 'FUSION_OSS'`. The report deliberately *excludes* `FUSION_CONTRACTS` and `FUSION_OM`. Almost every CTE re-applies the `FUSION_OSS` filter.
- **The engine owns the numbers.** The report reads VRM engine outputs (`net_line_amt`, `entered_cur_recog_rev_amt`, POLD distributions); it does not re-derive revenue from scratch. When a value looks wrong, suspect the *plumbing* (joins, currency, period attribution), not the arithmetic.
- **Grain matters constantly.** The natural reporting grain is the **performance obligation line (POL)**. Source doc lines (VSD), OSS products, satisfaction events, and POLD distributions all sit at *different* grains and will fan out if joined naively. See `data-model.md`.
- **Things fail silently.** The worst OSS bugs return rows — just wrong ones. Always validate against live data with the audit invariants in `waterfall-report.md` and the diagnostics in `gotchas-and-fixes.md`. Never present SQL changes as "done" without running them when an MCP connection is available.
- **Tenant-specific values exist.** COA segment meanings, `application_id = 10455`, the `Product_Reporting` catalog, and conversion-type IDs are specific to the Imagine tenant. They're flagged everywhere they appear; see `environment-and-tooling.md`.

## Default working approach

1. Confirm which tenant/environment is connected (`identify_environment` on the MCP) before trusting any live result — the connection has been observed silently switching between Imagine and other tenants mid-session.
2. Read `data-model.md` and the task-specific reference.
3. Write SQL in the user's mandated style (`sql-style.md`).
4. **Test against live data** before presenting. Wrap the query and check row counts and the audit invariants. A change that "should be correct by construction" still gets run — that mindset has masked real typos and parse errors here before.
5. Call out tenant-specific assumptions and any silent-failure risks in your explanation.
