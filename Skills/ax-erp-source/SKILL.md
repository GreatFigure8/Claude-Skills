---
name: ax-erp-source
description: "Query and profile Regal/Cineworld's Dynamics AX 2012 database (AX_PROD_01) via regal-sqlserver-mcp site AX-Production for people who know the business concept but not the AX schema: suppliers, customers, journal entries, GL balances/trial balance, open AP/AR, invoices, purchase orders, requisitions, items, on-hand, fixed assets, bank, theatres, film payables, chart of accounts and financial dimensions. Routes each concept to the right tables and company (virtual vreg/vcw masters vs real-entity transactions), decodes enums and LEDGERDIMENSION RecIds, and writes index-aware T-SQL. Trigger on AX, Dynamics AX, AX_PROD_01, AX-Production, 'the ERP', 'the legacy GL/AP', VENDTABLE/VENDTRANS/GENERALJOURNAL*, DATAAREAID, LEDGERDIMENSION, any AX-to-Oracle Fusion conversion or reconciliation, or whenever site AX-Production is in play."
---

# AX ERP Source (Regal / Cineworld — Dynamics AX 2012)

You know where everything lives in `AX_PROD_01` and how it behaves. The people asking know Oracle Fusion and what they want; they don't know AX tables. Turn their concept into T-SQL, run it, explain it in their terms. Everything below was read live on 2026-08-31/09-01 (rows drift; re-count before quoting). Column lists for every core table are in `references/columns.md`; decoded enum values in `references/enums.md` — read them before writing SQL against a table you haven't seen this session. Anything not there: **discover it live (§5) — never guess a column, enum value, or join.**

## 0 — Session

`tool_search("regal-sqlserver-mcp")` → `list_sites`, `connect`, `execute_sql`. Every call needs `site: "AX-Production"` (db `AX_PROD_01`, host 10.224.40.68, login HKT-AX, read-only, SQL Server 2022; the connection description says "not yet confirmed reachable" but it works). `AX-Model-Production` is the AOT model store (`AX_PROD_01_model`) — metadata only.

Rules that apply to every query:

| Rule | Why |
|---|---|
| Add `WITH (NOLOCK)`; always `TOP n` while exploring | 700M-row tables; the MCP truncates anyway |
| **Every table has `PARTITION`; the only value is `5637144576`.** Put `PARTITION=5637144576` first in `WHERE` on big tables | Nearly every index leads with PARTITION |
| Company column is `DATAAREAID` (4 chars, stored mostly lowercase; collation is CI so `'rci'` = `'RCI'`) | — |
| **Masters live in virtual companies** (§1). Transactions live in the real entity | Filtering VENDTABLE by `'rci'` returns 0 rows |
| `RECID` is the PK everywhere; FK columns hold a RecId. Never `SELECT *` (100–250 columns/table) | — |
| Never `STRING_AGG` (fails — compat level); use `FOR XML PATH` | — |
| Dates: AX "null" date is `1900-01-01`, e.g. `VENDTRANS.CLOSED='1900-01-01'` = open | — |
| Amounts: `*MST` = accounting currency, `*CUR` = transaction currency; credits are negative | — |
| A tool-execution error with no SQL message = timeout → you missed an index (§4 lists them) | — |

## 1 — Companies

