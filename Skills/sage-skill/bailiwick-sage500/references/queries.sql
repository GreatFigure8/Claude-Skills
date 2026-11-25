/* ============================================================================
   Bailiwick Sage 500 (MAS500_app) - validated query library
   Dialect : T-SQL, written for database compatibility level 100
             (no STRING_AGG WITHIN GROUP, STRING_SPLIT or TRY_CONVERT)
   Company : BDS is the operating company. Change @-style literals to suit.
   Status  : every statement below ran against the 2026-11-13 snapshot.
             Run one statement at a time; most query tools accept only one.
   Literals to change: 'BDS', fiscal year '2027', period 8, as-of date
             '2026-11-13', and the activity window start '2024-11-01'.
   ============================================================================ */


/* ---------------------------------------------------------------------------
   1. DECODE A STATUS OR CODE COLUMN
   Never guess what a number means. Ask the Sage dictionary.
   --------------------------------------------------------------------------- */
SELECT lv.TableName, lv.ColumnName, lv.DBValue, RTRIM(ls.LocalText) AS Meaning
FROM   tsmListValidation lv
JOIN   tsmLocalString ls ON ls.StringNo = lv.StringNo AND ls.LanguageID = 1033
WHERE  lv.TableName = 'tapVoucher'          -- table
  AND  lv.ColumnName = 'Status'             -- column
ORDER BY lv.DBValue;

-- Transaction types with their descriptions and per-company two-letter IDs
SELECT tt.TranType, RTRIM(d.ModuleID) AS Module, RTRIM(ttc.TranTypeID) AS TranTypeID,
       RTRIM(ls.LocalText) AS Description
FROM   tciTranType tt
LEFT JOIN tsmModuleDef d        ON d.ModuleNo = tt.ModuleNo
LEFT JOIN tciTranTypeCompany ttc ON ttc.TranType = tt.TranType AND ttc.CompanyID = 'BDS'
LEFT JOIN tsmLocalString ls     ON ls.StringNo = tt.TranDescStrNo AND ls.LanguageID = 1033
ORDER BY tt.TranType;


/* ---------------------------------------------------------------------------
   2. CHART OF ACCOUNTS
   --------------------------------------------------------------------------- */
-- 2a. Accounts with their classification and last period of activity
SELECT RTRIM(a.GLAcctNo)        AS GLAcctNo,
       RTRIM(a.Description)     AS Description,
       a.Status,                                  -- 1 Active, 2 Inactive, 3 Deleted
       a.PostingType,                             -- 1 Financial, 2 Statistical, 3 Both
       RTRIM(cat.Description)   AS Category,
       RTRIM(grp.AcctGroupID)   AS AcctGroup,
       RTRIM(typ.AcctTypeID)    AS AcctType,
       act.LastFiscYear, act.Periods
FROM   tglAccount a
JOIN   tglNaturalAcct n     ON n.NaturalAcctKey = a.NaturalAcctKey
LEFT JOIN tglAcctType typ   ON typ.AcctTypeKey = n.AcctTypeKey
LEFT JOIN tglAcctGroup grp  ON grp.AcctGroupKey = n.AcctGroupKey
LEFT JOIN tglAcctCategory cat ON cat.AcctCategoryKey = typ.AcctCategoryKey
LEFT JOIN (SELECT GLAcctKey, MAX(FiscYear) AS LastFiscYear, COUNT(*) AS Periods
           FROM   tglAcctHist
           WHERE  DebitAmt <> 0 OR CreditAmt <> 0
           GROUP BY GLAcctKey) act ON act.GLAcctKey = a.GLAcctKey
WHERE  a.CompanyID = 'BDS'
ORDER BY a.GLAcctNo;

-- 2b. Account + reference code combinations actually posted (input to the
--     Sage-to-Fusion account mapping). A NULL AcctRef means no reference code.
SELECT RTRIM(a.GLAcctNo) AS GLAcctNo, RTRIM(a.Description) AS AcctDesc,
       RTRIM(r.AcctRefCode) AS AcctRef, RTRIM(r.Description) AS AcctRefDesc,
       COUNT(*) AS Lines, SUM(t.PostAmtHC) AS NetAmt
FROM   tglTransaction t
JOIN   tglAccount a      ON a.GLAcctKey = t.GLAcctKey
LEFT JOIN tglAcctRef r   ON r.AcctRefKey = t.AcctRefKey
WHERE  a.CompanyID = 'BDS' AND t.FiscYear = '2027'
GROUP BY a.GLAcctNo, a.Description, r.AcctRefCode, r.Description
ORDER BY a.GLAcctNo, r.AcctRefCode;

