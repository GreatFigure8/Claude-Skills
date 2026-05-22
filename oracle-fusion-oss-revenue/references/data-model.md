# OSS / VRM / XLA / GL Data Model

The complete table graph for OSS subscription revenue, with grains and join keys. **Read this before writing any new query** — most OSS bugs are grain/join-key mistakes.

## Table of contents
1. The end-to-end data flow
2. Source layer: OSS subscriptions
3. Source layer: VRM source documents & lines
4. Engine layer: performance obligations (POL) and distributions (POLD)
5. Engine layer: satisfaction events
6. Billing
7. Accounting layer: XLA → GL
8. Reference/dimension tables (customers, items, COA, currency)
9. The canonical join map (one place, all keys)
10. Grain cheat-sheet

---

## 1. The end-to-end data flow

```
OSS_SUBSCRIPTIONS (header, versioned by major_version)
   └─ OSS_PRODUCTS (one row per subscription product line; PK = subscription_product_id)
            │  (OSS pushes each product line into VRM as a source-doc line)
            ▼
VRM_SOURCE_DOCUMENTS (document_type_code='FUSION_OSS'; one per subscription document)
   └─ VRM_SOURCE_DOC_LINES  (VSD; versioned; PK-ish = document_line_id)
            │  (the VRM engine creates performance obligations from each line)
            ▼
VRM_PERF_OBLIGATION_LINES  (POL; the natural reporting grain; engine-owned amounts)
   ├─ VRM_PERF_OBLIGATION_LIN_DISTS (POLD; one row per POL × period × account_class — engine-truth recognized revenue)
   └─ VRM_POL_SATISFACTION_EVENTS    (the recognition schedule; used to project future periods)
            │  (accounting is created in subledger accounting)
            ▼
XLA_DISTRIBUTION_LINKS → XLA_AE_LINES → XLA_AE_HEADERS  (subledger accounting)
            ▼
GL_CODE_COMBINATIONS / GL_LEDGERS / GL_PERIOD_STATUSES  (general ledger)
```

`VRM_CUSTOMER_CONTRACT_HEADERS` (VCC) sits beside POL (one contract header per POL via `customer_contract_header_id`) and carries the *contract* currency.

`VRM_BILLING_LINE_DETAILS` carries billing (billed amount/quantity/date) per document line.

---

## 2. Source layer: OSS subscriptions

### OSS_SUBSCRIPTIONS (subscription header)
- **Versioned** by `major_version`. Always dedup to latest: `ROW_NUMBER() OVER (PARTITION BY subscription_id ORDER BY major_version DESC) = 1`.
- Key columns: `subscription_id`, `subscription_number`, `status`, `source_key` (sales order header id), `primary_party_id` (→ customer), `major_version`, `extn_attribute_char005` (service contract header id).

### OSS_PRODUCTS (subscription product lines)
- **One row per product line** within a subscription. **PK = `subscription_product_id`.** This is the most important OSS key — it's the bridge target from VRM (see §9).
- A single subscription can have *hundreds* of product rows (348 observed on one Imagine subscription). Joining at subscription-header grain alone causes catastrophic fan-out (see gotchas).
- Key columns: `subscription_product_id`, `subscription_id`, `product_number`, `product_name`, `inventory_item_id`, `status`, `product_total`, `start_date`, `end_date`, `bill_to_acct_id`, `po_number`, `cust_trx_type_seq_id`, `extn_attribute_char006` (end user).
- `start_date`/`end_date` are the OSS contract line dates — used for *display* columns (contract start/end, schedule ship date) but **NOT** for bucket math. Bucket math uses VPO revenue dates (see recognition reference).

---

## 3. Source layer: VRM source documents & lines

