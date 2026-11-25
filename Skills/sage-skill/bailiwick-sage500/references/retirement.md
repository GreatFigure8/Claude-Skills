# Retiring Sage 500 at Bailiwick

Conversion moves the open position into Fusion. Retirement is everything else: keeping what must be
kept, cutting every interface, and switching the system off without losing the ability to answer an
auditor. Finance goes first, and Sage keeps running for the other legs, so retirement here is staged.

## Contents

1. Staged retirement
2. What must be archived
3. What can be left behind
4. Interfaces to cut or re-point
5. Reports to replace
6. Sensitive data
7. Access and operations
8. Readiness checklist

## 1. Staged retirement

Sales orders, purchasing, inventory, warehousing and projects all post to the Sage ledger: in fiscal
2027, shipments and receipts produced about 450,000 GL lines and manual journals only 4,200. Moving
finance first therefore leaves a live operational Sage whose accounting still has to reach a ledger.

| Stage | State of Sage | Key question |
|---|---|---|
| A. Finance cut-over | GL, AP, AR and CM frozen for new entry; operations continue | How do Sage's operational postings (shipments, receipts, inventory adjustments, AR invoices raised from shipments) reach Fusion? A summarised journal feed from `tglTransaction` by source module is the usual bridge |
| B. Later legs | Modules switched off as each moves | Which module's last posting closes which Sage period? |
| C. Read-only | No entry of any kind | Is every interface in section 4 stopped or re-pointed? |
| D. Archive and decommission | Database retained as an archive, application removed | Is the archive queryable without Sage installed? |

Agree the bridge in stage A before cut-over. It is the most commonly missed piece of a finance-first
programme.

## 2. What must be archived

The database is about 128 GB. Keep the whole thing as the system of record for history; these are the
tables an auditor, a tax authority or a customer dispute will actually need.

| Area | Tables | Size |
|---|---|---|
| General ledger | `tglTransaction`, `tglAcctHist`, `tglAcctHistAcctRef`, `tglAccount`, `tglFiscalPeriod`, `tglJournal` | 29.9 million journal lines, 2003 to 2026 |
| Payables | `tapVoucher`, `tapVoucherDetl`, `tapVoucherLineDist`, `tapVendPmt`, `tapVendPmtAppl`, `tapVendor`, `tapVendAddr` | 1.07 million vouchers, 186,148 payments |
| Receivables | `tarInvoice`, `tarInvoiceDetl`, `tarInvoiceLineDist`, `tarCustPmt`, `tarCustPmtAppl`, `tarCustomer`, `tarCustAddr` | 630,709 invoices, 12.2 million lines |
| Sales tax | `tciSTaxTran`, `tciSTaxCodeTran`, `tciSTaxDetail` | 20.3 million and 21.4 million rows |
| 1099 | `tapVend1099Hist`, `tapVend1099Bal`, the 1099 columns on vouchers and payment applications | |
| Cash | `tcmCashTran`, `tcmBankStatement` | 230,040 transactions |
| Projects | `tPA00175`, `tPA00176`, `tPA00125`, `tPA00100`, `tPAGLTranRef` | 203,613 projects |
| Audit trail | `tciMaintAuditLog`, `tciBatchLog`, the `...Log` tables per module | 919,915 master-data changes |
| Shared | `tciAddress`, `tciContact`, `tsmCompany`, `tsmUser` (without password columns), `tsmListValidation`, `tsmLocalString`, `tciTranType` | Needed to decode everything else |

**Keep the decode tables with the data.** Status numbers and transaction types are meaningless
without `tsmListValidation`, `tsmLocalString`, `tciTranType` and `tsmModuleDef`.

**Keep the custom view definitions.** The Bailiwick views encode how the business read its own data.
Script them from production, where the source is readable, and store the script with the archive.

Retention periods are a legal and tax decision for ePlus finance; this file does not set them. Note
that data reaches back to 2003, and that the dormant companies `BEL`, `UTH` and `BMH` and the test
company `XBD` share the database.

Archive shape, in rising order of effort: keep the SQL Server database read-only on supported
infrastructure; export the tables above to an analytical store with the decode tables flattened in;
or do both, with the database kept offline as the legal copy. Whatever is chosen, prove it by
answering three questions from the archive alone: a supplier's payment history, a customer invoice
with its lines and tax, and a GL account's activity for a past period.

## 3. What can be left behind

Sage demonstration companies; `...Wrk` report work tables (tens of millions of rows of residue); the
empty `Stg...` staging tables; the dated backup tables from February 2025; the `aspnet_...` tables;
unused manufacturing and configurator tables; `tsmTraceTable_20061110_SSSI`; the `_ERP` shadow copies
of AR invoice lines once it is confirmed that nothing reads them. The full list is in
`custom-objects.md`, section 8.

