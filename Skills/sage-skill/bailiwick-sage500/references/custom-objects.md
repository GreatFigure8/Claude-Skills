# Custom and third-party objects in MAS500_app

Twenty years of add-ons, reseller work and in-house reporting sit on top of standard Sage 500. This
file is the review of that layer: what exists, who appears to have built it, whether it is alive, and
what each piece means for the Fusion finance conversion and for retirement.

## Contents

1. How the review was done, and its limits
2. Origin tags
3. Finance-relevant customisations
4. Integrations and the systems behind them
5. In-house reporting views
6. Extension tables and user fields
7. Screen customisations
8. Backups, one-offs and debris
9. Counts at a glance
10. Re-running the review

## 1. Method and limits

Objects were classified from the SQL Server catalog by three signals: a suffix or prefix that marks an
author, a creation date outside Sage's install and upgrade waves (see `data-model.md`), and row counts
with last-activity dates.

**The login cannot read module source.** `sys.sql_modules.definition` is NULL for all 1,482 views,
3,420 triggers, 209 procedures and 59 functions, and `sys.sql_expression_dependencies` is empty. Every
statement below about what an object *does* rests on its name, its columns and its data. Before a
custom view is rebuilt or a trigger's side effect is ruled out, ask the Bailiwick DBA for a script of
the definitions, or for `VIEW DEFINITION` on the database.

Only 178 stored procedures are visible, far fewer than a Sage 500 install carries, so the procedure
list is incomplete in this copy.

Vendor names against tags are the reviewer's reading. Those marked *unconfirmed* should be checked
with Bailiwick IT.

## 2. Origin tags

| Tag | Appears to be | Period | State |
|---|---|---|---|
| `_BW`, `BW_`, `Bwick`, `bwick`, `_BWICK` | Bailiwick in-house | 2005 to 2025 | Live. About 110 views, four tables, one function |
| `_RKL`, `_rkl` | RKL eSolutions, the Sage reseller | 2017 to 2025 | Live. Concur, Modula, auto-ship, integration log |
| `_XPNS_rkl` | Concur expense interface, built by RKL | 2020 onward | Live. Log entries to 2026-11-12 |
| `_SSSI`, `_sssi`, `_SSS` | An earlier reseller or consultant (*unconfirmed*) | 2005 to 2008 | Dormant. Project history and diagnostics |
| `_MAG`, `tmag_`, `Mag...` | An early project-accounting integrator (*unconfirmed*) | 2005 to 2008 | Structure still referenced; link tables hold data |
| `_ERP` | A middleware or reseller layer (*unconfirmed*) | 2008 to 2014 | Mixed. Large shadow copies of AR invoice tables |
| `_DSC`, `twl`, `spwl` | Radio-frequency warehouse add-on (*vendor unconfirmed*) | 2006 | Superseded by later warehouse systems |
| `_HAI`, `tmf...`, `tpc...` | Manufacturing and configurator tables as shipped | 2005 onward | Seed-level data only. Not in use |
| `to2...`, `_O2`, `vo2...`, `t2g...`, `tev...`, `toa...` | Operations and warehouse add-on, modules `O2` and `OA` (*vendor unconfirmed*) | 2015 to 2019 | Partly live. `timInvtTranDist_O2` has 15.7 million rows |
| `tum...`, `vum...`, `mas_site`, `obj_ver` | mobe3 warehouse management | 2019 to 2025 | Live, hosted outside this database |
| `exactor_...`, `_Exactor` | Exactor sales-tax service | 2014 to 2018 | **Dead.** Last transaction 2018-01-04. Triggers still attached |
| `_VBS` | A document or comment add-on (*unconfirmed*) | 2012 | Seven views |
| `frl_...` | FRx financial reporting | 2005 | Legacy report writer tables |
| `aspnet_...`, `tbp...` | Sage web and portal plumbing | 2008 to 2013 | Empty |
| `attrep_truncation_safeguard` | A change-data-capture replication tool | 2024 | Evidence that the production database is replicated somewhere |

## 3. Finance-relevant customisations

These touch the ledger, payables or receivables, and each needs a decision in the first leg.

**Concur expense import (`_XPNS_rkl`, `tpaConcur...`, `tcnConfig_rkl`).** Files from Concur are loaded
as AP vouchers and project expenses. `tpaConcurLog_rkl` records 1,884 file downloads, the latest on
2026-11-12, with interface type `AP`. `tcnConfig_rkl` holds the file paths, the vendor class and offset
account used, a `SummarizeTrans` switch and a run-as credential (do not select `RunAsPwd`).
`tpaXRef_rkl` and `tpaColumnMap_rkl` hold the Concur-to-Sage cross-references. `idsVend_XPNS_RKL`
(258,383 rows) and `idsPmt_XPNS_RKL` (383,364) are change queues that feed vendors and payments back
to Concur. **Fusion impact:** this is a two-way interface that must be re-pointed at Fusion Payables,
and its cross-reference tables are a ready-made mapping source.

