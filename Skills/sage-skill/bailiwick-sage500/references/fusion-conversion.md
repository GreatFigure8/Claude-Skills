# Converting Bailiwick finance from Sage 500 to Oracle Fusion

This is the first leg: general ledger, payables, receivables and cash. The aim of this file is to
make every conversion object small, defensible and reconciled.

The Fusion targets named here are the standard file-based data import (FBDI) objects for each area.
They are the usual destination, not a statement of this engagement's design: check each against the
programme's conversion inventory and the Fusion release in use before building a template.

## Contents

1. Principles
2. Scope in numbers
3. Object by object
4. The chart of accounts problem
5. The calendar problem
6. Reconciliation
7. Extraction mechanics
8. Decisions for the business

## 1. Principles

- **Convert open items and balances, archive history.** Sage holds 1.07 million vouchers and 630,709
  invoices; about 5,200 and 4,400 of them are open. History belongs in the archive
  (`retirement.md`), not in Fusion.
- **Convert what is used, not what exists.** Activity in the last 24 months is the test for master
  data. It cuts suppliers from 5,481 to under 1,000 and customers from 88,072 to a few dozen
  accounts plus the sites they need.
- **Company `BDS` only.** Every extract filters to it.
- **Tie to the ledger.** An extract is accepted when its total equals the control account balance
  for the same date, or when the difference is itemised.
- **Keep the Sage key.** Carry `VendKey`, `CustKey`, `VoucherKey`, `InvcKey` and `GLAcctKey` in a
  reference or descriptive field through staging, so that Fusion records trace back to the source.

## 2. Scope in numbers

Snapshot of 2026-11-13, company `BDS`. Re-run `queries.sql` section 8 against the cut-over copy.

| Object | In Sage | Likely to convert | Basis |
|---|---|---|---|
| GL accounts | 347 (194 active) | about 173 | Accounts with activity in fiscal 2026 or 2027 |
| Account reference codes | 74 | to be decided | See section 4 |
| Suppliers | 5,481 (1,933 active) | about 900 | 882 active suppliers vouchered in 24 months, plus any with open items |
| Supplier sites | 8,485 addresses, all companies | sites of converted suppliers | Purchasing and remit-to addresses |
| Supplier bank accounts | 1,612 addresses with bank details | those of converted suppliers | EFT is the main payment method: 11,000 EFT lines against 330 check lines in fiscal 2027 |
| 1099 suppliers | 132 active | all | Carry form, box and type; year-to-date amounts if cut-over is mid calendar year |
| Open AP | 5,205 documents, 8,218,251.65 | all | Ties to GL `200000` |
| Unposted vouchers | 84 | none | Post or delete in Sage before cut-over |
| Customers | 88,072 (87,830 active) | **decision needed** | 52 invoiced in 24 months, 29 with open items |
| National accounts | 715 | candidates for the Fusion customer account level | Section 8 |
| Open AR | 4,406 documents, 22,980,151.60 | all | 910,725.16 above GL `101000`, almost all from manual journals. Section 6 |
| Unapplied receipts | 39, 483,785.98 | all | As on-account or unapplied receipts |
| Bank accounts | 4 cash accounts | all | Configuration, not load |
| Payment terms | 22 | those in use | Configuration |
| GL balances | 25 fiscal years | to be decided | Section 5 |
| Budgets | none for fiscal 2027 | none | Budgeting is evidently done outside Sage |
| Recurring templates | 25 journals, 85 vouchers, 2,564 invoices | re-create in Fusion | Not loadable; list them for the process owners |

## 3. Object by object

### Chart of accounts and balances

| | |
|---|---|
| Source | `tglAccount`, `tglNaturalAcct`, `tglAcctType`, `tglAcctGroup`, `tglAcctCategory`, `tglAcctRef`, `tglAcctHist`, `tglAcctHistAcctRef` |
| Fusion target | Segment values and hierarchies import (`GL_SEGMENT_VALUES_INTERFACE`, `GL_SEGMENT_HIER_INTERFACE`); balances and journals through Journal Import (`GL_INTERFACE`) |
| Key rules | Balance = period-1 `BegBal` plus cumulative activity. Use `tglAcctHistAcctRef` when balances are needed by reference code. The retained earnings account is named in `tglOptions.RetainedEarnAcct` |
| Account type | `tglAcctCategory` gives Asset, Liability, Equity, Revenue and the expense groupings that set the Fusion account type |
| Watch for | Sage `Status` 3 (Deleted) accounts that still hold history; statistical accounts (`PostingType` 2 or 3) |

### Suppliers