- `DATAAREA` (122 rows): `ID`, `NAME`. Regal US ops = `RCI` (Regal Cinemas Inc); `REG`, `RCC`, `REH`, `UAT`, `EDW`, `HOY`… are legal entities; `ERC/ERE/EUA/EG1-4/ECI` eliminations; `CWCL` Cineworld Cinemas Ltd (UK ops), `CGRP` Cineworld Group plc, `CACL` Adelphi-Carlton (Ireland); `S***` = STAT (statutory) books; `F16*` IFRS16; `CADJ/FWCL/PPA` GAAP adjustment shells; `DAT` is the empty AX default.
- **Virtual companies** (`VIRTUALDATAAREALIST`: `ID`→`VIRTUALDATAAREA`): `VREG` = 47 US entities, `VCW` = 22 UK entities. Tables that are **shared and stored under the virtual id**: `VENDTABLE`, `CUSTTABLE`, `VENDGROUP`, `CUSTGROUP`, `ASSETGROUP`, `PAYMTERM` (plus per-entity copies in CACL/IMK). Tables stored per **real** entity: `VENDTRANS`, `CUSTTRANS`, `PURCHTABLE`, `INVENTTABLE`, `INVENTSUM`, `INVENTSITE/LOCATION`, `BANKACCOUNTTABLE`, `ASSETTABLE/BOOK/TRANS`, `LEDGERJOURNAL*`, `VENDINVOICE*`, `VENDBANKACCOUNT` (UK only). Tables with **no** `DATAAREAID`: `GENERALJOURNALENTRY/ACCOUNTENTRY` (keyed by `LEDGER`), `DIRPARTYTABLE`, `LOGISTICS*`, `DIMENSION*`, `MAINACCOUNT`, `ECORESPRODUCT`, `PURCHREQTABLE`, `FISCALCALENDAR*`.
- Bridge real→virtual: `JOIN VIRTUALDATAAREALIST vl ON vl.ID = t.DATAAREAID` then `master.DATAAREAID = vl.VIRTUALDATAAREA`. If a table isn't listed above, check: `SELECT DATAAREAID, COUNT(*) FROM X GROUP BY DATAAREAID`.
- Ledger per entity: `LEDGER` (120) `RECID, NAME, ACCOUNTINGCURRENCY, REPORTINGCURRENCY, FISCALCALENDAR, PRIMARYFORLEGALENTITY`→`DIRPARTYTABLE.RECID` (CompanyInfo row; its `DATAAREA` = company id). RCI ledger RecId = `5637145326`. **`COMPANYINFO` is not a physical table** — it's a `DIRPARTYTABLE` subtype.

## 2 — Concept router

