---
name: digikey-brand-guidelines
description: Applies DigiKey's official brand colors, typography, logo, and visual design standards to any generated output — including HTML/React artifacts, Microsoft Word documents, PowerPoint decks, Excel workbooks, PDFs, dashboards, charts, one-pagers, and styled documents. Use this skill whenever the user asks for DigiKey branding, DigiKey-themed materials, DigiKey-styled documents, client-facing DigiKey deliverables, or mentions "DigiKey colors", "DigiKey logo", "DigiKey report", "DigiKey presentation", "DigiKey dashboard", or anything that should look like it came from DigiKey. Also trigger when the user works on DigiKey-related projects (such as the Remittance App, Oracle Fusion integration work, or any internal DigiKey tooling) and asks for a polished or branded output, even if they don't explicitly say "branding".
---

# DigiKey Brand Design System

Applies DigiKey's post-2023 ("We Get Technical") visual identity to
any output. The palette is tight and confident: Pomegranate red
is the hero, Mine Shaft charcoal carries the type, and white carries
the space. Use red as a spice, not a base — it belongs on the logo,
the primary CTA, accent rules, and deliberate emphasis.

When generating output, apply this skill automatically. Do not ask
the user to confirm brand choices — they already asked for DigiKey
branding, so use these values.

---

## 1. Color palette

### Core brand colors (verified from DigiKey's 2023 refresh)

| Token         | Hex       | RGB             | Name         | Use                                    |
| ------------- | --------- | --------------- | ------------ | -------------------------------------- |
| `--dk-red`    | `#EE2821` | 238, 40, 33     | Pomegranate  | Primary brand color, logo, CTAs, accent |
| `--dk-white`  | `#FFFFFF` | 255, 255, 255   | White        | Primary surface                        |
| `--dk-charcoal` | `#333333` | 51, 51, 51    | Mine Shaft   | Body text, headings, strong neutral    |

### Derived reds (for states and subtle fills)

| Token             | Hex       | Use                              |
| ----------------- | --------- | -------------------------------- |
| `--dk-red-dark`   | `#C31D17` | Hover / pressed state            |
| `--dk-red-darker` | `#8F1511` | Deep accent, chart 5th series    |
| `--dk-red-tint-10`| `#FDE9E8` | Very light red wash for callouts |
| `--dk-red-tint-25`| `#F9B8B5` | Light red for stacked fills      |

### Supporting neutrals

| Token                | Hex       | Use                              |
| -------------------- | --------- | -------------------------------- |
| `--dk-black`         | `#000000` | Maximum contrast                 |
| `--dk-near-black`    | `#1A1A1A` | Deep headers                     |
| `--dk-dark-gray`     | `#4A4A4A` | Secondary headings               |
| `--dk-gray`          | `#6C6C6C` | Secondary / caption text         |
| `--dk-medium-gray`   | `#9A9A9A` | Tertiary text, muted labels      |
| `--dk-light-gray`    | `#D1D1D1` | Borders, chart gridlines         |
| `--dk-lighter-gray`  | `#E8E8E8` | Subtle dividers                  |
| `--dk-soft-gray`     | `#F4F4F4` | Card / section backgrounds       |
| `--dk-off-white`     | `#FAFAFA` | Zebra rows, subtle fills         |

### Status colors (use sparingly — red is reserved for brand)

| Token          | Hex       | Use                |
| -------------- | --------- | ------------------ |
| `--dk-success` | `#2E7D32` | Positive variance  |
| `--dk-warning` | `#F5A623` | Caution thresholds |
| `--dk-info`    | `#0B6FB4` | Neutral info       |
| `--dk-error`   | `#EE2821` | Same as brand red  |

### Chart palette (use in this order)

1. `#EE2821` (DK_RED) — first series is always brand red
2. `#333333` (DK_CHARCOAL) — strong neutral
3. `#9A9A9A` (DK_MEDIUM_GRAY)
4. `#0B6FB4` (DK_INFO) — when hue separation is needed
5. `#8F1511` (DK_RED_DARKER)
6. `#6C6C6C` (DK_GRAY)
7. `#F9B8B5` (DK_RED_TINT_25)
8. `#D1D1D1` (DK_LIGHT_GRAY)

---

## 2. Typography

DigiKey's 2023+ identity uses a custom commercial sans-serif. For
reproducible output use **Inter** (free, Google Fonts) with
**Arial** as a universal fallback. The feel is clean, slightly
geometric, engineered.

- **Primary typeface:** Inter
- **Web fallback:** Arial, Helvetica, sans-serif
- **Monospace (for part numbers, code, data):** Roboto Mono, Consolas, Menlo

Google Fonts import:
```html
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=Roboto+Mono:wght@400;500&display=swap" rel="stylesheet">
```

### Type scale (web, rem-based)

| Role     | Size     | Weight   | Usage                        |
| -------- | -------- | -------- | ---------------------------- |
| Display  | 3.5rem   | 800 Black| Hero titles                  |
| H1       | 2.5rem   | 800      | Page titles (often DK_RED)   |
| H2       | 2rem     | 700 Bold | Section headings             |
| H3       | 1.5rem   | 700      | Subsection headings          |
| H4       | 1.25rem  | 600 Semibold | Minor headings           |
| Body     | 1rem     | 400 Regular | Paragraphs                |
| Small    | 0.875rem | 400      | Meta, labels                 |
| Caption  | 0.75rem  | 400      | Footnotes, legal             |

### Type scale (Office docs, points)

