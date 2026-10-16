/* ============================================================================
   gp_customer_extract.sql
   Picturehouse Dynamics GP 2010 customer extract, one row per customer x
   address, in the shape a Fusion Customer Import mapping needs.

   WHERE TO RUN
     The same query runs on each company's own MCP site. Table names are
     unqualified, so the site decides the company, and DB_NAME() (which equals
     SY01500.INTERID, the company code) is stamped on every row.

       Company  MCP site              Rows expected (2026-10-16, no filter)
       PHTRA    PHTRA-Great-Plains    8,469 address rows + 19 customers with
                                      no address row = 8,488
       PHEN2    PHEN2-Great-Plains    1,167
       PHBOO    PHBOO-Great-Plains    18
       PHGAP    (skip: no customers)

     Those row counts are derived from the profile. The query itself ran
     successfully on PHEN2-Great-Plains and PHTRA-Great-Plains on 2026-10-16
     (verification pass, no fixes needed). PHBOO was not re-run.

   WHY IT LOOKS LIKE THIS
     - company_qualified_id: the same CUSTNMBR means a different customer in
       each company (PHTRA and PHEN2 share 1,163 numbers, 0 with the same
       name), so CUSTNMBR alone can never be the Fusion key.
     - Address columns come from RM00102, the source of truth. RM00101's copy
       of the primary address drifts (2 PHTRA, 2 PHEN2). The 19 PHTRA customers
       with no RM00102 row are kept, using RM00101's copy, and flagged by
       address_source so a rule can decide what to do with them.
     - RTRIM on every char column: GP pads char(n) with spaces and never
       stores NULL. NULLIF(..., '19000101') turns GP's "no date" into NULL.
     - Open balance is net functional currency: RMDTYPAL 1-6 add, 7-9
       subtract, voided documents excluded. Functional currency is GBP in
       both companies (MC40000.FUNLCURR). Originating-currency amounts live
       in MC020102 (PHTRA 179 rows, PHEN2 1,687), which this query does not
       join, so PHEN2's 41 EUR open documents appear here in GBP only.
     - Last activity is MAX(DOCDATE) over RM20101 and RM30101, as the research
       measured it. Two open PHTRA documents carry years 3026 and 8202, so
       last_activity_is_future flags them instead of hiding them.

   PERSONAL DATA
     Phone, fax and email VALUES are not selected. The run happens inside a
     Claude session, and those values have no place in its context. Presence
     flags and counts are returned instead. The value columns are present but
     commented out, marked [VALUE], for the controlled run that builds the
     actual load file. Card numbers (CRCRDNUM) and bank data (SY06000) are
     never extracted. CUSTNAME and CNTCPRSN are included because the import
     needs them, but many PHTRA customers are individuals: keep the output
     out of reports.

   COMPATIBILITY
     Compatibility level 100 (SQL 2008). Derived tables rather than CTEs, no
     STRING_AGG, no post-2008 functions. Read-only SELECT.

   SELECTION
     No filter is applied by default. The three candidate rules from
     references/gp-source-model.md section 6 sit at the bottom as commented-
     out WHERE options. Choosing one is Jonathan's decision.
   ============================================================================ */

