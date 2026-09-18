---
name: hcm-production-health-check
description: Run a full Oracle Fusion Cloud HCM production health check through the Hackett Fusion MCP server (execute_sql via the BIP SQL runner, catalog download, Fusion REST) and deliver it as a Hackett-branded, interactive, self-contained HTML report that reads as a client deliverable — scorecard by domain, filterable findings register, statistics-only access review, root-caused failing processes, payroll, recruiting, AoR, journeys and module coverage. Encodes the client-agreed counting rules (employee = active primary assignment + open assigned payroll; ex-employees, candidates and contingent workers are never employees or duplicates; nothing before go-live), the hard-won table and join patterns (assigned payroll via rel groups, inverted ASE_ROLE_ROLE_MBR naming, fusion_ora_ess.request_history/request_property, flow child tasks not parents, AoR and audit tables), the known measurement gaps (no last-login in the DB, ESS REST 403), and the report rules (stats only, no names or emails, no methodology, sticky nav, Framer-style appear animation). Use whenever asked for an HCM health check, implementation review, post-go-live assessment, "why are reports failing", privileged-access review, duplicate-employee check, or to refresh/re-run the IP PROD health check — even if the client is not IP.
---

# Oracle Fusion HCM production health check

You are acting as a senior Fusion HCM implementer running a read-only health check of a live tenant and writing it up for the client. Everything in the report is measured in the environment; nothing is estimated. Where a measure cannot be taken, the report says so and lists the alternative source.

## 0. Before you start — confirm the counting rules with the user

Ask (or read from memory / the request) and write them into the report's definitions block:

| Rule | Default (agreed with IP, Sept 2026) |
|---|---|
| **Employee** | Active primary assignment of type E, status ACTIVE, current on run date, **and** an open assigned payroll (start ≤ today, end null or ≥ today). Not paid in Fusion = not an employee, however active the HR record. |
| **Not an employee** | Ex-employees, terminated people (incl. the post-termination account grace period), Recruiting candidates, contingent workers, pending workers, contacts, suspended assignments, workers paid outside Fusion (e.g. a Mexico LDG fed by extracts). |
| **Duplicate employees** | Compared only among employees. **EX_EMP records and candidates are never duplicates.** A candidate duplicating a current employee is a *Recruiting* configuration gap, not a duplicate employee. |
| **Data window** | Nothing before go-live. Charts and activity counts start at go-live; current-state facts (accounts, roles, structures) are as of the run date. Never label anything with a pre-go-live date. |
| **Account grace period** | Terminated people may keep an active account for N days (IP: 30). Report "terminated > N days with active, unsuspended account" as the finding. |
| **Requested lists** | Non-employee account count; non-employee accounts with no login in 30 days (see gap below); accounts holding IT Security Manager; accounts holding any role that contains BI Administrator (direct **and inherited**); shared NIDs among employees. |

## 1. Session

1. `tool_search` → load `list_environments`, `select_environment`, `execute_sql`, `catalog_download_object`, `fusion_rest_get`.
2. `select_environment` the PROD environment. The SQL runner is `/~<user>/HK_SQL_RUNNER.xdo`; it returns ORA errors verbatim — when a query fails with ORA-00904/00942, probe `all_tab_columns` and retry; never guess a column.
3. Keep a running `findings.md` log with every number and its source query; the report is built from that log.

## 2. Checks to run (in this order)

Full SQL patterns and table gotchas are in `references/checks-and-sql.md`. Run them all; each produces either a finding or a "working well" item.

1. **Population** — person counts, person-type usages, assignment status × payroll state → employee baseline; characterise the active-no-payroll group by LDG.
2. **User accounts** — classify every PER_USERS row (employee / not paid / leave / CWK / terminated ≤N / terminated >N active-unsuspended / no current assignment / no person); roles still held by open leaver accounts; roleless accounts; HR_TERMINATED flag.
3. **Privileged roles** — direct grants of IT Security Manager and BI Admin roles; then trace **every container** of the seeded `BIAdministrator` and `ORA_FND_IT_SECURITY_MANAGER_JOB` through `ASE_ROLE_ROLE_MBR` and count distinct users by holder class. The inherited count is the finding.
4. **SoD and role stacking** — payroll-run roles ∩ HR admin, ∩ IT Security Manager, ∩ BI Admin; Application Implementation Consultant and HCM Integration Specialist counts; users with ≥10 / ≥20 roles.
5. **Security profiles** — `PER_PERSON_SECURITY_PROFILES` flags (view_all, secure_by_aor…); superseded versions still enabled.
6. **Audit** — `FND_AUDIT_ATTRIBUTES` enabled tables vs the sensitive list (NID, pay methods, users/roles, assignments, addresses, element entries, salary); `PER_SENSITIVE_DATA_AUDIT` row count since go-live (0 = never enabled).
7. **National identifiers** — normalise, group by legislation+type, split into employee↔employee, employee↔other (classify other by system_person_type), placeholders, format.
8. **Areas of responsibility** — `PER_ASG_RESPONSIBILITIES` (`status='Active'`): by type, held by leavers, usage null, auto-provision, scope dimension; location coverage gaps for HRBP / HR Coordinator / Pay Field Admin.
9. **Manager hierarchy** — cycles, spans, contingent managers, managers on leave, managers without the Line Manager role, depth.
10. **Scheduled processes** — 90 days of `fusion_ora_ess.request_history` (requesttype 1,3,8; states 10 error / 11 warning / 9 cancelled / 12 succeeded); group by job def and by BIP `report_url` from `request_property`; separate seeded CX noise from real failures; download the data model of any bursting report that fails at ~100% and read the query (exception-only query → NO_DATA_TO_PROCESS, MOS 1925999.1).
11. **Recurring schedules ownership** — requesttype 3 EssBipJob only; count schedules by owner class (service / employee / consultant / vendor) and runs from `/~` personal folders.
12. **Payroll flows** — `PAY_FLOW_TASK_INSTANCES` status, never the parent (parents show Completed); QuickPay left open; rollbacks by flow; report tasks in functional error; formula compile errors; JCostingJob; terminated with open assigned payroll; US actives with no payroll.
13. **Payroll elements** — non-seeded via `seed_data_source`; user-facing = not `% Results/Retro/Calculator/Distributor` and `indirect_only_flag<>'Y'`; unused since go-live; no eligibility (`PAY_ELEMENT_LINKS_F`); costing on the *family* (base + Results/Retro links, `PAY_COST_ALLOCATIONS_F` source_type EL); retro event group null; created since go-live and by whom; entry-level costing volume (source_type EE).
14. **Workforce structures** — counts, unused departments/jobs/grades/locations, vacant positions.
15. **Employee data quality** — position/job/grade/location/dept/manager/email/address/DOB/salary/user account/gender/ethnicity/future-dated rows — on the employee population only.
16. **Approvals** — `HRC_TXN_DATA.status` joined to `HRC_TXN_HEADER`: pending >30/90 days, drafts >90 days, aborted.
17. **Absence, Recruiting, Help Desk, Journeys, Talent, Comp, Benefits, Learning, T&L, Documents of record, Seniority, Calc cards** — configured vs used; recruiting requisition states and pipeline/offer states with idle >30 days; journeys initiated/completed and tasks expired/overdue.
18. **Table growth / purge** — run results, run result values, element entries, cost allocations, ESS history; purge jobs run since go-live.
19. **Non-US populations** (e.g. Mexico) — completeness and service reach.
20. **Transition risk** — everything owned by consultant, vendor, personal-folder or service accounts, pulled together as one finding.

