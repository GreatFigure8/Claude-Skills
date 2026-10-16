/* ============================================================================
   gp_customer_profile.sql
   Customer profile query set for the Picturehouse Dynamics GP 2010 companies.

   WHERE TO RUN
     Run each numbered query on the MCP site of the company being profiled.
     The queries use unqualified table names, so the site decides the company,
     and DB_NAME() stamps the company code on the output.

       Company  MCP site              Customers (2026-10-16)
       PHTRA    PHTRA-Great-Plains    8,484
       PHEN2    PHEN2-Great-Plains    1,167
       PHBOO    PHBOO-Great-Plains    18
       PHGAP    PHGAP-Great-Plains    0   (no customers; skip)

     Query 3 is the exception: it compares companies with three-part names and
     runs on PHTRA-Great-Plains only.

   RULES THESE QUERIES FOLLOW
     - Read-only. SELECT only, nothing is written.
     - Compatibility level 100 (SQL 2008): no STRING_AGG, no CTE needed;
       concatenation uses STUFF(... FOR XML PATH('')).
     - Every char column is RTRIMmed before it is compared or shown, because GP
       pads char(n) with trailing spaces and never stores NULL.
     - No email, phone, bank or card VALUES are selected. Those columns are
       only counted, because they are personal or sensitive data.
     - Run one numbered query per execute_sql call.

   PROVENANCE
     Queries 1 and 2 are the research's q_profile.sql and q_dims.sql (run
     2026-10-16 on all three live sites), lightly cleaned. The whole set was
     re-run on PHEN2-Great-Plains and PHTRA-Great-Plains on 2026-10-16 in a
     verification pass and needed no fixes. PHBOO was not re-run.
   ============================================================================ */


/* ----------------------------------------------------------------------------
   Query 1. One-row profile: about 75 counters for the company.
   Reference numbers: references/gp-source-model.md sections 3 and 5.
   ---------------------------------------------------------------------------- */