| | |
|---|---|
| Source | `tapVendor`, `tapVendAddr`, `tciAddress`, `tciContact`, `tapVendClass`, `tciPaymentTerms`, `tapVendPmtMethod` |
| Fusion target | Supplier import family: `POZ_SUPPLIERS_INT`, `POZ_SUP_ADDRESSES_INT`, `POZ_SUPPLIER_SITES_INT`, `POZ_SITE_ASSIGNMENTS_INT`, `POZ_SUP_CONTACTS_INT`. Bank accounts through the supplier bank account import (`IBY_TEMP_EXT_PAYEES`, `IBY_TEMP_EXT_BANK_ACCTS`, `IBY_TEMP_PMT_INSTR_USES`) |
| Mapping notes | `VendID` to supplier number or an alternate reference. `VendName` and `VendDBA` to name and alias. `DfltPurchAddrKey` and `DfltRemitToAddrKey` identify purchasing and pay sites. `tapVendAddr` holds the bank fields per address. `V1099Type`, `V1099Form`, `V1099Box` and `TaxPayerID` to income tax reporting. `HoldPmt` to a payment hold. `UserFld1` (Business Types) to tax organisation type where filled |
| Watch for | Supplier class names (`Labor`, `Equip & Mat`, `Lift`, `Freight`, `Employee`, `Utilities`) are candidates for supplier type. Class `Employee` suggests expense reimbursements paid as supplier invoices; with Concur in place, decide whether those convert at all. Eleven customers are linked to a vendor |
| Sensitive | Bank account numbers, routing numbers and taxpayer IDs. Extract to a controlled file, never into a chat or a ticket |

### Open payables

| | |
|---|---|
| Source | `tapVoucher` where `Status = 1`, with `tapVoucherDetl` and `tapVoucherLineDist` |
| Fusion target | Payables invoice import: `AP_INVOICES_INTERFACE`, `AP_INVOICE_LINES_INTERFACE` |
| Mapping notes | `TranNo` is the supplier invoice number; `VouchNo` is Sage's voucher number and makes a good reference. `TranDate` is the invoice date, `DueDate` and `PmtTermsKey` give terms, `BalanceHC` is the open amount. `TranType` 402 debit memos load as negative documents |
| Method | Load each open document for its **remaining balance** on a single line coded to a conversion clearing account, so that Fusion AP equals Sage AP on day one. Part-paid vouchers need this; reloading the original amount and the payments does not reconcile |
| Watch for | 13 open documents in class `Int Tech` post to `600500`, not to AP control. Vouchers on hold. Voucher lines matched to open purchase orders, if purchasing converts in the same leg |

### Customers

| | |
|---|---|
| Source | `tarCustomer`, `tarCustAddr`, `tciAddress`, `tciContact`, `tarCustClass`, `tarNationalAcct`, `tarNationalAcctLevel`, `tarNationalAcctMember` |
| Fusion target | Customer import family: `HZ_IMP_PARTIES_T`, `HZ_IMP_LOCATIONS_T`, `HZ_IMP_PARTYSITES_T`, `HZ_IMP_PARTYSITEUSES_T`, `HZ_IMP_ACCOUNTS_T`, `HZ_IMP_ACCTSITES_T`, `HZ_IMP_ACCTSITEUSES_T`, with contacts and contact points |
| Mapping notes | `CustID`, `CustName`, `DfltBillToAddrKey`, `DfltShipToAddrKey`, `PmtTermsKey` on the address row, `CreditLimit`, `Hold`, `BillingType` |
| Watch for | The volume. See section 8 before extracting anything |

### Open receivables

| | |
|---|---|
| Source | `tarInvoice` where `Status = 1`; `tarCustPmt` where `UnappliedAmtHC <> 0` |
| Fusion target | AutoInvoice: `RA_INTERFACE_LINES_ALL`, `RA_INTERFACE_DISTRIBUTIONS_ALL`. Unapplied cash through the standard receipt import |
| Mapping notes | `TranID` or `TranNo` is the invoice number, `CustPONo` the customer PO, `BalanceHC` the open amount. `TranType` 502 credit memos load as credit transactions. The project is on the invoice lines (`tarInvoiceDetl.ProjID`) |
| Method | As for payables: one line per document for the remaining balance, coded to a clearing account |
| Watch for | Open invoices dating back to 2005; agree a write-off pass before conversion. 84 unposted invoices in `tarPendInvoice`. Sales tax on converted balances should not be recalculated in Fusion |

### Banks and cash

`tcmBank` and `tcmCashAcct` (with its `GLAcctKey`). Bank, branch and account are Fusion Cash
Management setup. BDS has four cash accounts: a primary checking account on GL `100000`, a payroll
account on `100002`, an older account on `100001` and a clearing pseudo-account.

