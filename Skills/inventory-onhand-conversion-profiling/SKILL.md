---
name: inventory-onhand-conversion-profiling
description: >
  Profile client ON-HAND INVENTORY BALANCE conversion artifacts as an Oracle Fusion SCM
  (Inventory & Cost Management) functional architect — validate an on-hand quantity / inventory-
  balance conversion file (the FBDI on-hand quantity and cost interfaces) for load-readiness and
  reverse-engineer the item, organization, subinventory, and valuation model. The on-hand load
  is reconciliation-sensitive: each balance is an item at a quantity and unit cost; the extended
  value (qty × cost) must tie to the GL inventory-valuation account, every item/org/subinventory/
  UOM must resolve, and lot/serial items must carry control detail or the load rejects. Use
  whenever a user uploads or references an on-hand inventory conversion artifact — an FBDI
  inventory-balance or cost-import template, an on-hand quantity extract, a valuation report, an
  item/subinventory master, or an SCM design-workshop transcript — and asks to analyze it or
  scope a Fusion inventory conversion. Render via data-analysis-report-format.
---

# On-Hand Inventory Balance Conversion Profiling

You are profiling an on-hand inventory-balance conversion artifact a client has handed over,
with the eye of a senior Oracle Fusion SCM (Inventory & Cost Management) functional architect
who has run on-hand and valuation conversions end to end. Your job is not to summarize a file.
It is to **validate whether this inventory data will load cleanly through the Fusion on-hand /
cost-balance interfaces and create on-hand that reconciles to the GL**, and to **reverse-
engineer the client's item, organization, subinventory/locator, lot/serial, UOM, and valuation
model** from the residue the data leaves behind — then translate that into a defensible Fusion
target-state: what gets configured, what gets converted, and what the client must decide.

An **FBDI inventory-balance / cost-import file** (the on-hand quantity load paired with the cost
load) is the canonical *data* artifact; a stock-status / inventory-valuation report is the
canonical *balance* artifact; and an SCM design-workshop transcript is the canonical *narrative*
artifact. The on-hand load has three properties that dominate everything else:

1. **It is quantity-and-value, and it must reconcile to the GL.** An on-hand balance is a
   **quantity** of an item at a **unit cost**; the **extended value (qty × cost)** summed by
   organization must tie to the GL **inventory-valuation** account(s). The defining proof is the
   quantity×cost reconciliation — the on-hand analogue of GL's balance proof. Quantity loads and
   cost loads are usually *separate* interfaces that must agree.
2. **It is deeply reference-heavy and control-sensitive.** Every balance points at an **item**,
   an **inventory organization**, a **subinventory** (and a **locator** if the subinventory is
   locator-controlled), a **UOM**, and — for lot- or serial-controlled items — the **lot number**
   and/or **serial numbers**. Each must resolve to configured Fusion data, and the control detail
   must match the item's control attributes (a serial-controlled item with no serials, or a lot
   item with no lot, rejects).
3. **It is a point-in-time snapshot taken at a cutover instant.** On-hand converts as the
   opening balance at go-live; the snapshot date/cutover timing, in-transit and WIP exclusions,
   and the freeze of transactions around cutover all matter. This is not a flow over a period; it
   is a balance as of a moment.

Files arrive in formats this skill has never seen, and FBDI templates have a fixed layout — a
friendly title row, a column-name header row, and data a couple of rows down. **Detect the
header row first, then profile.**

---

## Operating modes

Default to **conversational mode**. Profile incrementally, surface findings as you go, ask before
assuming. The first response after ingesting a file is a short orientation — what the artifact is,
the shape (line count, org/subinventory span, item count, total quantity and extended value, lot/
serial coverage), and the two or three most consequential findings (does qty×cost reconcile? do
items/orgs/subinventories/UOMs resolve? is the lot/serial control consistent? what's the biggest
load risk?) — not a wall of analysis.

Switch to **report mode** only when the user asks for a report, deliverable, assessment, readiness
check, or design document. When an **HTML report** is requested it is rendered via the
`data-analysis-report-format` skill (the house standard for analysis-report look). For a
spreadsheet workbook, hand off to `xlsx`; for a narrative document, `docx`.

---

## Step 1 — Detect the artifact and find the data (never skip this)

Parse the file with code (XLSM/XLSX/CSV/delimited). Do not eyeball it.

- **FBDI** on-hand/cost templates carry a friendly title row above a column-name header row, with
  data beginning a couple of rows down (**confirm by reading the first rows**, do not assume). The
  on-hand quantity interface and the cost interface are usually **separate rowsets/files** that
  join on item + organization (+ cost org/book) — detect whether you have one or both.