-- 2c. Fiscal calendar. Map periods by date, never by number.
SELECT FiscYear, FiscPer, CONVERT(varchar(10), StartDate, 120) AS StartDate,
       CONVERT(varchar(10), EndDate, 120) AS EndDate, Status   -- 1 Open, 2 Closed
FROM   tglFiscalPeriod
WHERE  CompanyID = 'BDS' AND FiscYear >= '2024'
ORDER BY FiscYear, FiscPer;


/* ---------------------------------------------------------------------------
   3. TRIAL BALANCE
   BegBal is populated in period 1 only. Ending balance is the period-1 opening
   balance plus cumulative net activity. Total must be 0.000.
   --------------------------------------------------------------------------- */
SELECT RTRIM(a.GLAcctNo) AS GLAcctNo, RTRIM(a.Description) AS Description,
       SUM(CASE WHEN h.FiscPer = 1 THEN h.BegBal ELSE 0 END)              AS OpeningBal,
       SUM(h.DebitAmt)                                                    AS Debits,
       SUM(h.CreditAmt)                                                   AS Credits,
       SUM(CASE WHEN h.FiscPer = 1 THEN h.BegBal ELSE 0 END)
         + SUM(h.DebitAmt - h.CreditAmt)                                  AS EndingBal
FROM   tglAcctHist h
JOIN   tglAccount a ON a.GLAcctKey = h.GLAcctKey
WHERE  a.CompanyID = 'BDS'
  AND  h.FiscYear = '2027'
  AND  h.FiscPer <= 8
GROUP BY a.GLAcctNo, a.Description
HAVING SUM(CASE WHEN h.FiscPer = 1 THEN h.BegBal ELSE 0 END)
         + SUM(h.DebitAmt - h.CreditAmt) <> 0
ORDER BY a.GLAcctNo;

-- 3b. Integrity: activity in the journal lines equals activity in the balances
SELECT (SELECT SUM(CASE WHEN t.PostAmtHC > 0 THEN t.PostAmtHC ELSE 0 END)
        FROM tglTransaction t JOIN tglAccount a ON a.GLAcctKey = t.GLAcctKey
        WHERE a.CompanyID = 'BDS' AND t.FiscYear = '2027' AND t.FiscPer = 7) AS JournalDebits,
       (SELECT SUM(h.DebitAmt)
        FROM tglAcctHist h JOIN tglAccount a ON a.GLAcctKey = h.GLAcctKey
        WHERE a.CompanyID = 'BDS' AND h.FiscYear = '2027' AND h.FiscPer = 7) AS BalanceDebits;


/* ---------------------------------------------------------------------------
   4. GENERAL LEDGER DETAIL
   Positive PostAmtHC is a debit. Always filter FiscYear first: 29.9M rows.
   --------------------------------------------------------------------------- */
SELECT t.glTranKey,
       RTRIM(a.GLAcctNo)     AS GLAcctNo,
       RTRIM(r.AcctRefCode)  AS AcctRef,
       t.FiscYear, t.FiscPer,
       CONVERT(varchar(10), t.PostDate, 120) AS PostDate,
       CONVERT(varchar(10), t.TranDate, 120) AS TranDate,
       RTRIM(d.ModuleID)     AS SourceModule,
       t.TranType, RTRIM(ls.LocalText) AS TranTypeDesc,
       RTRIM(t.TranNo)       AS TranNo,
       t.TranKey,                                   -- key of the source document
       RTRIM(j.JrnlID)       AS Journal, t.JrnlNo,
       RTRIM(b.BatchID)      AS BatchID, RTRIM(b.PostUserID) AS PostedBy,
       t.PostAmtHC,
       t.PostCmnt
FROM   tglTransaction t
JOIN   tglAccount a          ON a.GLAcctKey = t.GLAcctKey
LEFT JOIN tglAcctRef r       ON r.AcctRefKey = t.AcctRefKey
LEFT JOIN tsmModuleDef d     ON d.ModuleNo = t.SourceModuleNo
LEFT JOIN tciTranType tt     ON tt.TranType = t.TranType
LEFT JOIN tsmLocalString ls  ON ls.StringNo = tt.TranDescStrNo AND ls.LanguageID = 1033
LEFT JOIN tglJournal j       ON j.JrnlKey = t.JrnlKey
LEFT JOIN tciBatchLog b      ON b.BatchKey = t.BatchKey
WHERE  a.CompanyID = 'BDS'
  AND  t.FiscYear = '2027' AND t.FiscPer = 8
  AND  a.GLAcctNo = '200000'
