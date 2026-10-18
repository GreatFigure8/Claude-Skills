-- =============================================================================
-- fusion_post_load_checks.sql
-- Read-only post-load checks for a GP (Picturehouse) Customer Import batch.
-- Target: Oracle Fusion FUSION schema, Regal DEV2 (ichqjb-dev2) first.
-- Run each statement separately through the Fusion SQL MCP / BIP SQL runner.
--
-- Why this exists: a batch can report records imported that were never created
-- (6 profiles "imported", 0 in HZ_CUSTOMER_PROFILES_F). Job status and batch
-- summary are not proof; these registry checks are.
--
-- Before running:
--   1. Confirm the connection is the Regal DEV2 pod (ichqjb-dev2), not
--      iartqy-dev1 or any other tenant.
--   2. Wait at least 30 s after the import job reports done; profiles land late.
--   3. Edit the params CTE in each statement: p_batch_id, p_batch_name,
--      p_orig_system (always 'GP' for this stream).
--
-- Column provenance:
--   Every column is verified on DEV2 (ALL_TAB_COLUMNS, owner FUSION,
--   2026-10-16) except in check 2c. "VERIFY COLUMN NAMES FIRST" marks that one
--   statement: its table is used by the playbook but its column list was NOT
--   captured. Run
--     SELECT column_name FROM all_tab_columns
--     WHERE owner = 'FUSION' AND table_name = '<TABLE>' ORDER BY column_id;
--   and correct the statement before trusting it.
--
-- Interface rows (HZ_IMP_*_T) disappear when a batch is purged. Checks 3 to 9
-- use HZ_ORIG_SYS_REFERENCES as well, so they keep working after a purge when
-- p_batch_id is ignored (see the note on check 3).
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 0. Find a free batch id for today (run BEFORE building a zip).
--    Batch id 2026091701 was once reused and the import ended in error.
--    Any id this query returns is taken; pick the next free YYYYMMDDnn.
--    Columns verified on DEV2.
-- -----------------------------------------------------------------------------
SELECT b.batch_id,
       b.batch_name,
       b.original_system,
       b.batch_status,
       b.creation_date
FROM   hz_imp_batch_summary b
WHERE  b.batch_id BETWEEN TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD') || '00')
                      AND TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD') || '99')
ORDER  BY b.batch_id;


-- -----------------------------------------------------------------------------
-- 1. Batch summary for one batch, and all GP batches.
--    Expect BATCH_STATUS COMPLETED with WHAT_IF_FLAG N for a commit, and
--    COMPL_WHATIF for a preview. COMPL_WHATIF after a run meant as a commit
--    = argument 14 was Y or blank. ERROR_MESSAGE holds batch-level messages
--    such as "The OS/OSR combination ... already exists."
--    Columns verified on DEV2.
-- -----------------------------------------------------------------------------
WITH params AS (
  SELECT 'GP_PH_EXPAND20_COMMIT' AS p_batch_name,
         'GP'                    AS p_orig_system
  FROM   dual
)
SELECT b.batch_id,
       b.batch_name,
       b.original_system,
       b.load_type,
       b.what_if_flag,
       b.batch_status,
       b.csv_status,
       b.processed_step,
       b.in_process_step,
       b.to_process_step,
       b.purge_date,
       b.error_message,
       b.request_id,
       b.creation_date
FROM   hz_imp_batch_summary b
CROSS  JOIN params p
WHERE  b.original_system = p.p_orig_system
   OR  b.batch_name      = p.p_batch_name
ORDER  BY b.batch_id;


-- -----------------------------------------------------------------------------
-- 2. Import errors for the batch, grouped by interface and message.
--    Expect 0 rows. HZ_DUPLICATE_COMBINATION = re-insert of an existing OSR
--    (send U, or drop the record). AR_CUSTIMP_*_REQ = a required profile column
--    is missing. HZ_DE_INVALID_DATERANGE = site-use dates outside site dates.
--    Columns verified on DEV2.
-- -----------------------------------------------------------------------------
WITH params AS (
  SELECT 2026100841 AS p_batch_id FROM dual
)
SELECT e.interface_table_name,
       e.message_name,
       e.error_type_code,
       COUNT(*)              AS error_count,
       MIN(e.error_msg_text) AS sample_message
FROM   hz_imp_errors e
CROSS  JOIN params p
WHERE  e.batch_id = p.p_batch_id
GROUP  BY e.interface_table_name, e.message_name, e.error_type_code
ORDER  BY error_count DESC;


