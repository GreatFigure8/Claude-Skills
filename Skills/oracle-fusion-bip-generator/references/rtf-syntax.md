# BIP RTF Template Syntax

This reference covers the BI Publisher tag syntax used inside RTF templates, plus the two approaches this skill uses to generate RTF files programmatically.

## Tag overview

BIP RTF tags are XSL-FO expressions wrapped in `<?...?>`. They can appear two ways inside an RTF file:

1. **As Microsoft Word form fields** with the tag stored in the field code. This is what the BIP Word add-in produces and what shows gray-highlighted in Word with field codes hidden. Preferred for end-user editing.
2. **As plain text** directly in the document body. BIP parses these identically. Easier to generate programmatically.

This skill generates plain-text tags by default. If the user wants form-field versions, they can open the RTF in Word with the BIP add-in and the add-in will convert plain-text tags to form fields.

## Tag cookbook

### Simple field reference
```
<?ELEMENT_NAME?>
```
Example: `<?INVOICE_NUMBER?>`, `<?TOTAL_DEBIT?>`.

The element name comes from the `<dataStructure>` `<element name="...">` attribute in the `.xdm`.

### Repeating group
```
<?for-each:G_GROUP_NAME?>
  ...content per row...
<?end for-each?>
```
Example:
```
<?for-each:G_INVOICE?>
  Invoice: <?INVOICE_NUMBER?>   Amount: <?INVOICE_AMOUNT?>
<?end for-each?>
```

### Sorted group
```
<?for-each:G_INVOICE?>
<?sort:INVOICE_DATE;'ascending';data-type='date'?>
  ...
<?end for-each?>
```

### Grouped output (group-by)
For grouping a flat dataset into header/detail without a multi-dataset model:
```
<?for-each-group:G_ROW;./CUSTOMER_NAME?>
  Customer: <?CUSTOMER_NAME?>
  <?for-each:current-group()?>
    Invoice: <?INVOICE_NUMBER?>
  <?end for-each?>
<?end for-each-group?>
```

### Conditional content
```
<?if: AMOUNT > 0?>
  ...content shown when condition is true...
<?end if?>
```

With else:
```
<?if: STATUS = 'PAID'?>
  Paid in full
<?else?>
  Outstanding: <?BALANCE_DUE?>
<?end if?>
```

Multi-way:
```
<?choose:?>
  <?when: AGE_BUCKET = '0-30'?>Current<?end when?>
  <?when: AGE_BUCKET = '31-60'?>Slightly overdue<?end when?>
  <?when: AGE_BUCKET = '61-90'?>Significantly overdue<?end when?>
  <?otherwise:?>Severely overdue<?end otherwise?>
<?end choose?>
```

### Aggregations
```
<?sum(AMOUNT)?>          -- sum across current context
<?count(G_INVOICE)?>     -- row count of group
<?avg(AMOUNT)?>          -- average
<?min(DUE_DATE)?>        -- earliest
<?max(DUE_DATE)?>        -- latest
```

Scoped sum (e.g., total for current customer group):
```
<?sum(current-group()/AMOUNT)?>
```

### Number formatting
```
<?format-number:AMOUNT;'$#,##0.00'?>
<?format-number:QUANTITY;'#,##0'?>
<?format-number:PERCENTAGE;'0.00%'?>
```

Locale-aware:
```
<?format-number:AMOUNT;'$#,##0.00';'en-US'?>
```

### Date formatting
```
<?format-date:INVOICE_DATE;'MM/DD/YYYY'?>
<?format-date:DUE_DATE;'MMM D, YYYY'?>
<?format-date:CREATED_AT;'YYYY-MM-DD HH:MI:SS'?>
```

### Parameters
Declare at the top of the document body:
```
<?param@begin:p_date_from?>
<?param@begin:p_date_to?>
<?param@begin:p_ledger_id?>
```

Reference anywhere after declaration:
```
Period: <?$p_date_from?> through <?$p_date_to?>
```

### Page breaks
```
<?split-by-page-break:?>     -- inside a for-each, breaks page after each row
```

Force page break:
```
<?break-on-column:?>          -- conditional page break
```

### Page numbering (in header/footer)
RTF Word fields:
- `Page <PAGE> of <NUMPAGES>` — use Word's built-in page number fields.

### Empty data handling
```
<?if:count(G_INVOICE) = 0?>
  No invoices found for the selected criteria.
<?end if?>
```

### Hyperlinks
```
<?fo:basic-link select="link('http://example.com')"?>
  Click here
<?end fo:basic-link?>
```

### Variables
Define and reuse:
```
<?xdoxslt:set_variable($_XDOCTX, 'running_total', 0)?>
...
<?xdoxslt:set_variable($_XDOCTX, 'running_total',
   xdoxslt:get_variable($_XDOCTX, 'running_total') + AMOUNT)?>
Running total: <?xdoxslt:get_variable($_XDOCTX, 'running_total')?>
```

## Generation approaches

### Approach 1: Generate `.docx` first, convert to `.rtf`

Use when the template needs complex tables, custom styling, embedded images, or full Word feature parity.

Workflow:
1. Use `python-docx` to construct the `.docx` with BIP tags as plain text in the document body.
2. Convert via `libreoffice --headless --convert-to rtf {file}.docx` or `pandoc -o {file}.rtf {file}.docx`.
3. Validate the resulting `.rtf` opens in Word and renders tags correctly.

Pros: full control over styling; python-docx is well-supported; produces clean output.
Cons: requires libreoffice/pandoc on the executing environment; conversion can lose some formatting.