SELECT
    -- identity ---------------------------------------------------------------
    RTRIM(DB_NAME())                                   AS company_code,
    RTRIM(DB_NAME()) + '-' + RTRIM(c.CUSTNMBR)         AS company_qualified_id,
    RTRIM(c.CUSTNMBR)                                  AS CUSTNMBR,
    RTRIM(c.CUSTNAME)                                  AS CUSTNAME,
    RTRIM(c.SHRTNAME)                                  AS SHRTNAME,
    RTRIM(c.STMTNAME)                                  AS STMTNAME,
    RTRIM(c.CUSTCLAS)                                  AS CUSTCLAS,

    -- address (RM00102 first, RM00101 copy only when no address row exists) --
    CASE WHEN a.CUSTNMBR IS NULL THEN 'RM00101 (no address row)'
         ELSE 'RM00102' END                            AS address_source,
    RTRIM(CASE WHEN a.CUSTNMBR IS NULL THEN c.ADRSCODE ELSE a.ADRSCODE END) AS ADRSCODE,
    RTRIM(CASE WHEN a.CUSTNMBR IS NULL THEN c.CNTCPRSN ELSE a.CNTCPRSN END) AS CNTCPRSN,
    RTRIM(CASE WHEN a.CUSTNMBR IS NULL THEN c.ADDRESS1 ELSE a.ADDRESS1 END) AS ADDRESS1,
    RTRIM(CASE WHEN a.CUSTNMBR IS NULL THEN c.ADDRESS2 ELSE a.ADDRESS2 END) AS ADDRESS2,
    RTRIM(CASE WHEN a.CUSTNMBR IS NULL THEN c.ADDRESS3 ELSE a.ADDRESS3 END) AS ADDRESS3,
    RTRIM(CASE WHEN a.CUSTNMBR IS NULL THEN c.CITY     ELSE a.CITY     END) AS CITY,
    RTRIM(CASE WHEN a.CUSTNMBR IS NULL THEN c.STATE    ELSE a.STATE    END) AS STATE,
    RTRIM(CASE WHEN a.CUSTNMBR IS NULL THEN c.ZIP      ELSE a.ZIP      END) AS ZIP,
    RTRIM(CASE WHEN a.CUSTNMBR IS NULL THEN c.COUNTRY  ELSE a.COUNTRY  END) AS COUNTRY,
    RTRIM(CASE WHEN a.CUSTNMBR IS NULL THEN c.CCode    ELSE a.CCode    END) AS CCode,

    -- phone presence flags (values are [VALUE] columns below) ---------------
    CASE WHEN RTRIM(CASE WHEN a.CUSTNMBR IS NULL THEN c.PHONE1 ELSE a.PHONE1 END) <> ''
          AND (CASE WHEN a.CUSTNMBR IS NULL THEN c.PHONE1 ELSE a.PHONE1 END) NOT LIKE '00000000000000%'
         THEN 1 ELSE 0 END                             AS has_phone1,
    CASE WHEN RTRIM(CASE WHEN a.CUSTNMBR IS NULL THEN c.PHONE2 ELSE a.PHONE2 END) <> '' THEN 1 ELSE 0 END AS has_phone2,
    CASE WHEN RTRIM(CASE WHEN a.CUSTNMBR IS NULL THEN c.PHONE3 ELSE a.PHONE3 END) <> '' THEN 1 ELSE 0 END AS has_phone3,
    CASE WHEN RTRIM(CASE WHEN a.CUSTNMBR IS NULL THEN c.FAX    ELSE a.FAX    END) <> '' THEN 1 ELSE 0 END AS has_fax,
    -- [VALUE] RTRIM(CASE WHEN a.CUSTNMBR IS NULL THEN c.PHONE1 ELSE a.PHONE1 END) AS PHONE1,
    -- [VALUE] RTRIM(CASE WHEN a.CUSTNMBR IS NULL THEN c.PHONE2 ELSE a.PHONE2 END) AS PHONE2,
    -- [VALUE] RTRIM(CASE WHEN a.CUSTNMBR IS NULL THEN c.PHONE3 ELSE a.PHONE3 END) AS PHONE3,
    -- [VALUE] RTRIM(CASE WHEN a.CUSTNMBR IS NULL THEN c.FAX    ELSE a.FAX    END) AS FAX,

    -- which uses this address carries ----------------------------------------
    RTRIM(c.ADRSCODE)                                  AS primary_ADRSCODE,
    RTRIM(c.PRBTADCD)                                  AS PRBTADCD,
    RTRIM(c.PRSTADCD)                                  AS PRSTADCD,
    RTRIM(c.STADDRCD)                                  AS STADDRCD,
    CASE WHEN a.CUSTNMBR IS NULL OR a.ADRSCODE = c.ADRSCODE THEN 1 ELSE 0 END AS is_primary_address,
    CASE WHEN a.ADRSCODE = c.PRBTADCD THEN 1 ELSE 0 END AS is_bill_to,
    CASE WHEN a.ADRSCODE = c.PRSTADCD THEN 1 ELSE 0 END AS is_ship_to,
    CASE WHEN a.ADRSCODE = c.STADDRCD THEN 1 ELSE 0 END AS is_statement_to,

    -- customer-level commercial defaults --------------------------------------
    RTRIM(c.PYMTRMID)                                  AS PYMTRMID,
    RTRIM(c.SLPRSNID)                                  AS SLPRSNID,
    RTRIM(c.SALSTERR)                                  AS SALSTERR,
    RTRIM(c.TAXSCHID)                                  AS TAXSCHID,
    RTRIM(c.SHIPMTHD)                                  AS SHIPMTHD,
    RTRIM(c.CURNCYID)                                  AS CURNCYID,
    c.CRLMTTYP                                         AS CRLMTTYP,
    c.CRLMTAMT                                         AS CRLMTAMT,
    c.HOLD                                             AS HOLD,
    c.INACTIVE                                         AS INACTIVE,
    c.STMTCYCL                                         AS STMTCYCL,
    c.BALNCTYP                                         AS BALNCTYP,
    RTRIM(c.TXRGNNUM)                                  AS TXRGNNUM,
    RTRIM(c.COMMENT1)                                  AS COMMENT1,
    RTRIM(c.COMMENT2)                                  AS COMMENT2,
    RTRIM(c.USERDEF1)                                  AS USERDEF1,
    RTRIM(c.USERDEF2)                                  AS USERDEF2,

    -- address-level overrides (3 PHTRA addresses differ on TAXSCHID) ----------
    RTRIM(a.TAXSCHID)                                  AS addr_TAXSCHID,
    RTRIM(a.SHIPMTHD)                                  AS addr_SHIPMTHD,
    RTRIM(a.SLPRSNID)                                  AS addr_SLPRSNID,
    RTRIM(a.SALSTERR)                                  AS addr_SALSTERR,

    -- dates (1900-01-01 means "no date") -------------------------------------
    NULLIF(c.CREATDDT, '19000101')                     AS CREATDDT,
    NULLIF(c.MODIFDT,  '19000101')                     AS MODIFDT,
    NULLIF(a.CREATDDT, '19000101')                     AS addr_CREATDDT,

    -- email presence (values are [VALUE] lines; see the header) ---------------
    c.Send_Email_Statements                            AS Send_Email_Statements,
    ISNULL(se.stmt_email_count, 0)                     AS stmt_email_count_rm00106,
    ISNULL(em.has_email, 0)                            AS has_email_sy01200,
    -- [VALUE] em.EmailToAddress text is not aggregated here; pull it in the
    -- [VALUE] controlled run with a direct join to SY01200 on
    -- [VALUE] Master_Type = 'CUS', RTRIM(Master_ID) = CUSTNMBR, ADRSCODE.

    -- derived activity ----------------------------------------------------------
    ISNULL(ob.open_balance_func, 0)                    AS open_balance_func,
    ISNULL(ob.open_doc_count, 0)                       AS open_doc_count,
    la.last_activity_date                              AS last_activity_date,
    CASE WHEN la.last_activity_date IS NULL THEN 0 ELSE 1 END AS has_activity,
    CASE WHEN la.last_activity_date > GETDATE() THEN 1 ELSE 0 END AS last_activity_is_future

