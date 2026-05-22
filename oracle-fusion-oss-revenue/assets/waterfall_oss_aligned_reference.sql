-- ============================================================================
-- Revenue Waterfall Report - OSS Subscriptions Only
-- Columns aligned to SubscriptionWaterfall.rtf layout + additional business cols
--
-- :p_period       expected as 'MON-YY' e.g. 'NOV-25'
--
-- Waterfall logic (per functional design):
--   * Bucket layout is RELATIVE to :p_period:
--       Prior Amount   = portion of contract value falling BEFORE :p_period - 5 months
--       5 preceding    = months p_date-5 through p_date-1
--       Selected month = p_date (current_month alias)
--       17 succeeding  = months p_date+1 through p_date+17
--   * Each bucket value is a PROJECTED proration of net_line_amt across the
--     revenue recognition life: VPO.REVENUE_START_DATE to NVL(VPO.REVENUE_END_DATE,
--     VSD.SRC_ATTRIBUTE_DATE7).
--       monthly_amount = net_line_amt / MONTHS_BETWEEN(end+1, start)
--       bucket_value   = monthly_amount * (days_active_in_bucket
--                                           / days_in_calendar_month)
--   * Prior bucket    = monthly_amount * months_before_(p_date - 5 months).
--   * NULL revenue dates -> all buckets render the static text
--     'start_date or end date_is null'.
--   * Buckets are VARCHAR (TO_CHAR'd) because of the static text marker.
--     Numeric values use format 'FM999999999999990.00' (Excel-parseable).
--   * CONTRACT_START_DATE / CONTRACT_END_DATE display columns continue to show
--     subscr.start_date / subscr.end_date (OSS subscription line dates) for
--     reference; the bucket math itself uses VPO revenue dates.
--   * Numeric bucket values are computed once in the buckets_n CTE so they can
--     be both formatted for display AND summed for unrecognized_revenue_t.
--   * UNRECOGNIZED_REVENUE / UNRECOGNIZED_REVENUE_T = sum of 17 strictly-future
--     buckets (m_1_ahead through m_17) per Jay Surface. Prior Amount and
--     current_month are EXCLUDED -- only periods strictly AFTER the selected
--     period count as 'unrecognized'.
--
-- Performance changes applied:
--   * MATERIALIZE hints removed from src_docs and base_data.
--   * acc_info CTE filters XLA accounting entries to a 36-month window
--     around :p_period to avoid scanning all revenue accounting entries.
--     PERIOD_NAME is attributed using vpold.ORIGINAL_ACCOUNTING_DATE so that
--     catch-up bookings (revenue economically belonging to an older period
--     but physically posted to a recent GL date) are reported in the correct
--     period. Without this, ~86% of revenue rows would misattribute.
--
-- Best-guess mappings (review and adjust):
--   COMPANY     = GL_CODE_COMBINATIONS.SEGMENT1 (from revenue accounting)
--   DEPARTMENT  = GL_CODE_COMBINATIONS.SEGMENT3 (GL natural account)
--                 NOTE: layout header says "GL Account" but BIP tag is DEPARTMENT
--   POB Classification = EGO_ITEM_EFF_B.ATTRIBUTE_CHAR1 where CONTEXT_CODE='Finance'
--   SCHEDULE_SHIP_DATE = subscr.start_date (OSS has no traditional ship date)
--   CONTRACT_START_DATE / CONTRACT_END_DATE = subscr.start_date / end_date
--   SALES_ORDER_CONTRACT_ATR50 = NULL placeholder (requires DOO_HEADERS_ALL join)
--   CONTRACT_MODIFIER = parsed suffix of document_number after '-C'
--   EXT_LIST_PRICE = NULL placeholder (no list-price source identified)
--   EXT_SELL_PRICE = vsd.line_amount
--   PLM = EGP_SYSTEM_ITEMS_B.ATTRIBUTE5 in GLO master org
--   PRODUCT_FAMILY = EGP_CATEGORIES_TL.DESCRIPTION from the Product_Reporting
--     catalog (DigiKey-specific catalog_code; adjust filter per tenant).
--     Revenue Stream is NULL pending business sign-off on the split rule.
--   FUNCTIONAL_CURRENCY = GL_LEDGERS.CURRENCY_CODE (from revenue accounting ledger)
--   CONVERSION_RATE_TF = fx_rate.period_end_rate (contract currency -> USD).
--     ASSUMPTION: functional currency is USD.
--   CONVERSION_DATE = pd.bill_date (the date the FX rate was sourced for).
--   CONVERSION_TYPE = 'Period End' when primary rate found, 'Corporate' on fallback,
--     NULL when no rate available. (Will be refined when fx_rate logic uses
--     conversion_type name lookup instead of internal ID.)
--   BILL_TO_CUSTOMER = VRM_SOURCE_DOC_LINES.BILL_TO_CUSTOMER_PARTY_NAME
--     (line-level, 100% populated in this tenant) with header-level fallback.
--   SATISFACTION_MEASUREMENT_DATE = latest satisfaction event date per POL.
--   HEADER_TCV_T = sum of line_amount from VRM_SOURCE_DOC_LINES per document.
--   Satisfaction % = revenue_amt / line_amt * 100 (proportion recognized).
-- ============================================================================

WITH pdt AS
(
SELECT
    TRUNC(TO_DATE(:p_period, 'MON-YY', 'NLS_DATE_LANGUAGE=AMERICAN'), 'MONTH') p_date
FROM
    dual
),
src_docs AS
(
SELECT
    vss.document_id,
    vss.document_number,
    vss.document_type_code,
    vss.legal_entity_id,
    vss.ledger_id,
    gll.currency_code functional_currency,
    NVL(gll.name, vss.ledger_name) ledger_name,
    vss.bill_to_customer_name,
    vss.organization_name business_unit
FROM
    vrm_source_documents vss,
    gl_ledgers gll
WHERE
    1 = 1
    AND vss.document_type_code = 'FUSION_OSS'
    AND gll.ledger_id (+) = vss.ledger_id
),
oss_latest AS
(
SELECT
    subscription_id,
    subscription_number,
    header_status,
    source_key,
    primary_party_id,
    extn_attribute_char005
FROM
    (
    SELECT
        oss.subscription_id,
        oss.subscription_number,
        oss.status header_status,
        oss.source_key,
        oss.primary_party_id,
        oss.extn_attribute_char005,
        ROW_NUMBER() OVER (PARTITION BY oss.subscription_id ORDER BY oss.major_version DESC) rn
    FROM
        oss_subscriptions oss
    )
WHERE
    rn = 1
),
subscr AS
(
SELECT
    osp.subscription_product_id,
    osp.product_number,
    osp.product_name,
    osp.status line_status,
    ol.header_status,
    osp.inventory_item_id,
    osp.product_total,
    osp.bill_to_acct_id,
    osp.po_number,
    osp.cust_trx_type_seq_id,
    ol.subscription_number contract_number,
    ol.extn_attribute_char005 service_contract_header_id,
    osp.start_date,
    osp.end_date,
    ol.source_key sales_order_header_id,
    osp.extn_attribute_char006 end_user,
    hp.party_name customer_name
FROM
    oss_latest ol,
    oss_products osp,
    hz_parties hp
WHERE
    1 = 1
    AND osp.subscription_id = ol.subscription_id
    AND hp.party_id (+) = ol.primary_party_id
),
vsd_for_pols AS
(
-- Source doc lines for all OSS documents. We INTENTIONALLY do NOT dedup by
-- version_number here, because perf obligation lines (POLs) anchor to a
-- specific VSD version's document_line_id - and when a contract is modified,
-- newer VSD versions are created but existing POLs continue to reference the
-- OLDER version. Filtering to rn=1 by version_number would silently drop
-- those POLs (15 active POLs in this tenant as of 2026-05-14).
--
-- The downstream join in base_data (vpo.document_line_id = vsd.document_line_id)
-- naturally selects the correct VSD version per POL because each POL is
-- anchored to a specific document_line_id. Per-line columns (line_amount,
-- quantity, item_id, dates, doc_line_id_char_2) are therefore correct for
-- the POL's anchored version - which is the engine-truth version for that POL.
--
-- header_tcv (below) does its own dedup-at-latest-version to avoid double
-- counting line amounts when summing per document.
SELECT
    vsd.document_id,
    vsd.document_line_id,
    vsd.document_type_code,
    vsd.line_num,
    vsd.item_number,
    vsd.item_id,
    vsd.line_amount,
    vsd.quantity,
    vsd.src_attribute_date7,
    vsd.doc_line_id_char_2,
    vsd.bill_to_customer_party_name,
    vsd.version_number
FROM
    vrm_source_doc_lines vsd,
    src_docs              sd
WHERE
    1 = 1
    AND sd.document_id = vsd.document_id
    AND vsd.document_type_code = 'FUSION_OSS'
),
base_data_se AS
(
SELECT
    document_line_id,
    perf_obligation_line_id,
    satisfaction_measurement_date,
    satisfaction_measurement_num,
    satisfaction_quantity,
    sbl,
    net_line_amt,
    sbh,
    rn
FROM
    (
    SELECT
        vps.document_line_id,
        vps.perf_obligation_line_id,
        vps.satisfaction_measurement_date,
        vps.satisfaction_measurement_num,
        vps.satisfaction_quantity,
        vps.satisfaction_period_proportion sbl,
        vpo.net_line_amt,
        vpo.satisfaction_base_proportion sbh,
        ROW_NUMBER() OVER (PARTITION BY vps.document_line_id, vps.perf_obligation_line_id
                           ORDER BY vps.satisfaction_measurement_num DESC) rn
    FROM
        vrm_pol_satisfaction_events vps,
        vrm_perf_obligation_lines vpo,
        vsd_for_pols vsd
    WHERE
        1 = 1
        AND vpo.perf_obligation_line_id = vps.perf_obligation_line_id
        AND vsd.document_line_id = vps.document_line_id
        AND vps.processed_flag = 'Y'
    )
),
period_der AS
(
SELECT
    document_line_id,
    MAX(bill_date) bill_date,
    SUM(CASE WHEN bill_amount < 0 THEN -ABS(bill_quantity) ELSE bill_quantity END) bill_quantity,
    SUM(NVL(bill_amount, 0)) total_billed
FROM
    vrm_billing_line_details
WHERE
    1 = 1
    AND document_type_code = 'FUSION_OSS'
    AND NVL(bill_quantity, -1) <> 0
GROUP BY
    document_line_id
),
fx_rate AS
(
-- FX rates between any currency pair. Previously hardcoded to_currency='USD'
-- but Imagine has multiple functional-currency ledgers (USD, INR, AUD, EUR,
-- etc.) so the lookup must support whatever functional currency the POL's
-- ledger uses.
--
-- Two rate types are extracted:
--   period_end_rate : USER_CONVERSION_TYPE = 'Period End' (primary)
--   corporate_rate  : USER_CONVERSION_TYPE = 'Corporate'  (fallback)
--
-- We join to GL_DAILY_CONVERSION_TYPES to look up by the readable name
-- (USER_CONVERSION_TYPE) rather than the opaque internal ID. The old SQL
-- used the literal '300000002367347' which happens to be Period End in
-- this tenant but is non-portable across customers.
--
-- The downstream consumer (recognized_revenue_f, net_line_tcv_f) uses
-- NVL(period_end_rate, corporate_rate) so Period End is preferred and
-- Corporate provides a fallback when no Period End rate is loaded.
--
-- The join in base_data uses AT-OR-BEFORE date semantics (not exact-match)
-- so that POLs with bill_dates falling on weekends/holidays/dates with no
-- loaded rate still resolve to the most recent prior rate. This recovers
-- FX conversion for ~100% of cross-currency POLs vs ~10% under exact-match.
SELECT
    r.from_currency,
    r.to_currency,
    r.conversion_date,
    MAX(CASE WHEN dct.user_conversion_type = 'Period End'
              THEN r.conversion_rate END) period_end_rate,
    MAX(CASE WHEN dct.user_conversion_type = 'Corporate'
              THEN r.conversion_rate END) corporate_rate
FROM
    gl_daily_rates            r,
    gl_daily_conversion_types dct
WHERE
    1 = 1
    AND dct.conversion_type = r.conversion_type
    AND dct.user_conversion_type IN ('Period End', 'Corporate')
GROUP BY
    r.from_currency,
    r.to_currency,
    r.conversion_date
),
pol_fx AS
(
-- Resolves the FX rate per source document line using AT-OR-BEFORE date
-- semantics. For each cross-currency POL (where transaction currency differs
-- from the document's functional currency), we pick the most recent rate
-- whose conversion_date <= the target date.
--
-- Target date precedence (per POL):
--   1. The line's last billing date (pd.bill_date), when the line has billed
--   2. LAST_DAY of the selected accounting period (LAST_DAY(p_date)), when
--      the line has never billed -- this gives unbilled cross-currency
--      contracts a sensible Period End rate for the selected month
--
-- The functional currency comes from the source document's ledger
-- (vrm_source_documents.ledger_id -> gl_ledgers.currency_code), so a POL
-- booked to a USD ledger gets a transaction-to-USD rate, a POL booked to an
-- INR ledger gets a transaction-to-INR rate, etc.
--
-- ROW_NUMBER... rn = 1 picks the latest at-or-before rate per source doc
-- line. Same-currency lines (transaction = functional) have no row here and
-- downstream code treats them as rate=1 with conversion_type='N/A'.
SELECT
    document_line_id,
    transaction_currency,
    functional_currency,
    fx_conversion_date,
    period_end_rate,
    corporate_rate
FROM
    (
    SELECT
        vsd.document_line_id,
        vpo.line_currency_code transaction_currency,
        sd.functional_currency,
        fr.conversion_date fx_conversion_date,
        fr.period_end_rate,
        fr.corporate_rate,
        ROW_NUMBER() OVER (PARTITION BY vsd.document_line_id
                           ORDER BY fr.conversion_date DESC) rn
    FROM
        vrm_source_doc_lines vsd,
        vrm_perf_obligation_lines vpo,
        src_docs sd,
        period_der pd,
        fx_rate fr,
        pdt
    WHERE
        1 = 1
        AND vsd.document_type_code = 'FUSION_OSS'
        AND vpo.document_line_id = vsd.document_line_id
        AND vpo.removed_flag = 'N'
        AND sd.document_id = vsd.document_id
        AND vpo.line_currency_code <> sd.functional_currency
        AND pd.document_line_id (+) = vsd.document_line_id
        AND fr.from_currency = vpo.line_currency_code
        AND fr.to_currency   = sd.functional_currency
        AND fr.conversion_date <= NVL(pd.bill_date, LAST_DAY(pdt.p_date))
        AND NVL(fr.period_end_rate, fr.corporate_rate) IS NOT NULL
    )
WHERE
    rn = 1
),
pob_class AS
(
SELECT
    inventory_item_id,
    MAX(attribute_char1) pob_classification
FROM
    ego_item_eff_b
WHERE
    1 = 1
    AND context_code = 'Finance'
GROUP BY
    inventory_item_id
),
plm_glo AS
(
-- PLM attribute pulled from EGP_SYSTEM_ITEMS_B.ATTRIBUTE5 in the GLO master org
SELECT
    s.inventory_item_id,
    MAX(s.attribute5) plm
FROM
    egp_system_items_b s,
    inv_organization_definitions_v od
WHERE
    1 = 1
    AND od.organization_code = 'GLO'
    AND s.organization_id = od.organization_id
    AND s.approval_status = 'A'
    AND s.template_item_flag = 'N'
    AND NVL(s.item_object_type, 'ITEM') IN ('ITEM', 'DOCUMENT')
GROUP BY
    s.inventory_item_id
),
prod_category AS
(
-- Product Family from the Product_Reporting catalog (DigiKey's active item-
-- classification catalog, ~62K items each assigned to one category).
--
-- The "Product Family" value is sourced from EGP_CATEGORIES_TL.DESCRIPTION
-- because EGP_CATEGORIES_B.CATEGORY_CODE only holds the numeric internal code
-- (e.g. '121') while the readable business name (e.g. 'Eclipse+') lives in
-- the TL description column.
--
-- Revenue Stream currently mirrors Product Family as a placeholder until the
-- business rule for distinguishing them is confirmed. Both columns will show
-- the same value (e.g. 'Eclipse+'). When Jay provides the actual split rule,
-- update the second MAX(...) expression below.
--
-- UPDATE (2026-05-14): Revenue Stream is now sourced from the GL Chart of
-- Accounts SEGMENT8 ('Revenue Stream' in Imagine's COA) via the acc_info CTE.
-- The column below remains NULL here so it doesn't conflict; base_data now
-- reads revenue_stream from acc_info instead of prod_category.
--
-- Tenant note: 'Product_Reporting' is DigiKey-specific. Other tenants may use
-- 'PRODUCT_FAMILY', 'PRODUCT_CATALOG', or other catalog_code values. Adjust
-- the filter below per tenant.
SELECT
    eic.inventory_item_id,
    MAX(ect.description)        product_family,
    CAST(NULL AS VARCHAR2(240)) revenue_stream
FROM
    egp_item_categories eic,
    egp_categories_b    ecb,
    egp_categories_tl   ect,
    egp_category_sets_b ecs
WHERE
    1 = 1
    AND ecs.catalog_code     = 'Product_Reporting'
    AND eic.category_set_id  = ecs.category_set_id
    AND ecb.category_id      = eic.category_id
    AND ect.category_id      = ecb.category_id
    AND ect.language         = USERENV('LANG')
GROUP BY
    eic.inventory_item_id
),
header_tcv AS
(
-- Sum line amounts per document at the source-doc grain. Pulled out separately
-- so the value isn't multiplied by perf-obligation or satisfaction fan-out
-- happening downstream in base_data.
--
-- IMPORTANT: this CTE deduplicates VSD to the LATEST version per (document,
-- line_num) BEFORE summing. The companion vsd_for_pols CTE intentionally
-- keeps all VSD versions (so POLs on older versions are not dropped), but
-- header_tcv is a per-document sum and would double-count modified lines if
-- it used all versions. Using latest-only here gives the current-state TCV.
SELECT
    document_id,
    SUM(line_amount) header_tcv_t
FROM
    (
    SELECT
        vsd.document_id,
        vsd.line_amount,
        ROW_NUMBER() OVER (PARTITION BY vsd.document_id, vsd.line_num
                           ORDER BY vsd.version_number DESC) rn
    FROM
        vrm_source_doc_lines vsd,
        src_docs              sd
    WHERE
        1 = 1
        AND sd.document_id = vsd.document_id
        AND vsd.document_type_code = 'FUSION_OSS'
    )
WHERE
    rn = 1
GROUP BY
    document_id
),
acc_info AS
(
-- Per-POL accounting context: code combination (for company/department),
-- functional currency, and the GL period the revenue actually belongs to.
--
-- IMPORTANT: period_name is derived from vpold.ORIGINAL_ACCOUNTING_DATE, not
-- xah.accounting_date. These often differ because the engine performs catch-up
-- bookings (e.g. revenue belonging to APR-20 may be physically booked in
-- APR-26 due to migration or backdated activations). 86% of POLD revenue rows
-- in this tenant are catch-ups; using accounting_date would misattribute
-- $millions of revenue to a single recent period.
--
-- The xah.accounting_date filter below limits the XLA scan to recent
-- BOOKINGS (performance) but the period_name itself is computed from the
-- original accounting date.
SELECT
    perf_obligation_line_id,
    code_combination_id,
    original_accounting_date accounting_date,
    period_name,
    company,
    department,
    revenue_stream,
    functional_currency
FROM
    (
    SELECT
        vpold.perf_obligation_line_id,
        xal.code_combination_id,
        vpold.original_accounting_date,
        glp.period_name,
        gcc.segment1 company,
        gcc.segment3 department,
        gcc.segment8 revenue_stream,
        gll.currency_code functional_currency,
        ROW_NUMBER() OVER (PARTITION BY vpold.perf_obligation_line_id ORDER BY xdl.ROWID) rn
    FROM
        vrm_perf_obligation_lin_dists vpold,
        xla_distribution_links xdl,
        xla_ae_lines xal,
        xla_ae_headers xah,
        gl_period_statuses glp,
        gl_code_combinations gcc,
        gl_ledgers gll,
        pdt
    WHERE
        1 = 1
        AND xdl.source_distribution_id_num_1 = vpold.perf_obligation_line_dist_id
        AND xdl.application_id = vpold.application_id
        AND xdl.source_distribution_type = vpold.account_class
        AND xdl.event_type_code IN ('REV_PERF_OBL_SATISFIED', 'REV_PERF_OBL_BILLED', 'REV_INITIAL_PERF')
        AND xal.ae_header_id = xdl.ae_header_id
        AND xal.ae_line_num = xdl.ae_line_num
        AND xah.ae_header_id = xal.ae_header_id
        AND xah.accounting_entry_status_code IN ('F', 'D')
        AND xah.accounting_date >= ADD_MONTHS(NVL(pdt.p_date, TRUNC(SYSDATE, 'MONTH')), -24)
        AND xah.accounting_date <= ADD_MONTHS(NVL(pdt.p_date, TRUNC(SYSDATE, 'MONTH')), 12)
        AND glp.ledger_id = xah.ledger_id
        AND vpold.original_accounting_date BETWEEN glp.start_date AND glp.end_date
        AND glp.adjustment_period_flag = 'N'
        AND glp.application_id = 10455
        AND gcc.code_combination_id = xal.code_combination_id
        AND gcc.segment3 LIKE '4%'
        AND gll.ledger_id = xah.ledger_id
    )
WHERE
    rn = 1
),
base_data AS
(
SELECT
    vss.document_number,
    vss.document_id,
    vpo.perf_obligation_line_id,
    vpo.document_line_id,
    vcc.customer_contract_number,
    vpo.line_currency_code transaction_currency,
    vsd.line_num,
    vsd.item_number,
    vsd.item_id,
    vsd.line_amount,
    vsd.quantity,
    vpo.entered_cur_billed_amt billed_amt,
    vpo.entered_cur_recog_rev_amt recog_amt,
    vpo.net_line_amt,
    vpo.revenue_start_date,
    NVL(vpo.revenue_end_date, vsd.src_attribute_date7) revenue_end_date,
    vpo.satisfaction_measurement_model,
    pd.bill_date,
    pd.bill_quantity,
    pd.total_billed,
    se.satisfaction_measurement_date,
    se.sbl,
    se.sbh,
    subscr.customer_name,
    subscr.contract_number,
    subscr.start_date schedule_ship_date,
    subscr.start_date contract_start_date,
    subscr.end_date contract_end_date,
    subscr.product_number,
    subscr.header_status,
    subscr.line_status,
    subscr.end_user,
    vss.ledger_name,
    NVL(vsd.bill_to_customer_party_name, vss.bill_to_customer_name) bill_to_customer_name,
    vss.business_unit,
    pc.pob_classification,
    pg.plm,
    pcat.product_family,
    ai.revenue_stream,
    htcv.header_tcv_t,
    ai.company,
    ai.department,
    ai.period_name acc_period_name,
    vss.functional_currency,
    fr.fx_conversion_date,
    fr.period_end_rate,
    fr.corporate_rate
FROM
    src_docs vss,
    vsd_for_pols vsd,
    vrm_perf_obligation_lines vpo,
    vrm_customer_contract_headers vcc,
    period_der pd,
    base_data_se se,
    subscr,
    pol_fx fr,
    pob_class pc,
    plm_glo pg,
    prod_category pcat,
    header_tcv htcv,
    acc_info ai
WHERE
    1 = 1
    AND vsd.document_id = vss.document_id
    AND vpo.document_line_id = vsd.document_line_id
    AND vcc.customer_contract_header_id = vpo.customer_contract_header_id
    AND pd.document_line_id (+) = vsd.document_line_id
    AND se.perf_obligation_line_id (+) = vpo.perf_obligation_line_id
    AND se.rn (+) = 1
    AND subscr.contract_number (+) = vss.document_number
    AND subscr.subscription_product_id (+) = TO_NUMBER(vsd.doc_line_id_char_2)
    AND fr.document_line_id (+) = vsd.document_line_id
    AND pc.inventory_item_id (+) = vsd.item_id
    AND pg.inventory_item_id (+) = vsd.item_id
    AND pcat.inventory_item_id (+) = vsd.item_id
    AND htcv.document_id (+) = vss.document_id
    AND ai.perf_obligation_line_id (+) = vpo.perf_obligation_line_id
    AND vpo.removed_flag = 'N'
),
final_data AS
(
SELECT
    b.document_number,
    b.document_id,
    b.perf_obligation_line_id,
    b.document_line_id,
    b.customer_contract_number,
    b.transaction_currency,
    b.line_num,
    b.item_number,
    b.item_id,
    b.line_amount,
    b.quantity,
    b.billed_amt,
    b.recog_amt,
    b.net_line_amt,
    b.bill_date,
    b.bill_quantity,
    b.total_billed,
    b.satisfaction_measurement_date,
    b.sbl,
    b.sbh,
    b.customer_name,
    b.contract_number,
    b.revenue_start_date,
    b.revenue_end_date,
    b.schedule_ship_date,
    b.contract_start_date,
    b.contract_end_date,
    CASE
        WHEN b.revenue_start_date IS NULL OR b.revenue_end_date IS NULL
            THEN NULL
        WHEN MONTHS_BETWEEN(b.revenue_end_date + 1, b.revenue_start_date) <= 0
            THEN NULL
        ELSE b.net_line_amt
             / MONTHS_BETWEEN(b.revenue_end_date + 1, b.revenue_start_date)
    END monthly_amount,
    b.product_number,
    b.header_status,
    b.line_status,
    b.end_user,
    b.ledger_name,
    b.bill_to_customer_name,
    b.business_unit,
    b.pob_classification,
    b.plm,
    b.product_family,
    b.revenue_stream,
    b.header_tcv_t,
    b.functional_currency,
    b.fx_conversion_date,
    b.period_end_rate,
    b.corporate_rate,
    b.company,
    b.department,
    b.acc_period_name,
    b.satisfaction_measurement_model,
    pdt.p_date,
    TRUNC(MONTHS_BETWEEN(TRUNC(NVL(b.satisfaction_measurement_date, pdt.p_date), 'MONTH'),
                         pdt.p_date)) month_offset,
    CASE
        WHEN b.satisfaction_measurement_model = 'ORA_MEASURE_QUANTITY_SATISFIED'
            THEN b.recog_amt
        WHEN b.satisfaction_measurement_model = 'ORA_MEASURE_PERIOD_SATISFIED'
            THEN ROUND((b.sbl / NULLIF(b.sbh, 0)) * b.recog_amt, 2)
    END revenue_amt,
    CASE
        WHEN b.satisfaction_measurement_model = 'ORA_MEASURE_QUANTITY_SATISFIED'
            THEN b.line_amount
        WHEN b.satisfaction_measurement_model = 'ORA_MEASURE_PERIOD_SATISFIED'
            THEN ROUND((b.sbl / NULLIF(b.sbh, 0)) * b.line_amount, 2)
    END line_amt
FROM
    base_data b,
    pdt
),
buckets_n AS
(
-- Numeric bucket values computed once. Final SELECT formats them for display
-- AND sums the 17 strictly-future buckets (m_1_ahead through m_17) for
-- unrecognized_revenue_t per Jay Surface's design. Prior Amount and
-- current_month are EXCLUDED.
SELECT
    f.*,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        WHEN f.revenue_start_date >= ADD_MONTHS(f.p_date, -5)
            THEN 0
        ELSE ROUND(f.monthly_amount * GREATEST(0, MONTHS_BETWEEN(
            LEAST(f.revenue_end_date + 1, ADD_MONTHS(f.p_date, -5)),
            f.revenue_start_date
        )), 2)
    END prior_amount_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, -5)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, -5))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, -5)) - ADD_MONTHS(f.p_date, -5) + 1, 0),
            2
        )
    END m_5_ago_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, -4)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, -4))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, -4)) - ADD_MONTHS(f.p_date, -4) + 1, 0),
            2
        )
    END m_4_ago_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, -3)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, -3))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, -3)) - ADD_MONTHS(f.p_date, -3) + 1, 0),
            2
        )
    END m_3_ago_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, -2)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, -2))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, -2)) - ADD_MONTHS(f.p_date, -2) + 1, 0),
            2
        )
    END m_2_ago_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, -1)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, -1))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, -1)) - ADD_MONTHS(f.p_date, -1) + 1, 0),
            2
        )
    END m_1_ago_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, 0)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, 0))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, 0)) - ADD_MONTHS(f.p_date, 0) + 1, 0),
            2
        )
    END current_month_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, 1)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, 1))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, 1)) - ADD_MONTHS(f.p_date, 1) + 1, 0),
            2
        )
    END m_1_ahead_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, 2)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, 2))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, 2)) - ADD_MONTHS(f.p_date, 2) + 1, 0),
            2
        )
    END m_2_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, 3)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, 3))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, 3)) - ADD_MONTHS(f.p_date, 3) + 1, 0),
            2
        )
    END m_3_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, 4)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, 4))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, 4)) - ADD_MONTHS(f.p_date, 4) + 1, 0),
            2
        )
    END m_4_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, 5)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, 5))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, 5)) - ADD_MONTHS(f.p_date, 5) + 1, 0),
            2
        )
    END m_5_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, 6)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, 6))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, 6)) - ADD_MONTHS(f.p_date, 6) + 1, 0),
            2
        )
    END m_6_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, 7)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, 7))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, 7)) - ADD_MONTHS(f.p_date, 7) + 1, 0),
            2
        )
    END m_7_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, 8)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, 8))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, 8)) - ADD_MONTHS(f.p_date, 8) + 1, 0),
            2
        )
    END m_8_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, 9)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, 9))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, 9)) - ADD_MONTHS(f.p_date, 9) + 1, 0),
            2
        )
    END m_9_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, 10)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, 10))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, 10)) - ADD_MONTHS(f.p_date, 10) + 1, 0),
            2
        )
    END m_10_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, 11)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, 11))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, 11)) - ADD_MONTHS(f.p_date, 11) + 1, 0),
            2
        )
    END m_11_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, 12)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, 12))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, 12)) - ADD_MONTHS(f.p_date, 12) + 1, 0),
            2
        )
    END m_12_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, 13)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, 13))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, 13)) - ADD_MONTHS(f.p_date, 13) + 1, 0),
            2
        )
    END m_13_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, 14)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, 14))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, 14)) - ADD_MONTHS(f.p_date, 14) + 1, 0),
            2
        )
    END m_14_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, 15)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, 15))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, 15)) - ADD_MONTHS(f.p_date, 15) + 1, 0),
            2
        )
    END m_15_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, 16)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, 16))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, 16)) - ADD_MONTHS(f.p_date, 16) + 1, 0),
            2
        )
    END m_16_n,
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL
            THEN NULL
        WHEN f.monthly_amount IS NULL
            THEN 0
        ELSE ROUND(
            f.monthly_amount *
            GREATEST(0,
                LEAST(f.revenue_end_date, LAST_DAY(ADD_MONTHS(f.p_date, 17)))
                - GREATEST(f.revenue_start_date, ADD_MONTHS(f.p_date, 17))
                + 1
            ) /
            NULLIF(LAST_DAY(ADD_MONTHS(f.p_date, 17)) - ADD_MONTHS(f.p_date, 17) + 1, 0),
            2
        )
    END m_17_n,
    -- Long-tail summary buckets (calendar-quarter and calendar-year aggregates).
    -- These extend the projection beyond the m_17 horizon (Sep-27) for clients
    -- that want visibility into multi-year contracts. Math uses MONTHS_BETWEEN
    -- on the overlap of (revenue window) and (bucket window), same approach as
    -- prior_amount_n. NOTE: these are ABSOLUTE calendar dates, not relative to
    -- :p_period. If the report is run with :p_period inside one of these
    -- ranges, the bucket will include the current and any prior months in
    -- that range.
    -- Q4 2027 (Oct 1 2027 - Dec 31 2027)
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL THEN NULL
        WHEN f.monthly_amount IS NULL THEN 0
        ELSE ROUND(f.monthly_amount * GREATEST(0, MONTHS_BETWEEN(
            LEAST(f.revenue_end_date + 1, DATE '2028-01-01'),
            GREATEST(f.revenue_start_date,  DATE '2027-10-01')
        )), 2)
    END q4_2027_n,
    -- Q1 2028 (Jan 1 2028 - Mar 31 2028)
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL THEN NULL
        WHEN f.monthly_amount IS NULL THEN 0
        ELSE ROUND(f.monthly_amount * GREATEST(0, MONTHS_BETWEEN(
            LEAST(f.revenue_end_date + 1, DATE '2028-04-01'),
            GREATEST(f.revenue_start_date,  DATE '2028-01-01')
        )), 2)
    END q1_2028_n,
    -- Q2 2028 (Apr 1 2028 - Jun 30 2028)
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL THEN NULL
        WHEN f.monthly_amount IS NULL THEN 0
        ELSE ROUND(f.monthly_amount * GREATEST(0, MONTHS_BETWEEN(
            LEAST(f.revenue_end_date + 1, DATE '2028-07-01'),
            GREATEST(f.revenue_start_date,  DATE '2028-04-01')
        )), 2)
    END q2_2028_n,
    -- Q3 2028 (Jul 1 2028 - Sep 30 2028)
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL THEN NULL
        WHEN f.monthly_amount IS NULL THEN 0
        ELSE ROUND(f.monthly_amount * GREATEST(0, MONTHS_BETWEEN(
            LEAST(f.revenue_end_date + 1, DATE '2028-10-01'),
            GREATEST(f.revenue_start_date,  DATE '2028-07-01')
        )), 2)
    END q3_2028_n,
    -- Q4 2028 (Oct 1 2028 - Dec 31 2028)
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL THEN NULL
        WHEN f.monthly_amount IS NULL THEN 0
        ELSE ROUND(f.monthly_amount * GREATEST(0, MONTHS_BETWEEN(
            LEAST(f.revenue_end_date + 1, DATE '2029-01-01'),
            GREATEST(f.revenue_start_date,  DATE '2028-10-01')
        )), 2)
    END q4_2028_n,
    -- Calendar Year 2029
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL THEN NULL
        WHEN f.monthly_amount IS NULL THEN 0
        ELSE ROUND(f.monthly_amount * GREATEST(0, MONTHS_BETWEEN(
            LEAST(f.revenue_end_date + 1, DATE '2030-01-01'),
            GREATEST(f.revenue_start_date,  DATE '2029-01-01')
        )), 2)
    END y2029_n,
    -- Calendar Year 2030
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL THEN NULL
        WHEN f.monthly_amount IS NULL THEN 0
        ELSE ROUND(f.monthly_amount * GREATEST(0, MONTHS_BETWEEN(
            LEAST(f.revenue_end_date + 1, DATE '2031-01-01'),
            GREATEST(f.revenue_start_date,  DATE '2030-01-01')
        )), 2)
    END y2030_n,
    -- Calendar Year 2031
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL THEN NULL
        WHEN f.monthly_amount IS NULL THEN 0
        ELSE ROUND(f.monthly_amount * GREATEST(0, MONTHS_BETWEEN(
            LEAST(f.revenue_end_date + 1, DATE '2032-01-01'),
            GREATEST(f.revenue_start_date,  DATE '2031-01-01')
        )), 2)
    END y2031_n,
    -- Calendar Year 2032
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL THEN NULL
        WHEN f.monthly_amount IS NULL THEN 0
        ELSE ROUND(f.monthly_amount * GREATEST(0, MONTHS_BETWEEN(
            LEAST(f.revenue_end_date + 1, DATE '2033-01-01'),
            GREATEST(f.revenue_start_date,  DATE '2032-01-01')
        )), 2)
    END y2032_n,
    -- Calendar Year 2033
    CASE
        WHEN f.revenue_start_date IS NULL OR f.revenue_end_date IS NULL THEN NULL
        WHEN f.monthly_amount IS NULL THEN 0
        ELSE ROUND(f.monthly_amount * GREATEST(0, MONTHS_BETWEEN(
            LEAST(f.revenue_end_date + 1, DATE '2034-01-01'),
            GREATEST(f.revenue_start_date,  DATE '2033-01-01')
        )), 2)
    END y2033_n