## 4. Interfaces to cut or re-point

Each of these writes to or reads from Sage today. Retirement is not complete while any is running.

| Interface | Direction | Evidence it is live | Action for the finance leg |
|---|---|---|---|
| Concur expenses | In (vouchers, project expenses) and out (vendors, payments) | File log to 2026-11-12 | Re-point to Fusion Payables. Reuse `tpaXRef_rkl` as the mapping source |
| Planning feed (`vAdaptive...` views) | Out (GL balances and lines) | Views maintained to 2023 | Give the planning tool a Fusion source |
| Integration hub (`Prod_MAS500Integration`) | Both (master data stages, invoice archive) | Synonyms; shipment log to 2026-11-12 | Identify each stage's owner; move the finance ones |
| Fieldpoint field service | Both (requisitions, projects, items) | Synonyms from 2023; a recurring journal entry references it | Confirm what posts to finance and how it will reach Fusion |
| Change-data-capture replication | Out (whole database) | `attrep_truncation_safeguard`, 2024 | Find the downstream warehouse or lake; its finance reports change source |
| FRx reporting | Out | `frl_...` tables from 2005 | Confirm it is unused; replace with Fusion reporting |
| mobe3, Modula, ShipExec, UPS, ServiceNow | Both | Various | Supply-chain leg. They keep running against Sage until then |
| Exactor sales tax | Out | **None since January 2018** | Already dead. Drop the five triggers at decommission |
| Bank files | Out (ACH), in (statements) | `tapACHLog` (610 rows), `tcmBankStatement` (146) | Re-establish payment and statement formats in Fusion |
| Bank reconciliation tool | Unknown | Sage shows about 175,000 cash transactions never cleared, so reconciliation is done elsewhere | Find it; it reads Sage payments and receipts today |

There are no SQL Server linked servers in this copy, and every synonym target is missing, so
dependency checking must be repeated on the production server, where the SQL Agent jobs, linked
servers and the integration database can be seen.

## 5. Reports to replace

The inventory of what users run is the set of custom views (`custom-objects.md`, section 5), the 70
non-system Business Insights data views in `tsmDataView`, the financial statement definitions in
`tglFSReport` (50 reports with their rows and columns), and whatever SSRS or Crystal reports sit
outside the database. For each finance report decide: replaced by a Fusion standard report, rebuilt
(OTBI or BI Publisher), served from the archive, or retired. `tglFSReport`, `tglFSRow` and
`tglFSColumn` are worth extracting early, because they document the statement layout the business
expects from Fusion.

## 6. Sensitive data

The database contains material that should not travel into extracts or an archive without control:

- `tapVendAddr.BankAcctNo` and `BankRoutingTrnstNo` (1,612 BDS supplier addresses), `tapVendor.TaxPayerID`.
- `tsmUser.Password` and `DBPassword`; `tsmSiteProfile.AppRolePassword`, unlock and registration keys.
- `tcnConfig_rkl.RunAsUser` and `RunAsPwd` (the Concur interface's run-as credential).
- `tcmCashAcct` bank account and ACH origin identifiers.
- Customer and supplier contact details in `tciContact` and `tciAddress`.

For an archive, mask or drop the credential columns, restrict the banking and tax columns, and rotate
any credential that has been copied out of production, including the application role password, which
is present in this copy.

## 7. Access and operations

- 115 Sage users exist in `tsmUser`. Review them against current staff before granting archive access.
- This copy's login is read-only and cannot see module source. An archive reader needs no more.
- Once read-only, disable SQL Agent jobs that post, import or purge, and keep the purge settings in
  `tglOptions` and its sibling option tables from deleting history.

## 8. Readiness checklist

1. Final Sage period closed; trial balance sums to zero; AP and AR tie to the ledger.
2. No pending documents: `tapPendVoucher`, `tarPendInvoice`, `tapPendVendPmt`, `tarPendCustPmt` empty,
   and no batch at status In Use, Out of Balance or Interrupted that anyone intends to post.
3. Conversion loads reconciled and signed (see `fusion-conversion.md`, section 6).
4. Bridge for operational postings running and reconciled for at least one period.
5. Every interface in section 4 stopped, re-pointed or explicitly accepted as still running.
6. Every finance report in section 5 has a disposition.
7. Custom definitions scripted from production and stored.
8. Archive built, the three test questions answered from it, credentials masked.
9. Users moved to read-only, then removed.
10. Retention owner and destruction date recorded.
