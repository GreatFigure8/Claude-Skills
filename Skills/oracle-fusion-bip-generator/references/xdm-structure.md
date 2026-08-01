# XDM Data Model Structure

This reference documents the XML structure of Oracle BIP Data Models (`.xdm` files). The skill uses this to assemble valid data models that BIP will accept on first upload, without manual XML repair.

## File overview

A BIP Data Model is an XML document with root element `<dataModel>`. The root has several child blocks, each representing a different aspect of the model:

| Block | Purpose | Required |
|-------|---------|----------|
| `<dataModel>` (root) | Top-level container; carries data source reference | Yes |
| `<dataProperties>` | Data engine settings (sample size, SQL pruning, etc.) | Yes |
| `<dataSets>` | The actual query/queries | Yes |
| `<parameters>` | Parameter definitions exposed to the runtime | Optional but typical |
| `<lovs>` | Lookup queries backing menu parameters | Optional |
| `<valueSets>` | Connects parameters to LOVs | Optional |
| `<triggers>` | Pre/post-fetch PL/SQL hooks | Optional, advanced |
| `<output>` | Root group name and row tag for the XML output | Yes |
| `<dataStructure>` | Maps SQL columns to friendly output element names | Recommended |
| `<bursting>` | Bursting definition for split delivery | v2 (out of scope for v1) |

## Root element

```xml
<dataModel xmlns="http://xmlns.oracle.com/oxp/xmlp"
           xmlns:xdm="http://xmlns.oracle.com/oxp/xmlp"
           xmlns:xsd="http://www.w3.org/2001/XMLSchema"
           defaultDataSourceRef="ApplicationDB_FSCM"
           version="2.0">
  ...
</dataModel>
```

Notes:
- `defaultDataSourceRef` is set from the user-supplied data source choice (FSCM / HCM / CRM / custom).
- `version="2.0"` is correct for current Fusion BIP.

## Data properties block

Standard defaults that work for most reports:

```xml
<dataProperties>
  <property name="include_parameters" value="true"/>
  <property name="include_null_Element" value="true"/>
  <property name="xml_tag_case" value="upper"/>
  <property name="include_rowsettag" value="false"/>
  <property name="sql_monitor_report_enabled" value="false"/>
  <property name="default_calendar" value="GREGORIAN"/>
  <property name="db_fetch_size" value="500"/>
  <property name="enable_sql_pruning" value="false"/>
</dataProperties>
```

Override when:
- `xml_tag_case` — set `lower` only if the user explicitly wants lowercase XML element names.
- `enable_sql_pruning` — set `true` when you want BIP to drop unused columns from the SQL based on RTF template field usage. Keep `false` by default; pruning can cause confusion when templates change.
- `db_fetch_size` — increase for very large datasets; decrease for memory-constrained environments.

## Data sets block

The `<dataSets>` block holds one or more SQL queries. For v1, the skill emits a single dataset.

```xml
<dataSets>
  <dataSet name="Q_MAIN" type="simple">
    <sql dataSourceRef="ApplicationDB_FSCM">
      <![CDATA[
        SELECT gjh.name             AS journal_name,
               gjl.je_line_num      AS line_number,
               gcc.segment1         AS company,
               gcc.segment3         AS account,
               gjl.entered_dr       AS debit,
               gjl.entered_cr       AS credit
          FROM gl_je_headers       gjh,
               gl_je_lines         gjl,
               gl_code_combinations gcc
         WHERE gjh.je_header_id = gjl.je_header_id
           AND gjl.code_combination_id = gcc.code_combination_id
           AND gjh.ledger_id = :p_ledger_id
           AND gjh.period_name = :p_period_name
         ORDER BY gjh.name, gjl.je_line_num
      ]]>
    </sql>
  </dataSet>
</dataSets>
```