ORDER BY t.glTranKey;

-- 4b. Where the ledger's volume comes from (sizes the post-cut-over bridge)
SELECT RTRIM(d.ModuleID) AS SourceModule, t.TranType, RTRIM(ls.LocalText) AS TranTypeDesc,
       COUNT(*) AS Lines,
       SUM(CASE WHEN t.PostAmtHC > 0 THEN t.PostAmtHC ELSE 0 END) AS Debits
FROM   tglTransaction t
JOIN   tglAccount a          ON a.GLAcctKey = t.GLAcctKey
LEFT JOIN tsmModuleDef d     ON d.ModuleNo = t.SourceModuleNo
LEFT JOIN tciTranType tt     ON tt.TranType = t.TranType
LEFT JOIN tsmLocalString ls  ON ls.StringNo = tt.TranDescStrNo AND ls.LanguageID = 1033
WHERE  a.CompanyID = 'BDS' AND t.FiscYear = '2027'
GROUP BY d.ModuleID, t.TranType, ls.LocalText
ORDER BY Lines DESC;


/* ---------------------------------------------------------------------------
   5. ACCOUNTS PAYABLE
   --------------------------------------------------------------------------- */
-- 5a. Supplier conversion candidates: active in the window or holding open items.
--     Bank and tax columns are deliberately left out; add them only for the
--     controlled supplier-bank extract.
SELECT v.VendKey, RTRIM(v.VendID) AS VendID, RTRIM(v.VendName) AS VendName,
       RTRIM(v.VendDBA) AS VendDBA, v.Status,
       RTRIM(vc.VendClassID) AS VendClass,
       RTRIM(pt.PmtTermsID)  AS PmtTerms,
       RTRIM(pm.VendPmtMethID) AS PmtMethod,
       v.V1099Type, RTRIM(v.V1099Form) AS V1099Form, RTRIM(v.V1099Box) AS V1099Box,
       v.HoldPmt,
       RTRIM(v.UserFld1) AS BusinessType,
       act.Vouchers24m, CONVERT(varchar(10), act.LastVoucher, 120) AS LastVoucher,
       ISNULL(op.OpenDocs, 0) AS OpenDocs, ISNULL(op.OpenBal, 0) AS OpenBal
FROM   tapVendor v
LEFT JOIN tapVendClass vc     ON vc.VendClassKey = v.VendClassKey
LEFT JOIN tciPaymentTerms pt  ON pt.PmtTermsKey = v.PmtTermsKey
LEFT JOIN tapVendPmtMethod pm ON pm.VendPmtMethKey = v.VendPmtMethKey
LEFT JOIN (SELECT VendKey, COUNT(*) AS Vouchers24m, MAX(TranDate) AS LastVoucher
           FROM   tapVoucher
           WHERE  TranDate >= '2024-11-01' AND TranDate < '2027-01-01'
           GROUP BY VendKey) act ON act.VendKey = v.VendKey
LEFT JOIN (SELECT VendKey, COUNT(*) AS OpenDocs, SUM(BalanceHC) AS OpenBal
           FROM   tapVoucher WHERE Status = 1
           GROUP BY VendKey) op ON op.VendKey = v.VendKey
WHERE  v.CompanyID = 'BDS'
  AND  (act.VendKey IS NOT NULL OR op.VendKey IS NOT NULL)
ORDER BY v.VendID;

-- 5b. Supplier addresses (purchasing and remit-to) for those suppliers
SELECT v.VendKey, RTRIM(v.VendID) AS VendID, RTRIM(va.VendAddrID) AS VendAddrID,
       CASE WHEN va.AddrKey = v.DfltPurchAddrKey   THEN 1 ELSE 0 END AS IsDefaultPurchasing,
       CASE WHEN va.AddrKey = v.DfltRemitToAddrKey THEN 1 ELSE 0 END AS IsDefaultRemitTo,
       RTRIM(ad.AddrName) AS AddrName, RTRIM(ad.AddrLine1) AS AddrLine1,
       RTRIM(ad.AddrLine2) AS AddrLine2, RTRIM(ad.City) AS City,
       RTRIM(ad.StateID) AS StateID, RTRIM(ad.PostalCode) AS PostalCode,
       RTRIM(ad.CountryID) AS CountryID,
       CASE WHEN RTRIM(ISNULL(va.BankAcctNo, '')) <> '' THEN 1 ELSE 0 END AS HasBankDetails
