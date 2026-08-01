# DigiKey Branding for Microsoft Word (`.docx`)

Use these defaults when generating DigiKey-branded Word documents with
`python-docx`. Every element below maps to the tokens defined in
`assets/digikey_brand.py`.

## Page setup

- **Paper size:** US Letter (8.5" × 11")
- **Margins:** 1" top/bottom, 1" left/right
- **Default font:** Inter (fall back to Arial on systems without Inter)
- **Body line spacing:** 1.15
- **Body size:** 11pt
- **Body color:** `#333333` (Mine Shaft / DK_CHARCOAL)

## Text hierarchy

| Element        | Font  | Size | Weight | Color                |
| -------------- | ----- | ---- | ------ | -------------------- |
| Document title | Inter | 28pt | Black  | `#EE2821` (DK_RED)   |
| H1             | Inter | 22pt | Bold   | `#333333`            |
| H2             | Inter | 16pt | Bold   | `#333333`            |
| H3             | Inter | 14pt | Semibold | `#333333`          |
| Body           | Inter | 11pt | Regular | `#333333`           |
| Caption/meta   | Inter | 9pt  | Regular | `#6C6C6C` (DK_GRAY) |
| Code / part no.| Consolas | 10pt | Regular | `#333333`        |

Use red **only** for the document title, the accent rule beneath it,
hyperlinks, callouts, and deliberate emphasis. Never paint every
heading red — it flattens hierarchy and breaks brand.

## Signature layout pattern

1. **Title page or header block:** Title in DK_RED, 28pt, left-aligned.
2. **Red accent rule** (3pt, `#EE2821`) immediately under the title.
3. **Subtitle / date / author line** in DK_GRAY 10pt.
4. **Body content** begins one blank paragraph below.
5. **Footer** on every page: `© {year} DigiKey Electronics` in 9pt
   DK_GRAY, right-aligned.

## Tables

- Header row: solid `#EE2821` fill, white Inter Bold 11pt, left aligned.
- Body rows: 10pt Inter Regular, DK_CHARCOAL text.
- Zebra fill on even rows: `#FAFAFA` (DK_OFF_WHITE).
- Cell padding: 0.08" all sides.
- Outer border: 0.5pt `#D1D1D1` (DK_LIGHT_GRAY). No inner vertical lines.

## Callout / pull quote

A 4pt left border in `#EE2821`, 0.15" left padding, italic Inter 12pt
DK_CHARCOAL text. Use for quotes, key findings, or important warnings.

## Logo placement

- Header: top-left, max height 0.4".
- Cover page: centered, max width 2.5".
- Always preserve clear space equal to 1× the logo's cap-height on all
  sides. Never place on a background that clashes with Pomegranate red.

## Python example

```python
from docx import Document
from docx.shared import Pt, Inches, RGBColor
from digikey_brand import (
    DK_RED, DK_CHARCOAL, DK_FONT, DK_TYPE_SCALE,
    hex_to_rgb, apply_docx_heading_style, apply_docx_body_style,
    add_docx_red_accent_rule,
)

doc = Document()

# Title
title = doc.add_paragraph("Quarterly Operations Review")
apply_docx_heading_style(title, level=1)   # 28pt, DK_RED

# Red accent rule
add_docx_red_accent_rule(doc)

# Subtitle
sub = doc.add_paragraph("Q1 2026  ·  Thief River Falls, MN")
for run in sub.runs:
    run.font.name = DK_FONT
    run.font.size = Pt(10)
    run.font.color.rgb = RGBColor(0x6C, 0x6C, 0x6C)

# Section heading
h = doc.add_paragraph("Summary")
apply_docx_heading_style(h, level=2)

# Body
p = doc.add_paragraph("Order volume grew 12% quarter-over-quarter...")
apply_docx_body_style(p)

doc.save("/mnt/user-data/outputs/report.docx")
```