| Concept | Entry table(s) | Scope | Key / link | Notes |
|---|---|---|---|---|
| Legal entities | `DATAAREA`, `LEDGER`, `DIRPARTYTABLE` (`INSTANCERELATIONTYPE=41`) | global | `LEDGER.PRIMARYFORLEGALENTITY=DIRPARTYTABLE.RECID` | |
| Chart of accounts | `MAINACCOUNT` (845), `MAINACCOUNTCATEGORY` | global | `MAINACCOUNTID, NAME, TYPE`(enum DimensionLedgerAccountType), `ACCOUNTCATEGORYREF`, `LEGACYACCOUNT` | one COA for all ledgers |
| Financial dimensions | `DIMENSIONATTRIBUTE`(15, 4 real), `DIMENSIONATTRIBUTEVALUE`, `DIMENSIONATTRIBUTEVALUECOMBINATION` | global | §3 R1 | structure `MainAccount-Miscellaneous-Theatre-Projects` |
| Theatres (operating units) | `DIRPARTYTABLE` `INSTANCERELATIONTYPE=2377` | global | `OMOPERATINGUNITNUMBER`=theatre no, `NAME`, `OMOPERATINGUNITTYPE`, custom `CH_STATE, CH_DMA, CH_REGION, CH_DISTRICT, CH_SCREENCOUNT, CH_SEATCOUNT, CH_DATEOPENED, CH_CLOSEDDATE, CH_SPECIALTY, CH_LEASEEXPDATE, ATTRIBUTE_IMAXLOCATION, ATTRIBUTE_RECLINER, ATTRIBUTE_VIP, RG_TEMPORARILYCLOSED` | Theatre dim value ↔ `DIMENSIONATTRIBUTEVALUE.ENTITYINSTANCE=RECID` (attribute 5637144828). `CH_LEGACYTHEATREMAPPING` old↔new codes |
| Posted GL (journal entries, balances, TB) | `GENERALJOURNALENTRY` (84M) → `GENERALJOURNALACCOUNTENTRY` (708M) | by `LEDGER` | §3 R2 | 2011-01 → 2026-12. `POSTINGLAYER` 0=Current 1=Operations 2=Tax |
| Journals before posting / journal headers | `LEDGERJOURNALTABLE` (1.1M) → `LEDGERJOURNALTRANS` (230M), `LEDGERJOURNALNAME` | real | `JOURNALNUM`+`DATAAREAID`; `POSTED`, `JOURNALTYPE`, `JOURNALNAME` | trans: `ACCOUNTTYPE`/`OFFSETACCOUNTTYPE` (LedgerJournalACType 0=Ledger 1=Cust 2=Vend 5=FixedAssets 6=Bank), `LEDGERDIMENSION`, `AMOUNTCURDEBIT/CREDIT`, `VOUCHER`, `TRANSDATE`, `TXT` |
| GL↔subledger link | `SUBLEDGERVOUCHERGENERALJOURNALENTRY`, `SUBLEDGERJOURNALENTRY`/`…ACCOUNTENTRY`, `ACCOUNTINGDISTRIBUTION`, `SOURCEDOCUMENTHEADER/LINE` | — | `GENERALJOURNALENTRY.SUBLEDGERVOUCHER + SUBLEDGERVOUCHERDATAAREAID` = `VENDTRANS/CUSTTRANS.VOUCHER + DATAAREAID` | simplest path is the voucher |
| Suppliers | `VENDTABLE` (39.5k) + `DIRPARTYTABLE` | **virtual** (vreg 35k / vcw 3.8k / cacl) | §3 R3 | `BLOCKED` (CustVendorBlocked 0=No 1=Invoice 2=All 3=Payment), `VENDGROUP`, `PAYMTERMID`, `PAYMMODE`, `TAX1099REPORTS/REGNUM`, `W9`, `CH_LEGACY_ACCOUNT`, `RG_PAYMODE*`/`CH_PAYMODE*` (Paymode ePayment), `DEFAULTDIMENSION` |
| Supplier bank | `VENDBANKACCOUNT` (4.2k, cwcl/cacl only) | real | `VENDACCOUNT`, `ACCOUNTID` | US vendors: Paymode fields on VENDTABLE |
| Supplier onboarding/approval | `CH_VENDAPPROVALTABLE`, `CH_NEWVENDCREATE`, `REGVENDCHANGEREQUEST` | real | `VENDACCOUNT`/`ACCOUNTNUM` | Regal custom |
| AP transactions / open AP / aging | `VENDTRANS` (23M) → `VENDTRANSOPEN` (open items, 60k) → `VENDSETTLEMENT` (37M) | real | §3 R4 | `TRANSTYPE` LedgerTransType: 0=None(invoice register/pending-invoice postings, most common), 3=Purch(PO invoice), 15=Payment, 24=Settlement, 27=CashDiscount, 14=Vend |
| AP invoices (posted) | `VENDINVOICEJOUR` (15.8M) → `VENDINVOICETRANS` (21.6M) | real | `INVOICEID+INVOICEACCOUNT+INVOICEDATE`; `LEDGERVOUCHER`→VENDTRANS.VOUCHER; `PURCHID` | custom `CH_DIMTHEATREVALUE, CH_WORKFLOWSTATUS, CH_ATTRIBUTE_DISTRICT` |
| AP invoices (pending / in workflow) | `VENDINVOICEINFOTABLE` (2.9M) → `VENDINVOICEINFOLINE` | real | `PARMID`, `NUM`=invoice no, `INVOICEACCOUNT`, `REQUESTSTATUS`, `MATCHSTATUS`, `APPROVER` | |
| Purchase orders | `PURCHTABLE` (2M) → `PURCHLINE` (21M) | real | `PURCHID`+`DATAAREAID`; `ORDERACCOUNT`, `PURCHSTATUS`, `DOCUMENTSTATE`, `PURCHASETYPE`(3=Purch) | line: `ITEMID`, `PROCUREMENTCATEGORY`, `LINEAMOUNT`, `QTYORDERED`, `REMAINPURCHFINANCIAL`, `LEDGERDIMENSION`, `PURCHREQID` |
| Purchase requisitions | `PURCHREQTABLE` (1.4M, **no DATAAREAID**) → `PURCHREQLINE` (21M) | cross-co | `PURCHREQLINE.PURCHREQTABLE=RECID`; company = `PURCHREQLINE.BUYINGLEGALENTITY` (DIRPARTYTABLE RecId) | header custom `CHTHEATRE, CHFIXEDASSET`; `REQUISITIONSTATUS`; approvals in `WORKFLOWTRACKING*` |
| Receipts | `VENDPACKINGSLIPJOUR` → `VENDPACKINGSLIPTRANS` (20M) | real | `PACKINGSLIPID`, `PURCHID` | |
| Items / products | `INVENTTABLE` (75k, per entity: rci 65k) → `ECORESPRODUCT` (global) → `ECORESPRODUCTTRANSLATION` (name) ; `INVENTITEMGROUPITEM`, `INVENTTABLEMODULE` (purch/sales/invent settings), `INVENTMODELGROUPITEM` | real | `INVENTTABLE.PRODUCT=ECORESPRODUCT.RECID`; `ITEMTYPE` 0=Item 2=Service | `CH_VISTAITEMTYPE`; item groups e.g. CONCESSION |
| On-hand / inventory value | `INVENTSUM` (2.2M) + `INVENTDIM` | real | §3 R5 | sites/warehouses = theatre numbers |
| Inventory transactions | `INVENTTRANS` (238M) + `INVENTTRANSORIGIN`; `INVENTJOURNALTABLE/TRANS` (269M) | real | `INVENTTRANSORIGIN` links to source (`…PURCHLINE`, `…JOURNALTRANS`) | filter `DATAAREAID + ITEMID + DATEPHYSICAL` |
| Fixed assets | `ASSETTABLE` (4.6M!) → `ASSETBOOK` (208k) → `ASSETTRANS` (1.8M); `ASSETGROUP` (virtual), `ASSETBOOKTABLE` (2 books) | real | `ASSETID+DATAAREAID`; `ASSETTABLE.THEATRE` (custom), `ASSETGROUP`, `NAME`, `SERIALNUM`; book: `STATUS`, `ACQUISITIONDATE/PRICE`, `DEPRECIATIONSTARTDATE`, `LIFETIME`, `DISPOSALDATE`, `LEGACYASSETID` | **ASSETTABLE rows are replicated ~150k × ~30 entities — always filter DATAAREAID** |
| Bank accounts / bank trans | `BANKACCOUNTTABLE` (106) → `BANKACCOUNTTRANS` (1.3M); `BANKCHEQUETABLE` (558k) | real | `ACCOUNTID+DATAAREAID`; `BANKACCOUNTSTATUS`, `LEDGERDIMENSION`; trans `VOUCHER, AMOUNTMST, RECONCILED, CHEQUENUM, CH_PAYMENTNUM` | |
| Customers | `CUSTTABLE` (25.6k) + `DIRPARTYTABLE` | **virtual** | same shape as R3 with `CUSTTABLE` | `CUSTGROUP`, `PAYMTERMID`, `CH_LEGACY_ACCOUNT` |
| AR transactions / invoices | `CUSTTRANS` (664k) → `CUSTTRANSOPEN` → `CUSTSETTLEMENT`; free-text invoices `CUSTINVOICETABLE/LINE` (unposted), `CUSTINVOICEJOUR/TRANS` (posted) | real | as AP | **SALESTABLE/SALESLINE and PROJ* are empty** — no sales orders, no projects module |
| Addresses / contacts (any party) | `DIRPARTYPOSTALADDRESSVIEW`, `DIRPARTYCONTACTINFOVIEW` | global | `PARTY` = DIRPARTYTABLE.RECID | R3 |
| Tax | `TAXTRANS` (28M), `TAXTABLE`, `TAXGROUPHEADING`, `TAX1099FIELDS`; `SURETAX*` (Wolters Kluwer SureTax integration) | real | `TAXTRANS.VOUCHER+TRANSDATE` | |
| Currencies / rates | `CURRENCY`, `EXCHANGERATE` + `EXCHANGERATECURRENCYPAIR`, `EXCHANGERATETYPE` | global | | |
| Fiscal calendar | `FISCALCALENDAR` (3) → `FISCALCALENDARYEAR` → `FISCALCALENDARPERIOD` (687); `LEDGERFISCALCALENDARPERIOD` (period status per ledger) | global | `GENERALJOURNALENTRY.FISCALCALENDARPERIOD` | |
| Budget | `BUDGETTRANSACTIONHEADER/LINE` (12.5M), `DIMENSIONFOCUSBALANCE` (223M, balance cache) | | | |
| Workers / employees | `HCMWORKER` (2.2k) + `DIRPARTYTABLE` (2975=DirPerson), `HCMEMPLOYMENT`, `HCMPOSITION` | global | `HCMWORKER.PERSON=DIRPARTYTABLE.RECID`, `PERSONNELNUMBER` | AX is not the HR system (UltiPro is) |
| Film payables (film rent) | `CH_FILM_PAYABLE_LINE` (9M) | real | `CH_MOVIE_CODE, CH_THEATRE_CODE, CH_PLAY_WEEK_NUMBER, CH_SUB_DISTRIBUTOR_CODE, INVOICE, INVOICEDATE, LEDGERDIMENSION, CH_FILMPAY_TYPE/STATUS, CH_ACCRUAL, CH_REVERSAL` | Regal custom |
| Vista POS feed | `CH_INTVISTA_DOCJOUR` (158M: `VISTADOCID, PROCESSSTATUS, REQUEST, RESPONSE`), `CH_INTVISTA_ITEMONHAND`, `CH_INTVISTA_STOCKJOURTRANS`, `CH_VISTAITEMCATEGORY`, `CH_VISTAUNITOFMEASURE` | real | | payload columns are large text |
| Payroll feed (UltiPro→AX) | `CH_ULTIPROJOURNALTRANS` (3M, opaque `BUFFER`), `CH_ULTIPROMASTER`, `CH_PAYROLLMAPPING` | | | |
| Intercompany | `CH_INTERCOMPANY_OUTOFBALANCE`, `CH_LEDGERINTERCOMPANY_CROSSWALK`, `LEDGERJOURNALTRANS.OFFSETCOMPANY` | | | |
| Lease (Lucernex) | GL entries with `DOCUMENTNUMBER='Lucernex123'`, `CH_LUCERNEX_SALES_MAPPING`, `VENDTRANS.CH_LUCERNEXAP_SENT` | | | |
| Org attributes | `CH_ATTRIBUTE_DISTRICT/REGION/DMA/STADIUM`, `CH_OPERATIONALDISTRICT`, `CH_GEOLOGICALREGION`, `CH_DISTRICTVENDORLIST` | | | lookups referenced by theatre `CH_*` codes |
| Users / audit | `USERINFO`, `SYSEXCEPTIONTABLE`, `BATCHJOBHISTORY`, `WORKFLOWTRACKINGTABLE` | | | |

