# Gotchas and Fixes — the OSS Revenue Trap Catalog

The highest-value file in this skill. Every entry is a real bug found against live Imagine data. The defining characteristic of OSS revenue bugs: **they return rows that look plausible rather than erroring out.** A query can run clean and still be silently wrong by millions of dollars. Treat each of these as a checklist item when reviewing or building OSS revenue SQL.

## Table of contents
1. The 348-way OSS_PRODUCTS fan-out
2. Version-skew silently drops POLs after a modification
3. Catch-up accounting dates misattribute 86% of revenue
4. Cross-currency label/value mismatch (T vs contract vs functional)
5. The lifetime-recognized math bug
6. The SUBSTR document-number bridge that matches nothing
7. Oracle outer-join silent inner-join conversion
8. Header-TCV double counting
9. Non-deterministic accounting-row pick (ROWID)
10. Missing measurement-model branch
11. Hardcoded tenant values
12. General debugging method for "zero rows" / "wrong numbers"
13. Audit invariants to always check

---

## 1. The 348-way OSS_PRODUCTS fan-out

**Symptom:** Every source document line appears an identical large number of times (348 was the observed value). A duplicate-source diagnostic shows `row_count = product_count = 348` and `pob_count = 1` → "OSS PRODUCT FAN-OUT".

**Cause:** Joining `oss_products` to source documents only at the *subscription-header* grain:
```sql
AND subscr.contract_number (+) = vss.document_number   -- WRONG: header-only join
```
A subscription with 348 product lines matches *every* source line to *all 348* products, because the only join key (subscription number) is shared by all products in the subscription.

**Fix — the OSS→VRM per-line bridge.** OSS writes the originating `subscription_product_id` onto the VRM source line. Join on it:
```sql
-- expose subscription_product_id in the subscr CTE, then:
AND subscr.contract_number (+) = vss.document_number
AND subscr.subscription_product_id (+) = TO_NUMBER(vsd.doc_line_id_char_2)
```
This collapses 348→1. As a consequence `product_number`, `start_date`, `end_date`, `product_total`, `end_user`, etc. become *row-accurate per line* instead of muddled across the whole subscription.

**Discovery path (worth knowing for similar problems):** the bridge was found by listing `SRC_ATTRIBUTE_*` columns on a fanned-out line and spotting `src_attribute_char8 = '000000000010756-C20-PRDT-32739142'` — the `<subscription_number>-PRDT-<product_id>` pattern. `32739142` turned out to be `oss_products.subscription_product_id`. The clean numeric form of the same value lives in `doc_line_id_char_2`.

**Diagnostic query (keep this):**
```sql
SELECT document_number, line_num, COUNT(*) row_count,
       COUNT(DISTINCT perf_obligation_line_id) pob_count,
       COUNT(DISTINCT product_number) product_count,
       CASE WHEN COUNT(DISTINCT perf_obligation_line_id) > 1
              AND COUNT(DISTINCT product_number) = 1 THEN 'PERF OBLIGATION FAN-OUT'
            WHEN COUNT(DISTINCT perf_obligation_line_id) = 1
              AND COUNT(DISTINCT product_number) > 1 THEN 'OSS PRODUCT FAN-OUT'
            WHEN COUNT(DISTINCT perf_obligation_line_id) > 1
              AND COUNT(DISTINCT product_number) > 1 THEN 'BOTH FAN-OUTS'
            ELSE 'OTHER' END duplicate_source
FROM ( <the query under test> )
GROUP BY document_number, line_num
HAVING COUNT(*) > 1
ORDER BY row_count DESC FETCH FIRST 20 ROWS ONLY;
```

---

## 2. Version-skew silently drops POLs after a modification

**Symptom:** Active contracts are simply *missing* from the report. In Imagine: 15 POLs across 7 documents vanished, including all 8 POLs of a fully-active 4-month $1,000 contract (`LineSplitsTest04`) — zero rows in the output despite being live.

**Cause:** Deduping `VRM_SOURCE_DOC_LINES` to the latest version:
```sql
ROW_NUMBER() OVER (PARTITION BY document_id, line_num ORDER BY version_number DESC) = 1  -- WRONG for the POL spine
```
When a contract is modified, the engine creates a *new* VSD version, but the existing POL still references the *old* version's `document_line_id`. The `rn=1` filter keeps the new version (which has no POL), then the inner join `vpo.document_line_id = vsd.document_line_id` drops the row entirely.