FROM   tapVendor v
JOIN   tapVendAddr va ON va.VendKey = v.VendKey
JOIN   tciAddress ad  ON ad.AddrKey = va.AddrKey
WHERE  v.CompanyID = 'BDS' AND v.Status = 1
ORDER BY v.VendID, va.VendAddrID;

-- 5c. Open payables, aged from DueDate as of a stated date
SELECT RTRIM(v.VendID) AS VendID, RTRIM(v.VendName) AS VendName,
       vo.VoucherKey,
       RTRIM(vo.TranNo)  AS SupplierInvoiceNo,
       RTRIM(vo.VouchNo) AS SageVoucherNo,
       RTRIM(ttc.TranTypeID) AS DocType,           -- IN invoice, DM debit memo
       CONVERT(varchar(10), vo.TranDate, 120) AS InvoiceDate,
       CONVERT(varchar(10), vo.DueDate, 120)  AS DueDate,
       RTRIM(pt.PmtTermsID) AS PmtTerms,
       vo.TranAmtHC AS OriginalAmt, vo.BalanceHC AS OpenAmt,
       vo.HoldPmt,
       RTRIM(vc.VendClassID) AS VendClass,
       RTRIM(a.GLAcctNo) AS APControlAcct,
       CASE WHEN vo.DueDate >= '2026-11-13' THEN 'Current'
            WHEN DATEDIFF(day, vo.DueDate, '2026-11-13') <= 30 THEN '1-30'
            WHEN DATEDIFF(day, vo.DueDate, '2026-11-13') <= 60 THEN '31-60'
            WHEN DATEDIFF(day, vo.DueDate, '2026-11-13') <= 90 THEN '61-90'
            ELSE 'Over 90' END AS AgeBucket
FROM   tapVoucher vo
JOIN   tapVendor v              ON v.VendKey = vo.VendKey
LEFT JOIN tapVendClass vc       ON vc.VendClassKey = vo.VendClassKey
LEFT JOIN tglAccount a          ON a.GLAcctKey = vc.AcctsPaybleAcctKey
LEFT JOIN tciPaymentTerms pt    ON pt.PmtTermsKey = vo.PmtTermsKey
LEFT JOIN tciTranTypeCompany ttc ON ttc.CompanyID = vo.CompanyID AND ttc.TranType = vo.TranType
WHERE  vo.CompanyID = 'BDS' AND vo.Status = 1
ORDER BY v.VendID, vo.DueDate;

-- 5d. AP subledger to GL, by control account. Variance must be 0.
SELECT s.APControlAcct, s.OpenDocs, s.SubledgerBal, -g.GLBal AS GLBal,
       s.SubledgerBal + g.GLBal AS Variance
FROM  (SELECT RTRIM(a.GLAcctNo) AS APControlAcct, a.GLAcctKey,
              COUNT(*) AS OpenDocs, SUM(vo.BalanceHC) AS SubledgerBal
       FROM   tapVoucher vo
       JOIN   tapVendClass vc ON vc.VendClassKey = vo.VendClassKey
       JOIN   tglAccount a    ON a.GLAcctKey = vc.AcctsPaybleAcctKey
       WHERE  vo.CompanyID = 'BDS' AND vo.Status = 1
       GROUP BY a.GLAcctNo, a.GLAcctKey) s
JOIN  (SELECT h.GLAcctKey,
              SUM(CASE WHEN h.FiscPer = 1 THEN h.BegBal ELSE 0 END)
                + SUM(h.DebitAmt - h.CreditAmt) AS GLBal
       FROM   tglAcctHist h
       WHERE  h.FiscYear = '2027' AND h.FiscPer <= 8
       GROUP BY h.GLAcctKey) g ON g.GLAcctKey = s.GLAcctKey;
-- Note: an expense account used as a class "control" account (600500 for class
-- Int Tech) will show a variance by nature; only true liability accounts tie.

-- 5e. Payment history for one supplier
SELECT RTRIM(p.TranID) AS PaymentID, RTRIM(ttc.TranTypeID) AS PmtType,   -- CK, EF, OT
       CONVERT(varchar(10), p.TranDate, 120) AS PmtDate, p.TranAmtHC AS PmtAmt,
       RTRIM(ap.ApplyToTranID) AS AppliedToInvoice, ap.PmtAmtHC AS AppliedAmt,
       ap.DiscTakenAmtHC AS DiscountTaken