Notes:
- `name="Q_MAIN"` is conventional; use a meaningful dataset name when there are multiple.
- `type="simple"` for plain SQL queries. Other types include `bursting`, `summary`, `aggregate`.
- The SQL goes inside `<![CDATA[ ... ]]>` to avoid XML escaping the `<`, `>`, `&` characters.
- `dataSourceRef` on `<sql>` overrides the root-level `defaultDataSourceRef` if a specific dataset needs a different source.

## Parameters block

```xml
<parameters>
  <parameter name="p_ledger_id"
             dataType="xsd:string"
             defaultValue=""
             rowPlacement="1">
    <input label="Ledger" size="40"/>
  </parameter>

  <parameter name="p_period_name"
             dataType="xsd:string"
             defaultValue=""
             rowPlacement="1">
    <input label="Period Name" size="40"/>
  </parameter>

  <parameter name="p_date_from"
             dataType="xsd:date"
             defaultValue=""
             rowPlacement="2">
    <input label="Date From" size="20"/>
  </parameter>

  <parameter name="p_date_to"
             dataType="xsd:date"
             defaultValue=""
             rowPlacement="2">
    <input label="Date To" size="20"/>
  </parameter>

  <parameter name="p_business_unit_ids"
             dataType="xsd:string"
             defaultValue=""
             multiValuesAllowed="true"
             rowPlacement="3">
    <input label="Business Units" size="60"/>
  </parameter>
</parameters>
```

Notes:
- `dataType` values: `xsd:string`, `xsd:date`, `xsd:integer`, `xsd:decimal`, `xsd:boolean`.
- `multiValuesAllowed="true"` enables multi-select; pair with the multi-select SQL pattern.
- `rowPlacement` controls how parameters are grouped on the prompt screen — same number = same row.
- `defaultValue=""` means no default; supply a literal or a function like `{$SYSDATE()}` when a default is wanted.

### Hidden parameters
For parameters used internally (e.g., a passed-in security key) but not shown to end users:
```xml
<parameter name="p_user_id"
           dataType="xsd:integer"
           defaultValue="{$USER_ID()}"
           hidden="true"/>
```

### System-supplied defaults
BIP provides these expression defaults:
- `{$SYSDATE()}` — current date.
- `{$USER_ID()}` — running user's ID.
- `{$USER_NAME()}` — running user's username.
- `{$LANG()}` — current language code.

## LOVs block

Each menu parameter references an LOV. The LOV is a SQL query in its own right.

```xml
<lovs>
  <lov name="LOV_LEDGER" type="sql" dataSourceRef="ApplicationDB_FSCM">
    <sqlText>
      <![CDATA[
        SELECT ledger_id  AS value,
               name       AS display
          FROM gl_ledgers_v
         ORDER BY name
      ]]>
    </sqlText>
  </lov>

  <lov name="LOV_PERIOD" type="sql" dataSourceRef="ApplicationDB_FSCM">
    <dataConstraints>
      <dataConstraint name="LEDGER_DEP" parameter="p_ledger_id"/>
    </dataConstraints>
    <sqlText>
      <![CDATA[
        SELECT gp.period_name AS value,
               gp.period_name AS display
          FROM gl_periods gp,
               gl_ledgers  gl
         WHERE gp.period_set_name = gl.period_set_name
           AND (:p_ledger_id IS NULL OR gl.ledger_id = :p_ledger_id)
         ORDER BY gp.start_date DESC
      ]]>
    </sqlText>
  </lov>
</lovs>
```

Notes:
- LOV name convention: `LOV_<purpose>` in uppercase.
- The `<dataConstraints>` block declares parent → child cascade. When `p_ledger_id` changes, BIP re-evaluates LOV_PERIOD.
- The cascading SQL uses the same null-guard pattern: `(:p_ledger_id IS NULL OR ...)`.

## Value sets block

`<valueSets>` connects parameters to their LOVs:

```xml
<valueSets>
  <valueSet id="VS_LEDGER" type="sql">
    <sql dataSourceRef="ApplicationDB_FSCM" lovId="LOV_LEDGER"/>
  </valueSet>

  <valueSet id="VS_PERIOD" type="sql">
    <sql dataSourceRef="ApplicationDB_FSCM" lovId="LOV_PERIOD"/>
  </valueSet>
</valueSets>
```

Then, on the parameter, reference the value set:
```xml
<parameter name="p_ledger_id" dataType="xsd:string" defaultValue="" valueSet="VS_LEDGER">
  <input label="Ledger" size="40"/>
</parameter>
```

## Output and data structure blocks

The `<output>` element names the root group and the row tag. The `<dataStructure>` block maps SQL columns to friendly XML element names.

```xml
<output rootName="DATA_DS" uniqueRowName="false">
  <nodeList name="data-structure">
    <dataStructure>
      <group name="G_JOURNALS" dataType="xsd:string" source="Q_MAIN">
        <element name="JOURNAL_NAME"   value="journal_name"   dataType="xsd:string"/>
        <element name="LINE_NUMBER"    value="line_number"    dataType="xsd:integer"/>
        <element name="COMPANY"        value="company"        dataType="xsd:string"/>
        <element name="ACCOUNT"        value="account"        dataType="xsd:string"/>
        <element name="DEBIT"          value="debit"          dataType="xsd:decimal"/>
        <element name="CREDIT"         value="credit"         dataType="xsd:decimal"/>
      </group>
    </dataStructure>
  </nodeList>
</output>
```

Notes:
- `rootName` defaults to `DATA_DS` for most reports.
- `group name="G_JOURNALS"` becomes the repeating element name in the XML output. The RTF template references this name in `<?for-each:G_JOURNALS?>`.
- `value="journal_name"` maps to the SQL column alias (case-insensitive, but match lowercase for clarity).
- Friendly element names (`JOURNAL_NAME`, etc.) are what RTF templates reference: `<?JOURNAL_NAME?>`.

### Hierarchical groups (header / lines pattern)
For reports with parent-child structure, use nested `<group>` elements:

```xml
<dataStructure>
  <group name="G_INVOICE" dataType="xsd:string" source="Q_MAIN">
    <element name="INVOICE_NUMBER" value="invoice_number" dataType="xsd:string"/>
    <element name="VENDOR_NAME"    value="vendor_name"    dataType="xsd:string"/>
    <group name="G_INVOICE_LINE" dataType="xsd:string" source="Q_MAIN">
      <element name="LINE_NUMBER"  value="line_number"  dataType="xsd:integer"/>
      <element name="LINE_AMOUNT"  value="line_amount"  dataType="xsd:decimal"/>
    </group>
  </group>
</dataStructure>
```

Notes:
- True multi-dataset header/line reports (separate queries joined by key) are **v2 scope**. For v1, the skill emits a single flat dataset and lets the RTF template handle grouping via `<?for-each-group:G_ROW;./INVOICE_NUMBER?>`.

## Complete minimal example

