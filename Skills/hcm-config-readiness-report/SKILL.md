---
name: hcm-config-readiness-report
description: >
  Produce an Oracle Fusion HCM configuration READINESS report: compare a requirements baseline
  (KDD / RTM / Configuration Workbooks) against what is actually configured in a live Fusion
  environment, and score readiness with a defensible, shown formula. Use whenever someone asks
  for a "readiness report", "state of configuration", "config state", "where are we in the
  configuration", "what's implemented vs. designed", a "fit-gap" or "gap analysis" against an
  environment, or to validate the environment against the KDDs / RTM / config workbooks — for
  Oracle Fusion HCM (Core HR, Compensation, Talent, Recruiting, Learning, Payroll, Absence,
  Benefits, Time & Labor, Help Desk, Security). Trigger even without the word "readiness": any
  request to assess, audit, or scorecard how far an HCM environment has progressed against design
  artifacts. Also trigger when only an environment is available and no requirements artifacts are
  given (falls back to a no-percentage config-state audit). HCM-first; method extends to ERP/SCM.
---

# Oracle Fusion HCM Configuration Readiness Report

## What this produces

A single, self-contained branded HTML report that tells the reader **where the configuration
stands** by comparing **what was designed/required** (the client's KDDs, RTM, and Configuration
Workbooks) against **what is actually configured in the live environment**, expressed as a
color-coded, area-by-area readiness scorecard with an explicit, auditable percentage.

The value scales with the requirements data provided: the more of the KDD / RTM / Config
Workbook set is supplied, the more precise the readiness verdict. With none, the report degrades
gracefully to a configuration-state audit **with no percentage** (there is no defensible
denominator without a requirements baseline).

## The two modes — decide first

**Mode A — Readiness (one or more requirements artifacts provided).** Build a requirements
baseline from the artifact(s), validate each area against the live environment, and score
readiness with the formula below. This is the primary mode.

**Mode B — Config-state audit (no requirements artifact).** Do **not** emit any percentage —
maturity or readiness. State explicitly that no defensible denominator exists without a
requirements baseline, report only present-vs-absent / customer-built-vs-seeded with the same
color verdicts, and add a callout inviting the user to supply a KDD / RTM / Config Workbook to
convert the audit into a scored readiness report.

> Never invent a denominator. The percentage exists only in Mode A and only against committed
> requirements.

## Workflow

1. **Read the companion references.** Before querying, read `references/fusion-hcm-objects.md`
   (the object/column catalog, custom-vs-seeded predicates, and hard-won environment quirks) and
   `references/report-format.md` (the exact HTML layout, palette, and section structure). These
   encode environment-specific gotchas that will otherwise cause failed queries and wrong counts.

2. **Bind the environment.** Select the target Fusion environment before any SQL
   (`select_environment` with its ID). Re-select if the session reports `environment-not-selected`
   — the binding drops between calls.

3. **Parse the requirements artifacts (Mode A).** Read every provided artifact and extract the
   committed requirements. See `references/artifact-parsing.md` for the known shapes of the KDD
   Disposition tracker, the RTM, the Design Decisions log, and the per-module Configuration
   Workbooks, including which columns carry the decisions and dispositions.

4. **Validate against the live environment.** For each requirement area, query the environment
   and judge whether it is configured and whether the configured value **matches** the
   requirement. Verify objects via `all_objects` first (many HCM/ASM objects are synonyms/views,
   not base tables). Separate Oracle-seeded baseline from customer configuration — seeded counts
   are NOT evidence of build. Flag anything unqueryable as NOT ASSESSED rather than guessing.

5. **Score (Mode A).** Apply the formula below and show it in the report.

6. **Render and present.** Build the HTML per `references/report-format.md`, save to
   `/mnt/user-data/outputs/`, and present it.

## Scoring formula (Mode A) — make the percentage defensible

