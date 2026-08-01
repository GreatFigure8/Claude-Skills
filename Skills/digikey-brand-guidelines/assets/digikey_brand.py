"""
digikey_brand.py
================
Reusable constants and tiny helper functions for applying DigiKey
branding (2023+ identity) to Python-generated Office documents.

Designed for use with:
    * python-docx   (Word)
    * python-pptx   (PowerPoint)
    * openpyxl      (Excel)
    * matplotlib / plotly / svgwrite (charts)

Import only what you need:
    from digikey_brand import DK_RED, DK_CHARCOAL, DK_FONT, apply_heading_style
"""

# --------------------------------------------------------------
# 1. COLORS  — hex strings and RGB tuples
# --------------------------------------------------------------

# Core brand palette
DK_RED          = "#EE2821"   # Pomegranate — primary accent
DK_WHITE        = "#FFFFFF"
DK_CHARCOAL     = "#333333"   # Mine Shaft — body text

# Derived reds for hover/pressed/deep accent
DK_RED_DARK     = "#C31D17"
DK_RED_DARKER   = "#8F1511"
DK_RED_TINT_10  = "#FDE9E8"
DK_RED_TINT_25  = "#F9B8B5"

# Supporting neutrals
DK_BLACK        = "#000000"
DK_NEAR_BLACK   = "#1A1A1A"
DK_DARK_GRAY    = "#4A4A4A"
DK_GRAY         = "#6C6C6C"
DK_MEDIUM_GRAY  = "#9A9A9A"
DK_LIGHT_GRAY   = "#D1D1D1"
DK_LIGHTER_GRAY = "#E8E8E8"
DK_SOFT_GRAY    = "#F4F4F4"
DK_OFF_WHITE    = "#FAFAFA"

# Status colors (use sparingly, red is reserved for brand)
DK_SUCCESS      = "#2E7D32"
DK_WARNING      = "#F5A623"
DK_INFO         = "#0B6FB4"

# Chart palette — use in this order so charts feel on-brand.
# Red is the hero; grays and a single supporting blue round it out.
DK_CHART_PALETTE = [
    DK_RED,           # 1st series — always brand red
    DK_CHARCOAL,      # 2nd — strong neutral
    DK_MEDIUM_GRAY,   # 3rd
    DK_INFO,          # 4th — only when you need a hue separation
    DK_RED_DARKER,    # 5th
    DK_GRAY,          # 6th
    DK_RED_TINT_25,   # 7th — light red for stacked fills
    DK_LIGHT_GRAY,    # 8th
]

# --------------------------------------------------------------
# 2. TYPOGRAPHY
# --------------------------------------------------------------
# DigiKey's 2023+ identity uses a custom commercial sans. For
# Office docs we recommend these widely-available substitutes that
# preserve the clean, engineered feel:

DK_FONT          = "Inter"         # First choice if installed
DK_FONT_FALLBACK = "Arial"         # Universally available
DK_FONT_MONO     = "Consolas"      # For code / part numbers / data

# Type scale for Word/PowerPoint (points)
DK_TYPE_SCALE = {
    "display":  44,
    "h1":       28,
    "h2":       22,
    "h3":       16,
    "h4":       14,
    "body":     11,
    "small":    10,
    "caption":   9,
}

# --------------------------------------------------------------
# 3. CONVERSION HELPERS
# --------------------------------------------------------------

def hex_to_rgb(hex_color: str) -> tuple[int, int, int]:
    """'#EE2821' -> (238, 40, 33)"""
    h = hex_color.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


# --------------------------------------------------------------
# 4. python-docx helpers (Word)
# --------------------------------------------------------------
# These lazily import python-docx so this module is safe to load
# even if the library isn't installed.

def apply_docx_heading_style(paragraph, level: int = 1):
    """
    Style a python-docx paragraph as a DigiKey-branded heading.

    Usage:
        from docx import Document
        doc = Document()
        p = doc.add_paragraph("Executive Summary")
        apply_docx_heading_style(p, level=1)
    """
    from docx.shared import Pt, RGBColor

    sizes = {1: 28, 2: 22, 3: 16, 4: 14}
    size_pt = sizes.get(level, 14)

    for run in paragraph.runs:
        run.font.name = DK_FONT
        run.font.size = Pt(size_pt)
        run.font.bold = True
        # Headings use charcoal; use DK_RED only for the *top* title
        # of a document. Don't paint every heading red.
        color_hex = DK_RED if level == 1 else DK_CHARCOAL
        run.font.color.rgb = RGBColor(*hex_to_rgb(color_hex))


def apply_docx_body_style(paragraph):
    """Style a paragraph as DigiKey body copy."""
    from docx.shared import Pt, RGBColor
    for run in paragraph.runs:
        run.font.name = DK_FONT
        run.font.size = Pt(DK_TYPE_SCALE["body"])
        run.font.color.rgb = RGBColor(*hex_to_rgb(DK_CHARCOAL))


