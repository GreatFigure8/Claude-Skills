# AX enum values present in SRSANALYSISENUMS (read live 2026-09-01, LANGUAGEID='en-us')

Only 139 enums exist in that table. Anything not listed here: profile the column's distinct values and confirm against Microsoft AX 2012 documentation; cite the source.

| Enum | Used by | Values |
|---|---|---|
| LedgerTransType | VENDTRANS.TRANSTYPE, CUSTTRANS.TRANSTYPE, BANKACCOUNTTRANS.LEDGERTRANSTYPE | 0 None · 1 Transfer · 2 Sales · 3 Purch · 4 Invent · 5 Production · 6 Project · 7 Interest · 8 Cust · 9 ExchAdjustment · 10 SummedUp · 11 Payroll · 12 FixedAssets · 13 CollectionLetter · 14 Vend · 15 Payment · 16 Tax · 17 Bank · 18 Conversion · 19 BillOfExchange · 20 PromissoryNote · 21 Cost · 22 Work · 23 Fee · 24 Settlement · 25 Allocation · 26 Elimination · 27 CashDiscount · 28 OverUnder · 29 PennyDifference · 30 CrossCompanySettlement · 31 PurchReq · 33 PurchAdvanceApplication · 34 ConversionReporting · 100 PdsRebateCreditNote · 101 PdsRebatePassToAP (36 appears in data, unlabelled) |
| LedgerPostingType | GENERALJOURNALACCOUNTENTRY.POSTINGTYPE | 0 None · 1 ExchRateGain · 2 ExchRateLoss · 3 InterCompany · 4 Tax · 5 VATRoundOff · 6 Allocation · 7 InvestmentDuty · 8 Liquidity · 9 MSTDiffSecond · 10 ErrorAccount · 11 MSTDiff … (full list: query the table; 14 and 41 are the common AP/purchase postings — decode live) |
| LedgerJournalACType | LEDGERJOURNALTRANS.ACCOUNTTYPE / OFFSETACCOUNTTYPE | 0 Ledger · 1 Cust · 2 Vend · 3 Project · 5 FixedAssets · 6 Bank |
| CustVendorBlocked | VENDTABLE.BLOCKED, CUSTTABLE.BLOCKED | 0 No · 1 Invoice · 2 All · 3 Payment · 4 Requisition · 5 Never |
| DimensionLedgerAccountType | MAINACCOUNT.TYPE | 0 ProfitAndLoss · 1 Revenue · 2 Expense · 3 BalanceSheet · 4 Asset · 5 Liability · 6 Equity · 8 Total · 9 Reporting · 10 Blank |
| PurchaseType | PURCHTABLE.PURCHASETYPE, VENDINVOICEJOUR.PURCHASETYPE | 0 Journal · 3 Purch · 4 ReturnItem (1,2,5 deleted) |
| PurchInvoiceType | VENDINVOICEJOUR.INVOICETYPE | 0 Standard · 1 VendorAdvance |
| CustVendPaymStatus | LEDGERJOURNALTRANS.PAYMENTSTATUS | 0 None · 2 Sent · 3 Confirmed · 4 Rejected · 5 Recieved · 6 Delete · 7 SentDelete · 8 Deleted |
| ItemType | INVENTTABLE.ITEMTYPE | 0 Item · 2 Service |
| CurrentOperationsTax | GENERALJOURNALENTRY.POSTINGLAYER | 0 Current · 1 Operations · 2 Tax |
| ModuleInventCustVend | various MODULE columns | 0 Invent · 1 Cust · 2 Vend |

## Not in SRSANALYSISENUMS (confirm from data + docs before use)
OMOperatingUnitType (theatres are 4 in the data), AssetTransType, AssetStatus, PurchStatus, DocumentStatus, VendInvoiceSaveStatus/REQUESTSTATUS, PurchReqRequisitionStatus, LogisticsElectronicAddressMethodType (1 Phone 2 Email 3 URL 4 Telex 5 Fax — verified against contact rows), NoYes (0/1).

## Table ids seen in DIRPARTYTABLE.INSTANCERELATIONTYPE (model store)
41 CompanyInfo · 2303 DirPartyTable · 2377 OMOperatingUnit · 2975 DirPerson · 2978 DirOrganization · 5329 OMTeam