FROM   tapVendPmt p
JOIN   tapVendor v              ON v.VendKey = p.VendKey
LEFT JOIN tapVendPmtAppl ap     ON ap.ApplyFromPmtKey = p.VendPmtKey
LEFT JOIN tciTranTypeCompany ttc ON ttc.CompanyID = p.CompanyID AND ttc.TranType = p.TranType
WHERE  p.CompanyID = 'BDS' AND v.VendID = 'Stratix'
  AND  p.TranDate >= '2026-04-01'
ORDER BY p.TranDate, p.TranID;


/* ---------------------------------------------------------------------------
   6. ACCOUNTS RECEIVABLE
   --------------------------------------------------------------------------- */
-- 6a. Customers that are actually billed, with their national account
SELECT c.CustKey, RTRIM(c.CustID) AS CustID, RTRIM(c.CustName) AS CustName, c.Status,
       RTRIM(cc.CustClassID) AS CustClass,
       RTRIM(na.NationalAcctID) AS NationalAcctID, RTRIM(na.Description) AS NationalAcct,
       act.Invoices24m, act.Billed24m, CONVERT(varchar(10), act.LastInvoice, 120) AS LastInvoice,
       ISNULL(op.OpenDocs, 0) AS OpenDocs, ISNULL(op.OpenBal, 0) AS OpenBal
FROM   tarCustomer c
LEFT JOIN tarCustClass cc            ON cc.CustClassKey = c.CustClassKey
LEFT JOIN tarNationalAcctLevel nal   ON nal.NationalAcctLevelKey = c.NationalAcctLevelKey
LEFT JOIN tarNationalAcct na         ON na.NationalAcctKey = nal.NationalAcctKey
LEFT JOIN (SELECT CustKey, COUNT(*) AS Invoices24m, SUM(TranAmtHC) AS Billed24m,
                  MAX(TranDate) AS LastInvoice
           FROM   tarInvoice
           WHERE  TranDate >= '2024-11-01' AND Status <> 3
           GROUP BY CustKey) act ON act.CustKey = c.CustKey
LEFT JOIN (SELECT CustKey, COUNT(*) AS OpenDocs, SUM(BalanceHC) AS OpenBal
           FROM   tarInvoice WHERE Status = 1
           GROUP BY CustKey) op ON op.CustKey = c.CustKey
WHERE  c.CompanyID = 'BDS'
  AND  (act.CustKey IS NOT NULL OR op.CustKey IS NOT NULL)
ORDER BY act.Billed24m DESC;

-- 6b. Open receivables, aged from DueDate as of a stated date
SELECT RTRIM(c.CustID) AS CustID, RTRIM(c.CustName) AS CustName,
       i.InvcKey, RTRIM(i.TranID) AS InvoiceNo,
       RTRIM(ttc.TranTypeID) AS DocType,           -- IN invoice, CM credit memo
       CONVERT(varchar(10), i.TranDate, 120) AS InvoiceDate,
       CONVERT(varchar(10), i.DueDate, 120)  AS DueDate,
       RTRIM(i.CustPONo) AS CustPONo,
       RTRIM(pt.PmtTermsID) AS PmtTerms,
       i.TranAmtHC AS OriginalAmt, i.BalanceHC AS OpenAmt,
       i.SalesAmt, i.STaxAmt, i.ShipAmt,
       RTRIM(cc.CustClassID) AS CustClass,
       CASE WHEN i.DueDate >= '2026-11-13' THEN 'Current'
            WHEN DATEDIFF(day, i.DueDate, '2026-11-13') <= 30 THEN '1-30'
            WHEN DATEDIFF(day, i.DueDate, '2026-11-13') <= 60 THEN '31-60'
            WHEN DATEDIFF(day, i.DueDate, '2026-11-13') <= 90 THEN '61-90'
            ELSE 'Over 90' END AS AgeBucket
FROM   tarInvoice i
JOIN   tarCustomer c            ON c.CustKey = i.CustKey
LEFT JOIN tarCustClass cc       ON cc.CustClassKey = i.CustClassKey
LEFT JOIN tciPaymentTerms pt    ON pt.PmtTermsKey = i.PmtTermsKey
LEFT JOIN tciTranTypeCompany ttc ON ttc.CompanyID = i.CompanyID AND ttc.TranType = i.TranType
WHERE  i.CompanyID = 'BDS' AND i.Status = 1
ORDER BY c.CustID, i.DueDate;

