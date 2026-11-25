# Sage 500 data model, as found at Bailiwick

Everything here was read from `MAS500_app` in November 2026. Row counts are for the whole database
unless a company is named.

## Contents

1. Platform and version
2. Naming conventions
3. Companies
4. Shared patterns: keys, batches, transaction types, addresses, audit columns
5. General Ledger
6. Accounts Payable
7. Accounts Receivable
8. Cash Management
9. Project Accounting
10. Status and code decodes
11. Data quality notes

## 1. Platform and version

- SQL Server 2022 Standard, database `MAS500_app`, compatibility level 100, collation
  `SQL_Latin1_General_CP1_CI_AS` (case-insensitive).
- `tsmVersionControl` reports the core modules (SM, CI, GL, AP, AR, IM, SO, CM, MC, PO) at **7.70.0**.
  The newest `tsmDBHistory` row reads 7.80. Treat the product as Sage 500 ERP 7.7x and confirm the
  marketing release with Bailiwick IT before quoting it.
- Object waves, visible in `sys.objects.create_date`, tell the upgrade story: initial build
  2005-04-26, warehouse add-on 2006-11-12, upgrades 2008-07-26, 2013-12-27, 2015-03-27 and
  2019-04-05/06, an operations add-on 2015-06-30, and warehouse-system work 2025-02-18 to 2025-02-23.
  An object created on any other day is almost certainly custom.
- Modules active for `BDS`: SM, CI, GL, AP, AR, IM, SO, CM, PO, WM, PA, CZ (Customizer), DA, DP, EX,
  BA, BE, NA, IN, O2, OA. Multicurrency (MC), Manufacturing (MF) and Payroll (PR) are not active.

## 2. Naming conventions

| Pattern | Meaning |
|---|---|
| `t<mod><Name>` | Table. `<mod>` is a two-letter module: `gl`, `ap`, `ar`, `cm`, `ci`, `sm`, `im`, `so`, `po` |
| `tPA#####`, `tPA<Name>`, `pa<mod><Name>` | Project Accounting tables, with their own Hungarian columns (`intJobKey`, `chrJobNumber`, `numJTDActualCost`) |
| `v<mod>...`, `vdv...`, `vlu...` | Views: module views, Business Insights data views, lookup views |
| `sp<mod>...`, `fn...` | Procedures and functions |
| `tI_`, `tU_`, `tD_<table>` | Insert, update and delete triggers that enforce Sage's referential integrity |
| `...Wrk` | Report work table. Contents are leftovers from the last report run. **Never a source of truth** |
| `...Log` | Posting or change log. Useful as audit evidence, not for balances |
| `tPend...` (`tapPendVoucher`, `tarPendInvoice`) | Entered but **unposted** documents |
| `Stg...` | Data Migrator staging tables, nearly all empty |
| `txx...` | Seed and template data shipped by Sage |
| a suffix after an underscore | Custom or third party. See `custom-objects.md` |

## 3. Companies

`tsmCompany` holds twelve rows. Only one matters for conversion.

| CompanyID | Name | Standing |
|---|---|---|
| `BDS` | Bailiwick Services, LLC | **Operating company.** USD, single currency. Postings through 2026-11-12 |
| `BEL` | Palmetto, LLC | 41 vouchers, last in 2018. Fiscal years end at 2018 |
| `UTH` | Ubiquitous Technology Holding, LLC | 323 vouchers, last in 2018 |
| `BMH` | Bailiwick Management Holdings | Chart of accounts only, no transactions |
| `XBD` | CRP Bailiwick Test Company | Conference-room-pilot test data from 2005 and 2006 |
| `CAD`, `COA`, `CON`, `DKS`, `SGE`, `SLS`, `SOA` | Sage demonstration companies | `DemoData` is set. Ignore |

`BEL`, `UTH` and `BMH` are a retention question (do their ledgers need archiving?), not a conversion one.

## 4. Shared patterns

**Keys.** Surrogate integer keys are issued from `tciSurrogateKey`. They are unique per table across
all companies, so a join on a key never needs `CompanyID`, but a filter does.

