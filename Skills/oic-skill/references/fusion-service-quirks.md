# Oracle Fusion Service Quirks

Service-by-service quirks discovered when integrating with Oracle Fusion's REST and SOAP APIs from OIC.

## REST base path

All Fusion REST services live under `/fscmRestApi/resources/11.13.18.05/` or, equivalently, `/fscmRestApi/resources/latest/`. The version-pinned form is more stable but requires updating when Fusion releases roll forward.

## REST authentication

OIC connects to Fusion REST using HTTP Basic Auth. Use the OIC Connections UI to configure the connection; do not hand-roll the auth header in JavaScript or REST adapter overrides.

## Query parameter conventions

Fusion REST GET endpoints support these standard query parameters:

| Parameter | Usage |
|-----------|-------|
| `q` | Filter clause. **Syntax depends on REST-Framework-Version (see below).** Under v4 (this tenant): SQL-style operators `=`, `IN (...)`, `BETWEEN 'x' AND 'y'`, joined with ` AND `. Under v1/v2: `Field='value';Field>=value` (semicolon-separated, implicit AND). |
| `fields` | Comma-separated field names to return. Reduces payload size. |
| `expand` | Comma-separated child resource names to include. |
| `orderBy` | Field name + `:asc` or `:desc` (e.g. `ReceiptDate:asc`). |
| `onlyData` | `true` to suppress HATEOAS link decorations. |
| `limit`, `offset` | Pagination. |

**Critical:** field names in `q`, `fields`, and `orderBy` must EXACTLY match the response field casing. Use a captured response to confirm.

## REST-Framework-Version and q-clause syntax (verified 2026-05)

**The `fa-ewpl-test-saasfaprod1` tenant uses REST-Framework-Version 4.** This changes the q-clause grammar in a way that matters and is easy to get wrong.

**Under v4, use SQL-style operators joined with ` AND ` (spaces required):**

```
q=CustomerAccountNumber in ('1410875') AND ReceiptDate BETWEEN '2026-02-17' AND '2026-02-21'
```

- `IN (...)` for set membership — multiple anchor customers in one call: `CustomerAccountNumber in ('1410875','3218124')`.
- `BETWEEN 'x' AND 'y'` for inclusive ranges (dates, amounts).
- ` AND ` (with surrounding spaces) joins predicates. **Not** the older `;` separator.
- String literals are single-quoted, including numeric-looking account numbers.

**The older `;`-separated `>=/<=` form (v1/v2) is NOT what this tenant expects.** It will not parse correctly under v4. Set the header `REST-Framework-Version: 4` on the connection (or per-invoke), and emit the SQL form. If you see HTTP 400 parse errors on a q-clause that looks fine, the framework version is the first thing to check.

**Generation gotcha — the space before `AND`:** when building the clause by string concatenation, the join token must be `' AND '` with a leading space. Concatenating `')' + 'AND ...'` yields `)AND ...` which is malformed. This bit the cash app once (lib v32→v33 fix).

## `/standardReceipts` quirks

**Status is NOT queryable.** A `q` clause containing `Status='REM'` (or any other status filter) returns a 500 error from the service. The Status field appears in the response but cannot be filtered server-side.

**You usually don't need to filter on Status at all.** For cash application, the receipt match requires `UnappliedAmount == payment_amount`. A fully-applied receipt has `UnappliedAmount = 0`, which can never equal a positive payment amount — so it's excluded by the amount match without any status predicate. Don't add client-side Status filtering unless a specific case demands it (the cash app v32 lib does none).

**Date window filtering works (v4 SQL form):**
```
q=CustomerAccountNumber in ('1410875') AND ReceiptDate BETWEEN '2026-02-17' AND '2026-02-21'
```

**`expand=remittanceReferences` populates the child collection.** Without expand, the child collection is returned empty (`"remittanceReferences": []`). With expand, it's populated with one entry per application against the receipt.

**ConversionRate has wild decimal precision.** Don't store or compare these as floats — use string comparison if you need to verify rate identity, or `_moneyEq`-style tolerance arithmetic.

**Known field list** (verified against `fa-ewpl-test-saasfaprod1` test tenant):

