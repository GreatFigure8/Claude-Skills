# Archrock Brand Reference

Sourced from Archrock's own published stylesheet (`archrock.com/css/base.css`) and
`brandfetch.com/archrock.com`, August 2026. Re-derive from `archrock.com` directly if
this file is more than a few months old — brand refreshes happen, and this was captured
from one page, not an official brand-guidelines PDF.

## Applying this file

Layer these tokens over `design-system.md`'s `:root` block — override only `--brand`,
`--brand-2`, `--brand-dark`, `--brand-soft`, `--brand-light`, and the topbar's accent
stop. Everything else in the design system (verdict colors, spacing, component
structure) stays as-is.

```css
:root{
  --brand:      #0c7eb0;  /* primary blue — buttons, header rules, thead background source */
  --brand-2:    #00a9e0;  /* sky blue — secondary accent, hover states */
  --brand-dark: #00394d;  /* deep navy — header/footer bands, headings */
  --brand-soft: #e8f5fb;  /* pale blue tint — callouts, code chip background */
  --brand-light:#bfe9f7;  /* light blue — text-on-dark accents */
}
```

Additional utility hexes seen in Archrock's own palette, useful for one-off accents (not
part of the core token set above): `--ar-yellow:#ffc600` (their brightest accent — good
for the topbar's third gradient stop, sparingly, and for the highlight span in `<pre>`
blocks), `--ar-orange:#ff8200`, `--ar-red:#da291c`, `--ar-teal:#00b398`,
`--ar-charcoal:#262626`, `--ar-alum:#e6e6e6`.

## Fonts

Archrock's licensed typefaces are Metric (display) and Factoria (body) — not
redistributable. Substitute Manrope (display) and Inter (body), matching the design
system's default, and disclose the substitution once in the report footer:
`"Palette follows archrock.com's published stylesheet; Archrock's licensed typefaces
(Metric / Factoria) are substituted with Manrope / Inter."`

## Logo

`assets/archrock_logo.png` — trimmed to the visible mark (418×81, transparent
background), pulled from `archrock.imgix.net/cssimg/archrock_logo.png` (the mark used in
Archrock's own site header).

**The wordmark is white "Arch" + gray "rock", built for a dark background.** Placed
directly on the report's light canvas or a white card, the white half disappears
entirely. Always place it on a `--brand-dark` band — see the `.brandline` component in
`design-system.md`, which puts a full-width navy strip directly under the topbar with
the logo left-aligned and a small-caps "Oracle Integration Review" label right-aligned.
Don't attempt to recolor, outline, or add a drop-shadow to make it work on a light
background instead — use the band.

## Provenance note

If asked, this palette and logo were extracted programmatically from Archrock's own
public website assets for use in an internal consulting deliverable, not copied from a
third-party brand-asset database as the primary source (Brandfetch was checked only to
corroborate the extracted hexes). Re-verify against `archrock.com` if this file is stale
or if Archrock has since published formal brand guidelines.
