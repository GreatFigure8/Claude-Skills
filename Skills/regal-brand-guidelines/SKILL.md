---
name: regal-brand-guidelines
description: "Applies Regal Cinemas' official brand colors, typography, and visual design standards to any visual output including HTML artifacts, timelines, dashboards, data visualizations, presentations, one-pagers, and styled documents. Also applies to PowerPoint (.pptx) presentations — use the PPTX Color Scheme section for exact hex codes from the official Regal template. Use when creating branded deliverables, client-facing materials, charts, diagrams, or any artifact that should reflect Regal's corporate identity. Also use when the user mentions 'Regal branding', 'Regal brand colors', 'Regal Cinemas styling', 'Regal template', or requests professional entertainment/cinema-industry styling for Regal. Trigger this skill for any visual output intended for Regal Cinemas or Regal Entertainment Group, even if the user doesn't explicitly say 'branded' — if the context is Regal, apply this skill."
---

## Regal Cinemas Brand Design System

### PRIMARY COLOR PALETTE
CSS variables to use consistently:

```css
--regal-orange: #F56601;         /* Primary brand orange - headlines, key elements, CTAs */
--regal-dark: #212933;           /* Near-black - dark backgrounds, primary text on light */
--regal-charcoal: #3C3C3B;       /* Secondary dark - headers, emphasis on light backgrounds */
--regal-red: #DE181A;            /* Accent red - used sparingly, cinematic drama */
```

### SECONDARY COLOR PALETTE
```css
--regal-orange-mid: #F8A56E;     /* Mid-tone orange - secondary fills, gradients */
--regal-orange-light: #FAC090;   /* Light orange/peach - backgrounds, subtle fills */
--regal-gray-dark: #333333;      /* Dark gray - body text, secondary content */
--regal-gray-mid: #595959;       /* Mid gray - supporting text */
--regal-gray-light: #7C878E;     /* Light gray - captions, metadata */
--regal-off-white: #FFFFFF;      /* White - content backgrounds */
```

### ACCENT / STRUCTURAL COLORS (for diagonal stripes, design elements)
From the Regal template's signature diagonal stripe motif:
```css
--regal-stripe-black: #1C1C1C;   /* Deep black stripe */
--regal-stripe-dark: #333333;    /* Dark charcoal stripe */
--regal-stripe-gray: #595959;    /* Mid gray stripe */
--regal-stripe-silver: #7F7F7F;  /* Silver gray stripe */
--regal-stripe-orange: #F56601;  /* Primary orange stripe */
--regal-stripe-peach: #F8A56E;   /* Peach/mid-orange stripe */
--regal-stripe-light: #FAC090;   /* Light peach stripe */
```