```
StandardReceiptId, ReceiptNumber, BusinessUnit, ReceiptMethod, ReceiptDate,
DocumentNumber, Amount, Currency, ConversionRateType, ConversionDate,
ConversionRate, State, Status, RemittanceBankName, RemittanceBankBranch,
RemittanceBankAccountNumber, RemittanceBankDepositDate,
RemittanceBankAllowOverride, CustomerName, TaxpayerIdentificationNumber,
CustomerSite, CustomerAccountNumber, CustomerBank, CustomerBankBranch,
CustomerBankAccountNumber, UnappliedAmount, AccountedAmount,
AccountingDate, MaturityDate, PostmarkDate, ReceiptAtRisk,
ReceivablesSpecialist, Comments, CreditCardTokenNumber,
CreditCardAuthorizationRequestIdentifier, CardHolderFirstName,
CardHolderLastName, CreditCardIssuerCode, CreditCardExpirationDate,
VoiceAuthorizationCode, ReversalCategory, ReversalReason, ReversalDate,
ReversalComments, ReceiptBatchName, ReceiptBatchDate,
StructuredPaymentReference, CreatedBy, CreationDate, LastUpdateDate,
LastUpdatedBy, remittanceReferences (child)
```

**Useful field subset for cash application:**
```
ReceiptNumber, StandardReceiptId, ReceiptDate, Amount, UnappliedAmount,
CustomerAccountNumber, Currency, ConversionRate, Status
```

**Field-name caution — `Currency`, not `CurrencyCode`.** The receipt resource returns the currency element as `Currency`. The cash app's `_parseReceiptsItems` reads exactly: `ReceiptNumber`, `StandardReceiptId`, `Amount`, `UnappliedAmount`, `Currency`, `CustomerAccountNumber`, `ReceiptDate`, `Status`, `ConversionRate`. If you wire a REST response Sample JSON with `CurrencyCode`, the JS currency match silently fails (the field comes through empty). The invoice resource is the one that uses `BusinessUnit`; receipts do not feed BU into the cash app match.

## `/receivablesInvoices` quirks

Used to look up invoices by `TransactionNumber` to validate the allocation's invoice. Returns:
- `BillToCustomerNumber` — the customer who owes
- `InvoiceBalanceAmount` — the remaining balance (0 means fully paid)
- `BusinessUnit` — the BU the invoice is in
- Other transaction-level fields

The lookup pattern (v4 q form): `GET /receivablesInvoices?q=TransactionNumber in ('123423','120533721')&fields=CustomerTransactionId,TransactionNumber,InvoiceBalanceAmount,BillToCustomerNumber,BusinessUnit,InvoiceCurrencyCode,InvoiceStatus&onlyData=true`. The `IN (...)` form fetches every invoice in the request in one call. An empty `items` array means none of the transaction numbers exist.

**The invoice row feeds response enrichment.** In the payload-in-JS cash app, each allocation's matched invoice row carries `BusinessUnit` and `BillToCustomerNumber`; the JS copies these onto the response allocation as `businessUnit` and `invoiceCustomer`. They are populated whenever the invoice was found (even for a zero-balance / `no-remaining-balance` verdict), and empty only when the invoice wasn't found. This enrichment happens in JS, not via a separate OIC mapping — see `references/payload-in-js-orchestration.md`.

## StandardReceiptService SOAP — `createApplyReceipt`

The SOAP service for applying a receipt to an invoice. WSDL location follows Fusion conventions: `https://<tenant>/fscmService/StandardReceiptService?WSDL`.

**Request shape (no processControl, no BusinessUnit):**

```xml
<typ:createApplyReceipt>
  <typ:applyReceipt>
    <ar:ReceiptNumber>1002</ar:ReceiptNumber>
    <ar:TrxNumber>123423</ar:TrxNumber>
    <ar:AmountApplied>100.00</ar:AmountApplied>
    <ar:ApplyDate>2025-05-22</ar:ApplyDate>
    <ar:ApplicationGlDate>2026-05-20</ar:ApplicationGlDate>
  </typ:applyReceipt>
</typ:createApplyReceipt>
```

**The five fields are all required.** Other fields exist in the WSDL but are optional. `ApplicationGlDate` should be the current date (`fn:current-date()`), not the payment date — accounting periods don't accept arbitrary backdating.

**Do NOT include:**
- `processControl/returnMode` — FBDI batch-service control, rejected here.
- `processControl/exceptionReturnMode` — same.
- `processControl/partialFailureAllowed` — same.
- `BusinessUnit` — the receipt's BU is implicit from `ReceiptNumber`.

**Response shape — fault info INSIDE the success envelope:**