A complete, valid `.xdm` for a simple report:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<dataModel xmlns="http://xmlns.oracle.com/oxp/xmlp"
           xmlns:xsd="http://www.w3.org/2001/XMLSchema"
           defaultDataSourceRef="ApplicationDB_FSCM"
           version="2.0">

  <dataProperties>
    <property name="include_parameters" value="true"/>
    <property name="include_null_Element" value="true"/>
    <property name="xml_tag_case" value="upper"/>
    <property name="db_fetch_size" value="500"/>
  </dataProperties>

  <dataSets>
    <dataSet name="Q_MAIN" type="simple">
      <sql dataSourceRef="ApplicationDB_FSCM">
        <![CDATA[
          /* GL Trial Balance — one row per natural account, summed per period */
          SELECT gcc.segment3                  AS account_code,
                 SUM(gjl.accounted_dr)         AS total_debit,
                 SUM(gjl.accounted_cr)         AS total_credit
            FROM gl_je_headers       gjh,
                 gl_je_lines         gjl,
                 gl_code_combinations gcc
           WHERE gjh.je_header_id = gjl.je_header_id
             AND gjl.code_combination_id = gcc.code_combination_id
             AND gjh.ledger_id   = :p_ledger_id
             AND gjh.period_name = :p_period_name
             AND gjh.status      = 'P'
           GROUP BY gcc.segment3
           ORDER BY gcc.segment3
        ]]>
      </sql>
    </dataSet>
  </dataSets>

  <lovs>
    <lov name="LOV_LEDGER" type="sql" dataSourceRef="ApplicationDB_FSCM">
      <sqlText>
        <![CDATA[
          SELECT ledger_id AS value, name AS display
            FROM gl_ledgers_v
           ORDER BY name
        ]]>
      </sqlText>
    </lov>
    <lov name="LOV_PERIOD" type="sql" dataSourceRef="ApplicationDB_FSCM">
      <dataConstraints>
        <dataConstraint name="LEDGER_DEP" parameter="p_ledger_id"/>
      </dataConstraints>
      <sqlText>
        <![CDATA[
          SELECT gp.period_name AS value, gp.period_name AS display
            FROM gl_periods gp,
                 gl_ledgers  gl
           WHERE gp.period_set_name = gl.period_set_name
             AND (:p_ledger_id IS NULL OR gl.ledger_id = :p_ledger_id)
           ORDER BY gp.start_date DESC
        ]]>
      </sqlText>
    </lov>
  </lovs>

  <valueSets>
    <valueSet id="VS_LEDGER" type="sql">
      <sql dataSourceRef="ApplicationDB_FSCM" lovId="LOV_LEDGER"/>
    </valueSet>
    <valueSet id="VS_PERIOD" type="sql">
      <sql dataSourceRef="ApplicationDB_FSCM" lovId="LOV_PERIOD"/>
    </valueSet>
  </valueSets>

  <parameters>
    <parameter name="p_ledger_id" dataType="xsd:string" defaultValue="" valueSet="VS_LEDGER" rowPlacement="1">
      <input label="Ledger" size="40"/>
    </parameter>
    <parameter name="p_period_name" dataType="xsd:string" defaultValue="" valueSet="VS_PERIOD" rowPlacement="1">
      <input label="Period" size="40"/>
    </parameter>
  </parameters>

  <output rootName="DATA_DS" uniqueRowName="false">
    <nodeList name="data-structure">
      <dataStructure>
        <group name="G_ACCOUNTS" dataType="xsd:string" source="Q_MAIN">
          <element name="ACCOUNT_CODE"  value="account_code"  dataType="xsd:string"/>
          <element name="TOTAL_DEBIT"   value="total_debit"   dataType="xsd:decimal"/>
          <element name="TOTAL_CREDIT"  value="total_credit"  dataType="xsd:decimal"/>
        </group>
      </dataStructure>
    </nodeList>
  </output>

</dataModel>
```

## Validation checklist

Before declaring an `.xdm` complete:
- [ ] Root `<dataModel>` element has correct namespace, version, and `defaultDataSourceRef`.
- [ ] All `<dataSet>` SQL has been validated via `hackett-fusion:execute_sql`.
- [ ] All `<lov>` SQL has been validated separately.
- [ ] Every parameter referenced in SQL appears in `<parameters>`.
- [ ] Every menu parameter has a `valueSet` reference pointing to an existing `<valueSet>`.
- [ ] Every `<valueSet>` `lovId` matches an existing `<lov>` `name`.
- [ ] Cascading LOVs have `<dataConstraints>` declared.
- [ ] `<dataStructure>` `value` attributes match SQL column aliases.
- [ ] No raw `<` or `>` outside `<![CDATA[ ... ]]>` blocks.
- [ ] File starts with `<?xml version="1.0" encoding="UTF-8"?>` declaration.