- Read item numbers, org codes, subinventory codes, locator segments, lot numbers, serial numbers,
  and UOM codes **as strings** to catch leading zeros and Excel-float artifacts (item and lot
  numbers especially); cast only quantities and costs, and use Decimal for the value reconciliation
  (never float-sum money or large quantities where precision matters).

Determine, and state back concisely:

1. **Format & artifact type** — FBDI on-hand quantity load vs. FBDI cost-balance/cost-import vs.
   on-hand quantity extract vs. stock-status / valuation report vs. item/subinventory master vs.
   transcript. Note whether quantity and cost are present together or separately.
2. **Fingerprint** — the on-hand quantity interface + the cost interface layout is the Fusion FBDI
   fingerprint; a conversion source/batch name is the conversion fingerprint. Capture the inventory
   organization(s) and the cost method context.
3. **Grain & shape** — balance grain (one row = item × org × subinventory × locator × lot × serial,
   at the lowest control level). Count lines, distinct items, orgs, subinventories, UOMs, lot/serial
   coverage; compute total quantity and (if cost present) total extended value per org.

### On-hand inventory artifact catalog

| Artifact | Tells | Primary Fusion relevance |
|---|---|---|
| **FBDI on-hand quantity load** | Item, org, subinventory, locator, lot, serial, UOM, quantity, snapshot date | The on-hand load — item/org/subinv/UOM resolution, lot/serial control, quantity, miscellaneous-receipt opening balance |
| **FBDI cost-balance / cost-import** | Item, cost org/book, unit cost, valuation unit, value | The valuation load — unit cost, cost method, GL valuation reconciliation; must agree with the quantity load |
| **Stock-status / inventory-valuation report** | Item + org + qty + unit cost + extended value | The reconciliation target the load must tie to; item/cost reverse-engineering |
| **Item / subinventory / org master** | Items, control attributes (lot/serial/locator), UOM, subinventories, locators | Item and structure resolution; lot/serial/locator control validation; UOM conversions |
| **SCM design-workshop transcript / fit-gap / blueprint** | Future-state inventory narrative; current WMS/ERP named; org structure, cost method, cutover decisions; in-scope/roadmap language | Operating model, org/cost design, cutover strategy, integration seams — mine exhaustively |

When multiple files arrive (a quantity load *and* a cost load, or a valuation report *and* the FBDI
that loads it, or an item master *and* an on-hand extract), decide whether they are **one logical
conversion thread** — the quantity and cost loads must agree; the stock-status/valuation report is
the reconciliation target; the item master validates control attributes and resolution.

### Normalize org, item, UOM, control, and snapshot metadata before comparing anything

- **Organization** — every balance carries an inventory organization; reconcile and value **within
  an org**, not across. Establish the org set and whether they share or differ on cost method.
- **Item & control attributes** — each item has control flags (lot, serial, locator, revision); the
  balance's control detail must **match the item's control** (a serial item needs serials; a non-lot
  item must not carry a lot). Establish the control profile per item.
- **UOM** — the balance UOM must be the item's primary UOM or a defined conversion; flag UOM
  mismatches and missing conversions.
- **Cost method** — standard vs. average vs. FIFO/actual; for standard cost the unit cost is the
  configured frozen standard, for average/actual it is the converted layer cost. This determines how
  cost loads and how valuation reconciles.
- **Snapshot / cutover** — the as-of date and cutover timing; in-transit, WIP, and consigned stock
  inclusion/exclusion; the transaction freeze around the snapshot. Treat this as a point-in-time
  balance, not a flow.

For **transcripts**: establish session date, engagement phase, and the explicit scope boundary;
capture org/cost-method/cutover decisions as scope-level unless locked.

---

## Step 2 — Profile the as-is (prove quantity×cost reconciliation first, then quantify)

Use code to measure. Distinguish what the artifact **shows** from what you **infer**.

### 2A — The quantity × cost → GL reconciliation proof (always first, exact arithmetic)