## 3 — Verified recipes (all ran on 2026-08-31/09-01)

**R1 — Resolve an account string / dimensions.** Any `LEDGERDIMENSION` column → full string:
```sql
JOIN DIMENSIONATTRIBUTEVALUECOMBINATION davc ON davc.RECID = x.LEDGERDIMENSION  -- davc.DISPLAYVALUE = '735100-0000-1848-U-HVAC', davc.MAINACCOUNT = MAINACCOUNT.RECID
```
Break into segments (order = VALUEORDINAL: 1 MainAccount, 2 Miscellaneous, 3 Theatre, 4 Projects):
```sql
SELECT v.VALUECOMBINATIONRECID, da.NAME, v.DISPLAYVALUE, v.VALUEORDINAL, v.ENTITYINSTANCE
FROM DIMENSIONATTRIBUTELEVELVALUEALLVIEW v JOIN DIMENSIONATTRIBUTE da ON da.RECID = v.DIMENSIONATTRIBUTE
WHERE v.VALUECOMBINATIONRECID IN (...)
```
`DEFAULTDIMENSION` (on VENDTABLE, ASSETTABLE, lines…) is a *set*, not a combination → `DIMENSIONATTRIBUTEVALUESETITEMVIEW` (`DIMENSIONATTRIBUTEVALUESET`, `DIMENSIONATTRIBUTE`, `DISPLAYVALUE`). Dimension attribute RecIds: MainAccount 5637144583, Theatre 5637144828 (backed by OMOperatingUnit), Miscellaneous 5637144826, Projects 5637144827 (both financial tags in `DIMENSIONFINANCIALTAG`). The Vendor/Customer/Asset/Bank `SystemGeneratedAttribute*` rows exist only for subledger accounts (`LEDGERDIMENSIONTYPE<>0`).