| Role     | Size | Weight   |
| -------- | ---- | -------- |
| Display  | 44pt | Black    |
| H1       | 28pt | Bold     |
| H2       | 22pt | Bold     |
| H3       | 16pt | Semibold |
| H4       | 14pt | Semibold |
| Body     | 11pt | Regular  |
| Small    | 10pt | Regular  |
| Caption  | 9pt  | Regular  |

**Important:** letter-spacing of `-0.02em` on display/H1 tightens the
wordmark-adjacent feel. Body text uses normal letter-spacing and a
1.55 line-height for readability.

---

## 3. Logo

- **Wordmark:** lowercase "digikey" in Pomegranate red on white, or
  white on Pomegranate red / charcoal.
- **Tagline (paired with logo):** "We Get Technical"
- **Clear space:** at least 1× the cap-height of "digikey" on all
  four sides.
- **Minimum size:** 80px wide on screen, 0.75" in print.
- **Never:** stretch, skew, recolor (other than the approved
  white-on-dark reversal), add drop shadows, or place on a
  background that clashes with Pomegranate red.
- **Placeholder assets** live in `assets/`:
  - `digikey-logo-placeholder.svg` — red wordmark on transparent
  - `digikey-logo-white-placeholder.svg` — white wordmark on transparent

For client-facing, public, or press deliverables, **replace the
placeholder with DigiKey's official asset**. Tell the user this
once when they first ask for a branded output, then stop nagging.

---

## 4. Visual style principles

- **Red is a spice.** The signature red belongs on the logo, the
  primary CTA, a top banner, an accent rule beneath a heading, hover
  states, and deliberate emphasis. Keep large surfaces white or
  soft gray. Never paint every heading or every button red.
- **One red CTA per view.** Use the outlined secondary style for
  everything else.
- **Clean, engineered, calm.** Generous white space. Left-align most
  text. Center only for hero titles and stat callouts.
- **Sharp geometry over soft curves.** Border-radius stays modest
  (4–8px for buttons and cards, 12px max for containers). No pill
  shapes except for tags.
- **No gratuitous gradients.** Flat color is the default. A subtle
  dark-red gradient on hero sections is acceptable; rainbow or
  trendy gradients are not.
- **Photography & imagery:** clean product shots on neutral
  backgrounds; real engineers and makers at work; circuit-board
  textures for abstract backgrounds. Avoid generic stock imagery.

### Signature DigiKey layout patterns

1. **Red top banner** — 0.3" tall, full-bleed `#EE2821` strip at
   the top of slides, report covers, and email headers.
2. **Red accent rule** — a short 3pt red horizontal line beneath a
   title, acts as the brand's visual fingerprint.
3. **Stat callout** — big DK_RED or DK_CHARCOAL number in Inter
   Black with a thin red underline and a small DK_GRAY label.
4. **Zebra tables** — white / `#FAFAFA` alternating rows with a
   solid red header row.

---

## 5. How to use this skill — by output type

Before generating a branded output, **view the relevant reference
file** in `references/` to get the detailed rules for that format.

| User wants                        | Read this reference                              |
| --------------------------------- | ------------------------------------------------ |
| HTML artifact, React, dashboard   | `references/html-artifact-guide.md`              |
| Word `.docx` report, memo, letter | `references/word-docx-guide.md`                  |
| PowerPoint `.pptx` deck           | `references/powerpoint-pptx-guide.md`            |
| Excel `.xlsx` workbook, data      | `references/excel-xlsx-guide.md`                 |

### Reusable assets in `assets/`

- `digikey-theme.css` — drop-in CSS variables + component classes
  for HTML/React artifacts. Paste inline in a `<style>` tag.
- `digikey_brand.py` — Python constants and helper functions for
  `python-docx`, `python-pptx`, `openpyxl`, and `matplotlib`. Copy
  to your working directory and import.
- `digikey-logo-placeholder.svg` — red wordmark placeholder.
- `digikey-logo-white-placeholder.svg` — white wordmark placeholder.

### Standard workflow

1. User asks for a DigiKey-branded output (e.g. "make me a DigiKey
   quarterly report in Word").
2. Read the appropriate `references/*-guide.md` file.
3. If generating code that needs the Python or CSS tokens, copy
   `assets/digikey_brand.py` or `assets/digikey-theme.css` into the
   working directory first (or inline the relevant values).
4. Read the matching core skill (`/mnt/skills/public/docx/SKILL.md`,
   `pptx/SKILL.md`, `xlsx/SKILL.md`) for format-specific mechanics.
5. Generate the output, placing the final file in
   `/mnt/user-data/outputs/`.
6. Present the file with the `present_files` tool.

---

## 6. Voice & tone (for copy generated in branded materials)

DigiKey's voice is the **"Eye-Level Expert"** — humble confidence,
friendly, attentive, straight-shooting. Highly technical subject
matter delivered without condescension.

- **Do:** use precise technical language when the audience is
  technical; use clear plain English when it's not; be direct;
  celebrate the community of engineers and makers.
- **Don't:** hype, overpromise, use corporate buzzwords, or
  condescend to the reader.
- **Tagline to use in hero contexts:** "We Get Technical."
- **Footer copyright:** `© {year} DigiKey. All Rights Reserved.`

---

## 7. Quick reference card

Copy-paste-ready tokens for any context:

```
Primary red:     #EE2821   rgb(238, 40, 33)
Body charcoal:   #333333   rgb(51, 51, 51)
Surface white:   #FFFFFF   rgb(255, 255, 255)
Hover red:       #C31D17
Card fill:       #F4F4F4
Border:          #D1D1D1
Caption gray:    #6C6C6C

Font:            Inter, Arial, sans-serif
Mono:            Roboto Mono, Consolas, monospace
Tagline:         "We Get Technical"
Radius:          4px (btn) / 8px (card) / 12px (hero)
```