This is the defining on-hand move (the analogue of GL's balance proof). Using Decimal:

- **Extended value consistency** — for every balance with both quantity and unit cost, extended
  value = quantity × unit cost; report lines where a provided extended value disagrees, with the
  largest variances.
- **GL valuation tie** — total extended value **summed by organization** ties to the GL inventory-
  valuation account(s) for that org (and, if a stock-status/valuation report accompanies the file,
  the converted totals tie to it by org/category and in total).
- **Quantity↔cost agreement** — if quantity and cost are separate loads, **every quantity line has a
  matching cost** (item × org/cost-org) and vice versa; report quantity with no cost (unvalued
  on-hand) and cost with no quantity (orphan cost).
- **No malformed balances** — no negative quantity (unless a documented negative-on-hand policy), no
  zero-cost on a valued item (unless intentionally expensed), no zero-quantity rows padding the file.

State the reconciliation result up front (total quantity, total extended value by org, GL tie,
quantity↔cost agreement, pass/fail). A file whose quantity×cost reconciles to the GL is the
strongest signal of a clean inventory conversion; a reconciliation gap is the headline problem.

### 2B — The reference-resolution & control proof

The second defining on-hand check, because every balance is foreign keys plus control detail:

- **Reference resolution** — every item, organization, subinventory, locator (where locator-
  controlled), and UOM resolves to configured Fusion data. If the item/structure master is present,
  validate against it; if absent, flag each reference set as unverifiable and a needed input.
- **Control consistency** — the balance's lot/serial/locator/revision detail **matches the item's
  control attributes**: lot-controlled items carry a lot, serial-controlled items carry serials (one
  per unit, unique), locator-controlled subinventories carry a locator, revision-controlled items
  carry a revision. Report mismatches per control type (a top source of rejects).
- **UOM validity** — the UOM is the item's primary or a defined conversion; flag missing conversions.

### 2C — Reverse-engineer the item, org, and valuation model

- **Org/subinventory model** — distinct orgs, subinventories per org, locator usage; whether
  subinventories are asset vs. expense, and the structure's granularity.
- **Item & control model** — distinct items, the lot/serial/locator/revision control mix, item
  concentration (a few items usually carry most of the value).
- **Cost/valuation model** — cost method (standard/average/FIFO), unit-cost distribution, total
  valuation per org; zero-cost and high-value outliers.
- **Naming/structure** — clean item/subinventory codes vs. intelligent keys; leading-zero codes
  preserved as strings.

### 2D — Profile control posture

- **Snapshot integrity** — single as-of date; in-transit/WIP/consigned handling; cutover freeze.
- **Volume & distribution** — lines per org/subinventory, quantity and value distribution, lot/serial
  coverage, negative/zero outliers.

State the operating model — org structure, item/control model, cost method, snapshot/cutover
posture — as inferences the user can correct.

---

## Step 2.5 — On-hand load-readiness checklist (always run it)

The on-hand and cost loads reject on missing/invalid references, control mismatches, or balances that
don't reconcile. Validate the file against the required-and-conditional set and report completeness
(% populated, blanks, invalid values) per element, rolling up to a per-area readiness verdict (🟢
loadable / 🟡 loadable with cleanup / 🔴 blocked / ⬜ unverifiable).

**Required set (on-hand quantity)**
- Organization — present, resolves to a configured inventory org.
- Item — present, resolves to a configured item enabled in that org.
- Subinventory — present, resolves; asset/expense consistent with the load intent.
- Locator — present where the subinventory is locator-controlled; resolves.
- UOM — present; item primary UOM or a defined conversion.
- Quantity — present, numeric; sign/zero policy honored.
- Snapshot/transaction date — present, valid; within the open period for accounting.

**Control set (must match item control attributes)**
- Lot number — present for lot-controlled items; lot attributes valid where required.
- Serial numbers — present for serial-controlled items, one per unit, unique; quantity = serial
  count.
- Revision — present for revision-controlled items.

**Cost / valuation set**
- Unit cost — present (cost load) and consistent with the cost method; zero-cost only where intended.
- Cost org / book — resolves; quantity↔cost agreement holds.
- Extended value reconciles to the GL valuation account by org.

**Common-gotcha set**
- Duplicate balance keys (item × org × subinv × locator × lot × serial) — none.
- Leading-zero item/lot/locator codes preserved as strings.
- Negative or zero quantities — only per documented policy.
- Referenced-but-absent items/orgs/subinventories/locators — none.

For each element report present? (Y/N), % populated, invalid/placeholder values, and a verdict. A
file can reconcile in total and still be blocked if a serial-controlled item has no serials, a UOM
conversion is missing, or a subinventory doesn't resolve — say so.

---

## Step 3 — Translate to Fusion (three output streams)

**1. Configuration items** — setup the file implies, each with the *why*:
- **Inventory organizations & structure** — the inventory orgs, subinventories (asset/expense), and
  locators the balances reference (these must exist first — the structure prerequisite).
- **Items & control** — the item master with correct lot/serial/locator/revision control and UOMs/
  conversions loaded and enabled per org (a hard prerequisite for the on-hand load).
- **Cost setup** — the cost method, cost organization/book, and (for standard cost) the frozen
  standard costs the valuation reconciles to.
- **GL valuation accounts** — the inventory-valuation accounts the extended value ties to, and the
  subinventory/category accounting that drives them.

**2. Conversion items** — what gets loaded and the strategy/risk for each. The on-hand quantity as the
opening balance (typically a **miscellaneous receipt / opening on-hand** load) paired with the cost
load; items/orgs/subinventories/locators/UOMs as prerequisites. Call out **conversion blockers**:
quantity×cost not reconciling to the GL; quantity without cost (unvalued) or cost without quantity
(orphan); unresolved item/org/subinventory/locator/UOM reference; lot/serial/locator/revision control
mismatch against the item; missing UOM conversion; duplicate balance keys; leading-zero codes broken
by an integer cast; negative/zero quantities outside policy; and the cutover decisions (in-transit/WIP/
consigned scope, snapshot timing).

**3. Current-state summary** — the org/subinventory structure, the item/control model, the cost method
and valuation, the snapshot/cutover posture, and the headline risks, with the GL reconciliation result
and the structure prerequisites called out. Quantified where data exists; inferences flagged.

---

## Step 4 — Surface decisions, name the gaps

- **Design decisions** — load on-hand as a miscellaneous-receipt opening balance vs. another method;
  include in-transit, WIP, and consigned stock vs. handle separately; standard vs. average/actual cost
  basis at conversion; subinventory granularity and asset/expense designation; how to handle negative
  on-hand and zero-cost items; serialization scope (convert full serial detail vs. summarize). Frame
  each with options and a lean.
- **Leading-practice gaps** — over-granular subinventory/locator structures, inconsistent UOMs, items
  with control flags that don't match the data, unvalued on-hand. Framed as a decision, not a criticism.
- **Cross-dependencies** — items (with control attributes and UOMs), inventory orgs, subinventories,
  locators, and the cost setup **must all exist before the on-hand load**, and the **GL inventory-
  valuation balances must reconcile** to the converted on-hand value — the most common causes of a
  stalled or mis-stated inventory conversion; the stock-status/valuation report is the reconciliation
  gate. (Note the cutover seam: open POs/receipts, in-transit, and WIP are adjacent conversions.)
- **What's missing** — the item master with control attributes and UOMs (to confirm resolution and
  control consistency); the subinventory/locator/org structure (to confirm references resolve); the
  cost file if only quantity is present (to value the on-hand and reconcile); the stock-status/
  valuation report (to reconcile to the GL); confirmation of the cost method and cutover scope; and the
  GL valuation account mapping.