## 3. Known gaps — state them, don't work around them

- **Last login** is not in the HCM database (`ASE_USER_LOGIN_INFO`, `ZCA_BI_USER_LOGIN_ACTIVITY`, `FFS_USER` are empty; SCIM returns 403 to the service account). Deliver the non-employee account classification and say the 30-day cut needs an identity-domain / Security Console sign-in export.
- **ESS request detail REST** (`/ess/rest/scheduler/v1/requests/{id}`) returns ESS-02003 for the service account. Read `ERROR_WARNING_MESSAGE` / `ERROR_WARNING_DETAIL` from `request_history`, and confirm root cause from the report's data model and run duration.
- BPM approval rules, sandboxes, page personalisations, OIC, IDCS, release level and licence counts are not in the database — list them as "needs another source".

## 4. Findings and scoring

- One finding per mechanism, not per symptom. Each has: id, severity, domain, title (the fact, in one line), metric + label, evidence (numbers, no procedure), impact, 3–4 concrete actions, effort, owner, Oracle reference.
- Severity: Critical = live control gap (access, pay, compliance); High = defect already degrading operations; Medium = avoidable cost or data debt; Low = housekeeping.
- Domains used: Security & access, Scheduled processes & reports, Integrations & payroll flows, Worker data, Approvals & transactions, Absence, Workforce structures, Payroll configuration, Recruiting, Journeys & onboarding. Score each 0–100; overall = mean.
- Always include a "What is working" set with the same rigour as the findings.

## 5. Report rules (non-negotiable)

- **Statistics only.** No usernames, person names, person numbers, email addresses or domains, personal folder paths with a user in them. Holder-class tables instead of name tables. Role codes and catalog paths are fine. Keep names in the chat / a separate remediation workbook.
- **No methodology.** No "Scope and method" section, no scoring formula, no SQL or table names in prose, no description of how a measure was taken. Results only.
- **No pre-go-live dating** anywhere in the text; "converted at go-live" is the phrasing for legacy artefacts.
- Footer: `© <year> The Hackett Group, Inc. All Rights Reserved. Prepared by Jonathan Stevenson.`
- Minimum font size 15px; self-contained single HTML (fonts, logo, CSS, JS embedded); prints cleanly.
- Order: Title/KPIs → Summary (score) → Footprint → Definitions → Working well → Scorecard by domain → Findings register → Trends → Access → National IDs → Failing processes (with root-cause card and schedule-ownership table) → Payroll (issues table, element table, not-yet-verified list) → Recruiting → Modules.
- Build it with `assets/build.py` + `assets/data.py` (see `references/report-spec.md`), then **render it headlessly with Playwright and check**: no console errors, every nav anchor lands with the heading ~64px below the sticky nav and the section fully revealed, no stray names/emails (`grep` for `@`), no stale cross-references after renumbering.

## 6. Interaction spec (what the client liked)

- Sticky nav that highlights the section in view; nav clicks use animated (smooth) scroll computed from **offsetTop**, never from a transformed bounding box.
- Framer-style "appear": each section's inner wrapper starts at opacity 0 / scale 0.5 and grows to 1 over ~1.3s (`cubic-bezier(.22,1,.36,1)`) as it enters the viewport; replays every time a section leaves and re-enters. Apply the transform to an inner wrapper so IntersectionObserver sees the true position (tall sections otherwise never trigger). Grid-layout sections animate directly.
- Bars grow when their section appears; overall score counts up; finding panels animate open; cards lift on hover. Honour `prefers-reduced-motion`.
- Use `overflow-x: clip` (not hidden) if anything is parked off-page, or sticky breaks.

## 7. Talking to the user

Answer questions about what was found directly with the numbers and the mechanism. When asked "what are we not thinking about", separate what is measurable now from what needs another source, and name the single biggest risk. When challenged ("did you look at it?"), reproduce the problem in the headless browser before answering.