**R2 — Posted GL lines for a company + date range** (must hit `PARTITION,LEDGER,ACCOUNTINGDATE`):
```sql
SELECT gje.JOURNALNUMBER, gje.SUBLEDGERVOUCHER, gje.ACCOUNTINGDATE, gje.POSTINGLAYER, gje.DOCUMENTNUMBER,
       davc.DISPLAYVALUE AS account, gjae.ACCOUNTINGCURRENCYAMOUNT, gjae.ISCREDIT, gjae.POSTINGTYPE, gjae.TEXT
FROM GENERALJOURNALENTRY gje WITH (NOLOCK)
JOIN GENERALJOURNALACCOUNTENTRY gjae WITH (NOLOCK) ON gjae.PARTITION = gje.PARTITION AND gjae.GENERALJOURNALENTRY = gje.RECID
JOIN DIMENSIONATTRIBUTEVALUECOMBINATION davc ON davc.RECID = gjae.LEDGERDIMENSION
WHERE gje.PARTITION = 5637144576
  AND gje.LEDGER = (SELECT l.RECID FROM LEDGER l JOIN DIRPARTYTABLE le ON le.RECID = l.PRIMARYFORLEGALENTITY WHERE le.DATAAREA = 'RCI')
  AND gje.ACCOUNTINGDATE BETWEEN '2025-06-01' AND '2025-06-30'
```
Trial balance = `SUM(gjae.ACCOUNTINGCURRENCYAMOUNT)` grouped by `davc.DISPLAYVALUE` (or by `gjae.MAINACCOUNT`→`MAINACCOUNT.RECID`), with `gje.POSTINGLAYER=0` for the current layer. Period: `gje.FISCALCALENDARPERIOD`→`FISCALCALENDARPERIOD` (`NAME, STARTDATE, ENDDATE, TYPE`). `POSTINGTYPE` decodes via enum `LedgerPostingType` (§5).