-- 6c. Unapplied receipts
SELECT RTRIM(c.CustID) AS CustID, RTRIM(c.CustName) AS CustName,
       RTRIM(p.TranID) AS ReceiptID, CONVERT(varchar(10), p.TranDate, 120) AS ReceiptDate,
       p.TranAmtHC AS ReceiptAmt, p.UnappliedAmtHC AS UnappliedAmt
FROM   tarCustPmt p
JOIN   tarCustomer c ON c.CustKey = p.CustKey
WHERE  p.CompanyID = 'BDS' AND p.UnappliedAmtHC <> 0
ORDER BY p.UnappliedAmtHC DESC;

-- 6d. AR subledger to GL. Snapshot result: subledger 910,725.16 above GL.
SELECT s.OpenInvoices, s.OpenInvoiceBal, u.UnappliedReceipts, u.UnappliedBal,
       s.OpenInvoiceBal - u.UnappliedBal AS SubledgerNet,
       g.GLBal,
       s.OpenInvoiceBal - u.UnappliedBal - g.GLBal AS Variance
FROM  (SELECT COUNT(*) AS OpenInvoices, SUM(BalanceHC) AS OpenInvoiceBal
       FROM   tarInvoice WHERE CompanyID = 'BDS' AND Status = 1) s
CROSS JOIN
      (SELECT COUNT(*) AS UnappliedReceipts, ISNULL(SUM(UnappliedAmtHC), 0) AS UnappliedBal
       FROM   tarCustPmt WHERE CompanyID = 'BDS' AND UnappliedAmtHC <> 0) u
CROSS JOIN
      (SELECT SUM(CASE WHEN h.FiscPer = 1 THEN h.BegBal ELSE 0 END)
                + SUM(h.DebitAmt - h.CreditAmt) AS GLBal
       FROM   tglAcctHist h
       WHERE  h.FiscYear = '2027' AND h.FiscPer <= 8
         AND  h.GLAcctKey IN (SELECT AcctsRecAcctKey FROM tarCustClass WHERE CompanyID = 'BDS')) g;

-- 6e. Postings to the AR control account that did not come from AR
--     (first place to look for the variance)
SELECT RTRIM(d.ModuleID) AS SourceModule, t.TranType, t.FiscYear,
       COUNT(*) AS Lines, SUM(t.PostAmtHC) AS NetAmt
FROM   tglTransaction t
JOIN   tglAccount a      ON a.GLAcctKey = t.GLAcctKey
LEFT JOIN tsmModuleDef d ON d.ModuleNo = t.SourceModuleNo
WHERE  a.CompanyID = 'BDS' AND a.GLAcctNo = '101000'
  AND  t.SourceModuleNo <> 5
GROUP BY d.ModuleID, t.TranType, t.FiscYear
ORDER BY t.FiscYear, SourceModule;


/* ---------------------------------------------------------------------------
   7. CASH
   --------------------------------------------------------------------------- */
-- 7a. Cash accounts and their GL accounts (bank numbers deliberately omitted)
SELECT ca.CashAcctKey, RTRIM(ca.CashAcctID) AS CashAcctID, RTRIM(ca.Description) AS Description,
       RTRIM(b.BankID) AS BankID, RTRIM(ca.CurrID) AS CurrID,
       RTRIM(a.GLAcctNo) AS GLAcctNo, ca.CurntBal
FROM   tcmCashAcct ca
LEFT JOIN tcmBank b    ON b.BankKey = ca.BankKey
LEFT JOIN tglAccount a ON a.GLAcctKey = ca.GLAcctKey
WHERE  ca.CompanyID = 'BDS';

-- 7b. Outstanding (uncleared) cash transactions
SELECT RTRIM(ca.CashAcctID) AS CashAcctID, ct.TranType,
       COUNT(*) AS Items, SUM(ct.TranAmtHC) AS Amount,
       CONVERT(varchar(10), MIN(ct.TranDate), 120) AS Oldest
FROM   tcmCashTran ct
JOIN   tcmCashAcct ca ON ca.CashAcctKey = ct.CashAcctKey
WHERE  ct.CompanyID = 'BDS' AND ct.Status = 1
GROUP BY ca.CashAcctID, ct.TranType
ORDER BY ca.CashAcctID, ct.TranType;


/* ---------------------------------------------------------------------------
   8. CONVERSION SCOPE COUNTS (re-run on the cut-over copy)
   --------------------------------------------------------------------------- */