```xml
<env:Envelope>
  <env:Body>
    <ns0:createApplyReceiptResponse>
      <ns0:result>
        <!-- Sequence 1: fault-bearing messages, empty on clean success -->
        <ns0:Message>
          <ns0:code>AR-30003</ns0:code>
          <ns0:message>Amount applied exceeds remaining balance.</ns0:message>
          <ns0:severity>ERROR</ns0:severity>
          <ns0:detail>...</ns0:detail>
        </ns0:Message>
        <!-- Sequence 2: application records, one per successful apply -->
        <ns0:Value>
          <ns0:AmountApplied>100.00</ns0:AmountApplied>
          <ns0:ReceiptId>294469</ns0:ReceiptId>
          <ns0:CustomerTrxId>300000123456789</ns0:CustomerTrxId>
          <ns0:Comments>...</ns0:Comments>
          <ns0:Discount>0</ns0:Discount>
          <ns0:Instalment>0</ns0:Instalment>
        </ns0:Value>
      </ns0:result>
    </ns0:createApplyReceiptResponse>
  </env:Body>
</env:Envelope>
```

**Critical:** There is NO separate SOAP fault binding for business-rule failures. Errors come back inside the success envelope's `Message` collection. The Invoke activity's fault path won't fire on AR-NNNN errors.

**Fault detection logic:**

A fault is signaled when (a) at least one `Message` element has any of `code`/`message`/`severity` populated, AND (b) either `Value` collection is empty OR the sum of `AmountApplied` across all `Value`s is ≤ 0.

Anything else is success — including the "success with warnings" case where messages are present but at least one Value carries a non-zero AmountApplied.

**There is NO `ReceivableApplicationId` in the response.** Earlier expectation was wrong. The receipt's affected application identifier is the `ReceiptId` inside each Value (which is the parent receipt, not the application). To find the new application record, query the receipt's remittanceReferences after the apply.

**Implementation:** see the cash app's `dkcas_parseSoapResultIsSuccess(faultMessageCount, valueCount, totalAmountApplied)` function. The three scalars are computed in OIC via `count()` (for messages-with-content), `count()` (for Values), and `sum()` (for AmountApplied) — then passed to JS for the decision.

## BIP `runReport` SOAP

The BI Publisher report execution service. Used to run custom XDM reports from the Fusion catalog.

**Endpoint:** `https://<tenant>/xmlpserver/services/v2/ReportService?WSDL`

**Operation:** `runReport`

**Request:**
```xml
<v2:runReport>
  <v2:reportRequest>
    <v2:reportAbsolutePath>/Custom/DK Integration/DK AR CashAppV2 Pay Rels.xdo</v2:reportAbsolutePath>
    <v2:parameterNameValues>
      <v2:listOfParamNameValues>
        <v2:item>
          <v2:name>customer_number</v2:name>
          <v2:values>
            <v2:item>2741591</v2:item>
          </v2:values>
        </v2:item>
      </v2:listOfParamNameValues>
    </v2:parameterNameValues>
  </v2:reportRequest>
</v2:runReport>
```

**Path format:** Absolute path WITHOUT `/Shared Folders/` prefix, ending in `.xdo`.

**Response:**
```xml
<runReportResponse>
  <runReportReturn>
    <reportBytes>PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgi...</reportBytes>
    <reportContentType>text/xml</reportContentType>
    <reportFileID xsi:nil="true"/>
    <reportLocale>en-US</reportLocale>
  </runReportReturn>
</runReportResponse>
```

**`reportBytes` is Base64-encoded.** There is no XPath-navigable structure beneath it, regardless of how the data model is configured. To work with the XML inside, decode the Base64 and parse it.

**Parsing pattern: Stage File "Read Entire File"** with file reference set to the `reportBytes` leaf and Configure File Contents → Sample XML Document. OIC handles the Base64 decode + XML parse automatically when the reference points at a Base64-typed leaf. After the activity, the parsed structure is XPath-able at `$ParsePr/<root>`.

This pattern is faster and more robust than decoding in JavaScript.

## Common Fusion field name gotchas

- **`TrxNumber` vs `TransactionNumber`** — SOAP `createApplyReceipt` uses `TrxNumber` for the invoice reference; REST `/receivablesInvoices` uses `TransactionNumber`. Same data, different names.
- **`CustomerAccountNumber` vs `BillToCustomerNumber`** — receipt-side uses Customer Account Number; invoice-side uses Bill-To Customer Number. They're the same value semantically.
- **`Amount` vs `AmountApplied`** — receipt-level total vs application-level partial. Don't confuse them in apply calls.

## Test customer / receipt data

For testing against the `fa-ewpl-test-saasfaprod1` tenant, these customers are well-known:

- **Customer `1410875` (KLA-TENCOR MIE GMBH)** — the dedicated cash-app test customer. Carries many `DK_Test_Rec_*` named unapplied receipts (e.g. `DK_Test_Rec_2596015` $363, `DK_Test_Rec_2597020` $968) plus matching open and paid invoices. The go-to source for receipt↔invoice test pairs.
- **Customer `3218124` (MOTEC)** — USD receipt `UPP260218CTNUZU4` ($325.21 unapplied) exactly matched by two open invoices ($151.00 + $174.21). Good multi-allocation exact-match case.
- **Customer `4733672` (Adona Medical)** — has invoices but no AR relationships. Single-customer scenarios.
- **Customer `172948` (SANMINA CORPORATION)** — many active AR relationships. Multi-account / PR-check scenarios.
- **Customer `2741591` (HANLYM PURI-TECH)** — KRW receipts across dates. Date-window testing.

**Deterministic test-data principle:** when building a test plan, give each scenario a unique `(payment_amount, payment_date)` pair so the receipt match within the ±2-day window resolves to exactly one receipt. Shared amounts on the same date make the "first hit wins" match non-deterministic. Verify candidates against `AR_PAYMENT_SCHEDULES_ALL` (CLASS='PMT' for receipts, CLASS='INV' for invoices) before finalizing.

## Live tenant probing via the hackett-fusion MCP

The `hackett-fusion` MCP server provides four tools for live tenant queries:

- `auth_check` — confirm connectivity before running real queries.
- `identify_environment` — fingerprint the current tenant (DB user, enterprise name, ledger/BU/LE counts).
- `execute_sql` — run a SELECT via the HK_SQL_RUNNER BIP report. SQL is base64-passed and run via a ref cursor.
- `run_bip_report` — execute any BIP report by absolute path.

**Constraints on `execute_sql`:**
- SELECT only. No DDL/DML.
- Row cap of 1000 (FUSION_ROW_LIMIT).
- `ORDER BY` on aliased columns may not work — use `ORDER BY <position>` (e.g. `ORDER BY 1`).
- No SQL*Plus substitution variables (`&variable`) — use hardcoded literals.
- For row limits, wrap in a subquery: `SELECT * FROM (SELECT ...) WHERE ROWNUM <= N`. Don't use `FETCH FIRST N ROWS ONLY` inline.

**Accessible tables (confirmed 2026-05):** `HZ_CUST_ACCOUNTS`, `HZ_PARTIES`, `HZ_CUST_ACCT_RELATE_ALL`, and — newly accessible this round — the AR core tables: `AR_CASH_RECEIPTS_ALL`, `AR_PAYMENT_SCHEDULES_ALL`, `RA_CUSTOMER_TRX_ALL`, `AR_RECEIVABLE_APPLICATIONS_ALL`. Access can change between sessions, so probe with `SELECT COUNT(*) FROM <table> WHERE ROWNUM = 1` before relying on a table.

**Earlier-blocked, status may vary:** `FUN_BUSINESS_UNITS_V`, `HR_ALL_ORGANIZATION_UNITS` were inaccessible in prior sessions; re-probe. `ALL_TAB_PRIVS` consistently times out — avoid it.

**Useful AR_PAYMENT_SCHEDULES_ALL columns** (for finding test data): `CLASS` (`INV`/`PMT`/`CM`), `TRX_NUMBER`, `AMOUNT_DUE_ORIGINAL`, `AMOUNT_DUE_REMAINING` (negative for unapplied receipts), `INVOICE_CURRENCY_CODE`, `STATUS` (`OP`/`CL`), `TRX_DATE`, `CUSTOMER_ID`, `CUSTOMER_TRX_ID`, `CASH_RECEIPT_ID`. Note `AR_CASH_RECEIPTS_ALL` has no `UNAPPLIED_AMOUNT` column — derive unapplied from `AR_PAYMENT_SCHEDULES_ALL` where `CLASS='PMT'`.

**When timeouts cascade:** consecutive timeouts require a full server restart of the MCP. Not a permissions issue, not a SQL syntax issue — server state.

## Oracle SQL style (project preference)

For SQL written for the hackett-fusion MCP or for BIP data models in this project:

- **Traditional comma-separated FROM clause** with join predicates in WHERE.
- **`(+)` for outer joins.** Do not use ANSI JOIN syntax.
- **`ROWNUM` for row limits**, not `FETCH FIRST N ROWS ONLY`.
- **Production filters from the start:** filter for active status (`STATUS = 'A'`), date effectivity, relevant flags. Don't write the lazy version first; the production version is the only one that gets tested.