Do not take outstanding items from Sage. Bank reconciliation is not maintained there: about 175,000
cash transactions back to 2008 still show as outstanding. The list of uncleared checks and deposits
at cut-over has to come from wherever finance reconciles the bank today.

### Reference data

Payment terms (`tciPaymentTerms`, with the due-date and discount options decoded in `data-model.md`),
payment methods, sales tax schedules (`tciSTaxSchedule`, `tciSTaxCode`) and currencies are
configuration. Extract them as mapping tables, not as loads.

## 4. The chart of accounts problem

Sage BDS has a single six-digit segment. Fusion will have a multi-segment chart. Every other segment
must therefore be **derived**, and the source for derivation is thin:

- **Company** comes from `CompanyID`. All of BDS is one legal entity value.
- **Department or cost centre** can come only from account reference codes, which appear on a small
  share of lines (about 5,700 of 1.1 million in fiscal 2027). Lines without one need a default.
- **Project, location or line of business** are not in the ledger at all. They exist on subledger
  documents (project on invoice and voucher lines) and would have to be joined in.

Build the mapping as a table of Sage `GLAcctNo` plus `AcctRefCode` to a full Fusion combination,
profile it with `queries.sql` section 2, and have finance sign it before any balance is loaded. Agree
at the same time whether history is converted at account level only.

## 5. The calendar problem

Sage's years are calendar years to 2023, then an eight-period year ending 2024-08-18, an eight-period
year ending 2025-03-31, then April-to-March. Fusion's calendar for the entity will be ePlus's.

- Never map `FiscPer` to a Fusion period by number. Map by `tglFiscalPeriod.EndDate`.
- Period 8 of fiscal 2024 (18 days) and period 1 of fiscal 2025 (13 days) both fall in August 2024.
  If monthly history is loaded, decide whether they combine into one Fusion period.
- Decide how much history Fusion needs: opening balances only, the current year by period, or
  comparatives. Each further year multiplies the mapping risk in section 4.

## 6. Reconciliation

Run in this order. Each step has a query in `queries.sql`.

1. **Ledger integrity.** The trial balance sums to zero for the cut-over period. (Verified: 0.000 for
   fiscal 2027 period 8.)
2. **Activity integrity.** Debits in `tglTransaction` equal `tglAcctHist.DebitAmt` for the period.
   (Verified for fiscal 2027 period 7.)
3. **AP to GL.** Open vouchers by control account against the GL balance of that account. (Verified:
   8,214,959.78 on both sides for `200000`.)
4. **AR to GL.** Open invoices less unapplied receipts against `101000`. **The subledger is
   910,725.16 higher than the ledger.** Query 6e shows why: 504 general journal lines posted directly
   to `101000` from 2006 to 2026 net to -909,483.02, and one AP line adds 1,770.96, leaving about
   3,013 to find. In effect the ledger carries a manual reduction of receivables (a reserve or
   accumulated corrections) inside the control account. Finance must decide before conversion whether
   that amount is written off against specific invoices, moved to a reserve account, or converted as
   a separate balance. Fusion will not tolerate a control account that differs from its subledger.
5. **Extract to source.** Row count and amount of each extract against the query that defined it.
6. **Load to extract.** Fusion interface and base table totals against the extract.
7. **Fusion subledger to Fusion GL** after the conversion journals post.

Keep the output of every step with its run date. It is the audit evidence for the conversion.

## 7. Extraction mechanics

- Extract with one statement per object and stable ordering, so that reruns compare cleanly.
- Use `start_extract` (or any bulk export) for anything over a few thousand rows; the query tool caps
  interactive results.
- `RTRIM` every `char` column, and convert dates with `CONVERT(varchar(10), col, 120)`.
- Strip or escape embedded delimiters and line breaks in free text such as `TranCmnt` and addresses.
- This copy is static. Final extracts must come from production, or from a copy taken after the
  final Sage close, with the reconciliation re-run on that copy.

## 8. Decisions for the business

1. **What is a customer in Fusion?** With 87,830 active rows and 52 billed, choose between converting
   national accounts as customer accounts with sites beneath, converting only billed customers and
   their open-item sites, or another model. This decision sizes the whole receivables conversion.
2. **How are the missing chart segments derived**, and what is the default when a line has no
   reference code?
3. **How much GL history**, and are the two August 2024 stub periods merged?
4. **The AR variance** of 910,725.16, built from manual journals to the control account: write off,
   reclassify to a reserve, or convert separately, and who owns it?
5. **Old open receivables** from 2005 onward: write off before conversion, or convert?
6. **Dormant companies** `BEL`, `UTH` and `BMH`: archive only, or bring closing balances?
7. **Employee suppliers and Concur**: do reimbursed employees become Fusion suppliers?
8. **Projects**: is the project number carried on converted open items, and where?