Skeleton:
```python
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH

doc = Document()

# Page setup
section = doc.sections[0]
section.top_margin = Inches(0.5)
section.bottom_margin = Inches(0.5)

# Title
title = doc.add_paragraph()
title.alignment = WD_ALIGN_PARAGRAPH.CENTER
run = title.add_run("AR Invoice Aging")
run.font.size = Pt(16)
run.font.bold = True
run.font.color.rgb = RGBColor(0x00, 0x1A, 0x3A)  # Hackett navy

# Parameter declarations
doc.add_paragraph("<?param@begin:p_date_from?>")
doc.add_paragraph("<?param@begin:p_date_to?>")

# Parameter echo
doc.add_paragraph("Period: <?$p_date_from?> through <?$p_date_to?>")

# Data table
table = doc.add_table(rows=2, cols=5)
table.style = "Light Grid Accent 1"
hdr = table.rows[0].cells
hdr[0].text = "Invoice #"
hdr[1].text = "Customer"
hdr[2].text = "Date"
hdr[3].text = "Due"
hdr[4].text = "Amount"

# Repeating row
row = table.rows[1].cells
row[0].text = "<?for-each:G_INVOICE?><?INVOICE_NUMBER?>"
row[1].text = "<?CUSTOMER_NAME?>"
row[2].text = "<?format-date:INVOICE_DATE;'MM/DD/YYYY'?>"
row[3].text = "<?format-date:DUE_DATE;'MM/DD/YYYY'?>"
row[4].text = "<?format-number:AMOUNT;'$#,##0.00'?><?end for-each?>"

doc.save("report.docx")
# Then convert: libreoffice --headless --convert-to rtf report.docx
```

### Approach 2: Hand-author the `.rtf` directly

Use for simple single-table templates or when conversion tools aren't available.

Use `templates/rtf-base-hackett.rtf` as the starting skeleton and modify in place. RTF is plain-text with control words prefixed by `\`. Key constructs:

```
{\rtf1\ansi\deff0
{\fonttbl{\f0\froman Times New Roman;}{\f1\fswiss Calibri;}}
{\colortbl ;\red0\green26\blue58;\red200\green169\blue81;}
\f1\fs22

\b\fs32\cf1 Report Title\b0\fs22\cf0\par
\par
<?param@begin:p_date_from?>\par
<?param@begin:p_date_to?>\par
Period: <?$p_date_from?> through <?$p_date_to?>\par
\par
<?for-each:G_INVOICE?>\par
  Invoice: <?INVOICE_NUMBER?>  Amount: <?format-number:AMOUNT;'$#,##0.00'?>\par
<?end for-each?>\par
}
```

Key RTF control words:
- `\rtf1\ansi` — file header.
- `{\fonttbl...}` — font table; index `\fN` refers back to it.
- `{\colortbl...}` — color table; `\cfN` selects color N.
- `\f1\fs22` — font 1, size 22 half-points (11pt).
- `\b ... \b0` — bold on/off.
- `\par` — paragraph break.
- `\cf1` — foreground color 1.
- `\page` — page break.

Pros: no external dependencies; can be generated by string templating.
Cons: RTF is finicky; complex layouts (tables, headers, footers) require deep RTF knowledge.

## Branding application

### Hackett default (when user doesn't specify)
Use the `hackett-brand-guidelines` skill for full standards. Quick reference:
- Primary color: navy `#001A3A`.
- Accent color: gold `#C8A951`.
- Font: Calibri 10pt body, 14pt section headers, 16pt title.
- Logo: place in top-left of page header.
- Header band: full-width navy band with white title text.
- Footer: gold accent line above page number.

### Moss & Associates
- Primary: forest green `#1B5E20`.
- Accent: warm gold `#D4A017`.
- Background: cream `#F5F5DC`.

### Ochsner Health
- Primary: navy `#001A3A`.
- Secondary: blue `#003DA5`.
- Accent: gold `#C8A951`.

### Custom brand from user
When the user provides a brand spec (image, color codes, font names), extract:
- Hex codes for primary, accent, background.
- Font family for headings and body.
- Logo image (if provided).
- Header/footer treatment description.

Document the brand decision in the companion README.

## Validation checklist for RTF templates

Before declaring an `.rtf` complete:
- [ ] File opens in MS Word without error.
- [ ] All BIP tags use correct `<?...?>` syntax.
- [ ] Every field reference matches an element name in the `.xdm` `<dataStructure>`.
- [ ] Every `<?for-each:G_...?>` has a matching `<?end for-each?>`.
- [ ] Every `<?if:?>` has a matching `<?end if?>`.
- [ ] Every parameter referenced as `<?$p_xxx?>` is declared via `<?param@begin:p_xxx?>` at the top.
- [ ] Number and date formatting masks are present where currency/dates appear.
- [ ] Branding matches the user-specified or Hackett-default standard.
- [ ] Page header and footer are populated.
- [ ] Optional: an empty-data branch (`<?if:count(G_...) = 0?>`) for graceful behavior with no rows.

## Preview generation (optional)

After emitting the `.rtf`, optionally produce a sample-data preview PDF:
1. Generate a small sample XML payload matching the `.xdm` `<output>` structure with 3-5 fake rows.
2. Use the BIP server-side renderer (if accessible) or local FOP-based rendering to produce a PDF.
3. Save as `{report_short_name}_preview.pdf` in the same `v{N}` folder.

The preview is for visual sign-off only — it's not a substitute for testing against the real data model in the BIP catalog.