**Fix:** Do **not** dedup VSD by version on the POL spine. Use a CTE (`vsd_for_pols`) that keeps *all* versions:
```sql
vsd_for_pols AS (
  SELECT ... FROM vrm_source_doc_lines vsd, src_docs sd
  WHERE sd.document_id = vsd.document_id
    AND vsd.document_type_code = 'FUSION_OSS'   -- NO version dedup
)
```
The `vpo.document_line_id = vsd.document_line_id` join then naturally picks the correct version per POL (each POL anchors to a specific `document_line_id`). Per-line columns are correct because they come from the POL's anchored version — the engine-truth version for that POL.

**But:** header-TCV summing *does* need dedup, or it double-counts modified lines — handle that separately (see #8).

**Validation:** recovered 15 POLs (output went 7,216 → 7,231, matching the engine's count). Confirm by checking that known modified contracts (e.g. `LineSplitsTest04`, `CA000000866S`) appear.

---

## 3. Catch-up accounting dates misattribute 86% of revenue

**Symptom:** A single recent period shows wildly inflated revenue — potentially years of recognition piled into one month. Most extreme observed case: $62,844 of revenue belonging to April 2020 booked to April 2026.

**Cause:** Using `xah.accounting_date` (or POLD `accounting_date`) for period attribution. **86% of POLD revenue rows in Imagine are catch-up bookings** where the physical GL date differs from the period the revenue economically belongs to (migrations, backdated activations).

**Fix:** Attribute by `original_accounting_date`, never `accounting_date`:
```sql
-- period the revenue BELONGS to:
TRUNC(vpold.original_accounting_date, 'MM')
-- the GL date booked (use only to bound the XLA scan for performance, never for attribution):
xah.accounting_date
```
In `acc_info`, derive `period_name` from `vpold.original_accounting_date BETWEEN glp.start_date AND glp.end_date`. Keep an `xah.accounting_date BETWEEN ...` filter only as a performance bound on the XLA scan.

**Note:** Jay later requested the *displayed* "Accounting Period" column simply echo the selected `:p_period` parameter rather than the economic period. That's a display choice; the underlying `original_accounting_date` mechanism still matters for picking the right distribution row.

---

## 4. Cross-currency label/value mismatch

**Symptom:** Currency column shows the wrong currency code; F-column (functional) values are wrong or null. Affected ~3,000 cross-currency POLs in Imagine (e.g. 1,911 EUR-entered / GBP-contract POLs, plus HKD/SGD/CAD populations).

**Three distinct currency concepts that get conflated:**
- **Transaction (entered) currency** = `vpo.line_currency_code`. This is what `net_line_amt` and `entered_cur_recog_rev_amt` are denominated in. **This is (T).**
- **Contract currency** = `vcc.contract_currency_code`. Informational only. *Not* the denomination of the amounts.
- **Functional currency** = `gl_ledgers.currency_code` of the document's ledger. **This is the basis for (F).**

**The bug:** the original labeled amounts with `contract_currency_code` (wrong — they're in transaction currency) and converted to USD using a rate sourced *from* the contract currency (wrong direction) while assuming functional=USD.

**Fixes (full detail in `currency-tf.md`):**
- Label/display currency = `vpo.line_currency_code` (transaction).
- For (F): when `transaction_currency = functional_currency`, no conversion (rate 1, type 'N/A', date = today). Else look up `transaction → functional` rate.
- FX lookup must support *any* functional currency (Imagine has USD, INR, AUD, EUR, GBP ledgers — not all USD), not a hardcoded `to_currency='USD'`.
- Use at-or-before-date rate semantics with Period End primary / Corporate fallback (see #4 detail in currency ref) — exact-date matching recovered only ~10 of 3,024 cross-currency POLs; at-or-before recovered ~100%.

**Worked example (POL 30001):** GBP contract, USD transaction, USD ledger. Old code showed GBP and multiplied an already-USD amount by 1.3497 → $6.2M. Correct: show USD, no conversion → $4.6M.

---

## 5. The lifetime-recognized math bug

**Symptom:** `revenue_amt`, `unrecognized_revenue`, and `satisfaction_pct` are subtly wrong for period-satisfied lines.

**Cause:** `final_data` computed `(b.sbl / NULLIF(b.sbh,0)) * b.recog_amt`. But `recog_amt` (`entered_cur_recog_rev_amt`) is **lifetime** recognized revenue, while `sbl/sbh` is the *latest period's* satisfaction proportion. Multiplying them yields a quantity with no clean meaning.

**Fix:** apply the satisfaction ratio to `net_line_amt` (the correct projection base), not to lifetime `recog_amt`. For audit columns, prefer deriving by subtraction from engine truth (see invariants, #13): `unrecognized = net_line_amt − recog_amt`.

---

## 6. The SUBSTR document-number bridge that matches nothing

**Cause:** `SUBSTR(document_number, 4) = subscription_number` was used to bridge VRM→OSS. It doesn't match real document-number formats: `SUBSTR('UK000000032SUB',4)='000000032SUB' ≠ 'UK000000032SUB'`; `SUBSTR('OIC_LineSplitsTest04',4)='_LineSplitsTest04' ≠ 'LineSplitsTest04'`. The `(+)` outer join then silently NULLs `customer_name`, `product_name`, `contract_start_date`, etc. on every row.

**Fix:** the product-id bridge (#1): `vsd.doc_line_id_char_2 = osp.subscription_product_id`.

---

## 7. Oracle outer-join silent inner-join conversion

**Trap:** In Oracle `(+)` syntax, a predicate on an outer-joined table *without* `(+)` silently converts the outer join back to an inner join, dropping rows.

```sql
WHERE a.col = b.col (+)
  AND b.status = 'X'          -- BUG: no (+), demotes the outer join to inner
```
**Fix:** every predicate on the deficient table needs `(+)`:
```sql
  AND b.status (+) = 'X'
```
This is a frequent silent cause of "I added a filter and now rows disappeared." Audit every `(+)` chain when row counts drop unexpectedly.

---

## 8. Header-TCV double counting

**Cause:** Header TCV = `SUM(line_amount)` per document. If you sum across *all* VSD versions (which the version-skew fix #2 deliberately keeps), modified lines are counted multiple times.

**Fix:** `header_tcv` is the *one* place to dedup VSD to latest version before summing:
```sql
header_tcv AS (
  SELECT document_id, SUM(line_amount) header_tcv_t
  FROM ( SELECT vsd.document_id, vsd.line_amount,
                ROW_NUMBER() OVER (PARTITION BY vsd.document_id, vsd.line_num
                                   ORDER BY vsd.version_number DESC) rn
         FROM vrm_source_doc_lines vsd, src_docs sd
         WHERE sd.document_id = vsd.document_id AND vsd.document_type_code='FUSION_OSS' )
  WHERE rn = 1
  GROUP BY document_id )
```
So the report keeps all versions on the POL spine (#2) **and** a separate latest-version sum for header TCV. The two coexist. (Validated: `HEADER_TCV_T = SUM(NET_LINE_TCV_T)` across all 1,075 OSS documents — zero mismatches.)

---

## 9. Non-deterministic accounting-row pick (ROWID)

**Cause:** `acc_info` picks one accounting line per POL via `ROW_NUMBER() OVER (... ORDER BY xdl.ROWID) = 1`. ROWID is not a stable sort key. For POLs with multiple distributions across *different* revenue streams, the chosen `company`/`department`/`revenue_stream` is non-deterministic.

**Mitigation:** acceptable for single-distribution POLs (the common case). Flag it for QA on multi-distribution POLs. A deterministic tiebreaker (e.g. by amount or date) is preferable if it matters.

---

## 10. Missing measurement-model branch

**Cause:** The `CASE WHEN model='ORA_MEASURE_QUANTITY_SATISFIED' ... WHEN 'ORA_MEASURE_PERIOD_SATISFIED' ... END` has no branch for `ORA_MEASURE_PERCENT_SATISFIED` → NULL revenue_amt/line_amt for percent-satisfied lines.

**Status:** **Confirmed harmless in Imagine today** — all OSS POLs are PERIOD_SATISFIED; PERCENT and QUANTITY are only used by FUSION_DOO / FUSION_CONTRACTS, which the report filters out. But it's brittle if OSS configuration changes. Add the branch defensively if touching this logic.

---

## 11. Hardcoded tenant values

These work in Imagine but will break or mislead in other tenants. Always flag them:
- `glp.application_id = 10455` — the period-statuses application id (confirmed via `FND_APPLICATION` for Imagine). Look it up rather than hardcode.
- `gcc.segment3 LIKE '4%'` — revenue-account convention. Tenant-specific COA.
- `gcc.segment8` = Revenue Stream, `segment1`=Company, `segment3`=Account — Imagine COA segment assignment.
- `catalog_code = 'Product_Reporting'` — DigiKey/Imagine item catalog; other tenants use `PRODUCT_FAMILY`, `PRODUCT_CATALOG`, etc.
- Conversion-type internal id `'300000002367347'` — this was a hardcoded opaque id that happens to be 'Period End' in this tenant. **Never hardcode**; join `GL_DAILY_CONVERSION_TYPES` on `user_conversion_type` instead.
- `'GLO'` master org for PLM attribute.

---

## 12. General debugging method

**For "zero rows":**
1. Check the `(+)` chains for accidental inner-join demotion (#7).
2. Comment out / outer-join-isolate newly added CTEs one at a time; re-check row count after each.
3. Suspect hardcoded tenant filters (`application_id`, segment patterns) returning nothing in this environment.
4. Verify a column you just added actually exists in the schema (a bad column name parse-errors, but a bad *join* silently zeroes).
5. Check whether the `:p_period` / parameter parsing matches the data (LOV display value vs. bare value mismatches).

**For "wrong / duplicated numbers":**
1. Run the fan-out diagnostic (#1) — identify which join multiplies.
2. Check grain: is every finer-grain table pre-aggregated or per-line-bridged before it hits the POL spine? (See data-model grain cheat-sheet.)
3. Check the audit invariants (#13). A failing invariant points straight at the broken column.
4. For currency, separate the three currency concepts (#4) and verify which one each amount/label uses.

**Always:** when an MCP connection is live, *run the query* before declaring a fix done. "Correct by construction" reasoning has masked real typos and a stray duplicated `FROM` block in this codebase. Also re-check `identify_environment` — the connection has switched tenants mid-session, and a query against the wrong (empty) tenant returns zero rows that look like a logic bug.

---

## 13. Audit invariants to always check

The report is fully reconcilable. After any change, validate these across the whole population (not just sample rows). Each holds *by construction* when the columns are derived correctly, so a non-zero failure count localizes the bug:

| Invariant | How to enforce | Check |
|---|---|---|
| **Recog (T) + Unrecog (T) = Net Line TCV (T)** | define `unrecognized_revenue_t = NVL(net_line_amt,0) − NVL(recog_amt,0)` | `SUM(CASE WHEN ABS(recog + unrecog − net_line_amt) > 0.01 THEN 1 ELSE 0 END) = 0` |
| **Billed (T) + Unbilled (T) = Net Line TCV (T)** | define `unbilled_amount = net_line_amt − NVL(total_billed, billed_amt)`; both columns must reference the *same* billed value | failures = 0 |
| **Row Total = Net Line TCV (T)** | source `row_total = net_line_amt` directly (don't re-sum buckets) | failures = 0 |
| **Header TCV (T) = SUM(Net Line TCV (T)) over the document** | header_tcv dedups VSD versions then sums line_amount | 0 documents mismatch |

Whole-population check pattern:
```sql
SELECT COUNT(*) total_rows,
  SUM(CASE WHEN ABS(net_line_tcv_t - row_total) > 0.01 THEN 1 ELSE 0 END) row_total_failures,
  SUM(CASE WHEN ABS(NVL(recognized_revenue_t,0)+NVL(unrecognized_revenue_t,0)-NVL(net_line_tcv_t,0)) > 0.01 THEN 1 ELSE 0 END) is002_failures,
  SUM(CASE WHEN ABS(NVL(total_billed,0)+NVL(unbilled_amount,0)-NVL(net_line_tcv_t,0)) > 0.01 THEN 1 ELSE 0 END) is003_failures
FROM ( <full query> );
```
Validated result on Imagine: 7,362 rows, 0 / 0 / 0 failures.