-- -----------------------------------------------------------------------------
-- 2b. Error detail for the batch: the tokens name the column and value that
--     failed (e.g. TOKEN1_NAME = SET_CODE). Use it to fix the source row.
--     Columns verified on DEV2.
-- -----------------------------------------------------------------------------
WITH params AS (
  SELECT 2026100841 AS p_batch_id FROM dual
)
SELECT e.error_id,
       e.interface_table_name,
       e.message_name,
       e.error_msg_text,
       e.token1_name, e.token1_value,
       e.token2_name, e.token2_value,
       e.token3_name, e.token3_value,
       e.token4_name, e.token4_value,
       e.token5_name, e.token5_value,
       e.request_id
FROM   hz_imp_errors e
CROSS  JOIN params p
WHERE  e.batch_id = p.p_batch_id
ORDER  BY e.interface_table_name, e.message_name, e.error_seq_id;


-- -----------------------------------------------------------------------------
-- 2c. Entity counts for the batch (CUSTOMER_PROFILE appears only on commit,
--     never in preview). HZ_IMP_ENTITY_DETAILS is used by the playbook
--     (NUM_INSERTED), but its other column names have not been verified on
--     DEV2. VERIFY COLUMN NAMES FIRST:
--       SELECT column_name FROM all_tab_columns
--       WHERE owner = 'FUSION' AND table_name = 'HZ_IMP_ENTITY_DETAILS';
-- -----------------------------------------------------------------------------
WITH params AS (
  SELECT 2026100841 AS p_batch_id FROM dual
)
SELECT d.entity_name,
       d.num_inserted
FROM   hz_imp_entity_details d
CROSS  JOIN params p
WHERE  d.batch_id = p.p_batch_id
ORDER  BY d.entity_name;


-- -----------------------------------------------------------------------------
-- 3. Accounts created by the batch, with site, BILL_TO site use and
--    account-level profile presence (one row per account).
--    Every flag should be 'Y'. A missing profile is the commonest silent defect.
--    Note: to check ALL GP accounts (e.g. after a purge), delete the
--    "AND a_t.batch_id = p.p_batch_id" line and drive from the OSR table only.
--    Columns verified on DEV2.
-- -----------------------------------------------------------------------------
WITH params AS (
  SELECT 2026100841 AS p_batch_id,
         'GP'       AS p_orig_system
  FROM   dual
),
batch_accounts AS (
  SELECT DISTINCT a_t.cust_orig_system_reference AS osr
  FROM   hz_imp_accounts_t a_t
  CROSS  JOIN params p
  WHERE  a_t.cust_orig_system = p.p_orig_system
  AND    a_t.batch_id         = p.p_batch_id
),
accts AS (
  SELECT ca.cust_account_id,
         ca.account_number,
         ca.account_name,
         ca.customer_class_code,
         ca.status,
         osr.orig_system_reference
  FROM   batch_accounts ba
  JOIN   hz_orig_sys_references osr
         ON  osr.orig_system_reference = ba.osr
         AND osr.owner_table_name      = 'HZ_CUST_ACCOUNTS'
  JOIN   params p
         ON  osr.orig_system = p.p_orig_system
  JOIN   hz_cust_accounts ca
         ON  ca.cust_account_id = osr.owner_table_id
)
SELECT a.account_number,
       a.orig_system_reference,
       a.status,
       NVL(a.customer_class_code, '(none)') AS class_code,
       CASE WHEN EXISTS (SELECT 1 FROM hz_cust_acct_sites_all s
                         WHERE s.cust_account_id = a.cust_account_id
                         AND   s.status = 'A')
            THEN 'Y' ELSE 'N' END AS has_active_site,
       CASE WHEN EXISTS (SELECT 1 FROM hz_cust_acct_sites_all s
                         JOIN   hz_cust_site_uses_all u
                                ON u.cust_acct_site_id = s.cust_acct_site_id
                         WHERE  s.cust_account_id = a.cust_account_id
                         AND    u.site_use_code   = 'BILL_TO'
                         AND    u.status          = 'A')
            THEN 'Y' ELSE 'N' END AS has_bill_to,
       CASE WHEN EXISTS (SELECT 1 FROM hz_customer_profiles_f cp
                         WHERE cp.cust_account_id = a.cust_account_id
                         AND   cp.site_use_id IS NULL
                         AND   TRUNC(SYSDATE) BETWEEN cp.effective_start_date
                                    AND NVL(cp.effective_end_date, TRUNC(SYSDATE)))
            THEN 'Y' ELSE 'N' END AS has_account_profile