SELECT 'GL accounts'                AS Measure, COUNT(*) AS N FROM tglAccount WHERE CompanyID = 'BDS'
UNION ALL SELECT 'GL accounts active',          COUNT(*) FROM tglAccount WHERE CompanyID = 'BDS' AND Status = 1
UNION ALL SELECT 'Account reference codes',     COUNT(*) FROM tglAcctRef WHERE CompanyID = 'BDS'
UNION ALL SELECT 'Suppliers',                   COUNT(*) FROM tapVendor WHERE CompanyID = 'BDS'
UNION ALL SELECT 'Suppliers active',            COUNT(*) FROM tapVendor WHERE CompanyID = 'BDS' AND Status = 1
UNION ALL SELECT 'Suppliers 1099 active',       COUNT(*) FROM tapVendor WHERE CompanyID = 'BDS' AND Status = 1 AND V1099Type IN (1, 2)
UNION ALL SELECT 'Open AP documents',           COUNT(*) FROM tapVoucher WHERE CompanyID = 'BDS' AND Status = 1
UNION ALL SELECT 'Unposted vouchers',           COUNT(*) FROM tapPendVoucher WHERE CompanyID = 'BDS'
UNION ALL SELECT 'Customers',                   COUNT(*) FROM tarCustomer WHERE CompanyID = 'BDS'
UNION ALL SELECT 'Customers active',            COUNT(*) FROM tarCustomer WHERE CompanyID = 'BDS' AND Status = 1
UNION ALL SELECT 'National accounts',           COUNT(*) FROM tarNationalAcct WHERE CompanyID = 'BDS'
UNION ALL SELECT 'Open AR documents',           COUNT(*) FROM tarInvoice WHERE CompanyID = 'BDS' AND Status = 1
UNION ALL SELECT 'Unposted invoices',           COUNT(*) FROM tarPendInvoice WHERE CompanyID = 'BDS'
UNION ALL SELECT 'Unapplied receipts',          COUNT(*) FROM tarCustPmt WHERE CompanyID = 'BDS' AND UnappliedAmtHC <> 0
UNION ALL SELECT 'Cash accounts',               COUNT(*) FROM tcmCashAcct WHERE CompanyID = 'BDS'
UNION ALL SELECT 'Payment terms',               COUNT(*) FROM tciPaymentTerms WHERE CompanyID = 'BDS'
UNION ALL SELECT 'Open projects',               COUNT(*) FROM tPA00175 WHERE CompanyID = 'BDS' AND OpenOrClosed = 1;


/* ---------------------------------------------------------------------------
   9. CUSTOM OBJECT REVIEW (catalog only; module source is not readable here)
   --------------------------------------------------------------------------- */
-- 9a. Install and upgrade waves. Objects created on other days are suspects.
SELECT CONVERT(date, create_date) AS CreatedOn,
       SUM(CASE WHEN type = 'U'  THEN 1 ELSE 0 END) AS Tables,
       SUM(CASE WHEN type = 'V'  THEN 1 ELSE 0 END) AS Views,
       SUM(CASE WHEN type = 'TR' THEN 1 ELSE 0 END) AS Triggers,
       SUM(CASE WHEN type IN ('P', 'FN', 'IF', 'TF') THEN 1 ELSE 0 END) AS Code
FROM   sys.objects
WHERE  is_ms_shipped = 0 AND type IN ('U', 'V', 'P', 'FN', 'IF', 'TF', 'TR')
GROUP BY CONVERT(date, create_date)
HAVING COUNT(*) >= 15
ORDER BY CreatedOn;

-- 9b. Objects carrying an author tag, with size and last change
SELECT o.type_desc, o.name,
       CONVERT(varchar(10), o.create_date, 120) AS Created,
       CONVERT(varchar(10), o.modify_date, 120) AS Modified,
       (SELECT SUM(p.rows) FROM sys.partitions p
        WHERE p.object_id = o.object_id AND p.index_id IN (0, 1)) AS RowCnt
FROM   sys.objects o
WHERE  o.is_ms_shipped = 0
  AND  o.type IN ('U', 'V', 'P', 'FN', 'IF', 'TF')
  AND (o.name LIKE '%BW%'     OR o.name LIKE '%bwick%'  OR o.name LIKE '%[_]RKL%'
    OR o.name LIKE '%[_]SSS%' OR o.name LIKE '%MAG%'    OR o.name LIKE '%[_]ERP%'
    OR o.name LIKE '%exactor%' OR o.name LIKE '%[_]BDS' OR o.name LIKE '%XPNS%'
    OR o.name LIKE '%Modula%' OR o.name LIKE '%Adaptive%')