def add_docx_red_accent_rule(doc):
    """
    Insert a thin red horizontal rule as a visual divider. Useful
    beneath a title or between major sections.
    """
    from docx.oxml.ns import qn
    from docx.oxml import OxmlElement

    p = doc.add_paragraph()
    pPr = p._p.get_or_add_pPr()
    pBdr = OxmlElement("w:pBdr")
    bottom = OxmlElement("w:bottom")
    bottom.set(qn("w:val"), "single")
    bottom.set(qn("w:sz"), "18")           # 3pt
    bottom.set(qn("w:space"), "1")
    bottom.set(qn("w:color"), "EE2821")    # DigiKey red, no '#'
    pBdr.append(bottom)
    pPr.append(pBdr)
    return p


# --------------------------------------------------------------
# 5. python-pptx helpers (PowerPoint)
# --------------------------------------------------------------

def pptx_rgb(hex_color: str):
    """Return a pptx.dml.color.RGBColor for a hex string."""
    from pptx.dml.color import RGBColor
    return RGBColor(*hex_to_rgb(hex_color))


def apply_pptx_title(shape, text: str, color_hex: str = None):
    """Style a title shape in DigiKey's voice."""
    from pptx.util import Pt
    if color_hex is None:
        color_hex = DK_CHARCOAL
    tf = shape.text_frame
    tf.text = text
    p = tf.paragraphs[0]
    for run in p.runs:
        run.font.name = DK_FONT
        run.font.size = Pt(DK_TYPE_SCALE["h1"])
        run.font.bold = True
        run.font.color.rgb = pptx_rgb(color_hex)


def add_pptx_red_banner(slide, prs):
    """
    Add a full-width 0.3" red banner at the top of a slide —
    a common DigiKey layout flourish.
    """
    from pptx.util import Inches
    from pptx.enum.shapes import MSO_SHAPE
    banner = slide.shapes.add_shape(
        MSO_SHAPE.RECTANGLE,
        Inches(0), Inches(0),
        prs.slide_width, Inches(0.3),
    )
    banner.line.fill.background()
    banner.fill.solid()
    banner.fill.fore_color.rgb = pptx_rgb(DK_RED)
    return banner


# --------------------------------------------------------------
# 6. openpyxl helpers (Excel)
# --------------------------------------------------------------

def apply_xlsx_header_row(ws, row: int, last_col_letter: str):
    """
    Style an Excel header row with DigiKey red background and
    white bold text. Example:
        apply_xlsx_header_row(ws, row=1, last_col_letter="F")
    """
    from openpyxl.styles import PatternFill, Font, Alignment

    fill = PatternFill(start_color="EE2821", end_color="EE2821", fill_type="solid")
    font = Font(name=DK_FONT, bold=True, color="FFFFFF", size=11)
    align = Alignment(horizontal="left", vertical="center")

    for col in ws[f"A{row}:{last_col_letter}{row}"][0]:
        col.fill = fill
        col.font = font
        col.alignment = align


def apply_xlsx_zebra_rows(ws, first_row: int, last_row: int, last_col_letter: str):
    """Apply subtle zebra striping using DK_OFF_WHITE."""
    from openpyxl.styles import PatternFill

    fill = PatternFill(start_color="FAFAFA", end_color="FAFAFA", fill_type="solid")
    for r in range(first_row, last_row + 1):
        if r % 2 == 0:
            for cell in ws[f"A{r}:{last_col_letter}{r}"][0]:
                cell.fill = fill


# --------------------------------------------------------------
# 7. Chart helpers (matplotlib)
# --------------------------------------------------------------

def apply_matplotlib_style():
    """
    Register DigiKey's palette and typography with matplotlib.
    Call once before plotting:
        import matplotlib.pyplot as plt
        from digikey_brand import apply_matplotlib_style
        apply_matplotlib_style()
    """
    import matplotlib as mpl
    from cycler import cycler

    mpl.rcParams.update({
        "font.family":        [DK_FONT, DK_FONT_FALLBACK, "sans-serif"],
        "font.size":          11,
        "axes.titlesize":     14,
        "axes.titleweight":   "bold",
        "axes.labelsize":     11,
        "axes.labelcolor":    DK_CHARCOAL,
        "axes.edgecolor":     DK_LIGHT_GRAY,
        "axes.spines.top":    False,
        "axes.spines.right":  False,
        "axes.grid":          True,
        "grid.color":         DK_LIGHTER_GRAY,
        "grid.linewidth":     0.6,
        "xtick.color":        DK_GRAY,
        "ytick.color":        DK_GRAY,
        "text.color":         DK_CHARCOAL,
        "figure.facecolor":   DK_WHITE,
        "axes.facecolor":     DK_WHITE,
        "axes.prop_cycle":    cycler("color", DK_CHART_PALETTE),
    })