**Batches.** Every posted document belongs to a batch: `tciBatchLog` (`BatchKey`, `BatchID`,
`BatchType`, `Status`, `PostDate`, `PostUserID`, `SourceCompanyID`). `Status` 6 is Posted and 4 is
Balanced. `BDS` carries roughly 609,000 batches at status 4, mostly system-created shipment and
invoice batches; do not read them as an unposted backlog without checking the pending tables.

**Transaction types.** `TranType` is a number whose leading digits are the module: 3xx GL, 4xx AP,
5xx AR, 7xx IM, 8xx SO, 11xx PO. `tciTranType` holds the definition, `tciTranTypeCompany` the
two-letter `TranTypeID` per company (`IN`, `CM`, `DM`, `CK`, `EF`, `CR`), and the description is
`tsmLocalString.LocalText` joined on `tciTranType.TranDescStrNo` with `LanguageID = 1033`.

| TranType | Meaning | | TranType | Meaning |
|---|---|---|---|---|
| 303 | General journal | | 501 | AR invoice |
| 401 | AP invoice (voucher) | | 502 | AR credit memo |
| 402 | AP debit memo | | 503 | AR debit memo |
| 403 | AP credit memo | | 511 | Cash receipt |
| 411 | AP check | | 512 | Write-off |
| 416 | AP EFT | | 514 | Receipt reversal |
| 417 | AP other payment | | 516 | Refund check |
| 810 | Customer shipment | | 1110 | PO receipt |

**Document numbers.** `TranNo` is the number, `TranID` is the number with the type appended
(`3641458-IN`). On an AP voucher `TranNo` and `TranID` carry the **supplier's invoice number** and
`VouchNo` is Bailiwick's internal voucher number.

**Addresses and contacts.** `tciAddress` (13.1 million rows) is shared by every module and joined by
`AddrKey`. A vendor's addresses are in `tapVendAddr` and a customer's in `tarCustAddr`; both are
extension rows keyed by the same `AddrKey`. Contacts are in `tciContact` by `CntctKey`.

**Audit columns.** `CreateDate`, `CreateUserID`, `UpdateDate`, `UpdateUserID` and `CreateType`
(1 Standard, 2 Import, 7 Migrate, 8 Warehouse Automation) sit on most master and header tables.
`UpdateCounter` is an optimistic-lock counter, not a version of business meaning.

**User fields.** `UserFld1` to `UserFld4` on master tables are free columns whose labels are defined
per company in `tciUserField` (join `tciEntity` on `EntityType` for the host table). The labels in use
for `BDS` are listed in `custom-objects.md`.

## 5. General Ledger

| Table | Rows | Purpose |
|---|---|---|
| `tglAccount` | 3,834 (347 for BDS, 194 active) | Account. `GLAcctKey`, `GLAcctNo`, `Description`, `Status`, `NaturalAcctKey` |
| `tglNaturalAcct` | 1,607 | Natural account, carrying `AcctTypeKey` and `AcctGroupKey` |
| `tglAcctType`, `tglAcctGroup`, `tglAcctCategory` | 228 / 182 / 108 | Classification. BDS has 19 types, 19 groups and nine categories |
| `tglSegment`, `tglSegmentCode`, `tglAcctSegment` | 34 / 1,714 / 13,308 | Segment definitions, values, and the value of each segment per account |
| `tglAcctRef`, `tglAcctRefGroup` | 81 / 17 | Account reference codes (74 for BDS) |
| `tglFiscalYear`, `tglFiscalPeriod` | 87 / 1,077 | Calendar, with `StartDate`, `EndDate`, `Status`, and per-module locks |
| `tglAcctHist` | 39,957 | Period balances: `BegBal`, `DebitAmt`, `CreditAmt` by `FiscYear`, `FiscPer`, `GLAcctKey` |
| `tglAcctHistAcctRef` | 29,327 | The same activity split by account reference code |
| `tglTransaction` | 29,897,673 | Posted journal lines |
| `tglJournal` | 172 | Journal definitions (`JrnlID` such as `JE`) |
| `tglBudget`, `tglBudgetType` | 10,440 / 16 | Budgets. BDS has **no** budget rows for fiscal 2027 |
| `tglRecurJournal`, `tglRecurJrnlDetl` | 25 / 3,296 | Recurring journal templates |