FROM RM00101 c

LEFT JOIN RM00102 a
       ON a.CUSTNMBR = c.CUSTNMBR

-- Net open AR per customer, functional currency, voids excluded.
LEFT JOIN (SELECT t.CUSTNMBR,
                  SUM(CASE WHEN t.RMDTYPAL < 7 THEN t.CURTRXAM ELSE -t.CURTRXAM END) AS open_balance_func,
                  COUNT(*) AS open_doc_count
             FROM RM20101 t
            WHERE t.VOIDSTTS = 0
              AND t.CURTRXAM <> 0
            GROUP BY t.CUSTNMBR) ob
       ON ob.CUSTNMBR = c.CUSTNMBR

-- Last document date over open and history files.
LEFT JOIN (SELECT d.CUSTNMBR, MAX(d.DOCDATE) AS last_activity_date
             FROM (SELECT CUSTNMBR, DOCDATE FROM RM20101
                   UNION ALL
                   SELECT CUSTNMBR, DOCDATE FROM RM30101) d
            GROUP BY d.CUSTNMBR) la
       ON la.CUSTNMBR = c.CUSTNMBR

-- Statement email recipients per customer (count only).
LEFT JOIN (SELECT CUSTNMBR, COUNT(*) AS stmt_email_count
             FROM RM00106
            GROUP BY CUSTNMBR) se
       ON se.CUSTNMBR = c.CUSTNMBR

-- Email presence per customer address. Master_ID is char(31) and CUSTNMBR
-- char(15), so both sides are RTRIMmed.
LEFT JOIN (SELECT RTRIM(Master_ID) AS master_id,
                  RTRIM(ADRSCODE)  AS adrscode,
                  MAX(CASE WHEN RTRIM(INET1) <> '' OR DATALENGTH(EmailToAddress) > 0
                           THEN 1 ELSE 0 END) AS has_email
             FROM SY01200
            WHERE Master_Type = 'CUS'
            GROUP BY RTRIM(Master_ID), RTRIM(ADRSCODE)) em
       ON em.master_id = RTRIM(c.CUSTNMBR)
      AND em.adrscode  = RTRIM(CASE WHEN a.CUSTNMBR IS NULL THEN c.ADRSCODE ELSE a.ADRSCODE END)

/* ---- Selection options (uncomment exactly one; Jonathan decides) ----------

-- Option A: open balance only (any open, non-void document with CURTRXAM <> 0;
-- the same test the profile counted). 156 PHTRA / 166 PHEN2 / 0 PHBOO customers.
WHERE ISNULL(ob.open_doc_count, 0) > 0

-- Option B: open balance OR any document dated on or after 2024-01-01.
-- 1,965 PHTRA / 410 PHEN2 / 0 PHBOO customers. Includes the two open PHTRA
-- documents dated 3026 and 8202.
WHERE ISNULL(ob.open_doc_count, 0) > 0
   OR la.last_activity_date >= '20240101'

-- Option C: all active customers. 8,474 PHTRA / 1,164 PHEN2 / 18 PHBOO
-- (PHBOO derived: customers minus INACTIVE).
WHERE c.INACTIVE = 0

   Counts are customers, not rows: PHTRA has 4 customers with two addresses.
   A customer can have open documents that net to zero; Options A and B keep
   such a customer, because its open documents still need a customer in Fusion.
   ------------------------------------------------------------------------- */

ORDER BY c.CUSTNMBR, is_primary_address DESC,
         CASE WHEN a.CUSTNMBR IS NULL THEN c.ADRSCODE ELSE a.ADRSCODE END;
