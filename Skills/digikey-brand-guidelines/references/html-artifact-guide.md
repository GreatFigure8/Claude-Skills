# DigiKey Branding for HTML / React Artifacts

Use `assets/digikey-theme.css` as the foundation for any HTML or
React artifact. It exposes design tokens as CSS custom properties
(`--dk-red`, `--dk-font-sans`, etc.) and ships a handful of
component classes (`.dk-btn-primary`, `.dk-card`, `.dk-stat`, etc.).

## Quick start — single-file HTML artifact

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>DigiKey Weekly Digest</title>
  <!-- Paste the contents of digikey-theme.css inline in a <style> tag -->
  <style>
    /* ... contents of digikey-theme.css ... */
  </style>
</head>
<body>
  <header class="dk-header">
    <h1>Weekly Operations Digest</h1>
  </header>

  <main style="max-width: 900px; margin: 2rem auto; padding: 0 1rem;">
    <h2>Highlights</h2>
    <span class="dk-accent-bar"></span>

    <div class="dk-card">
      <div class="dk-stat">
        <div class="dk-stat-number">14.9M</div>
        <div class="dk-stat-label">Components in stock</div>
      </div>
    </div>
  </main>
</body>
</html>
```

## React artifacts

React artifacts run in a sandbox that supports Tailwind utility
classes but not external stylesheet imports. Two patterns work:

### Pattern 1 — inline `<style>` block with the design tokens

```jsx
export default function Dashboard() {
  return (
    <>
      <style>{`
        :root {
          --dk-red: #EE2821;
          --dk-charcoal: #333333;
          --dk-white: #FFFFFF;
          --dk-soft-gray: #F4F4F4;
          --dk-gray: #6C6C6C;
        }
        body { font-family: 'Inter', Arial, sans-serif; color: var(--dk-charcoal); }
      `}</style>

      <div style={{ background: "var(--dk-red)", color: "white", padding: 24 }}>
        <h1 style={{ fontWeight: 800, letterSpacing: "-0.02em" }}>
          DigiKey Weekly Digest
        </h1>
      </div>
    </>
  );
}
```

### Pattern 2 — Tailwind with arbitrary brand colors

Tailwind's `bg-[#EE2821]` / `text-[#333333]` arbitrary-value syntax
works in the sandbox:

```jsx
<button className="bg-[#EE2821] hover:bg-[#C31D17] text-white font-semibold
                   px-6 py-3 rounded transition-colors">
  Order Now
</button>
```

## Layout rules

- **Red is a spice, not a base.** The signature red belongs on the
  logo, the primary CTA, a top banner, an accent bar beneath a
  heading, hover states, and deliberate emphasis. Keep large surfaces
  white or soft gray.
- **One red CTA per view.** Multiple competing red buttons dilute
  the call-to-action. Use `.dk-btn-secondary` (outlined) for
  secondary actions.
- **Generous white space.** DigiKey's identity reads as engineered
  and calm — don't crowd elements.
- **Left-align most text.** Center-align is reserved for hero titles
  and single-stat callouts.

## Logo usage in HTML

Embed the SVG inline for crispness at any size:

```html
<img src="digikey-logo-placeholder.svg"
     alt="DigiKey"
     style="height: 40px; width: auto;">
```

For dark backgrounds use `digikey-logo-white-placeholder.svg`.
Preserve clear space equal to the cap-height of "digikey" on all
four sides. Never stretch, skew, or recolor the wordmark.

## Component recipes

### Hero banner

```html
<section style="background: var(--dk-red); color: white; padding: 4rem 2rem;">
  <div style="max-width: 1100px; margin: 0 auto;">
    <h1 style="font-size: 3.5rem; font-weight: 800; letter-spacing: -0.03em;">
      We Get Technical.
    </h1>
    <p style="font-size: 1.25rem; opacity: 0.9; max-width: 60ch;">
      Over 14.9 million components. Fast shipping. Expert support.
    </p>
  </div>
</section>
```

### Stat grid

```html
<div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 24px;">
  <div class="dk-card">
    <div class="dk-stat">
      <div class="dk-stat-number">50+</div>
      <div class="dk-stat-label">Years of service</div>
    </div>
  </div>
  <!-- repeat -->
</div>
```

### Data table

```html
<table class="dk-table">
  <thead>
    <tr><th>Part Number</th><th>Description</th><th>Price</th></tr>
  </thead>
  <tbody>
    <tr><td>296-1234-ND</td><td>10k Ohm Resistor</td><td>$0.15</td></tr>
  </tbody>
</table>
```

## Charts in React artifacts (recharts)

```jsx
const COLORS = ["#EE2821", "#333333", "#9A9A9A", "#0B6FB4", "#8F1511"];

<LineChart data={data}>
  <Line dataKey="revenue" stroke={COLORS[0]} strokeWidth={2.5} />
  <Line dataKey="target"  stroke={COLORS[1]} strokeDasharray="4 4" />
  <CartesianGrid stroke="#E8E8E8" vertical={false} />
  <XAxis stroke="#6C6C6C" />
  <YAxis stroke="#6C6C6C" />
</LineChart>
```