**The BDS chart is one segment.** The account mask is `999999`: a six-digit natural account and
nothing else. There is no company, department or location segment in the account number.

**Account reference codes do the work of a department segment.** `tglOptions.AcctRefUsage = 1` for BDS,
and journal lines carry `AcctRefKey` pointing at codes such as `Acct` (Accounting), `Admin`, `IT` and
`AB` (Arboretum Warehouse). About 5,700 of the 1.1 million fiscal-2027 lines carry one. They are the
only analytic dimension in the ledger, so they matter to the Fusion chart of accounts design.

**Account categories for BDS:** 1 Asset, 2 Liability, 3 Equity, 4 Revenue, 5 Cost of Sales,
6 Other Income and Expense, 7 Income Tax, 8 Expense, 9 Non-Financial.

**Sign and balance rules.**
- `tglTransaction.PostAmtHC` is in home currency; positive is a debit and negative a credit. `PostAmt`
  is the transaction-currency amount. For BDS the two are equal, because everything is USD.
- `tglAcctHist.BegBal` is populated in **period 1 only** and is zero in every later period. Income
  statement accounts open each year at zero.
- Ending balance = period-1 `BegBal` + sum of (`DebitAmt` - `CreditAmt`) for periods 1 to N.
- Proven on the snapshot: the trial balance for fiscal 2027 through period 8 sums to 0.000, and
  debits in `tglTransaction` equal `tglAcctHist.DebitAmt` for a tested period.

**Tracing a journal line to its source.** `SourceModuleNo` names the module (3 GL, 4 AP, 5 AR, 7 IM,
8 SO, 11 PO; the full list is in `tsmModuleDef`). `TranType` and `TranKey` identify the source document:
for `TranType` 401 the `TranKey` is a `tapVoucher.VoucherKey`, for 501 a `tarInvoice.InvcKey`, for 511 a
`tarCustPmt.CustPmtKey`. `BatchKey` leads to `tciBatchLog`, `JrnlKey` and `JrnlNo` to the journal.

Where fiscal 2027 volume comes from (BDS, April to mid-November 2026): AR invoices 509,000 lines,
SO shipments 431,000, AP invoices 80,000, PO receipts 20,000, cash receipts 14,000, EFT payments
11,000, and only 4,200 manual general journal lines. The ledger is fed almost wholly by subledgers.

## 6. Accounts Payable

| Table | Rows | Purpose |
|---|---|---|
| `tapVendor` | 6,837 (5,481 BDS) | Supplier. `VendKey`, `VendID`, `VendName`, `Status`, `VendClassKey`, `PmtTermsKey`, 1099 columns |
| `tapVendAddr` | 8,485 | Supplier address extension, including remit-to bank details |
| `tapVendClass` | 27 | Class. Carries the **AP control account** in `AcctsPaybleAcctKey` |
| `tapVendPmtMethod` | 36 | Payment methods |
| `tapVoucher` | 1,071,293 | Posted voucher header. `Status` 1 Open, 2 Closed. `Balance`, `BalanceHC`, `DueDate`, `HoldPmt` |
| `tapVoucherDetl` | 1,837,717 | Voucher lines, with `POLineKey` and `RcvrLineKey` for matched lines |
| `tapVoucherLineDist` | 1,837,717 | GL distribution per line: `GLAcctKey`, `AcctRefKey`, `ExtAmt` |
| `tapVendPmt` | 186,148 | Payments: checks (411), EFT (416), other (417) |
| `tapVendPmtAppl`, `tapVoucherAppl` | 1,068,412 / 1,068,570 | Payment-to-voucher applications, seen from each side |
| `tapPendVoucher` | 99 (84 BDS) | Unposted vouchers |
| `tapRecurVoucher` | 85 | Recurring voucher templates |
| `tapVendStatus` | 5,555 | Stored aging buckets as of `AgingDate`. A convenience, not a control total |