FROM   accts a
ORDER  BY a.account_number;


-- -----------------------------------------------------------------------------
-- 4. GP accounts lacking exactly one primary active BILL_TO.
--    Expect 0 rows. 0 = no billing site (AutoInvoice will reject);
--    2+ = ambiguous default bill-to.
--    Columns verified on DEV2.
-- -----------------------------------------------------------------------------
WITH params AS (
  SELECT 'GP' AS p_orig_system FROM dual
)
SELECT ca.account_number,
       ca.account_name,
       COUNT(u.site_use_id) AS primary_active_bill_to
FROM   hz_orig_sys_references osr
JOIN   params p
       ON  osr.orig_system = p.p_orig_system
JOIN   hz_cust_accounts ca
       ON  ca.cust_account_id = osr.owner_table_id
LEFT   JOIN hz_cust_acct_sites_all s
       ON  s.cust_account_id = ca.cust_account_id
       AND s.status          = 'A'
LEFT   JOIN hz_cust_site_uses_all u
       ON  u.cust_acct_site_id = s.cust_acct_site_id
       AND u.site_use_code     = 'BILL_TO'
       AND u.primary_flag      = 'Y'
       AND u.status            = 'A'
WHERE  osr.owner_table_name = 'HZ_CUST_ACCOUNTS'
GROUP  BY ca.account_number, ca.account_name
HAVING COUNT(u.site_use_id) <> 1
ORDER  BY ca.account_number;


-- -----------------------------------------------------------------------------
-- 5. GP accounts with no current account-level profile.
--    Expect 0 rows. If rows appear, first confirm 30 s have passed, then
--    re-send the profile TOGETHER with its account row (account U, profile I);
--    a profile sent alone reports "imported" and writes nothing.
--    HZ_CUSTOMER_PROFILES_F is date-effective: "current" = today falls between
--    EFFECTIVE_START_DATE and EFFECTIVE_END_DATE.
--    Columns verified on DEV2.
-- -----------------------------------------------------------------------------
WITH params AS (
  SELECT 'GP' AS p_orig_system FROM dual
)
SELECT ca.account_number,
       ca.account_name
FROM   hz_orig_sys_references osr
JOIN   params p
       ON  osr.orig_system = p.p_orig_system
JOIN   hz_cust_accounts ca
       ON  ca.cust_account_id = osr.owner_table_id
WHERE  osr.owner_table_name = 'HZ_CUST_ACCOUNTS'
AND    NOT EXISTS (SELECT 1
                   FROM   hz_customer_profiles_f cp
                   WHERE  cp.cust_account_id = ca.cust_account_id
                   AND    cp.site_use_id IS NULL
                   AND    TRUNC(SYSDATE) BETWEEN cp.effective_start_date
                                             AND NVL(cp.effective_end_date, TRUNC(SYSDATE)))
ORDER  BY ca.account_number;


-- -----------------------------------------------------------------------------
-- 5b. Current account-level profile settings on GP accounts, grouped.
--     Compare against the agreed defaults (GP batches so far: DEFAULT /
--     AR Manager / Net 30 / Monthly, credit check N, hold N, statements Y)
--     and the five import-required defaults (CREDIT_BALANCE_STATEMENTS,
--     COLLECTOR, TOLERANCE, OVERRIDE_TERMS, AUTO_REC_INCL_DISPUTED_FLAG).
--     Credit limit lives in two places: CREDIT_LIMIT / CREDIT_CURRENCY_CODE on
--     the profile row itself, and per-currency OVERALL_CREDIT_LIMIT /
--     TRX_CREDIT_LIMIT on HZ_CUST_PROFILE_AMTS_F (none set in DEV2 today).
--     RA_TERMS_TL is filtered to LANGUAGE 'US'.
--     Columns verified on DEV2.
-- -----------------------------------------------------------------------------
WITH params AS (
  SELECT 'GP' AS p_orig_system FROM dual
),
cur_prof AS (
  SELECT cp.*
  FROM   hz_customer_profiles_f cp
  WHERE  cp.site_use_id IS NULL
  AND    TRUNC(SYSDATE) BETWEEN cp.effective_start_date
                            AND NVL(cp.effective_end_date, TRUNC(SYSDATE))
),
cur_amts AS (
  SELECT pa.cust_account_profile_id,
         COUNT(*)                                        AS amt_rows,
         MAX(pa.currency_code)                           AS amt_currency,
         MAX(pa.overall_credit_limit)                    AS overall_credit_limit,
         MAX(pa.trx_credit_limit)                        AS trx_credit_limit
  FROM   hz_cust_profile_amts_f pa
  WHERE  TRUNC(SYSDATE) BETWEEN pa.effective_start_date
                            AND NVL(pa.effective_end_date, TRUNC(SYSDATE))
  GROUP  BY pa.cust_account_profile_id
)
SELECT pc.name                         AS profile_class,
       co.name                         AS collector,
       t.name                          AS standard_terms,
       sc.name                         AS statement_cycle,
       cp.status,
       cp.credit_checking,
       cp.credit_hold,
       cp.send_statements,
       cp.credit_balance_statements,
       cp.tolerance,
       cp.override_terms,
       cp.auto_rec_incl_disputed_flag,
       cp.credit_limit,
       cp.credit_currency_code,
       NVL(am.amt_rows, 0)             AS profile_amt_rows,
       am.amt_currency,
       am.overall_credit_limit,
       am.trx_credit_limit,
       COUNT(*)                        AS accounts
