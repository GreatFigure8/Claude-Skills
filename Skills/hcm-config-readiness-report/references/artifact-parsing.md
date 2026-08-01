# Parsing the Requirements Artifacts

How to extract the requirements baseline from the client's design artifacts. Use the `xlsx`
skill's `extract-text` or pandas/openpyxl to read. Confirm the header row per sheet — these
workbooks put titles, navigation, and comments in the first several rows, so the real header is
often not row 1.

## KDD Disposition tracker (e.g. `KDD_Disposition_*.xlsx`)
- Main sheet: `KDD tracker v3.0` (or similar). Real rows have a non-null **Unique ID** like
  `KDD.HCM.CMP.001`.
- Key columns: `Unique ID` (col ~2), `Area` (~3), `Track` (~4), `Workstream` (~5), `KDD Topic`
  (~8), `KDD Description` (~9), `Decision` (~10), `Status` (~12).
- Filter HCM with `Track == 'People & Culture'` (HCM modules) and `Track == 'Security'`
  (security KDDs). Workstreams look like `HCM (Core HR)`, `HCM (Compensation)`, etc.
- Use `Status == 'Confirmed'` decisions as the committed baseline. Map each KDD to a config area
  via its Workstream / the module token in the Unique ID.
- A `KDD Dashboard` sheet usually carries the confirmed/in-progress totals for a sanity check.

## RTM (`Requirement_Traceability_Matrix*.xlsx`)
- Main sheet: `RTM`. Real rows: `Requirement ID` starts with `REQ.` (skip the template example
  row).
- Key columns: `Requirement ID` (~1), `KDD#` (~2), `Track` (~3), `Workstream` (~4),
  `Requirement Disposition`/`Requirement Type` (~10/11), `Requirement Status` (~18),
  `Design Status` (~23), `Build Status` (~26), `Deployment - Status` (~32).
- Filter HCM with `Track == 'People & Culture'` (or `.HCM.` in the Requirement ID).
- **The weight denominator** = count of rows with `Requirement Disposition == 'Configuration'`
  per area. Integration / Data Conversion / Report / Security / Personalization dispositions are
  tracked separately and excluded from the configuration-readiness denominator.
- **Critical integrity check**: these RTMs frequently have lifecycle columns
  (Requirement/Design/Build/Deployment Status) **unpopulated** — everything reads "Open"/blank.
  If so, you cannot score from RTM status; score from live environment validation and say so in
  the report.

## Design Decisions log (`HCM_Design_Decisions.xlsx`)
- Sheet `Decisions`: columns `Decision`, `Answer`, `Oracle HCM Module`, `Topic`, `Status`,
  `Source Deck`. Supplements the KDDs with finer field-level decisions per module. Use `Status`
  (`Decided` vs `To be confirmed`) to weight confidence.

## Configuration Workbooks (`HCM_Configuration_Workbook_-_*.xlsx`, one per module)
- Each workbook has a `Contents` sheet listing configuration tasks and, often, per-environment
  status columns: `Dev2 Configuration`, `QA Configuration`, `PROD Configuration`. The Dev2
  column is the team's **self-reported** status (`Not Started` / `In Progress` / blank).
- These workbooks are the **design spec** of what each module should contain (per-task sheets
  carry the intended values). Treat the self-reported Dev2 status as a hint, but let the **live
  environment** be the authority for what is actually configured.
- Known workbooks: Core HR, Compensation, Talent Management, Recruiting Cloud, Learning,
  Goals and Performance, Help Desk, Communicate. Each maps to one or more config areas.

## Building the baseline
1. KDD confirmed decisions per area → the "what was decided" layer.
2. RTM Configuration-disposition requirement counts per area → the **weights**.
3. Workbook per-task intended values → the specific values to validate in the environment.
4. Design Decisions → field-level confirmations / open items.

Then map each area to its live-environment validation query (see `fusion-hcm-objects.md`),
assign MET/PARTIAL/NOT MET, and score.
