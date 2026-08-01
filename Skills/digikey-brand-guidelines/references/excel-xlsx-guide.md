# DigiKey Branding for Excel (`.xlsx`)

Use these defaults when generating DigiKey-branded spreadsheets with
`openpyxl`. Every token maps to `assets/digikey_brand.py`.

## Workbook setup

- **Default font:** Inter 11pt, fall back to Calibri (Excel's default)
  on machines without Inter. Body color `#333333`.
- **Default column width:** Auto-size numeric columns to content + 2;
  text columns to at least 18.
- **Freeze the header row** (`ws.freeze_panes = "A2"`) on every sheet.
- **Sheet tab color:** Pomegranate red `#EE2821` for the primary sheet;
  DK_LIGHT_GRAY `#D1D1D1` for supporting sheets. Set via
  `ws.sheet_properties.tabColor = "EE2821"`.

## Header row (the DigiKey signature for tables)

- **Fill:** `#EE2821` (DK_RED), solid.
- **Font:** Inter Bold 11pt, white `#FFFFFF`.
- **Alignment:** left horizontal, center vertical.
- **Row height:** 22pt.
- **Border:** none.

## Body rows

- **Font:** Inter Regular 11pt, `#333333`.
- **Zebra fill** on even rows: `#FAFAFA` (DK_OFF_WHITE).
- **Border:** 0.25pt `#D1D1D1` bottom border only — keep it airy.
- **Cell padding:** use vertical center alignment and a row height
  of 18pt.

## Number formatting

- Currency (USD): `"$#,##0.00"` — right-aligned.
- Percent: `"0.0%"` — right-aligned.
- Large counts: `"#,##0"` — right-aligned.
- Dates: `"yyyy-mm-dd"` — left-aligned, engineer-friendly ISO format.
- Part numbers / SKUs: treat as text (`cell.number_format = "@"`) so
  leading zeros don't disappear.

## Key-metric / summary cards

For KPI cells at the top of a dashboard sheet:

- **Label row:** Inter Regular 9pt `#6C6C6C`, uppercase, letter-spacing
  wide (simulate via actual uppercase text).
- **Value row:** Inter Black 24pt `#333333`, left-aligned.
- **Accent:** a single cell directly under the value, height 3pt,
  filled `#EE2821`, to mimic the brand's red underline.

## Chart styling (openpyxl's native charts)

- Apply `DK_CHART_PALETTE` — first series `#EE2821`, second
  `#333333`, third `#9A9A9A`, fourth `#0B6FB4`, then DK_RED_DARKER.
- Remove chart borders and background fill.
- Gridlines: `#E8E8E8` (DK_LIGHTER_GRAY), horizontal only.
- Axis labels: Inter 10pt `#6C6C6C`.
- Chart title: Inter Bold 12pt `#333333`, left-aligned above the plot.

## Conditional formatting recipes

- **Negative variance:** red text (`#EE2821`) with `#FDE9E8` fill
  (DK_RED_TINT_10).
- **Positive variance:** `#2E7D32` (DK_SUCCESS) text, no fill.
- **Warning threshold:** `#F5A623` (DK_WARNING) fill.

## Python example

```python
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment
from digikey_brand import (
    DK_RED, DK_CHARCOAL, DK_WHITE, DK_OFF_WHITE, DK_FONT,
    apply_xlsx_header_row, apply_xlsx_zebra_rows,
)

wb = Workbook()
ws = wb.active
ws.title = "Q1 Results"
ws.sheet_properties.tabColor = "EE2821"

# Data
headers = ["Part Number", "Description", "Units", "Revenue"]
rows = [
    ["296-1234-ND", "Resistor 10k 1%", 12500, 1875.00],
    ["AE10812-ND",  "Capacitor 10uF",    8340, 1251.00],
    ["ED1520-ND",   "LED 3mm Red",      22100, 1105.00],
]

ws.append(headers)
for r in rows:
    ws.append(r)

# Apply branded header
apply_xlsx_header_row(ws, row=1, last_col_letter="D")

# Zebra body rows
apply_xlsx_zebra_rows(ws, first_row=2, last_row=1 + len(rows),
                     last_col_letter="D")

# Number formats
for cell in ws["D"][1:]:
    cell.number_format = "$#,##0.00"
for cell in ws["C"][1:]:
    cell.number_format = "#,##0"

# Freeze header
ws.freeze_panes = "A2"

# Widen columns
widths = {"A": 18, "B": 28, "C": 12, "D": 14}
for col, w in widths.items():
    ws.column_dimensions[col].width = w

wb.save("/mnt/user-data/outputs/report.xlsx")
```
