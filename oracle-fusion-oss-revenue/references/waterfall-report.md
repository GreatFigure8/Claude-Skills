# The Subscription Waterfall Report

The full architecture of the waterfall data model: CTE chain, bucket math, column mappings, audit invariants, and RTF layout. Pair this with `assets/waterfall_oss_aligned_reference.sql` (the working implementation, ~1490 lines) — this file is the map, that file is the territory.

## Table of contents
1. What the report produces
2. The CTE chain (execution order)
3. Bucket math (Jay's spec)
4. Column mappings (all 85 RTF columns)
5. Audit invariants
6. RTF layout notes
7. The `:p_period` parameter

---

## 1. What the report produces

A month-by-month projection of revenue per OSS performance-obligation line, relative to a selected accounting period (`:p_period`, format `MON-YY`). Each row is one POL. Columns include identifying/dimension fields, engine amounts (recognized, unrecognized, billed, TCV in both transaction (T) and functional (F) currency), and a horizontal "waterfall" of prorated revenue buckets:

- **Prior Amount** — everything before (`:p_period` − 5 months)
- **5 trailing months** (`m_5_ago` … `m_1_ago`)
- **Current month** (`current_month`, = `:p_period`)
- **17 forward months** (`m_1_ahead` … `m_17`, reaching `:p_period` + 17)
- **Long-tail summary buckets** — calendar quarters Q4-2027…Q4-2028, then calendar years 2029…2033 (absolute dates, not relative to `:p_period`)

Total ~85 columns, ~73 SQL-bound. End user: Jay Surface.

---

## 2. The CTE chain (execution order)

```
pdt            -- parse :p_period 'MON-YY' → first-of-month date (p_date)
src_docs       -- FUSION_OSS documents + ledger join (exposes ledger_id + functional_currency)
oss_latest     -- OSS_SUBSCRIPTIONS deduped to latest major_version
subscr         -- oss_latest + OSS_PRODUCTS + HZ_PARTIES (per product line; exposes subscription_product_id)
vsd_for_pols   -- VRM_SOURCE_DOC_LINES, ALL versions (no dedup — see gotcha #2)
base_data_se   -- satisfaction events + POL, latest event per (doc_line, POL)
period_der     -- VRM_BILLING_LINE_DETAILS aggregated per document_line_id
fx_rate        -- GL_DAILY_RATES × GL_DAILY_CONVERSION_TYPES, all (from,to,date) pairs, Period End + Corporate
pol_fx         -- per-line resolved FX (cross-currency only), at-or-before-date, rn=1
pob_class      -- EGO_ITEM_EFF_B Finance context, MAX per item
plm_glo        -- EGP_SYSTEM_ITEMS_B attribute5 in GLO org, MAX per item
prod_category  -- Product Family from Product_Reporting catalog (revenue_stream NULL here)
header_tcv     -- SUM(line_amount) per document, VSD deduped to latest version (see gotcha #8)
acc_info       -- XLA traversal → company/department/revenue_stream/period_name, rn=1 per POL by original_accounting_date
base_data      -- the core assembly: joins all the above onto the POL spine
final_data     -- adds p_date, month_offset, monthly_amount, revenue_amt, line_amt
buckets_n      -- computes all numeric bucket values ONCE (so they can be both formatted AND summed)
<final SELECT> -- formats buckets for display, derives audit columns, emits 85 columns
```

Key structural choices:
- `revenue_stream` is read from `acc_info` (GL segment8), **not** from `prod_category` (where it's left NULL to avoid conflict).
- Numeric bucket values are computed once in `buckets_n` then formatted in the final SELECT — avoids recomputing the same proration twice and lets the same numbers feed both display and any sum.
- `MATERIALIZE` hints were removed from `src_docs` and `base_data` for performance.
- `acc_info` bounds the XLA scan to a ~36-month window around `p_date` for performance, but attributes period via `original_accounting_date` (gotcha #3).

---

## 3. Bucket math (Jay's spec)

The recognition life of a POL is `revenue_start_date` → `NVL(revenue_end_date, vsd.src_attribute_date7)`. Spread `net_line_amt` evenly across it:

```
monthly_amount = net_line_amt / MONTHS_BETWEEN(revenue_end_date + 1, revenue_start_date)
```

Each **monthly** bucket = the portion of the recognition life landing in that calendar month, by day overlap:
```
bucket_value = monthly_amount
             × (days_active_in_bucket / days_in_calendar_month)
```
where `days_active_in_bucket = GREATEST(0, LEAST(rev_end, LAST_DAY(month)) − GREATEST(rev_start, first_of_month) + 1)` and `days_in_calendar_month = LAST_DAY(month) − first_of_month + 1`.

**Prior Amount** and **long-tail** buckets use `MONTHS_BETWEEN` proration over the overlap of (recognition window) and (bucket window) rather than per-day, e.g.:
```
prior_amount = monthly_amount × GREATEST(0, MONTHS_BETWEEN(
                 LEAST(rev_end + 1, ADD_MONTHS(p_date,-5)), rev_start))
q4_2027      = monthly_amount × GREATEST(0, MONTHS_BETWEEN(
                 LEAST(rev_end + 1, DATE '2028-01-01'),
                 GREATEST(rev_start, DATE '2027-10-01')))
```

**NULL handling:** when `revenue_start_date` or `revenue_end_date` is NULL, every bucket renders the static text `'start_date or end date_is null'`. Because of that text marker, all bucket columns are VARCHAR (`TO_CHAR`'d with format `'FM999999999999990.00'`, Excel-parseable).

**`monthly_projected_revenue`** (separate from the buckets) = true remaining revenue spread over remaining life:
```
(net_line_amt − recog_amt) / GREATEST(FLOOR(MONTHS_BETWEEN(revenue_end_date, p_date)), 1)
```
NULL when `revenue_end_date` is missing.

**Long-tail layout** (per WR-006 / WR-010 design): 24 monthly buckets, then 3rd-year calendar quarters (Q4-2027 … Q4-2028), then calendar years (2029 … 2033) — no overlap between the monthly and quarter/year ranges. These long-tail buckets use absolute calendar dates, so if `:p_period` falls inside one, the bucket includes the current and prior months of that range.

---

## 4. Column mappings (the full layout)

Identity / dimensions:
| Column | Source |
|---|---|
| COMPANY | `gcc.segment1` (from revenue accounting) |
| DEPARTMENT | `gcc.segment3` (GL natural account; layout header says "GL Account" but BIP tag is DEPARTMENT) |
| REVENUE_STREAM | `gcc.segment8` raw code (R010=License, R012=Perpetual License, R020=Care, R040=Managed Services, R050=Hardware, R060=SaaS, R070=Subscription). User chose the *raw* segment8 code, not the value-set description lookup. |
| CONTRACT | `vcc.customer_contract_number` |
| CUSTOMER | `hz_parties.party_name` via subscription primary party |
| BILL_TO_CUSTOMER | `NVL(vsd.bill_to_customer_party_name, vss.bill_to_customer_name)` (line-level first) |
| END_USER_NAME | `osp.extn_attribute_char006` |
| BUSINESS_UNIT | `vss.organization_name` |
| LEDGER_NAME | `gll.name` |
| SOURCE_DOCUMENT_NUMBER | `vss.document_number` |
| SO_LINE | `vsd.line_num` |
| CONTRACT_MODIFIER | parsed suffix of `document_number` after `-C` |
| ITEM | `vsd.item_number` |
| POB Classification / EXTENDED_ATTRIBUTE | `ego_item_eff_b.attribute_char1` (context Finance) |
| PLM | `egp_system_items_b.attribute5` (GLO org) |
| PRODUCT_FAMILY | `egp_categories_tl.description` (Product_Reporting catalog) |
| SALES_ORDER_CONTRACT_ATR50 | `vsd.src_attribute_char50` (placeholder/optional) |

Dates (display; bucket math uses VPO revenue dates):
| Column | Source |
|---|---|
| REVENUE_START_DATE / REVENUE_END_DATE | `vpo.revenue_start_date` / `NVL(vpo.revenue_end_date, vsd.src_attribute_date7)` |
| SCHEDULE_SHIP_DATE | `osp.start_date` (OSS has no ship date) |
| CONTRACT_START_DATE / CONTRACT_END_DATE | `osp.start_date` / `osp.end_date` |
| SATISFACTION_MEASUREMENT_DATE | `LAST_DAY(p_date)` |
| Accounting Period / PERIOD_NAME | `TO_CHAR(p_date,'MON-YY')` (echoes the param per Jay) |

Amounts:
| Column | Source |
|---|---|
| EXT_SELL_PRICE | `vsd.line_amount` (carried as `line_amt`) |
| EXT_LIST_PRICE | NULL placeholder (no list-price source confirmed) |
| TOTAL_BILLED | `NVL(period_der.total_billed, vpo.entered_cur_billed_amt)` |
| RECOGNIZED_REVENUE / RECOGNIZED_REVENUE_T | `vpo.entered_cur_recog_rev_amt` |
| UNRECOGNIZED_REVENUE / _T | `net_line_amt − recog_amt` (audit invariant) |
| UNBILLED_AMOUNT | `net_line_amt − NVL(total_billed, billed_amt)` |
| NET_LINE_TCV_T | `vpo.net_line_amt` |
| HEADER_TCV_T | `SUM(line_amount)` per document (latest-version dedup) |
| RECOGNIZED_REVENUE_F / NET_LINE_TCV_F | T value × conversion rate (see currency ref) |
| ROW_TOTAL | `net_line_amt` directly (= Net Line TCV (T)) |
| SATISFACTION_PCT | `revenue_amt / line_amt × 100` |
| CONVERSION_DATE / TYPE / RATE_TF | see currency ref |
| REVENUE_METHOD | mapped from `satisfaction_measurement_model` (Quantity / Period / Percent) |
| FUNCTIONAL_CURRENCY | `gl_ledgers.currency_code` |
| CURRENCY | `vpo.line_currency_code` (transaction) |

---

## 5. Audit invariants

(Full detail and the population-check query in `gotchas-and-fixes.md` §13.) Summary — all validated at 0 failures across 7,362 Imagine POLs:
- Recog (T) + Unrecog (T) = Net Line TCV (T)
- Billed (T) + Unbilled (T) = Net Line TCV (T)
- Row Total = Net Line TCV (T)
- Header TCV (T) = Σ Net Line TCV (T) per document

Maps to the requirements doc issues: IS-002 (Recog+Unrecog=TCV), IS-003 (Billed+Unbilled=TCV), IS-004 (date-range=TCV, via Row Total). IS-001 / WR-006 (no projection past Sept 2027 in the monthly band) was already satisfied — don't "re-fix" it.

---

## 6. RTF layout notes

- The RTF template (`SubscriptionWaterfall_v7.rtf`) has 85 columns, 73 SQL-bound.
- Built programmatically with Python (`build_rtf_v7.py` and predecessors). BIP emits uppercase tag names because aliases are not double-quoted (Oracle uppercases unquoted identifiers) — so `net_line_tcv_t` → `<NET_LINE_TCV_T>`.
- Bucket columns are text (VARCHAR) to allow the NULL-date marker string; numeric format `FM999999999999990.00` keeps Excel parsing them as numbers when populated.

---

## 7. The `:p_period` parameter

- Format `MON-YY` (e.g. `NOV-25`, `APR-26`). Parsed via `TRUNC(TO_DATE(:p_period,'MON-YY','NLS_DATE_LANGUAGE=AMERICAN'),'MONTH')`.
- Drives the entire relative bucket layout. The long-tail calendar buckets are *absolute* and don't shift with it.
- Date arithmetic rule (style + correctness): use `TRUNC(SYSDATE - N)` not `TRUNC(SYSDATE) - N` for historical look-back; use `ADD_MONTHS(p_date, N)` for month offsets.
- LOV note: if the parameter LOV combines display values (e.g. `docnum - customer`), parse out the real key before filtering, or the match silently fails.