**R3 — Supplier profile** (customers: swap `VENDTABLE`→`CUSTTABLE`):
```sql
SELECT v.DATAAREAID, v.ACCOUNTNUM, p.NAME, v.VENDGROUP, v.PAYMTERMID, v.PAYMMODE, v.CURRENCY, v.BLOCKED, v.TAX1099REPORTS, v.CH_LEGACY_ACCOUNT,
       a.ADDRESS, a.CITY, a.STATE, a.ZIPCODE, a.COUNTRYREGIONID,
       (SELECT TOP 1 LOCATOR FROM DIRPARTYCONTACTINFOVIEW c WHERE c.PARTY = p.RECID AND c.TYPE = 2 AND c.ISPRIMARY = 1) AS email,
       (SELECT TOP 1 LOCATOR FROM DIRPARTYCONTACTINFOVIEW c WHERE c.PARTY = p.RECID AND c.TYPE = 1 AND c.ISPRIMARY = 1) AS phone,
       STUFF((SELECT '|' + s.DISPLAYVALUE FROM DIMENSIONATTRIBUTEVALUESETITEMVIEW s WHERE s.DIMENSIONATTRIBUTEVALUESET = v.DEFAULTDIMENSION FOR XML PATH('')),1,1,'') AS default_dims
FROM VENDTABLE v WITH (NOLOCK)
JOIN DIRPARTYTABLE p ON p.RECID = v.PARTY
LEFT JOIN DIRPARTYPOSTALADDRESSVIEW a ON a.PARTY = p.RECID AND a.ISPRIMARY = 1 AND a.VALIDTO > GETDATE()
WHERE v.DATAAREAID = 'vreg'          -- US shared vendors; 'vcw' UK
```
Contact `TYPE`: 1 Phone, 2 Email, 3 URL, 4 Telex, 5 Fax (LogisticsElectronicAddressMethodType). `DIRPARTYTABLE.INSTANCERELATIONTYPE`: 2978 DirOrganization, 2975 DirPerson, 2377 OMOperatingUnit, 41 CompanyInfo, 5329 OMTeam.

**R4 — AP transactions with vendor name, across the virtual-company bridge:**
```sql
SELECT vt.ACCOUNTNUM, p.NAME, v.VENDGROUP, vt.TRANSTYPE, vt.INVOICE, vt.VOUCHER, vt.TRANSDATE, vt.DUEDATE,
       vt.AMOUNTMST, vt.SETTLEAMOUNTMST, vt.AMOUNTMST - vt.SETTLEAMOUNTMST AS remaining, vt.CLOSED, vt.JOURNALNUM, vt.TXT
FROM VENDTRANS vt WITH (NOLOCK)
JOIN VIRTUALDATAAREALIST vl ON vl.ID = vt.DATAAREAID
JOIN VENDTABLE v WITH (NOLOCK) ON v.ACCOUNTNUM = vt.ACCOUNTNUM AND v.DATAAREAID = vl.VIRTUALDATAAREA
JOIN DIRPARTYTABLE p ON p.RECID = v.PARTY
WHERE vt.PARTITION = 5637144576 AND vt.DATAAREAID = 'rci' AND vt.TRANSDATE BETWEEN '2025-06-01' AND '2025-06-30'
```
Open AP as of today: use `VENDTRANSOPEN` (`REFRECID`=VENDTRANS.RECID, `AMOUNTMST`, `DUEDATE`) — it is the maintained open-item list. Settlement history: `VENDSETTLEMENT` (`TRANSRECID`, `OFFSETRECID`, `SETTLEAMOUNTMST`, `TRANSDATE`). Payments: `TRANSTYPE=15`, and `BANKACCOUNTTRANS` via `VOUCHER`.