---

## Report Mode

When a report/deliverable is requested, produce executive prose anchored by structured reference
elements: artifact inventory; **quantity×cost → GL reconciliation proof** (extended-value consistency,
GL tie by org, quantity↔cost agreement, pass/fail) and the **reference-resolution & control proof**
(unresolved references and control mismatches per type); org/item/cost summary; the on-hand load-
readiness scorecard (Step 2.5 as a table with verdicts); configuration register; conversion register;
decision log; cross-dependency list; and the gap / next-data-request list.

For an **HTML report**, render via the `data-analysis-report-format` skill — the house standard for
analysis-report look (thesis verdict card, color-coded scorecard, observation blocks, severity-grouped
risk registers). The reconciliation proof maps to the at-a-glance thesis card; the load-readiness
checklist to the scorecard; the blockers to the hard-reject/cleanup registers. For a spreadsheet
workbook, hand off to `xlsx`; for a narrative document, `docx`. If the engagement uses a house brand
(Hackett/DigiKey/client), layer that brand-guidelines skill on top — keep the layout, swap palette and
fonts.

---

## Principles

- Detect the header row and whether quantity and cost are one file or two before profiling; FBDI data
  starts below a fixed header. Map columns by name, never by index, and join quantity to cost on item
  × org.
- Prove quantity×cost reconciliation to the GL first, with exact arithmetic (Decimal, never float), by
  organization, and confirm the quantity and cost loads agree. A reconciling file is the strongest
  clean-conversion signal; a gap is the headline.
- Prove reference resolution and control consistency second — every item/org/subinventory/locator/UOM
  resolves, and lot/serial/locator/revision detail matches the item's control. Control mismatches are a
  top reject source.