BDS position in the snapshot:
- 1,933 active and 3,546 inactive suppliers. **882** active suppliers had a voucher in the 24 months to
  November 2026, and 278 have an open one.
- 5,205 open vouchers and debit memos, net **8,218,251.65**. Of that, 8,214,959.78 sits in classes
  whose control account is `200000 AP`, and it ties to the general ledger to the cent. The other
  3,291.87 belongs to class `Int Tech`, which posts to `600500`.
- Nine supplier classes hold open items: Labor, Equip & Mat, Lift, Freight, Other, Employee,
  Utilities, Int Tech and Customer.
- 132 active suppliers are flagged for 1099 reporting, 451 have a taxpayer ID, and 1,612 supplier
  addresses carry bank account details for EFT.

## 7. Accounts Receivable

| Table | Rows | Purpose |
|---|---|---|
| `tarCustomer` | 88,804 (88,072 BDS) | Customer. `CustKey`, `CustID`, `CustName`, `Status`, `CustClassKey`, `NationalAcctLevelKey` |
| `tarCustAddr` | 3,154,604 | Customer address extension. One customer has 2,424 addresses |
| `tarCustClass` | 48 | Class. Carries the **AR control account** in `AcctsRecAcctKey` |
| `tarNationalAcct`, `tarNationalAcctLevel`, `tarNationalAcctMember` | 733 / 72,040 / 87,685 | National account hierarchy |
| `tarInvoice` | 630,709 | Posted invoice header. `Status` 1 Open, 2 Closed, 3 Void |
| `tarInvoiceDetl`, `tarInvoiceLineDist` | 12,219,576 each | Lines and their GL distribution (`SalesAcctKey`) |
| `tarCustPmt` | 52,147 | Receipts, write-offs, reversals and refunds |
| `tarCustPmtAppl`, `tarInvoiceAppl` | 617,844 / 662,993 | Applications, seen from each side |
| `tarPendInvoice` | 150 (84 BDS) | Unposted invoices |
| `tarRecurInvoice` | 2,564 | Recurring invoice templates |
| `tarSalesperson` | 56 | Salespeople |

**Read the customer master with care.** BDS has 87,830 active customers, and nearly all of them
belong to a national account, yet only **52** were invoiced in the 24 months to November 2026 and
only 29 have an open invoice. The shape of the data (733 national accounts, 87,685 members, up to
2,424 addresses on one customer) suggests that most customer rows are individual service sites and
that the national account is the commercial customer. That reading is an inference to confirm with
Bailiwick finance. Either way, converting the table row for row would create tens of thousands of
dead Fusion accounts.

**Customer classes are people.** The classes holding open items are named for account managers
(`MWolter`, `KHexum`, `SMuschewske`, `BLange` and others), and every one posts to control account
`101000 A/R`. The class is a reporting attribute here, not an accounting one.

BDS position in the snapshot: 4,406 open invoices and credit memos, net **22,980,151.60**, and 39
receipts with 483,785.98 unapplied. Subledger net 22,496,365.62 against general ledger `101000` of
21,585,640.46, a difference of **910,725.16**. Nearly all of it is manual: 504 general journal lines
posted straight to `101000` between 2006 and 2026 net to -909,483.02, and one AP line adds 1,770.96.
That leaves about 3,013 unexplained. The control account has been adjusted by journal for years, so
the subledger, not the ledger, is the list of what customers owe.

## 8. Cash Management

`tcmBank` (14), `tcmCashAcct` (17, four for BDS, each mapped to a `GLAcctKey`), `tcmCashTran`
(230,040; `Status` 1 Outstanding, 2 Cleared, 3 Void), `tcmBankStatement` (146). AP payments and AR
receipts link to cash through `CashAcctKey` and `CashTranKey`.

**Bank reconciliation is not kept up in Sage.** About 175,000 BDS cash transactions are still
`Outstanding`, including 84,542 checks back to 2009 and 68,966 EFT payments back to 2018. The status
column therefore says nothing about what has cleared the bank; reconciliation evidently happens
elsewhere. Do not build an outstanding-items list from `tcmCashTran`.

## 9. Project Accounting

Bailiwick is a project business, and Project Accounting runs through sales, purchasing and billing.