ORDER BY o.type_desc, o.name;

-- 9c. Views and tables created outside the install waves (untagged custom work)
SELECT o.type_desc, o.name,
       CONVERT(varchar(10), o.create_date, 120) AS Created,
       CONVERT(varchar(10), o.modify_date, 120) AS Modified
FROM   sys.objects o
WHERE  o.is_ms_shipped = 0 AND o.type IN ('U', 'V')
  AND  CONVERT(date, o.create_date) NOT IN
       ('2005-04-26', '2006-11-12', '2008-07-26', '2008-07-27', '2013-12-27', '2013-12-28',
        '2015-03-27', '2015-06-30', '2019-04-05', '2019-04-06', '2020-07-14', '2025-02-18')
ORDER BY o.create_date;

-- 9d. Triggers created outside the install waves. Sage's own triggers
--     (tI_/tU_/tD_<table>, ..._DBAudit, ..._AppAudit) were all rebuilt on
--     2019-04-05/06, and the 2006 warehouse add-on's on 2006-11-12, so what
--     remains is custom. Name-based filters do not work: there are 3,420.
SELECT tr.name AS TriggerName, OBJECT_NAME(tr.parent_id) AS TableName, tr.is_disabled,
       CONVERT(varchar(10), tr.create_date, 120) AS Created
FROM   sys.triggers tr
WHERE  tr.parent_class = 1
  AND  CONVERT(date, tr.create_date) NOT IN ('2006-11-12', '2019-04-05', '2019-04-06')
ORDER BY tr.create_date;

-- 9e. External dependencies: every synonym and where it points
SELECT name AS SynonymName, base_object_name AS Target,
       CONVERT(varchar(10), create_date, 120) AS Created
FROM   sys.synonyms
ORDER BY base_object_name;

-- 9f. User-defined fields in use, by host table
SELECT RTRIM(e.HostTableName) AS HostTable, u.UserFldNo, RTRIM(u.Title) AS Title
FROM   tciUserField u
JOIN   tciEntity e ON e.EntityType = u.EntityType
WHERE  u.CompanyID = 'BDS' AND RTRIM(u.Title) NOT IN ('', 'Not Used')
ORDER BY e.HostTableName, u.UserFldNo;

-- 9g. Customised screens
SELECT RTRIM(f.FormName) AS FormName, f.CompanyID, f.CustomFormEnabled,
       RTRIM(f.UserID) AS OnlyForUser,
       (SELECT COUNT(*) FROM tsmCustomFormDetl d WHERE d.CustomFormKey = f.CustomFormKey) AS ControlsChanged
FROM   tsmCustomForm f
ORDER BY ControlsChanged DESC;

-- 9h. Is an interface still alive? Latest entry in each custom log.
SELECT 'Concur file log' AS Interface, COUNT(*) AS Entries,
       CONVERT(varchar(10), MAX(DownloadDate), 120) AS Latest FROM tpaConcurLog_rkl
UNION ALL SELECT 'RKL integration log', COUNT(*), CONVERT(varchar(10), MAX(CreateDate), 120) FROM tciIntegrationLog_RKL
UNION ALL SELECT 'Exactor sales tax',   COUNT(*), CONVERT(varchar(10), MAX(SalesDate), 120)  FROM exactor_transaction
UNION ALL SELECT 'Master-data audit',   COUNT(*), CONVERT(varchar(10), MAX(SysDate), 120)    FROM tciMaintAuditLog;


/* ---------------------------------------------------------------------------
   10. PROJECTS (context for open AR and AP; later leg)
   --------------------------------------------------------------------------- */
SELECT RTRIM(mp.chrMasterJobNumber) AS MasterProject, RTRIM(p.chrJobNumber) AS Project,
       RTRIM(p.chrJobName) AS ProjectName, RTRIM(c.CustID) AS CustID,
       p.OpenOrClosed,                               -- 1 Open, 2 Closed
       CONVERT(varchar(10), p.dteJobCommencement, 120) AS StartDate,
       p.numJTDActualCost AS ActualCost, p.numJTDActualSale AS ActualSales,
       p.numJTDCommitedCsts AS CommittedCost
FROM   tPA00175 p
LEFT JOIN tPA00176 mp   ON mp.intMasterJobKey = p.intMasterJobKey
LEFT JOIN tarCustomer c ON c.CustKey = p.CustKey
WHERE  p.CompanyID = 'BDS' AND p.OpenOrClosed = 1
ORDER BY mp.chrMasterJobNumber, p.chrJobNumber;