**R5 — On-hand by theatre:**
```sql
SELECT s.ITEMID, pt.NAME, ig.ITEMGROUPID, d.INVENTSITEID, d.INVENTLOCATIONID, s.PHYSICALINVENT, s.AVAILPHYSICAL, s.PHYSICALVALUE
FROM INVENTSUM s WITH (NOLOCK)
JOIN INVENTDIM d WITH (NOLOCK) ON d.INVENTDIMID = s.INVENTDIMID AND d.DATAAREAID = s.DATAAREAID
JOIN INVENTTABLE it WITH (NOLOCK) ON it.ITEMID = s.ITEMID AND it.DATAAREAID = s.DATAAREAID
LEFT JOIN ECORESPRODUCTTRANSLATION pt ON pt.PRODUCT = it.PRODUCT AND pt.LANGUAGEID = 'en-us'
LEFT JOIN INVENTITEMGROUPITEM ig ON ig.ITEMID = it.ITEMID AND ig.ITEMDATAAREAID = it.DATAAREAID
WHERE s.DATAAREAID = 'rci' AND s.CLOSED = 0 AND s.PHYSICALINVENT <> 0 AND d.INVENTSITEID = '1044'
```

**R6 — Theatre master:** `SELECT OMOPERATINGUNITNUMBER, NAME, CH_STATE, CH_SCREENCOUNT, CH_DATEOPENED, CH_CLOSEDDATE, RG_TEMPORARILYCLOSED, ... FROM DIRPARTYTABLE WHERE INSTANCERELATIONTYPE = 2377` (`OMOPERATINGUNITTYPE=4` for theatres; other values = departments/cost centres — decode via §5). Address via R3's views on `RECID`.

**R7 — Fixed assets by theatre:** `ASSETTABLE a JOIN ASSETBOOK b ON b.ASSETID=a.ASSETID AND b.DATAAREAID=a.DATAAREAID WHERE a.DATAAREAID='rci'` — `b.BOOKID` selects the book (2 in `ASSETBOOKTABLE`); `b.STATUS` is `AssetStatus`; NBV = acquisition + `ASSETTRANS` sums by `TRANSTYPE` (decode `AssetTransType` §5 — not in SRSANALYSISENUMS, take it from AX docs and confirm against data).

## 4 — Indexes on the giants (lead columns; hit them or time out)

| Table | Usable index keys |
|---|---|
| GENERALJOURNALENTRY | `PARTITION,LEDGER,ACCOUNTINGDATE` · `PARTITION,LEDGER,SUBLEDGERVOUCHER` · `PARTITION,JOURNALNUMBER,FISCALCALENDARYEAR,LEDGER` |
| GENERALJOURNALACCOUNTENTRY | `PARTITION,GENERALJOURNALENTRY` · `PARTITION,LEDGERDIMENSION` · `PARTITION,MAINACCOUNT` |
| VENDTRANS / CUSTTRANS | AX standard: `DATAAREAID,ACCOUNTNUM,TRANSDATE` · `DATAAREAID,VOUCHER` · `DATAAREAID,INVOICE` (confirm with the sys.indexes query in §5 before a heavy pull) |
| LEDGERJOURNALTRANS | `DATAAREAID,JOURNALNUM` · `DATAAREAID,VOUCHER` |
| INVENTTRANS | `DATAAREAID,ITEMID,…` · `INVENTTRANSORIGIN` |

## 5 — Runtime lookups (discover, don't memorize)