**Adaptive planning feed (`vAdaptiveGLAcctHist`, `vAdaptive500GLTrxn`).** Created in October 2019 and
edited in 2023. They expose period balances and journal lines with account category, group and type,
and four segment columns. They run in this copy. **Fusion impact:** a planning tool reads the ledger
through these; the feed needs a Fusion source before cut-over.

**GL transaction views (`VDVGLAccountTran_BW`, `vdvglAccountTran`, `vdvglAccountTran_RKL`).** Journal
lines with batch, journal, reference code, source document and, in the RKL version, the PO, receiver
and voucher keys behind each line. They are the model for a GL detail extract, and they are evidence
of what the finance team reports on today.

**Sales tax (`exactor_...`, `tarPendInvoice_Exactor`, `tciBatchLog_exactor`, `tciBatchTran_exactor`).**
Triggers `insertExactorTrigger`, `new_updateExactorTrigger` and `deleteExactorTrigger` on
`tarPendInvoice`, with `updateExactor_tciBatchLog` and `updateExactor_tciBatchTran`, are enabled, yet
the last Exactor transaction is dated January 2018. **Fusion impact:** none for conversion; confirm
how sales tax is calculated today, because this route is not it.

**AR invoice shadow tables (`tarInvoiceDetl_ERP`, `tarInvoiceLineDist_ERP`, `tarPendInvoice_ERP`).**
4.3 million, 4.3 million and 827,448 rows, with the same columns as the standard tables. They look
like a copy taken for an interface or an archive. **Do not extract from them.** The standard
`tarInvoiceDetl` (12.2 million rows) is the complete set.

**Custom triggers on supplier and payment tables.** `tR_tapVendor_idsVend_XPNS_rkl`,
`tR_tapVendAddr_idsVend_XPNS_rkl` and `tR_tciAddress_idsVend_XPNS_rkl` queue every supplier or
address change, and `tR_tapVendPmt_idsPmt_rkl` every payment, for the Concur feed. `BW_TransactionOverride`
(2019) sits on the shared `tciAddress` table. All are enabled. They do not change what is stored in
the finance tables as far as the catalog shows, but their source is unreadable here, so confirm it.

**Change auditing (standard Sage, switched on).** Triggers named `..._AppAudit` on `tapVendor`,
`tapVendAddr`, `tarCustomer`, `tarCustAddr`, `tarSalesperson`, `tciAddress`, `tglAccount`, `timItem`,
`timInventory` and `timItemDescription` were created by the 2019 upgrade and are Sage's own audit
feature, not custom work. `tciMaintAuditLog` holds 919,915 rows, the latest dated 2026-11-12. That log
is the audit trail for master-data changes and belongs in the archive.

**Fiscal calendar change.** `tsmAddonTask` chains `spapChangeFiscalCalendar`,
`sparChangeFiscalCalendar`, `spcmChangeFiscalCalendar` and `spimChangeFiscalCalendar` onto a GL task.
This is the machinery behind the 2024 year-end change, and it explains the two eight-period years.

**Supplier and customer extensions.** `tapVendorCustomData_SSS` and `tarCustomerCustomData_SSS` each
hold one row. Nothing to convert.

**Project accounting additions.** `tpaLogProjStatChange_sssi` (171,928 rows) logs project status
changes, `tpaProjHistory_sssi` (24,411) holds project history, and `tpaSOShipmentLink_MAG` (787,119)
with `tmag_tPASOLink` (793,996) link shipments to project lines. `tPA00125_ERPNotes` (275,049) holds
project line notes. Views `vdvPA...Postings_MAG` expose project postings by source. In scope only if
projects are.

## 4. Integrations and the systems behind them

The 101 synonyms are a map of everything Sage talks to. **None resolve in this copy** (error 5313),
because their target databases were not restored, so any view that reads one fails here.

