# DigiKey Branding for PowerPoint (`.pptx`)

Use these defaults when generating DigiKey-branded slide decks with
`python-pptx`. Every element below maps to tokens in
`assets/digikey_brand.py`.

## Slide setup

- **Aspect ratio:** 16:9 widescreen (13.333" × 7.5") — this is
  `python-pptx`'s default but verify explicitly.
- **Default font:** Inter (fall back to Arial).
- **Background:** White `#FFFFFF` for content slides; Pomegranate red
  `#EE2821` for section-divider slides.

## Signature DigiKey slide anatomy

Every content slide should use this pattern:

1. **Red top banner** — full-width, 0.3" tall, `#EE2821`. Always
   anchored to the very top edge.
2. **Slide title** — Inter Bold, 28pt, `#333333`, positioned 0.6"
   from the top, 0.5" from the left.
3. **Thin red underline** beneath the title — a 2pt line, 1.5" wide,
   `#EE2821`, sitting just below the title baseline.
4. **Body content** — starts ~1.5" from the top edge, left-aligned.
5. **Footer** at the bottom: small logo on the left (max 0.3" tall),
   slide number on the right in 9pt DK_GRAY, centered "DigiKey
   Confidential" or page theme optional.

## Type hierarchy for slides

| Element             | Size | Weight  | Color                |
| ------------------- | ---- | ------- | -------------------- |
| Section divider     | 54pt | Black   | `#FFFFFF` on red bg  |
| Slide title         | 28pt | Bold    | `#333333`            |
| Slide subtitle      | 18pt | Regular | `#6C6C6C`            |
| Body / bullets      | 16pt | Regular | `#333333`            |
| Small label / caption | 10pt | Medium | `#6C6C6C`            |
| Big stat number     | 72pt | Black   | `#EE2821` or `#333333` |

## Section-divider slide

Use for chapter breaks. Full-bleed `#EE2821` red background, large
white Inter Black title centered vertically, no other ornament.

## Data slides

- Charts use the `DK_CHART_PALETTE` in order — first series is always
  DigiKey red, second is DK_CHARCOAL.
- Table headers: `#EE2821` background, white Inter Bold 12pt.
- Table body: Inter 11pt, DK_CHARCOAL.
- Axis labels and gridlines: `#D1D1D1` (DK_LIGHT_GRAY) so data pops.

## Stat callouts

A large number in Inter Black with a small red underline. Subtitle
below in DK_GRAY. Example:

- `74%` in 72pt DK_RED
- 3pt wide, 1" long red rule
- "of engineers ship faster with DigiKey" in 12pt DK_GRAY

## Quote slides

- Quote body: Inter Regular Italic, 24pt, DK_CHARCOAL, max 60% width.
- Opening glyph: oversized red quotation mark (96pt DK_RED).
- Attribution: Inter Semibold 14pt DK_CHARCOAL, name on first line,
  title in DK_GRAY 12pt on second line.

## Python example

```python
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from digikey_brand import (
    DK_RED, DK_CHARCOAL, DK_WHITE, DK_FONT,
    pptx_rgb, add_pptx_red_banner, apply_pptx_title,
)

prs = Presentation()
prs.slide_width  = Inches(13.333)
prs.slide_height = Inches(7.5)

# ---- Title slide ----
slide = prs.slides.add_slide(prs.slide_layouts[6])   # blank
add_pptx_red_banner(slide, prs)

title_box = slide.shapes.add_textbox(
    Inches(0.5), Inches(0.6), Inches(12), Inches(1)
)
apply_pptx_title(title_box, "Quarterly Operations Review")

# Red underline beneath title
underline = slide.shapes.add_shape(
    MSO_SHAPE.RECTANGLE,
    Inches(0.5), Inches(1.55), Inches(1.5), Pt(2)
)
underline.fill.solid()
underline.fill.fore_color.rgb = pptx_rgb(DK_RED)
underline.line.fill.background()

# Subtitle
sub_box = slide.shapes.add_textbox(
    Inches(0.5), Inches(1.8), Inches(12), Inches(0.5)
)
sub_box.text_frame.text = "Q1 2026  ·  Thief River Falls, MN"
run = sub_box.text_frame.paragraphs[0].runs[0]
run.font.name = DK_FONT
run.font.size = Pt(18)
run.font.color.rgb = pptx_rgb("#6C6C6C")

prs.save("/mnt/user-data/outputs/deck.pptx")
```