FROM   hz_orig_sys_references osr
JOIN   params p
       ON  osr.orig_system = p.p_orig_system
JOIN   cur_prof cp
       ON  cp.cust_account_id = osr.owner_table_id
LEFT   JOIN cur_amts am                ON am.cust_account_profile_id = cp.cust_account_profile_id
LEFT   JOIN hz_cust_profile_classes pc ON pc.profile_class_id       = cp.profile_class_id
LEFT   JOIN ar_collectors           co ON co.collector_id           = cp.collector_id
LEFT   JOIN ra_terms_tl             t  ON t.term_id                 = cp.standard_terms
                                      AND t.language                = 'US'
LEFT   JOIN ar_statement_cycles     sc ON sc.statement_cycle_id     = cp.statement_cycle_id
WHERE  osr.owner_table_name = 'HZ_CUST_ACCOUNTS'
GROUP  BY pc.name, co.name, t.name, sc.name, cp.status,
          cp.credit_checking, cp.credit_hold, cp.send_statements,
          cp.credit_balance_statements, cp.tolerance, cp.override_terms,
          cp.auto_rec_incl_disputed_flag, cp.credit_limit, cp.credit_currency_code,
          NVL(am.amt_rows, 0), am.amt_currency, am.overall_credit_limit,
          am.trx_credit_limit
ORDER  BY accounts DESC;


-- -----------------------------------------------------------------------------
-- 6. GP orig-system references per entity.
--    Every customer should have one reference per layer it was loaded with
--    (party, location, party site, account, account site, site use; plus
--    contact entities if contacts converted). Uneven counts point at the layer
--    that failed. Also the list of OSRs to send as U, not I, on a re-run.
--    Columns verified on DEV2.
-- -----------------------------------------------------------------------------
WITH params AS (
  SELECT 'GP' AS p_orig_system FROM dual
)
SELECT osr.owner_table_name,
       osr.status,
       COUNT(*) AS ref_count
FROM   hz_orig_sys_references osr
JOIN   params p
       ON osr.orig_system = p.p_orig_system
GROUP  BY osr.owner_table_name, osr.status
ORDER  BY osr.owner_table_name, osr.status;


-- -----------------------------------------------------------------------------
-- 7. GP locations with null city or postal code (and the country/state shape).
--    GB: CITY must hold the town (geography level TOWNSHIP), STATE blank.
--    US: STATE is required (validation is Error at State level).
--    Columns verified on DEV2.
-- -----------------------------------------------------------------------------
WITH params AS (
  SELECT 'GP' AS p_orig_system FROM dual
)
SELECT osr.orig_system_reference AS location_osr,
       l.country,
       l.city,
       l.state,
       l.county,
       l.postal_code
FROM   hz_orig_sys_references osr
JOIN   params p
       ON  osr.orig_system = p.p_orig_system
JOIN   hz_locations l
       ON  l.location_id = osr.owner_table_id
WHERE  osr.owner_table_name = 'HZ_LOCATIONS'
AND   (l.city IS NULL
       OR l.postal_code IS NULL
       OR (l.country = 'US' AND l.state IS NULL))
ORDER  BY l.country, osr.orig_system_reference;