| Table | Rows | Purpose |
|---|---|---|
| `tPA00176` | 1,494 | Master project (`chrMasterJobNumber`) |
| `tPA00175` | 203,613 (201,693 BDS, **1,218 open**) | Project (`chrJobNumber`, `CustKey`, `OpenOrClosed`, job-to-date totals) |
| `tPA00125` | 5,017,247 | Project line: estimate, actual, committed and recognised amounts |
| `tPA00100` | 2,245,554 | Line detail |
| `tPAGLTranRef` | 3,490,312 | Project-to-GL posting reference |
| `tPA00007` | resources | Employees and their cost and charge rates |
| `paarInvcHdr`, `paarInvcLine`, `paapLine`, `papoLine` | 180,933 / 729,350 / 334,271 / 307,974 | Links from AR invoices, AP vouchers and PO lines to project lines |

`tarInvoiceDetl` also carries `ProjID` and `ProjClientID`. Projects are outside a finance-only first
leg unless Fusion Project Financials is in scope, but open AR and AP documents reference them, so
agree early whether the project number travels as an attribute.

## 10. Status and code decodes

The live source is `tsmListValidation` (`TableName`, `ColumnName`, `DBValue`, `StringNo`) joined to
`tsmLocalString` (`StringNo`, `LanguageID = 1033`, `LocalText`). Values confirmed there:

| Column | Values |
|---|---|
| `tglAccount.Status`, `tglNaturalAcct.Status` | 1 Active, 2 Inactive, 3 Deleted |
| `tglAccount.PostingType` | 1 Financial, 2 Statistical, 3 Both |
| `tglFiscalPeriod.Status`, `tglFiscalYear.Status` | 1 Open, 2 Closed |
| `tglSegment.SegmentType` | 1 Natural, 3 Validated |
| `tapVendor.Status`, `tarCustomer.Status` | 1 Active, 2 Inactive, 3 Temporary, 4 Deleted |
| `tapVendor.V1099Type` | 1 Business, 2 Individual, 3 none |
| `tapVoucher.Status` | 1 Open, 2 Closed |
| `tapVendPmt.RevrsStatus` | 0 none, 1 Reversed, 2 Reversal |
| `tarInvoice.Status` | 1 Open, 2 Closed, 3 Void |
| `tarCustomer.BillingType` | 1 Open Item, 2 Balance Forward |
| `tcmCashTran.Status` | 1 Outstanding, 2 Cleared, 3 Void |
| `tciBatchLog.Status` | 1 In Use, 2 On Hold, 3 Out of Balance, 4 Balanced, 5 Posting, 6 Posted, 7 Interrupted |
| `tciPaymentTerms.Status` | 1 Active, 2 Inactive, 3 Deleted |
| `tciPaymentTerms.DueDateOption` | 1 Months, 2 Days, 3 Day of month, 4 Fixed date |
| `tPA00175.OpenOrClosed` | 1 Open, 2 Closed |
| `CreateType` (everywhere) | 0 Unknown, 1 Standard, 2 Import, 3 Seed, 4 Upgrade, 5 Import pending, 6 Company copy, 7 Migrate, 8 Warehouse Automation |

## 11. Data quality notes

- **Impossible dates.** Closed AP vouchers carry `TranDate` values from 1900-01-01 to 2066-08-31. Bound
  every date filter at both ends, and prefer `PostDate` with `FiscYear` and `FiscPer` for period logic.
- **Padded text.** `char` columns such as `FiscYear`, `VendID` and `GLAcctNo` are space padded.
  Equality comparisons ignore the padding in SQL Server; exports and joins made outside it do not.
- **Duplicate identities.** Eleven BDS customers are also linked to a vendor (`tarCustomer.VendKey`).
- **Stored aging is stale by design.** `tapVendStatus` and `tarCustStatus` hold buckets as of their
  own `AgingDate`. Age from `DueDate` yourself.
- **Work tables look like data.** `tapAgedUnapplWrk` (6.1 million rows), `tarAgeInvUnApWrk` (12.5
  million) and `timPPInvtValLstWrk` (18.2 million) are report residue.
