# Typography Reference

Reference for ui-design and ui-review. Typography is the single highest-leverage
design decision — get this right and most of the interface follows.

## Principles

1. **One typeface family is enough.** Two max (one sans, one mono). Three is a code smell.
2. **Size creates hierarchy, not weight.** Jump at least 1.25x between levels.
3. **Tight tracking on headings, normal on body.** Never track body text tight.
4. **Line height decreases as size increases.** Headings: 1.1-1.2. Body: 1.5. Small text: 1.6.

## Font Stack (Default)

```css
/* Primary — system-first with Inter fallback */
--font-sans: "Inter var", "SF Pro Display", -apple-system, BlinkMacSystemFont,
             "Segoe UI", Roboto, sans-serif;

/* Display — accent font for headings/hero only */
--font-display: "Instrument Sans", "Inter var", var(--font-sans);

/* Code */
--font-mono: "JetBrains Mono", "SF Mono", "Fira Code", "Cascadia Code",
             ui-monospace, monospace;
```

**Per-project override**: If the project has a brand font, replace `--font-display`
and optionally `--font-sans`. Keep `--font-mono` as-is unless the project has a
brand monospace.

## Type Scale (Major Third — 1.25 ratio)

| Token | Size | Use |
|-------|------|-----|
| `--text-xs` | 12px | Captions, timestamps, badges |
| `--text-sm` | 14px | Secondary text, table cells, input labels |
| `--text-base` | 16px | Body copy, default |
| `--text-lg` | 18px | Lead paragraphs, nav items |
| `--text-xl` | 20px | Card headings, subheadings |
| `--text-2xl` | 24px | Section headings |
| `--text-3xl` | 30px | Page titles |
| `--text-4xl` | 36px | Hero headings (desktop) |
| `--text-5xl` | 48px | Display text, marketing pages |

## Weight Rules

| Weight | Token | When to Use |
|--------|-------|-------------|
| 400 | `--font-normal` | Body text, descriptions |
| 500 | `--font-medium` | Labels, nav items, emphasis |
| 600 | `--font-semibold` | Headings, buttons, active states |
| 700 | `--font-bold` | Hero headings, critical emphasis only |

**Rule**: Never bold body text for emphasis. Use `--font-medium` or color/position instead.

## Responsive Scaling

```css
/* Headings scale down on mobile */
@media (max-width: 640px) {
  --text-4xl: 1.875rem;  /* 30px instead of 36px */
  --text-5xl: 2.25rem;   /* 36px instead of 48px */
}
```

## Banned Fonts

These are AI-default fonts. Using them is a signal:

| Font | Why Banned | Acceptable Exception |
|------|-----------|---------------------|
| Inter (as sole font) | #1 AI default | OK as body if paired with distinctive display font |
| Roboto | #2 AI default, Material Design baggage | Only if the project is Material Design |
| Open Sans | Generic, overused | None |
| Poppins | Geometric, screams "Canva template" | None |
| Montserrat | 2015 design trend, dated | None |

## Pairing Suggestions

For projects that need a display + body combination:

| Display | Body | Mood |
|---------|------|------|
| Instrument Sans | Inter var | Clean tech (Linear, Vercel) |
| Plus Jakarta Sans | System stack | Warm professional |
| Geist Sans | Geist Mono | Developer tool |
| Space Grotesk | Inter var | Bold technical |
| Outfit | System stack | Friendly SaaS |
