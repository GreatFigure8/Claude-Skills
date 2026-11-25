---
name: bailiwick-sage500
description: Query, explain and plan the retirement of Bailiwick's Sage 500 ERP database (MAS500_app, the "Bailiwick-SAGE-Database" source on the ePlus legacy SQL Server) for the Oracle Fusion ERP finance conversion. Covers the Sage 500 data model (tgl/tap/tar/tcm/tci/tPA tables), surrogate-key joins, status decodes, the full inventory of custom and third-party objects (_BW, Bwick, _RKL, _SSSI, _MAG, _DSC, _O2, mobe3, Exactor, Concur, Modula), validated T-SQL for GL, AP, AR, cash and projects, Fusion FBDI target mapping, reconciliation and decommissioning. Use whenever Bailiwick, Sage, Sage 500, MAS 500, MAS500_app, company BDS, or tables such as tglTransaction, tapVoucher, tarInvoice or tPA00175 come up, and for any question about converting or retiring Bailiwick's ERP, even if Sage is not named.
---

# Bailiwick Sage 500 (MAS500_app)

Bailiwick Services runs its business on Sage 500 ERP, formerly MAS 500. A copy of that database now
sits beside the ePlus legacy databases, and the first leg of the move to Oracle Fusion is finance.
This skill lets you answer questions against that copy correctly on the first attempt, tell standard
Sage from the customisation layered on it over twenty years, and turn what you find into conversion
and retirement decisions.

## Connect

| | |
|---|---|
| MCP source | `Bailiwick-SAGE-Database` on the `aix-greenlight` server (`run_query`, `describe_table`, `start_extract`) |
| Database | `MAS500_app`, SQL Server 2022, **compatibility level 100**, schema `dbo`, about 128 GB |
| Access | Read-only. Object names are visible; view, procedure and trigger **source code is not** |
| Snapshot | Data runs through 2026-11-13. It is a restored copy, so it does not move |

With any other SQL client the same T-SQL applies; only the connection differs.

## Five rules that prevent wrong answers

1. **Filter to company `BDS`.** One database holds twelve companies. `BDS` (Bailiwick Services, LLC)
   is the operating company. `BEL`, `BMH` and `UTH` have no activity after 2018, `XBD` is a test company,
   and `CAD`, `COA`, `CON`, `DKS`, `SGE`, `SLS`, `SOA` are Sage demo data. An unfiltered count is wrong.
2. **Join on surrogate keys, show natural IDs.** Every entity has an integer `...Key` and a
   human `...ID` or `...No`. Join `VendKey`, `CustKey`, `GLAcctKey`; display `VendID`, `CustID`,
   `GLAcctNo`. Detail tables often carry no `CompanyID`, so reach it through the header or the account.
3. **Never guess a status code.** Decode it from `tsmListValidation` joined to `tsmLocalString`
   (query 1 in `references/queries.sql`). `Status = 1` is Open for a voucher and Active for a vendor.
4. **GL balances are cumulative.** `tglAcctHist.BegBal` is filled only in period 1. A balance is the
   period-1 `BegBal` plus the sum of `DebitAmt - CreditAmt` through the period you want. In
   `tglTransaction`, a positive `PostAmtHC` is a debit.
5. **Write for compatibility level 100.** `STRING_AGG ... WITHIN GROUP`, `STRING_SPLIT` and
   `TRY_CONVERT` fail here (tested). Use `STUFF(... FOR XML PATH(''))` to aggregate strings and `CASE`
   with `ISNUMERIC` or `ISDATE` to guard conversions. `IIF`, `FORMAT`, `CONCAT`, `EOMONTH`,
   `OFFSET/FETCH` and window functions work. `char` columns are space padded, so `RTRIM` what you display.

## Fiscal calendar

The year was reshaped when ePlus acquired the business, and any period-based work must respect it.

| Fiscal year | Dates | Periods |
|---|---|---|
| 2005 to 2023 | calendar year | 12 |
| 2024 | 2024-01-01 to 2024-08-18 | 8, the last one short |
| 2025 | 2024-08-19 to 2025-03-31 | 8, the first one short |
| 2026 onward | 1 April to 31 March | 12 |

`FiscYear` is a `char` column. Fiscal 2027 period 8 (November 2026) is the open period in the snapshot.
Always take dates from `tglFiscalPeriod`; never derive a period from a calendar month.

## Where things live

| Prefix | Module | Start with |
|---|---|---|
| `tgl` | General Ledger | `tglAccount`, `tglTransaction`, `tglAcctHist`, `tglFiscalPeriod` |
| `tap` | Accounts Payable | `tapVendor`, `tapVoucher`, `tapVendPmt`, `tapVendPmtAppl` |
| `tar` | Accounts Receivable | `tarCustomer`, `tarInvoice`, `tarCustPmt`, `tarCustPmtAppl` |
| `tcm` | Cash Management | `tcmCashAcct`, `tcmCashTran`, `tcmBank` |
| `tci` | Common Information | `tciAddress`, `tciContact`, `tciPaymentTerms`, `tciBatchLog`, `tciTranType` |
| `tPA`, `pa` | Project Accounting | `tPA00175` (project), `tPA00176` (master project), `tPA00125` (line) |
| `tpo`, `tso`, `tim` | Purchasing, Sales, Inventory | later legs of the programme |
| `tsm` | System Manager | `tsmCompany`, `tsmListValidation`, `tsmLocalString`, `tsmUser` |

## Read the reference that fits the task

| Task | Read |
|---|---|
| Write or explain a query; table, key and status detail | `references/data-model.md` |
| Start from SQL that has already been run against this database | `references/queries.sql` |
| Decide whether an object is standard, custom, third party or dead | `references/custom-objects.md` |
| Scope, extract, map or reconcile a conversion to Oracle Fusion | `references/fusion-conversion.md` |
| Plan archival, interface cut-over and switching Sage off | `references/retirement.md` |

## How to work

- **Verify before you assert.** Describe the table, run the query with `TOP`, then widen it. The
  references record what was true in the November 2026 snapshot; re-run anything a decision rests on.
- **Reconcile every extract.** A conversion extract is finished when its total ties to the general
  ledger control account, and not before. The method and the known variance are in
  `references/fusion-conversion.md`.
- **Use `start_extract` for whole tables.** `tglTransaction` has 29.9 million rows. Filter by
  `FiscYear` and company before anything else.
- **Say what you cannot see.** Module source is hidden from this login. Describe a custom view by its
  columns and say that its logic needs a definition export from the Bailiwick DBA.
- **Leave secrets alone.** Do not select `tsmUser.Password`, `tsmUser.DBPassword`,
  `tsmSiteProfile.AppRolePassword` or its key columns, `tcnConfig_rkl.RunAsPwd`,
  `tapVendAddr.BankAcctNo`, `tapVendAddr.BankRoutingTrnstNo` or `tapVendor.TaxPayerID` unless the task
  is the supplier bank or tax conversion itself, and then write them to the extract, never to chat.
- **Distrust cross-database synonyms.** All 101 point at databases that were not restored with this
  copy, and they raise error 5313. Views built on them fail too.