| System | Evidence | Finance relevance |
|---|---|---|
| Concur (expenses) | `_XPNS_rkl` tables, `tpaConcur...`, `tcnConfig_rkl` | Direct: creates AP vouchers |
| Planning tool fed by `vAdaptive...` | Two views | Direct: reads GL |
| `Prod_MAS500Integration` staging database | 16 synonyms `syn_MAS500Integration_...`: payment terms, vendor category, company category, item, requisition and shipment stages, an invoice stage archive | Direct: an integration hub stages master data and invoices here |
| Fieldpoint (field service) on `BW-C2-AGL`, database `Prod_FieldpointApp` | Nine synonyms: `Incident`, `Requisition`, `Project`, `ProjectTask`, `ItemMaster` | Indirect: requisitions and projects originate there. A November 2026 journal comment mentions a recurring Fieldpoint entry |
| mobe3 warehouse management | 55 synonyms to `prod_mobe3site`, 20 to database `bail715` on an Azure SQL Managed Instance, `tum...` tables | Inventory leg |
| Modula (automated storage) | `spsoModulaExport_RKL`, `spsoModulaImport_RKL`, `BW_ModulaExportProcessingErrors`, `v_ModulaGeneratedShipments` | Inventory leg |
| ShipExec and UPS WorldShip | `syn_MAS500Integration_ShipExec_...`, `vdvShipExec_Shipments`, `twlPackageUPSWorldShipIn`, `vUPSintegration` | Shipping; freight reaches AR invoices |
| ServiceNow | `ServiceNOWInventoryTranStaging` (12,069 rows, 2020 to 2021) | Inventory leg |
| `Prod_LCIDb` | `syn_LCIDB_tblTrackingInfo` | Shipment tracking |
| Integration log | `tciIntegrationLog_RKL`, 591,515 rows, all shipment type 810, latest 2026-11-12 | Shows the shipment interface is live |

## 5. In-house reporting views

About 110 views carry a Bailiwick tag. They are the working definition of "the reports people use",
and each one that finance relies on needs a Fusion replacement or a deliberate retirement. The
finance-facing ones:

| View | Subject |
|---|---|
| `Bwick_Voucher_Check_GL_AP` | Voucher, the payment that settled it and the GL account |
| `Bwick_Voucher_PO_AP`, `Bwick_Voucher_to_PO`, `VDV_bwick_VoucherPO`, `Vdv_BwickGLPOVoucher` | Voucher to purchase order to GL |
| `Vdv_Bwick_VendPymntHist`, `VDV_BwickVendorPmnt` | Supplier payment history with 1099 fields |
| `vdvVoucherLine_BW`, `VvoucherDSfreight_Bwick` | Voucher lines; drop-ship freight vouchers |
| `Vdv_BwickOpenInvoice` | Open AR by project, master project, senior manager and national account |
| `vdvInvoiceLine_BW`, `Bw_DistributionInvoice`, `vdvARInvoiceLineTaxInfo_BW`, `bwick_stax line detail` | AR invoice lines and their tax detail |
| `VDVGLAccountTran_BW` | GL transactions |
| `SSRS_ProjectProfit`, `VDV_bwickprojectprfit`, `VDV_BwickProjectProfitPM`, `VDV_BwickPrjInv`, `bwick_Prj` | Project profitability and project invoicing |
| `BwickTime`, `bwicktime2`, `VDV_BwickTime2`, `VDV_BwickTime3`, `TimeSheetData_sssi` | Timesheets |
| `BDC_MAS500_PrjToPO`, `BDC_VLU_MAS500_ProjectInfo` | Project data published to another application (the `BDC` prefix suggests SharePoint) |

The rest concern inventory, picking, serial numbers, bins and shipping (`InventoryStatusView_BW`,
`vdvSerialTransactions_BW`, `Bwick_PickStatus`, `vumDVShipPerf_BW`, the `vUSB...Parts` family that
appears to serve one customer programme, and similar). They belong to the supply-chain leg.

Views suffixed `_original`, `_backup`, `_OLD`, `_SCHEMA`, `_EDITS` or a date
(`vsoAutoShipQualifier_RKL_6.10.2025`) are saved copies of earlier versions. Ignore them, and note
that the live `vsoAutoShipQualifier_RKL` was last changed in August 2025: custom logic is still
being maintained.

## 6. Extension tables and user fields

**Extension tables keyed to a standard table.**

| Table | Rows | Holds |
|---|---|---|
| `tsoSalesOrder_BDS` | 140,706 | Per sales order: requisition number, project number, event number, project manager, ship dates, notes |
| `timItem_BDS` | 32,085 | Per item: manufacturer, country of origin, HTS code, UN code, customer item |
| `tsoShipLineLog_RKL`, `tsoShipmentLog_RKL` | 374,600 / 109,799 | Shipment interface logs |
| `BW_BusinessDays` | 18,262 | Business-day calendar |
| `BW_PrintPalletAudit` | 53,421 | Pallet label audit |

**User-defined fields in use for BDS** (`tciUserField`; the value sits in `UserFldN` on the host table).