### VRM_SOURCE_DOCUMENTS (VSS)
- One row per subscription document. Filter `document_type_code = 'FUSION_OSS'`.
- Key columns: `document_id`, `document_number`, `document_type_code`, `legal_entity_id`, `ledger_id` (→ GL_LEDGERS → functional currency), `ledger_name`, `bill_to_customer_name`, `organization_name` (business unit), `currency_code`.
- `document_number` carries a source-system prefix (first chars). An old version of the report tried `SUBSTR(document_number, 4) = subscription_number` to bridge to OSS — **this is wrong** (see gotchas #5). Use the product-id bridge instead.

### VRM_SOURCE_DOC_LINES (VSD)
- **Versioned.** Multiple rows per `(document_id, line_num)` differing by `version_number`. **Do NOT blindly dedup to latest version** — POLs anchor to specific (often older) versions; deduping drops them (see gotchas #6).
- Key columns: `document_id`, `document_line_id` (the POL anchor key), `document_type_code`, `line_num`, `item_number`, `item_id` (= inventory_item_id, → item dimensions), `line_amount`, `quantity`, `version_number`, `src_attribute_date7` (revenue-end-date fallback), `bill_to_customer_party_name` (line-level, ~100% populated in Imagine), `doc_line_id_char_2` (**the OSS bridge** — holds `subscription_product_id`).
- `SRC_ATTRIBUTE_CHAR*` / `SRC_ATTRIBUTE_DATE*` are 60+ pass-through columns OSS populates. Known mappings:
  - `doc_line_id_char_2` → `oss_products.subscription_product_id` (clean numeric bridge — preferred).
  - `src_attribute_char8` → composite key `<subscription_number>-PRDT-<subscription_product_id>` (same bridge, string form; extract trailing id with `REGEXP_SUBSTR(...,'\d+$')` if char_2 is unavailable).
  - `src_attribute_char50` → "Sales Order Contract" reference (ATR50 layout column).
  - `src_attribute_date7` → revenue end date fallback when `vpo.revenue_end_date` is null.

---

## 4. Engine layer: performance obligations

### VRM_PERF_OBLIGATION_LINES (POL / VPO) — the reporting grain
- One row per performance obligation. **A single VSD line can spawn multiple POLs** (bundled products, license/PCS/services splits, modifications). The report's natural grain.
- Always filter `removed_flag = 'N'` (excludes terminated/removed obligations from the active set; see recognition reference for termination handling).
- Key columns: `perf_obligation_line_id`, `document_line_id` (→ VSD), `customer_contract_header_id` (→ VCC), `net_line_amt` (**= Net Line TCV (T)**, the authoritative line value, transaction currency), `entered_cur_recog_rev_amt` (**lifetime** recognized, transaction currency), `entered_cur_billed_amt`, `revenue_start_date`, `revenue_end_date`, `satisfaction_measurement_model`, `satisfaction_base_proportion`, `line_currency_code` (**the transaction currency** — NOT the contract currency), `reference_currency_code`, `removed_flag`.
- **Critical**: `entered_cur_recog_rev_amt` is *lifetime* recognized revenue, not per-period. Multiplying it by a per-period satisfaction ratio is a known math bug (gotchas #1).

### VRM_PERF_OBLIGATION_LIN_DISTS (POLD / VPOLD) — engine-truth distributions
- **One row per (POL × period × account_class).** This is the engine's accounting distribution table and the *truth source* for what revenue belongs to which period.
- Key columns: `perf_obligation_line_id`, `perf_obligation_line_dist_id`, `application_id`, `account_class` (filter `'ORA_REV'` for revenue), `amount` (entered/transaction currency = T), `acctd_amount` (ledger/functional currency = F), `original_accounting_date` (**the period revenue actually belongs to** — use this), `accounting_date` (the GL date booked — often a catch-up date; do NOT use for attribution), `code_combination_id`, `ledger_id`, `event_id`, `exchange_rate`.
- `SUM(amount) GROUP BY perf_obligation_line_id, TRUNC(original_accounting_date,'MM')` filtered to `account_class='ORA_REV'` reconciles exactly to `POL.entered_cur_recog_rev_amt`.
- POLD already carries the engine's per-period FX (`exchange_rate`), so a POLD-based design needs no `gl_daily_rates` lookup at all.

---

## 5. Engine layer: satisfaction events

### VRM_POL_SATISFACTION_EVENTS (VPS)
- The recognition *schedule* per POL — used to project future (not-yet-recognized) periods.
- Key columns: `document_line_id`, `perf_obligation_line_id`, `satisfaction_measurement_date`, `satisfaction_measurement_num`, `satisfaction_quantity`, `satisfaction_period_proportion` (the per-event proportion, "sbl"), `processed_flag` (`'Y'` = already recognized), `discarded_flag` (`'N'` = still active; modifications/terminations set `'Y'`).
- Pairs with `vpo.satisfaction_base_proportion` ("sbh"). Projection for a future period = `(satisfaction_period_proportion / satisfaction_base_proportion) × net_line_amt`.
- The current waterfall takes the latest event per POL (`ROW_NUMBER ... ORDER BY satisfaction_measurement_num DESC = 1`) for the satisfaction-date display; a fuller bucket model needs the *whole* schedule (every event), not just the latest.

---

## 6. Billing

### VRM_BILLING_LINE_DETAILS
- Billing facts per document line. Filter `document_type_code='FUSION_OSS'` and `NVL(bill_quantity,-1) <> 0`.
- Aggregate per `document_line_id`: `MAX(bill_date)`, `SUM(bill_amount)` (= total billed), signed `bill_quantity` (flip sign for credit memos: `CASE WHEN bill_amount<0 THEN -ABS(bill_quantity) ELSE bill_quantity END`).

---

## 7. Accounting layer: XLA → GL

The original report traverses subledger accounting to get GL segments and period. POLD (§4) carries most of this directly, so a POLD-based rewrite collapses this six-table chain to `vpold → gcc, gll`. But the existing/validated report still uses the XLA path, so know it:

```
VRM_PERF_OBLIGATION_LIN_DISTS  vpold
  → XLA_DISTRIBUTION_LINKS  xdl  ON xdl.source_distribution_id_num_1 = vpold.perf_obligation_line_dist_id
                                 AND xdl.application_id = vpold.application_id
                                 AND xdl.source_distribution_type = vpold.account_class
  → XLA_AE_LINES   xal  ON xal.ae_header_id = xdl.ae_header_id AND xal.ae_line_num = xdl.ae_line_num
  → XLA_AE_HEADERS xah  ON xah.ae_header_id = xal.ae_header_id  (filter accounting_entry_status_code IN ('F','D'))
  → GL_CODE_COMBINATIONS gcc ON gcc.code_combination_id = xal.code_combination_id
  → GL_LEDGERS gll ON gll.ledger_id = xah.ledger_id
  → GL_PERIOD_STATUSES glp ON glp.ledger_id = xah.ledger_id
        AND vpold.original_accounting_date BETWEEN glp.start_date AND glp.end_date
        AND glp.adjustment_period_flag='N' AND glp.application_id = 10455   ← tenant-specific
```

- `xdl.event_type_code IN ('REV_PERF_OBL_SATISFIED','REV_PERF_OBL_BILLED','REV_INITIAL_PERF')` in the original. Note `REV_PERF_OBL_BILLED` mixes billing into revenue events; a cleaner filter is POLD `account_class='ORA_REV'`.
- The original picks one accounting line per POL with `ROW_NUMBER ... ORDER BY xdl.ROWID` — **ROWID is not a stable sort key**; for POLs with multiple distributions across different revenue streams the chosen row is non-deterministic. Same caveat applies to `company`/`department`/`revenue_stream` pulled this way.

---

## 8. Reference / dimension tables

### Customers
- `HZ_PARTIES`: `party_id`, `party_name`. Join `hz_parties.party_id (+) = oss_latest.primary_party_id` for customer name (subscription-header grain — one customer per subscription).

### Items (the `vsd.item_id` = `inventory_item_id` dimension)
- `EGO_ITEM_EFF_B`: extensible flexfields. **POB Classification** = `attribute_char1` where `context_code='Finance'`, aggregated `MAX` per `inventory_item_id`.
- `EGP_SYSTEM_ITEMS_B`: item master. **PLM** = `attribute5`, taken in the `'GLO'` master org (`inv_organization_definitions_v.organization_code='GLO'`), with `approval_status='A'`, `template_item_flag='N'`, `item_object_type IN ('ITEM','DOCUMENT')`.
- **Product Family** via the item-category catalog: `EGP_ITEM_CATEGORIES` → `EGP_CATEGORIES_B` → `EGP_CATEGORIES_TL` → `EGP_CATEGORY_SETS_B`, filtered to `catalog_code='Product_Reporting'` (tenant-specific catalog). The readable name is `EGP_CATEGORIES_TL.DESCRIPTION` (the `_B.CATEGORY_CODE` is just a numeric internal code like '121'; the business name like 'Eclipse+' lives in `_TL.DESCRIPTION`). Language filter `ect.language = USERENV('LANG')`.

### Chart of Accounts
- `GL_CODE_COMBINATIONS` (gcc): `segment1..segmentN`, `code_combination_id`. Segment meanings are tenant-specific — see `environment-and-tooling.md` for Imagine's mapping (Company=SEG1, Account=SEG3, Revenue Stream=SEG8, etc.).
- Revenue accounts identified by `segment3 LIKE '4%'` in Imagine (tenant-specific convention).
- `FND_ID_FLEX_SEGMENTS` / `FND_FLEX_VALUES(_TL)`: to resolve segment value-set codes (e.g. Revenue Stream code → description) portably by segment name. See currency/environment refs.

### Currency
- `GL_LEDGERS` (gll): `ledger_id`, `currency_code` (= **functional currency**), `name`.
- `GL_DAILY_RATES` (r): `from_currency`, `to_currency`, `conversion_date`, `conversion_rate`, `conversion_type`.
- `GL_DAILY_CONVERSION_TYPES` (dct): `conversion_type` → `user_conversion_type` (readable: 'Period End', 'Corporate'). Always join here rather than hardcoding internal conversion-type IDs. Full detail in `currency-tf.md`.

---

## 9. The canonical join map

Copy-paste reference. All in Oracle WHERE-clause join style.

```sql
-- OSS header → product line
osp.subscription_id = oss.subscription_id              -- OSS_PRODUCTS → OSS_SUBSCRIPTIONS

-- Source document → lines
vsd.document_id = vss.document_id                      -- VSD → VSS

-- ***THE OSS→VRM BRIDGE (per-line, eliminates fan-out)***
subscr.subscription_product_id (+) = TO_NUMBER(vsd.doc_line_id_char_2)
   -- where subscr exposes osp.subscription_product_id
   -- alt: TO_NUMBER(REGEXP_SUBSTR(vsd.src_attribute_char8,'\d+$'))

-- Source line → performance obligation
vpo.document_line_id = vsd.document_line_id            -- VPO → VSD  (do NOT pre-dedup vsd by version!)

-- POL → contract header (carries CONTRACT currency)
vcc.customer_contract_header_id = vpo.customer_contract_header_id

-- POL → distributions (engine-truth recognized revenue per period)
vpold.perf_obligation_line_id = vpo.perf_obligation_line_id

-- POL → satisfaction schedule
vps.perf_obligation_line_id = vpo.perf_obligation_line_id
vps.document_line_id        = vsd.document_line_id

-- Document → functional currency
gll.ledger_id (+) = vss.ledger_id                      -- GL_LEDGERS.currency_code = functional ccy

-- Item dimensions (all keyed on inventory_item_id = vsd.item_id)
pob_class.inventory_item_id (+) = vsd.item_id          -- POB classification
plm_glo.inventory_item_id  (+) = vsd.item_id           -- PLM
prod_category.inventory_item_id (+) = vsd.item_id      -- Product Family

-- Billing
pd.document_line_id (+) = vsd.document_line_id         -- VRM_BILLING_LINE_DETAILS agg

-- Customer (subscription-header grain)
hp.party_id (+) = oss_latest.primary_party_id
```

---

## 10. Grain cheat-sheet

| Entity | Grain | Dedup / aggregation needed |
|---|---|---|
| OSS_SUBSCRIPTIONS | subscription × major_version | dedup to latest `major_version` |
| OSS_PRODUCTS | subscription_product_id (per product line) | bridge per-line via `subscription_product_id`; never join at header grain alone |
| VRM_SOURCE_DOCUMENTS | document | filter FUSION_OSS |
| VRM_SOURCE_DOC_LINES | document_line_id × version | do NOT dedup by version for the POL join; DO dedup-to-latest only for header-TCV sum |
| VRM_PERF_OBLIGATION_LINES (POL) | perf_obligation_line_id | **the reporting grain**; filter removed_flag='N' |
| VRM_PERF_OBLIGATION_LIN_DISTS (POLD) | POL × period × account_class | `SUM ... GROUP BY POL, TRUNC(original_accounting_date,'MM')` filtered ORA_REV |
| VRM_POL_SATISFACTION_EVENTS | event (many per POL) | latest per POL for display; full schedule for projection |
| VRM_BILLING_LINE_DETAILS | billing detail (many per line) | aggregate per document_line_id |
| acc_info (XLA traversal) | one chosen row per POL | ROW_NUMBER tiebreak (ROWID — unstable; document the risk) |
| header_tcv | document | dedup VSD to latest version, then SUM(line_amount) per document |

**The single most important grain rule:** the report is at POL grain. OSS_PRODUCTS, satisfaction events, billing details, and POLD are all *finer or coarser* — every one of them needs either a per-line bridge, a pre-aggregation, or a dedup before it touches the POL spine, or it fans out.