-- -----------------------------------------------------------------------------
-- 8. Untrimmed text on GP records. GP char columns are space-padded and
--    Fusion does not trim. Expect 0 rows.
--    Columns verified on DEV2.
-- -----------------------------------------------------------------------------
WITH params AS (
  SELECT 'GP' AS p_orig_system FROM dual
)
SELECT 'HZ_CUST_ACCOUNTS.ACCOUNT_NAME' AS field, ca.account_number AS record_key
FROM   hz_orig_sys_references osr
JOIN   params p ON osr.orig_system = p.p_orig_system
JOIN   hz_cust_accounts ca ON ca.cust_account_id = osr.owner_table_id
WHERE  osr.owner_table_name = 'HZ_CUST_ACCOUNTS'
AND    ca.account_name <> TRIM(ca.account_name)
UNION ALL
SELECT 'HZ_CUST_ACCOUNTS.ACCOUNT_NUMBER', ca.account_number
FROM   hz_orig_sys_references osr
JOIN   params p ON osr.orig_system = p.p_orig_system
JOIN   hz_cust_accounts ca ON ca.cust_account_id = osr.owner_table_id
WHERE  osr.owner_table_name = 'HZ_CUST_ACCOUNTS'
AND    ca.account_number <> TRIM(ca.account_number)
UNION ALL
SELECT 'HZ_PARTIES.PARTY_NAME', osr.orig_system_reference
FROM   hz_orig_sys_references osr
JOIN   params p ON osr.orig_system = p.p_orig_system
JOIN   hz_parties hp ON hp.party_id = osr.owner_table_id
WHERE  osr.owner_table_name = 'HZ_PARTIES'
AND    hp.party_name <> TRIM(hp.party_name)
UNION ALL
SELECT 'HZ_LOCATIONS.ADDRESS1/CITY/POSTAL_CODE', osr.orig_system_reference
FROM   hz_orig_sys_references osr
JOIN   params p ON osr.orig_system = p.p_orig_system
JOIN   hz_locations l ON l.location_id = osr.owner_table_id
WHERE  osr.owner_table_name = 'HZ_LOCATIONS'
AND   (l.address1    <> TRIM(l.address1)
       OR l.city        <> TRIM(l.city)
       OR l.postal_code <> TRIM(l.postal_code))
UNION ALL
SELECT 'HZ_ORIG_SYS_REFERENCES.ORIG_SYSTEM_REFERENCE', osr.orig_system_reference
FROM   hz_orig_sys_references osr
JOIN   params p ON osr.orig_system = p.p_orig_system
WHERE  osr.orig_system_reference <> TRIM(osr.orig_system_reference);


-- -----------------------------------------------------------------------------
-- 9. Reconciliation: GP accounts in Fusion by GP company prefix.
--    Account OSR pattern is <COMPANY>-<CUSTNMBR> (e.g. PHEN2-D00189).
--    Compare each count against the selected GP population for that company
--    (LOAD + HELD + REJECT = source; the difference must be 0).
--    Live GP master counts on 2026-09-01: PHTRA 8,484, PHEN2 1,167, PHBOO 18,
--    PHGAP 0 (before any selection rule). Re-query GP for the current figure.
--    Columns verified on DEV2.
-- -----------------------------------------------------------------------------
WITH params AS (
  SELECT 'GP' AS p_orig_system FROM dual
)
SELECT CASE WHEN INSTR(osr.orig_system_reference, '-') > 0
            THEN SUBSTR(osr.orig_system_reference, 1,
                        INSTR(osr.orig_system_reference, '-') - 1)
            ELSE '(no prefix)'
       END                                            AS gp_company,
       COUNT(*)                                       AS fusion_accounts,
       SUM(CASE WHEN ca.status = 'A' THEN 1 ELSE 0 END) AS active_accounts,
       SUM(CASE WHEN ca.customer_class_code IS NULL
                THEN 1 ELSE 0 END)                    AS accounts_without_class
FROM   hz_orig_sys_references osr
JOIN   params p
       ON  osr.orig_system = p.p_orig_system
JOIN   hz_cust_accounts ca
       ON  ca.cust_account_id = osr.owner_table_id
WHERE  osr.owner_table_name = 'HZ_CUST_ACCOUNTS'
GROUP  BY CASE WHEN INSTR(osr.orig_system_reference, '-') > 0
               THEN SUBSTR(osr.orig_system_reference, 1,
                           INSTR(osr.orig_system_reference, '-') - 1)
               ELSE '(no prefix)'
          END
ORDER  BY gp_company;