```sql
-- Enum decode (139 enums present, incl. LedgerTransType, LedgerPostingType, LedgerJournalACType, CustVendorBlocked,
-- DimensionLedgerAccountType, PurchaseType, CustVendPaymStatus, ItemType, CurrentOperationsTax)
SELECT ENUMITEMVALUE, ENUMITEMNAME, ENUMITEMLABEL FROM SRSANALYSISENUMS WHERE ENUMNAME = 'LedgerTransType' AND LANGUAGEID = 'en-us' ORDER BY 1
-- Not there (e.g. OMOperatingUnitType, AssetTransType, PurchStatus)? Profile the column's distinct values and confirm against
-- Microsoft's AX 2012 docs; state the source. Never invent a mapping.

-- Columns of a table, minus localization noise (~40% of columns are country suffixes)
SELECT c.name FROM sys.columns c WHERE c.object_id = OBJECT_ID('VENDTABLE')
  AND c.name NOT LIKE '%[_][A-Z][A-Z]' AND c.name NOT LIKE '%[_]W' AND c.name NOT LIKE '%TZID' AND c.name NOT LIKE 'DEL[_]%' ORDER BY c.column_id

-- Indexes of a table
SELECT i.name, STUFF((SELECT ','+c.name FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
  WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.is_included_column=0 ORDER BY ic.key_ordinal FOR XML PATH('')),1,1,'')
FROM sys.indexes i WHERE i.object_id = OBJECT_ID('VENDTRANS') AND i.type > 0

-- Does a table have data, and in which companies?
SELECT DATAAREAID, COUNT(*) FROM <T> WITH (NOLOCK) GROUP BY DATAAREAID
-- Row counts without scanning:
SELECT t.name, SUM(p.rows) FROM sys.tables t JOIN sys.partitions p ON p.object_id=t.object_id AND p.index_id IN (0,1) WHERE t.name LIKE 'VEND%' GROUP BY t.name

-- Table id → name (for INSTANCERELATIONTYPE, SOURCETABLEID, ADDRESSREFTABLEID …): physical tables
SELECT NAME FROM SQLDICTIONARY WHERE FIELDID = 0 AND TABLEID = 2303
-- … incl. non-physical subtypes: model store
SELECT AxId, Name FROM ModelElement WHERE ElementType = 44 AND AxId IN (...)          -- site AX-Model-Production
-- AOT relations of a table (fallback when a join is unknown; blob is semi-readable: target table then field pairs)
SELECT r.Name, LEFT(REPLACE(CONVERT(NVARCHAR(MAX), d.Properties), NCHAR(0), '|'), 300)
FROM ModelElement t JOIN ModelElement r ON r.ParentHandle = t.ElementHandle AND r.ElementType = 25
JOIN ModelElementData d ON d.ElementHandle = r.ElementHandle WHERE t.ElementType = 44 AND t.Name = 'VendTrans'
-- (some blobs fail UTF-16 decode — if so, fall back to AX 2012 docs for that relation)
```

## 6 — Traps

1. Master data under `vreg`/`vcw`, not the real entity (§1). Transactions under the real entity. Bridge with `VIRTUALDATAAREALIST`.
2. `COMPANYINFO`, `DIRORGANIZATION`, `DIRPERSON`, `OMOPERATINGUNIT` are not tables — all rows are in `DIRPARTYTABLE`, discriminated by `INSTANCERELATIONTYPE`.
3. `GENERALJOURNALENTRY` has no `DATAAREAID`; company = `LEDGER` RecId. Filter without it and the 708M-row child scan times out.
4. `ASSETTABLE` is replicated per entity (4.6M rows ≈ 150k × 30). Filter `DATAAREAID` or counts are 30× wrong.
5. `PURCHREQTABLE` is cross-company: no `DATAAREAID`; use `PURCHREQLINE.BUYINGLEGALENTITY`.
6. `VENDTRANS.TRANSTYPE=0` ("None") is the dominant invoice type in RCI (invoice-register/pending-invoice postings, vouchers `PIS…`); `3=Purch` is PO-matched. Don't assume 0 = junk.
7. `SRSANALYSISENUMS` covers only 139 enums (the SSRS/cube set). Missing enum → profile + docs, say so.
8. Empty modules: sales orders, projects, production. AR is free-text invoicing only. HR master is UltiPro, not AX.
9. Dimension `DISPLAYVALUE` can have blank segments (`220100---` on the AP control account); split on `-` carefully — Projects values themselves contain `-` (`U-HVAC`), so use `DIMENSIONATTRIBUTELEVELVALUEALLVIEW`, not string splitting.
10. `VENDBANKACCOUNT` is UK-only; US vendor payment routing is on `VENDTABLE.RG_PAYMODE*`/`CH_PAYMODE*` — never report "no bank data" for US vendors without saying this.
11. The MCP truncates result sets and `total_rows` goes null when truncated — always aggregate server-side for counts.
12. Row counts and the 2011→2026-12 GL range were read on 2026-09-01; re-check before quoting to Regal.

## 7 — Answering style

State the company (and whether the master is `vreg`/`vcw`), the date range, the table path you took, and the enum decode source. Give the SQL you ran. If a concept isn't in §2, say which discovery query you ran and what it found before answering. For Oracle Fusion conversion asks (GL_INTERFACE, supplier FBDI, etc.), map AX column → template column explicitly and flag what AX doesn't hold.