SELECT
  RTRIM(DB_NAME()) AS company_code,
  -- population and status
  (SELECT COUNT(*) FROM RM00101) AS cust,
  (SELECT COUNT(*) FROM RM00101 WHERE INACTIVE = 1) AS inactive,
  (SELECT COUNT(*) FROM RM00101 WHERE HOLD = 1) AS hold,
  (SELECT COUNT(*) FROM RM00101 WHERE HOLD = 1 AND INACTIVE = 1) AS hold_and_inactive,
  -- address integrity
  (SELECT COUNT(*) FROM RM00101 c WHERE NOT EXISTS (SELECT 1 FROM RM00102 a WHERE a.CUSTNMBR = c.CUSTNMBR)) AS no_addr_rows,
  (SELECT COUNT(*) FROM RM00101 c WHERE RTRIM(c.ADRSCODE) = '') AS blank_primary_adrscode,
  (SELECT COUNT(*) FROM RM00101 c WHERE RTRIM(c.ADRSCODE) <> '' AND NOT EXISTS (SELECT 1 FROM RM00102 a WHERE a.CUSTNMBR = c.CUSTNMBR AND a.ADRSCODE = c.ADRSCODE)) AS primary_adrs_missing,
  (SELECT COUNT(*) FROM RM00101 c WHERE RTRIM(c.PRBTADCD) <> '' AND NOT EXISTS (SELECT 1 FROM RM00102 a WHERE a.CUSTNMBR = c.CUSTNMBR AND a.ADRSCODE = c.PRBTADCD)) AS billto_missing,
  (SELECT COUNT(*) FROM RM00101 c WHERE RTRIM(c.PRSTADCD) <> '' AND NOT EXISTS (SELECT 1 FROM RM00102 a WHERE a.CUSTNMBR = c.CUSTNMBR AND a.ADRSCODE = c.PRSTADCD)) AS shipto_missing,
  (SELECT COUNT(*) FROM RM00101 c WHERE RTRIM(c.STADDRCD) <> '' AND NOT EXISTS (SELECT 1 FROM RM00102 a WHERE a.CUSTNMBR = c.CUSTNMBR AND a.ADRSCODE = c.STADDRCD)) AS stmtto_missing,
  (SELECT COUNT(*) FROM RM00101 WHERE ADRSCODE = PRBTADCD AND ADRSCODE = PRSTADCD AND ADRSCODE = STADDRCD) AS all4_same,
  (SELECT COUNT(*) FROM (SELECT CUSTNMBR FROM RM00102 GROUP BY CUSTNMBR HAVING COUNT(*) > 1) x) AS multi_addr_cust,
  (SELECT MAX(n) FROM (SELECT COUNT(*) AS n FROM RM00102 GROUP BY CUSTNMBR) x) AS max_addr_per_cust,
  (SELECT COUNT(*) FROM RM00102 a WHERE NOT EXISTS (SELECT 1 FROM RM00101 c WHERE c.CUSTNMBR = a.CUSTNMBR)) AS orphan_addr,
  -- email presence (counts only)
  (SELECT COUNT(DISTINCT Master_ID) FROM SY01200 WHERE Master_Type = 'CUS' AND (RTRIM(INET1) <> '' OR DATALENGTH(EmailToAddress) > 0)) AS cust_with_email_sy01200,
  (SELECT COUNT(DISTINCT CUSTNMBR) FROM RM00106) AS cust_with_rm00106,
  -- customer number shape
  (SELECT MAX(LEN(CUSTNMBR)) FROM RM00101) AS max_custnmbr_len,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(CUSTNMBR) LIKE '% %') AS custnmbr_with_space,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(CUSTNMBR) LIKE '%[^A-Za-z0-9]%') AS custnmbr_nonalnum,
  (SELECT COUNT(*) FROM RM00101 WHERE CUSTNMBR LIKE ' %') AS custnmbr_leading_space,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(CUSTNMBR) LIKE '%[a-z]%' COLLATE Latin1_General_BIN) AS custnmbr_lowercase,
  -- names
  (SELECT MAX(LEN(CUSTNAME)) FROM RM00101) AS max_custname_len,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(CUSTNAME) = '') AS blank_custname,
  (SELECT COUNT(*) FROM (SELECT UPPER(RTRIM(CUSTNAME)) AS n FROM RM00101 GROUP BY UPPER(RTRIM(CUSTNAME)) HAVING COUNT(*) > 1) x) AS dup_name_groups,
  (SELECT ISNULL(SUM(k), 0) FROM (SELECT COUNT(*) AS k FROM RM00101 GROUP BY UPPER(RTRIM(CUSTNAME)) HAVING COUNT(*) > 1) x) AS dup_name_custs,
  -- blanks in the attributes Fusion needs
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(PHONE1) = '' OR PHONE1 LIKE '00000000000000%') AS blank_phone1,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(TAXSCHID) = '') AS blank_taxschid,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(PYMTRMID) = '') AS blank_pymtrmid,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(CUSTCLAS) = '') AS blank_class,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(CURNCYID) = '') AS blank_curncy,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(SLPRSNID) = '') AS blank_slprsn,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(SALSTERR) = '') AS blank_terr,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(ADDRESS1) = '') AS blank_addr1,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(COUNTRY) = '') AS blank_country,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(CCode) = '') AS blank_ccode,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(ZIP) = '') AS blank_zip,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(CITY) = '') AS blank_city,
  -- optional attributes in use
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(TXRGNNUM) <> '') AS has_txrgnnum,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(CNTCPRSN) <> '') AS has_contact,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(USERDEF1) <> '') AS has_userdef1,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(USERDEF2) <> '') AS has_userdef2,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(COMMENT1) <> '' OR RTRIM(COMMENT2) <> '') AS has_comment,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(SHRTNAME) <> '') AS has_shrtname,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(STMTNAME) <> '' AND RTRIM(STMTNAME) <> RTRIM(CUSTNAME)) AS stmtname_differs,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(CPRCSTNM) <> '') AS has_parent,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(CRCRDNUM) <> '') AS has_ccnum,      -- count only, never select the value
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(BANKNAME) <> '') AS has_bankname,
  (SELECT COUNT(*) FROM RM00101 c WHERE c.NOTEINDX > 0 AND EXISTS (SELECT 1 FROM SY03900 n WHERE n.NOTEINDX = c.NOTEINDX)) AS has_note,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(SHIPMTHD) <> '') AS has_shipmthd,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(PRCLEVEL) <> '') AS has_prclevel,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(CHEKBKID) <> '') AS has_chekbk,
  (SELECT COUNT(*) FROM RM00101 WHERE RTRIM(DOCFMTID) <> '') AS has_docfmt,
  (SELECT COUNT(*) FROM RM00101 WHERE Send_Email_Statements = 1) AS send_email_stmt,
  (SELECT COUNT(*) FROM RM00101 WHERE RMARACC <> 0) AS has_ar_acct_override,
  -- dates (1900-01-01 is GP's "no date")
  (SELECT COUNT(*) FROM RM00101 WHERE FRSTINDT = '19000101') AS frstindt_sentinel,
  (SELECT CONVERT(varchar(10), MIN(CREATDDT), 120) + ' .. ' + CONVERT(varchar(10), MAX(CREATDDT), 120) FROM RM00101) AS creatddt_range,
  (SELECT COUNT(*) FROM RM00101 WHERE CREATDDT = '19000101') AS creatddt_sentinel,
  -- activity and open AR (functional currency)
  (SELECT COUNT(*) FROM RM00101 c WHERE NOT EXISTS (SELECT 1 FROM RM20101 t WHERE t.CUSTNMBR = c.CUSTNMBR) AND NOT EXISTS (SELECT 1 FROM RM30101 h WHERE h.CUSTNMBR = c.CUSTNMBR)) AS no_activity,
  (SELECT COUNT(DISTINCT CUSTNMBR) FROM RM20101 WHERE CURTRXAM <> 0) AS cust_open_bal,
  (SELECT COUNT(*) FROM RM20101 WHERE CURTRXAM <> 0) AS open_docs_nonzero,
  (SELECT SUM(CASE WHEN RMDTYPAL < 7 THEN CURTRXAM ELSE -CURTRXAM END) FROM RM20101 WHERE VOIDSTTS = 0) AS net_open_ar_func,
  (SELECT COUNT(*) FROM RM00103 WHERE CUSTBLNC <> 0) AS rm00103_nonzero_bal,
  (SELECT COUNT(*) FROM RM00101 c WHERE c.INACTIVE = 1 AND EXISTS (SELECT 1 FROM RM20101 t WHERE t.CUSTNMBR = c.CUSTNMBR AND t.CURTRXAM <> 0)) AS inactive_with_open_bal,
  -- credit, balance type, statement cycle
  (SELECT COUNT(*) FROM RM00101 WHERE CRLMTTYP = 0) AS crlm_none,
  (SELECT COUNT(*) FROM RM00101 WHERE CRLMTTYP = 1) AS crlm_unlim,
  (SELECT COUNT(*) FROM RM00101 WHERE CRLMTTYP = 2) AS crlm_amount,
  (SELECT COUNT(*) FROM RM00101 WHERE BALNCTYP = 0) AS bal_openitem,
  (SELECT COUNT(*) FROM RM00101 WHERE BALNCTYP = 1) AS bal_fwd,
  (SELECT STUFF((SELECT ',' + CAST(STMTCYCL AS varchar(5)) + '=' + CAST(COUNT(*) AS varchar(10))
                 FROM RM00101 GROUP BY STMTCYCL FOR XML PATH('')), 1, 1, '')) AS stmtcycl_dist,
  -- address-level detail
  (SELECT COUNT(DISTINCT RTRIM(STATE)) FROM RM00102) AS distinct_state,
  (SELECT COUNT(*) FROM RM00102 WHERE RTRIM(ADDRESS1) = '') AS addr_blank_line1,
  (SELECT COUNT(*) FROM RM00102 a JOIN RM00101 c ON c.CUSTNMBR = a.CUSTNMBR WHERE a.TAXSCHID <> c.TAXSCHID) AS addr_tax_differs,
  (SELECT COUNT(*) FROM RM00102 a JOIN RM00101 c ON c.CUSTNMBR = a.CUSTNMBR WHERE a.SLPRSNID <> c.SLPRSNID) AS addr_slp_differs,
  (SELECT COUNT(*) FROM RM00102 a JOIN RM00101 c ON c.CUSTNMBR = a.CUSTNMBR AND a.ADRSCODE = c.ADRSCODE
     WHERE a.ADDRESS1 <> c.ADDRESS1 OR a.CITY <> c.CITY OR a.ZIP <> c.ZIP) AS primary_addr_copy_drift;


/* ----------------------------------------------------------------------------
   Query 2. Value distributions (dimension, value, count).
   Values are codes and years, never names, addresses or contact details.
   ---------------------------------------------------------------------------- */
SELECT 'CUSTCLAS' AS d, RTRIM(CUSTCLAS) AS v, COUNT(*) AS n FROM RM00101 GROUP BY CUSTCLAS
UNION ALL SELECT 'PYMTRMID', RTRIM(PYMTRMID), COUNT(*) FROM RM00101 GROUP BY PYMTRMID
UNION ALL SELECT 'TAXSCHID', RTRIM(TAXSCHID), COUNT(*) FROM RM00101 GROUP BY TAXSCHID
UNION ALL SELECT 'CURNCYID', RTRIM(CURNCYID), COUNT(*) FROM RM00101 GROUP BY CURNCYID
UNION ALL SELECT 'SHIPMTHD', RTRIM(SHIPMTHD), COUNT(*) FROM RM00101 GROUP BY SHIPMTHD
UNION ALL SELECT 'PRCLEVEL', RTRIM(PRCLEVEL), COUNT(*) FROM RM00101 GROUP BY PRCLEVEL
UNION ALL SELECT 'CCode', RTRIM(CCode), COUNT(*) FROM RM00101 GROUP BY CCode
UNION ALL SELECT 'ADRSCODE', RTRIM(ADRSCODE), COUNT(*) FROM RM00102 GROUP BY ADRSCODE
UNION ALL SELECT 'CLASS_vs_CURR', RTRIM(CUSTCLAS) + '/' + RTRIM(CURNCYID), COUNT(*) FROM RM00101 GROUP BY CUSTCLAS, CURNCYID
UNION ALL SELECT 'CUSTPREFIX', LEFT(CUSTNMBR, 2), COUNT(*) FROM RM00101 GROUP BY LEFT(CUSTNMBR, 2)
UNION ALL SELECT 'LASTACT_YEAR', ISNULL(CAST(y AS varchar(4)), 'none'), COUNT(*)
  FROM (SELECT c.CUSTNMBR,
               (SELECT MAX(YEAR(z.d))
                  FROM (SELECT MAX(h.DOCDATE) AS d FROM RM30101 h WHERE h.CUSTNMBR = c.CUSTNMBR
                        UNION ALL
                        SELECT MAX(t.DOCDATE) FROM RM20101 t WHERE t.CUSTNMBR = c.CUSTNMBR) z) AS y
          FROM RM00101 c) q
  GROUP BY y
UNION ALL SELECT 'CRLMTAMT_bucket',
  CASE WHEN CRLMTTYP <> 2 THEN 'n/a type ' + CAST(CRLMTTYP AS varchar(5))
       WHEN CRLMTAMT = 0 THEN '0'
       WHEN CRLMTAMT <= 1000 THEN '<=1k'
       WHEN CRLMTAMT <= 10000 THEN '<=10k'
       ELSE '>10k' END, COUNT(*)
  FROM RM00101
  GROUP BY CASE WHEN CRLMTTYP <> 2 THEN 'n/a type ' + CAST(CRLMTTYP AS varchar(5))
                WHEN CRLMTAMT = 0 THEN '0'
                WHEN CRLMTAMT <= 1000 THEN '<=1k'
                WHEN CRLMTAMT <= 10000 THEN '<=10k'
                ELSE '>10k' END
UNION ALL SELECT 'RM20101_DOCTYPE', CAST(RMDTYPAL AS varchar(5)), COUNT(*) FROM RM20101 WHERE CURTRXAM <> 0 GROUP BY RMDTYPAL
UNION ALL SELECT 'RM20101_CURR', RTRIM(CURNCYID), COUNT(*) FROM RM20101 WHERE CURTRXAM <> 0 GROUP BY CURNCYID;


/* ----------------------------------------------------------------------------
   Query 3. Cross-company customer-number clash. RUN ON PHTRA-Great-Plains.
   The same CUSTNMBR in two companies is a different customer; the same real
   customer carries different numbers. Research result (2026-10-16):
     PHTRA & PHEN2 1,163 same number / 0 same name
     PHTRA & PHBOO 18 / 0,  PHEN2 & PHBOO 13 / 0
     PHTRA & PHEN2 same name, different number: 239 pairs, 236 distinct
     PHTRA customers (verification pass). Across both companies combined,
     344 names cover 722 customers.
   COLLATE DATABASE_DEFAULT guards against a collation mismatch between DBs.
   ---------------------------------------------------------------------------- */
SELECT 'PHTRA & PHEN2' AS pair, COUNT(*) AS same_custnmbr,
       SUM(CASE WHEN UPPER(RTRIM(a.CUSTNAME)) = UPPER(RTRIM(b.CUSTNAME)) COLLATE DATABASE_DEFAULT THEN 1 ELSE 0 END) AS same_name
  FROM PHTRA..RM00101 a JOIN PHEN2..RM00101 b ON b.CUSTNMBR = a.CUSTNMBR COLLATE DATABASE_DEFAULT
UNION ALL
SELECT 'PHTRA & PHBOO', COUNT(*),
       SUM(CASE WHEN UPPER(RTRIM(a.CUSTNAME)) = UPPER(RTRIM(b.CUSTNAME)) COLLATE DATABASE_DEFAULT THEN 1 ELSE 0 END)
  FROM PHTRA..RM00101 a JOIN PHBOO..RM00101 b ON b.CUSTNMBR = a.CUSTNMBR COLLATE DATABASE_DEFAULT
UNION ALL
SELECT 'PHEN2 & PHBOO', COUNT(*),
       SUM(CASE WHEN UPPER(RTRIM(a.CUSTNAME)) = UPPER(RTRIM(b.CUSTNAME)) COLLATE DATABASE_DEFAULT THEN 1 ELSE 0 END)
  FROM PHEN2..RM00101 a JOIN PHBOO..RM00101 b ON b.CUSTNMBR = a.CUSTNMBR COLLATE DATABASE_DEFAULT
UNION ALL
SELECT 'PHTRA & PHEN2 same name, different number (pairs | distinct PHTRA)',
       COUNT(*), COUNT(DISTINCT a.CUSTNMBR)
  FROM PHTRA..RM00101 a
  JOIN PHEN2..RM00101 b
    ON UPPER(RTRIM(b.CUSTNAME)) = UPPER(RTRIM(a.CUSTNAME)) COLLATE DATABASE_DEFAULT
   AND b.CUSTNMBR <> a.CUSTNMBR COLLATE DATABASE_DEFAULT;


/* ----------------------------------------------------------------------------
   Query 4. Top 10 open balances, net functional currency.
   Sign comes from the document type: RMDTYPAL 1-6 increase AR, 7-9 decrease.
   CUSTNAME is shown because the open-balance owners are mostly companies;
   keep the output out of reports (some customers are individuals).
   Research top rows: PHTRA D00659 221,738.65; PHEN2 D05666 229,382.09.
   ---------------------------------------------------------------------------- */
SELECT TOP 10
       RTRIM(DB_NAME())    AS company_code,
       RTRIM(c.CUSTNMBR)   AS CUSTNMBR,
       RTRIM(c.CUSTNAME)   AS CUSTNAME,
       RTRIM(c.CURNCYID)   AS CURNCYID,
       COUNT(*)            AS docs,
       SUM(CASE WHEN t.RMDTYPAL < 7 THEN t.CURTRXAM ELSE -t.CURTRXAM END) AS net_open_func
  FROM RM20101 t
  JOIN RM00101 c ON c.CUSTNMBR = t.CUSTNMBR
 WHERE t.VOIDSTTS = 0
 GROUP BY c.CUSTNMBR, c.CUSTNAME, c.CURNCYID
 ORDER BY net_open_func DESC;


/* ----------------------------------------------------------------------------
   Query 5. Selection-rule counts (the options in gp-source-model.md section 6).
   Research results (2026-10-16), PHTRA / PHEN2 / PHBOO:
     open balance            156 / 166 / 0
     open OR doc >= 2024     1,965 / 410 / 0
     active (INACTIVE = 0)   8,474 / 1,164 / 18   (PHBOO derived)
   ---------------------------------------------------------------------------- */
SELECT
  RTRIM(DB_NAME()) AS company_code,
  (SELECT COUNT(*) FROM RM00101 c
     WHERE EXISTS (SELECT 1 FROM RM20101 t WHERE t.CUSTNMBR = c.CUSTNMBR AND t.CURTRXAM <> 0)) AS opt_a_open_balance,
  (SELECT COUNT(*) FROM RM00101 c
     WHERE EXISTS (SELECT 1 FROM RM20101 t WHERE t.CUSTNMBR = c.CUSTNMBR AND t.CURTRXAM <> 0)
        OR EXISTS (SELECT 1 FROM RM20101 t WHERE t.CUSTNMBR = c.CUSTNMBR AND t.DOCDATE >= '20240101')
        OR EXISTS (SELECT 1 FROM RM30101 h WHERE h.CUSTNMBR = c.CUSTNMBR AND h.DOCDATE >= '20240101')) AS opt_b_open_or_since_2024,
  (SELECT COUNT(*) FROM RM00101 WHERE INACTIVE = 0) AS opt_c_all_active,
  (SELECT COUNT(*) FROM RM00101 c
     WHERE EXISTS (SELECT 1 FROM RM20101 t WHERE t.CUSTNMBR = c.CUSTNMBR)
        OR EXISTS (SELECT 1 FROM RM30101 h WHERE h.CUSTNMBR = c.CUSTNMBR)) AS ref_any_activity_ever;