| Host table | Fields |
|---|---|
| `tapVendor` | 1 Business Types, 2 YR Purch Rec |
| `timItem` | 1 Pack Size, 2 Case Cube, 3 Est Value, 4 Equipment type, 5 Mobe3 Tracking, 6 Tracking Method |
| `tsoSalesOrder` | 1 ProjID, 2 Bwick Install, 3 Email Add |
| `tsoSOLine` | 1 Phase, 2 Task |
| `tsoRMA` | 1 Master Project |
| `tpoPurchOrder` | 1 Requisition, 2 Model, 3 Description/Use, 4 Serialized |
| `tpoPOLine` | 1 Project |
| `tPA00007` (resource) | 1 Goal, 2 Sr Manager, 3 days in wrk yr |
| `tPA00175` (project) | 1 Copies to Make?, 2 Base Template, 3 PrjNo |
| `tPA00176` (master project) | 1 Program Lead, 2 Status, 4 Number of Sites, 5 to 7 margin targets |

For finance, the supplier field **Business Types** holds a tax classification (`LLC Corp`,
`LLC Partnership`, `Inv.Sole Prop` and similar) on just 35 suppliers; it feeds the Fusion supplier
tax organisation type for those rows. The project and requisition references on orders are needed
wherever open documents must stay traceable. `tglAccount` and `tarCustomer` user fields are unused.

## 7. Screen customisations

Sage Customizer is licensed (module `CZ`) and used: 17 customised forms in `tsmCustomForm`, 462
changed controls, and 79 scripts in `tsmCustomScript`. The heavy ones are Maintain Item (two versions,
about 180 controls each) and Maintain Inventory (59). Finance screens are touched lightly: Invoice
Entry (8 controls), AR batch (5 and 2), Customer Maintenance (3), Vendor Maintenance (1), Company (3).
Business Insights Explorer holds 281 data views, 70 of them non-system. Read the script text in
`tsmCustomScript.Text` before assuming a finance screen behaves as standard.

## 8. Backups, one-offs and debris

Safe to exclude from conversion and to list for deletion at retirement:

- February 2025 inventory clean-up: `BW_BackupInv`, `timCostTier_Backup20250221`,
  `timCostTier_Backup20250221Open`, `ItemsAdjIntoStockSum_022125_rkl`,
  `ItemsRemovedFromStockDetail_022125_rkl`, `ItemsStockOutSum_022125_rkl`, `timitemRename_rkl`,
  `tpopoline_rkl_0221_bak`, `tsosoline_rkl_0221_bak`, `timItem_Mobe3Upgrade`, `timitem_TrackMethBDS`,
  `BK_ItemDescription`, `_BatchesToReset_RKL`.
- Old one-offs: `SHT003A_Cleanup`, `CREXPORT`, `fraglist`, `TrackBlocks`, `TrackBlocksDetl_new`,
  `MarchTime_sssi`, `test_sssi`, `Percent_sssi`, `cutoffdate_sssi`, `ProjCloseList`,
  `tsmTraceTable_20061110_SSSI`, `VIEW1`, `USB test view`, `vsp`, `ZZZtimItemConfig_O2`.
- Empty by design: the `Stg...` migration tables, `aspnet_...`, most `to2...` and `t2g...` tables,
  the `tmf..._HAI` and `tpc..._HAI` manufacturing set.

## 9. Counts at a glance

| Object type | Total | Notes |
|---|---|---|
| Tables | 3,095 | 1,154 hold data. About 230 carry a custom or third-party tag |
| Views | 1,482 | 110 Bailiwick, about 100 more created outside Sage's install waves, the rest Sage or add-on |
| Triggers | 3,420 | Nearly all Sage referential integrity and audit (`_DBAudit`, `_AppAudit`). About 40 custom: five Exactor, nine `...Alert`, four Concur queue triggers, `BW_TransactionOverride`, `tr_tsoPendShipment_update`, `tr_ServicenowInventoryTransaction`, `tr_PrintPalletKeyAudit`, three `..._mobe3` from February 2025, and a disabled `ModulaInsertEmail` |
| Procedures | 178 visible | Mostly the 2006 warehouse add-on. Custom: `spsoModulaExport_RKL`, `spsoModulaImport_RKL`, `spsoCallAutoCommitShip_RKL`, `spSObwick_BOLines`, `SerializedParts`, `spPAWIPReportPIT_sssi`, `spDF_ZeroOutDistPendQtys_v730` |
| Functions | 59 | Custom: `fn_BW_SplitParam`, `fn_Split_rkl` |
| Synonyms | 101 | All external, all unresolved in this copy |

## 10. Re-running the review

The catalog queries are in `queries.sql`, section 9. Compare their output with this file whenever a
fresh copy of the database arrives: a new tagged object, or a changed `modify_date` on a custom view,
means the customisation layer moved and this inventory needs the same edit.