```
Per requirement-area, assign a coverage score:
   MET          = 1.0   configured in the environment AND matches the KDD/RTM/workbook design
   PARTIAL      = 0.5   configured but incomplete, prototype, or value gaps remain
   NOT MET      = 0.0   required but absent / seed-only / test-only in the environment
   NOT ASSESSED = excluded from BOTH numerator and denominator (query-scope limit)

Area readiness %    = coverage score x 100

Overall readiness % = Sum( area_weight x coverage_score )  /  Sum( area_weight )  x 100

   where area_weight = count of RTM Configuration-disposition requirements mapped to that area
                       (the committed configuration scope). If the RTM is absent, fall back to
                       KDD decision counts per area as the weight, and say so.
```

Always display, beside any percentage: the weight basis, the assessed vs. excluded counts, and
the MET / PARTIAL / NOT MET split, so the number is auditable. If an area has zero assessed
requirements, show `n/a`, not 0%.

**Integrity check on RTM status columns.** The RTM often ships with its lifecycle columns
(Requirement Status, Design Status, Build Status, Deployment Status) unpopulated. If they are
blank, do NOT derive readiness from them — derive it from live environment validation and state
this plainly in the report so the score is not mistaken for RTM-reported progress. As those
columns get maintained, the environment-derived score can be reconciled against them.

## Audit scope

Query the live environment across these areas, using the confirmed objects, custom-vs-seeded
predicates, and quirks in `references/fusion-hcm-objects.md`:

- **Enterprise structures** — LDGs (legislation + currency), legal entities / legal employers,
  business units.
- **Workforce structures** — departments, organizations/trees, locations, jobs, positions,
  grades + grade rates.
- **Worker population** — persons/assignments by type and status; distinguish real population
  from config/test data.
- **Payroll** — payroll definitions vs. seeded statutory elements (seed is not build).
- **Security (expanded)** — role mappings; **custom roles** vs. seeded `ORA_` roles; **custom
  security profiles** (person/position/org/payroll/LDG/country) and whether wired to data roles;
  elevated-access callouts (e.g. IT Security Manager holders).
- **Extended audit (expanded)** — **Action / Action Reasons** (custom vs. seeded); **Salary
  Basis** mapping validated to LDG and to Grade Rate, flagging any basis missing either link;
  **custom flexfields** (DFF/EFF/KFF customer-deployed enabled segments vs. seeded registrations).
- **Always NOT ASSESSED unless specifically queried** — FSM feature opt-ins (ASM choice-table
  decode), fast formulas, BPM approval rules. Declare these out of scope for the pass rather than
  guessing.

## Verdict semantics (keep this color mapping)

🟢 green = MET / Configured · 🟠 amber = PARTIAL · 🔴 red = NOT MET / Not started ·
⚪ gray = NOT ASSESSED (excluded from scoring).

## Guardrails

- Never emit a percentage in Mode B; never invent a denominator.
- Never count Oracle-seeded objects as customer configuration (elements, payment methods, `ORA_`
  roles, seeded actions/reasons, DFF registrations — all seed unless proven custom).
- Verify every table/column before querying; on an `ORA-00904`/`ORA-00942`, re-check via
  `all_objects` / `all_tab_columns` rather than retrying the guess.
- Every number traces to a live query; query-scope limits are NOT ASSESSED, not assumptions.
- Re-`select_environment` if the session drops.
- Coverage scores are interpretive at the area level — say so, and offer requirement-level
  scoring for any module if the user wants a finer denominator.

## Extending to ERP / SCM

The method is pillar-agnostic: keep the modes, formula, validation logic, report format, and
guardrails; swap only the audit object set. ERP: ledgers, COA + segment values, BSV→LE, and the
AP/AR/FA/Cash/Tax/Procurement subledgers. SCM: inventory orgs, real items vs. templates,
subinventories, on-hand, costing, orders/supply. Build the requirements baseline the same way
from the same artifact types filtered to the pillar's track.