### CHART COLOR PALETTE (for data visualizations, in order)
- 1 color: Regal Orange (#F56601)
- 2 colors: Orange (#F56601), Charcoal (#3C3C3B)
- 3 colors: add Mid-Orange (#F8A56E)
- 4 colors: add Light Peach (#FAC090)
- 5+ colors: add Red (#DE181A), then Dark Gray (#333333)

### TYPOGRAPHY
- Primary headlines/titles: **Calibri Bold** or **Trebuchet MS Bold** — strong, cinematic weight
- Body text / subheadings: **Calibri** / **Arial**, weight: Regular (400), Semibold (600)
- Fallback web fonts: `font-family: 'Trebuchet MS', Arial, sans-serif`

| Element            | Size      | Weight  | Color              |
|--------------------|-----------|---------|-------------------|
| Slide title        | 36–44pt   | Bold    | #F56601 or #FFFFFF |
| Section header     | 20–24pt   | Bold    | #F56601            |
| Body text          | 14–16pt   | Regular | #212933 or #FFFFFF |
| Captions/metadata  | 10–12pt   | Regular | #7C878E            |

### LOGO
- **Regal Cinemas** — the "Regal" wordmark with the distinctive crown/film-frame icon
- Logo appears in **white** on dark/orange backgrounds
- Logo appears in **orange (#F56601) + dark** on white/light backgrounds
- SVG logo URL (official): `https://www.regmovies.com/` (fetch from their branding page at `/branding`)
- Always include adequate clear space equal to the height of the "R" letterform around the logo
- Do NOT distort, recolor (outside approved uses), or add effects to the logo

### PPTX COLOR SCHEME
When building PowerPoint presentations using the Regal template:

| Role              | Hex       | Usage                              |
|-------------------|-----------|------------------------------------|
| dk1 (Dark 1)      | `212933`  | Primary dark background            |
| dk2 (Dark 2)      | `3C3C3B`  | Secondary dark elements            |
| lt1 (Light 1)     | `FFFFFF`  | White backgrounds, light text      |
| Accent 1          | `F56601`  | Primary brand orange               |
| Accent 2          | `F8A56E`  | Secondary/mid orange               |
| Accent 3          | `FAC090`  | Tertiary/light peach               |
| Accent 4          | `706F6F`  | Neutral gray                       |
| Accent 5          | `DADADA`  | Light gray                         |
| Accent 6          | `DE181A`  | Red accent                         |

### SLIDE TEMPLATES & LAYOUTS
The Regal template includes these key layouts (match by usage):

1. **Title/Cover slide** — Dark background with cinema photo, large orange title text, color swatches at bottom
2. **Content slide** — White background with Hackett footer, cinema photo header strip (black-to-red gradient)
3. **Section divider** — Solid orange (#F56601) full-bleed, white text + Hackett Group logo top-right
4. **Dark content slide** — Black background with diagonal orange/gray stripe element right side, orange horizontal rule accent
5. **Two-column layout** — Cinema header strip + vertical divider, Hackett footer
6. **Three-column layout** — Cinema header strip + two vertical dividers, Hackett footer

### VISUAL STYLE & MOTIFS
- **Dark cinematic aesthetic**: Deep blacks and charcoals as the dominant backdrop — like a premium theater
- **Orange energy**: Regal Orange (#F56601) commands attention — use it for titles, CTAs, key callouts
- **Diagonal stripe motif**: The signature design element — angled stripes in black/gray/orange gradations suggest motion, energy, film
- **Cinema imagery**: Moody interior shots of theaters, lobbies, screens — always high-contrast, dramatic lighting
- **Color swatches bar**: The orange → mid-orange → peach → gray → dark gray horizontal swatch row (from cover slide)
- **Clean white content areas**: Sharp contrast between rich, dark branded slides and clean white content slides
- **Photography**: Dramatic, atmospheric cinema interior photography; avoid stock "people smiling" imagery

### FOOTER (HACKETT DELIVERABLES)
When creating Hackett-branded deliverables FOR Regal:
- Bottom-left: The Hackett Group® logo (blue mark + wordmark)
- Bottom-right: "© [year] The Hackett Group, Inc. All Rights Reserved. Reproduction of this document or any portion thereof without prior written consent is prohibited."
- Page number: right-aligned, small, dark gray

### BACKGROUNDS BY SLIDE TYPE
| Slide Type          | Background          | Text Color        |
|---------------------|--------------------|--------------------|
| Cover/Title         | Dark photo overlay  | #F56601 (title), #FFFFFF |
| Section Divider     | #F56601 solid       | #FFFFFF             |
| Dark Content        | #000000 / #1C1C1C   | #FFFFFF, #F56601 accent |
| Light Content       | #FFFFFF             | #212933, #F56601 headers |
| Closing/Thank You   | #F56601 solid       | #FFFFFF             |

### HTML/CSS USAGE
When building HTML artifacts for Regal:
```html
<link href="https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;700&display=swap" rel="stylesheet">
<style>
  :root {
    --regal-orange: #F56601;
    --regal-dark: #212933;
    --regal-charcoal: #3C3C3B;
    --regal-red: #DE181A;
    --regal-orange-mid: #F8A56E;
    --regal-orange-light: #FAC090;
    --regal-gray: #7C878E;
  }
  body { background: var(--regal-dark); color: #FFFFFF; font-family: 'Roboto', Arial, sans-serif; }
  h1, h2 { color: var(--regal-orange); }
  .card { background: #1C1C1C; border-left: 4px solid var(--regal-orange); }
  .cta { background: var(--regal-orange); color: #FFFFFF; }
  .accent { color: var(--regal-orange); }
</style>
```