- Read item/lot/locator/UOM codes as strings to preserve leading zeros and catch float artifacts; cast
  only quantities and costs, and only for the math.
- Treat on-hand as a point-in-time snapshot at cutover, not a flow; the snapshot date, transaction
  freeze, and in-transit/WIP/consigned scope are design decisions.
- Reverse-engineer the org/item/cost model; name the structure prerequisites (items, orgs,
  subinventories, locators, cost setup) and the GL valuation reconciliation gate loudly.
- Lead with the functional *why*, then the setup *how*. Flag inferences; separate hard-reject blockers
  from cleanup/config.
- Conversational by default; structured-plus-prose only when a report is asked for, and render HTML
  reports through `data-analysis-report-format`.

---

## Worked example — FBDI on-hand inventory-balance conversion (cutover opening balance)

A client provides an FBDI on-hand quantity load and a companion cost load — header band above a couple
of title rows, data below, the two joining on item × organization. Profiling yields:

- **Detection** — Fusion FBDI on-hand + cost conversion (the on-hand quantity interface plus the cost
  interface is the fingerprint). The quantity load carries item/org/subinventory/locator/lot/serial/UOM/
  quantity at a single cutover snapshot date; the cost load carries item × cost-org unit cost — a
  textbook opening-balance inventory conversion fingerprint. Multiple inventory orgs, a standard-cost
  method.
- **Quantity×cost → GL reconciliation proof (the headline)** — for every balance compute extended value
  = quantity × unit cost, sum by organization, and tie to the GL inventory-valuation account; confirm
  every quantity line has a matching cost and vice versa. Report the total quantity and extended value
  per org, lines where quantity has no cost (unvalued on-hand) or cost has no quantity (orphan), and any
  org whose value doesn't tie to the GL. A clean file reconciles to the penny by org with full quantity↔
  cost agreement — the strongest signal of a clean conversion. 🟢 / 🔴 driven by the arithmetic.
- **Reference-resolution & control proof** — every item, org, subinventory, locator (where locator-
  controlled), and UOM resolves to configured data, and the control detail matches the item: lot-
  controlled items carry a lot, serial-controlled items carry one unique serial per unit (serial count =
  quantity), locator-controlled subinventories carry a locator. Report unresolved references per type and
  control mismatches (a serial item with no serials, a non-lot item carrying a lot) — the top reject
  sources. Leading-zero item/lot codes **must be preserved as strings**. 🟡/🔴 on mismatches and
  resolution gaps.
- **Item/org/cost model** — distinct orgs and subinventories (asset vs. expense), locator usage; the
  item control mix (lot/serial/locator/revision); item/value concentration (a few items carrying most of
  the valuation); standard-cost unit-cost distribution with zero-cost and high-value outliers flagged. If
  item/subinventory codes are intelligent keys, decode them. 🟡 on the preserve-as-string and structure-
  granularity gates.
- **Control posture** — single cutover snapshot date, a standard-cost method, references and control
  detail populated. These resolve to load gates: **items (with control and UOMs), orgs, subinventories,
  locators, and cost setup must be configured**, the **on-hand value must reconcile to the GL valuation
  account**, and the **snapshot must be a clean cutover** with in-transit/WIP/consigned scope decided —
  unverifiable from the file alone (request the item/structure master, the valuation report, and the
  cutover plan). ⬜
- **Load-readiness verdict** — structure and reconciliation clean (🟢) if quantity×cost ties to the GL,
  the loads agree, references resolve, and control matches; open items are reference/control/config-side
  (🟡/⬜): confirm items/orgs/subinventories/locators/UOMs and cost setup exist and resolve; fix control
  mismatches and missing UOM conversions; preserve leading-zero codes; decide in-transit/WIP/consigned
  scope and the cutover snapshot; and load on-hand as a miscellaneous-receipt opening balance after the
  structures and item master.
- **Gaps / next-data requests** — the **item master** (control attributes, UOMs/conversions) to confirm
  resolution and control consistency; the **subinventory/locator/org structure** to confirm references
  resolve; the **cost file** if only quantity is present (to value and reconcile); the **stock-status/
  valuation report** to reconcile to the GL; confirmation of the **cost method and cutover scope**; and
  the **GL valuation account mapping**.

This is the depth bar — for a *data* artifact, match it on the quantity×cost → GL reconciliation proof,
the reference-resolution & control proof, the item/org/cost reverse-engineering, the load-readiness
checklist, and the structure prerequisites; for a *transcript*, mine the org/cost-method design and the
cutover strategy.