FROM
    final_data f
)
SELECT
    -- ---- Layout columns aligned to SubscriptionWaterfall.rtf ----
    company,
    department,
    TO_CHAR(revenue_start_date, 'MM/DD/YYYY') revenue_start_date,
    TO_CHAR(revenue_end_date, 'MM/DD/YYYY') revenue_end_date,
    TO_CHAR(schedule_ship_date, 'MM/DD/YYYY') schedule_ship_date,
    TO_CHAR(contract_start_date, 'MM/DD/YYYY') contract_start_date,
    TO_CHAR(contract_end_date, 'MM/DD/YYYY') contract_end_date,
    customer_contract_number contract,
    TO_CHAR(p_date, 'MON-YY') period_name,
    customer_name customer,
    bill_to_customer_name bill_to_customer,
    end_user end_user_name,
    business_unit,
    ledger_name,
    -- SALES_ORDER_CONTRACT_ATR50: placeholder. Source likely DOO_HEADERS_ALL.attribute50
    -- joined via subscr.sales_order_header_id. Add the join if needed.
    CAST(NULL AS VARCHAR2(150)) sales_order_contract_atr50,
    document_number source_document_number,
    line_num so_line,
    -- CONTRACT_MODIFIER parsed from document_number suffix after '-C'
    CASE
        WHEN INSTR(document_number, '-C') > 0
            THEN SUBSTR(document_number, INSTR(document_number, '-C') + 1)
    END contract_modifier,
    item_number item,
    pob_classification extended_attribute,
    transaction_currency currency,
    -- EXT_LIST_PRICE: placeholder. No list-price source identified yet.
    CAST(NULL AS NUMBER) ext_list_price,
    line_amt ext_sell_price,
    NVL(total_billed, billed_amt) total_billed,
    recog_amt recognized_revenue,
    -- IS-002 audit equation: Recog (T) + Unrecog (T) = Net Line TCV (T) by
    -- construction. Previously this column summed the 17 forward bucket
    -- projections, which fell short for long-tail contracts.
    NVL(net_line_amt, 0) - NVL(recog_amt, 0) unrecognized_revenue,
    -- ---- Additional business columns ----
    header_status,
    line_status,
    ROUND(NVL(revenue_amt, 0) / NULLIF(line_amt, 0) * 100, 2) satisfaction_pct,
    CASE satisfaction_measurement_model
        WHEN 'ORA_MEASURE_QUANTITY_SATISFIED' THEN 'Quantity'
        WHEN 'ORA_MEASURE_PERIOD_SATISFIED'   THEN 'Period'
        WHEN 'ORA_MEASURE_PERCENT_SATISFIED'  THEN 'Percent'
        ELSE satisfaction_measurement_model
    END revenue_method,
    plm,
    product_family,
    revenue_stream,
    functional_currency,
    TO_CHAR(LAST_DAY(p_date), 'MM/DD/YYYY') satisfaction_measurement_date,
    -- Conversion Date / Type / Rate (T->F).
    -- When transaction_currency = functional_currency, no conversion is
    -- needed: show today's date, 'N/A', and rate 1. Else show the resolved
    -- FX date/type/rate from pol_fx.
    CASE
        WHEN transaction_currency = functional_currency
            THEN TO_CHAR(SYSDATE, 'MM/DD/YYYY')
        ELSE TO_CHAR(fx_conversion_date, 'MM/DD/YYYY')
    END conversion_date,
    CASE
        WHEN transaction_currency = functional_currency THEN 'N/A'
        WHEN period_end_rate IS NOT NULL                THEN 'Period End'
        WHEN corporate_rate  IS NOT NULL                THEN 'Corporate'
    END conversion_type,
    CASE
        WHEN transaction_currency = functional_currency THEN 1
        ELSE NVL(period_end_rate, corporate_rate)
    END conversion_rate_tf,
    net_line_amt - NVL(total_billed, billed_amt) unbilled_amount,
    recog_amt recognized_revenue_t,
    ROUND(
        recog_amt *
        CASE
            WHEN transaction_currency = functional_currency THEN 1
            ELSE NVL(period_end_rate, corporate_rate)
        END,
        2
    ) recognized_revenue_f,
    -- IS-002 audit equation: Recog (T) + Unrecog (T) = Net Line TCV (T).
    NVL(net_line_amt, 0) - NVL(recog_amt, 0) unrecognized_revenue_t,
    header_tcv_t,
    net_line_amt net_line_tcv_t,
    ROUND(
        net_line_amt *
        CASE
            WHEN transaction_currency = functional_currency THEN 1
            ELSE NVL(period_end_rate, corporate_rate)
        END,
        2
    ) net_line_tcv_f,
    -- ---- Prorated waterfall buckets ----
    -- Numeric bucket values computed once in the buckets_n CTE; this section
    -- only formats them for display (with NULL-date marker handling).
    -- See header for math description.
    -- Monthly projected revenue = TRUE remaining unrecognized revenue spread
    -- evenly across the remaining recognition life. Per Jay Surface:
    --   numerator   = net_line_amt - recog_amt  (the total amount still to
    --                 recognize across the full life of the contract,
    --                 regardless of where it falls relative to the 17-month
    --                 visible waterfall window)
    --   denominator = whole months from selected period (p_date) to
    --                 revenue_end_date. GREATEST(_, 1) prevents divide by
    --                 zero / negatives if revenue_end_date <= p_date.
    -- NULL when revenue_end_date is missing.
    CASE
        WHEN revenue_end_date IS NULL
            THEN NULL
        ELSE ROUND(
            (NVL(net_line_amt, 0) - NVL(recog_amt, 0)) /
            GREATEST(FLOOR(MONTHS_BETWEEN(revenue_end_date, p_date)), 1),
            2
        )
    END monthly_projected_revenue,
    -- Prior Amount: portion of contract value falling before ADD_MONTHS(p_date, -5)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(prior_amount_n, 0), 'FM999999999999990.00')
    END prior_amount,
    -- NOV-25 (relative: p_date -5)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(m_5_ago_n, 0), 'FM999999999999990.00')
    END m_5_ago,
    -- DEC-25 (relative: p_date -4)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(m_4_ago_n, 0), 'FM999999999999990.00')
    END m_4_ago,
    -- JAN-26 (relative: p_date -3)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(m_3_ago_n, 0), 'FM999999999999990.00')
    END m_3_ago,
    -- FEB-26 (relative: p_date -2)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(m_2_ago_n, 0), 'FM999999999999990.00')
    END m_2_ago,
    -- MAR-26 (relative: p_date -1)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(m_1_ago_n, 0), 'FM999999999999990.00')
    END m_1_ago,
    -- APR-26 (relative: selected period)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(current_month_n, 0), 'FM999999999999990.00')
    END current_month,
    -- MAY-26 (relative: p_date +1)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(m_1_ahead_n, 0), 'FM999999999999990.00')
    END m_1_ahead,
    -- JUN-26 (relative: p_date +2)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(m_2_n, 0), 'FM999999999999990.00')
    END m_2,
    -- JUL-26 (relative: p_date +3)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(m_3_n, 0), 'FM999999999999990.00')
    END m_3,
    -- AUG-26 (relative: p_date +4)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(m_4_n, 0), 'FM999999999999990.00')
    END m_4,
    -- SEP-26 (relative: p_date +5)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(m_5_n, 0), 'FM999999999999990.00')
    END m_5,
    -- OCT-26 (relative: p_date +6)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(m_6_n, 0), 'FM999999999999990.00')
    END m_6,
    -- NOV-26 (relative: p_date +7)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(m_7_n, 0), 'FM999999999999990.00')
    END m_7,
    -- DEC-26 (relative: p_date +8)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(m_8_n, 0), 'FM999999999999990.00')
    END m_8,
    -- JAN-27 (relative: p_date +9)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(m_9_n, 0), 'FM999999999999990.00')
    END m_9,
    -- FEB-27 (relative: p_date +10)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(m_10_n, 0), 'FM999999999999990.00')
    END m_10,
    -- MAR-27 (relative: p_date +11)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(m_11_n, 0), 'FM999999999999990.00')
    END m_11,
    -- APR-27 (relative: p_date +12)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(m_12_n, 0), 'FM999999999999990.00')
    END m_12,
    -- MAY-27 (relative: p_date +13)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(m_13_n, 0), 'FM999999999999990.00')
    END m_13,
    -- JUN-27 (relative: p_date +14)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(m_14_n, 0), 'FM999999999999990.00')
    END m_14,
    -- JUL-27 (relative: p_date +15)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(m_15_n, 0), 'FM999999999999990.00')
    END m_15,
    -- AUG-27 (relative: p_date +16)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(m_16_n, 0), 'FM999999999999990.00')
    END m_16,
    -- SEP-27 (relative: p_date +17)
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(m_17_n, 0), 'FM999999999999990.00')
    END m_17,
    -- ---- Long-tail summary buckets (calendar quarters / years) ----
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(q4_2027_n, 0), 'FM999999999999990.00')
    END qtr4_2027,
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(q1_2028_n, 0), 'FM999999999999990.00')
    END qtr1_2028,
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(q2_2028_n, 0), 'FM999999999999990.00')
    END qtr2_2028,
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(q3_2028_n, 0), 'FM999999999999990.00')
    END qtr3_2028,
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(q4_2028_n, 0), 'FM999999999999990.00')
    END qtr4_2028,
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(y2029_n, 0), 'FM999999999999990.00')
    END year_2029,
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(y2030_n, 0), 'FM999999999999990.00')
    END year_2030,
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(y2031_n, 0), 'FM999999999999990.00')
    END year_2031,
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(y2032_n, 0), 'FM999999999999990.00')
    END year_2032,
    CASE
        WHEN revenue_start_date IS NULL OR revenue_end_date IS NULL
            THEN 'start_date or end date_is null'
        ELSE TO_CHAR(NVL(y2033_n, 0), 'FM999999999999990.00')
    END year_2033,
    -- ROW_TOTAL = Net Line TCV (T). Sourced directly from the engine's
    -- net_line_amt so the audit equation Row Total = TCV holds by
    -- construction, regardless of bucket coverage or contract length.
    -- This pairs with IS-002 (Recog + Unrecog = TCV) and IS-003 (Billed +
    -- Unbilled = TCV) to give a fully reconcilable report.
    net_line_amt row_total
FROM
    buckets_n
;
