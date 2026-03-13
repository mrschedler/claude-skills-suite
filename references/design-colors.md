# Color Reference

Reference for ui-design and ui-review. Color is where AI-generated UIs fail most
visibly — too many colors, wrong contrast, gradient abuse. This reference enforces
restraint.

## Principles

1. **Restrained palette.** 2-3 colors max. One dominant neutral, one accent, optional secondary.
2. **OKLCH color space.** Perceptually uniform. If two colors have the same lightness value, they look the same lightness. HSL lies about this.
3. **No raw hex/rgb in components.** All color via `var(--color-*)` tokens.
4. **No gradients on backgrounds.** Flat color or subtle opacity. Gradients are the #1 AI tell.
5. **Near-black, not black. Near-white, not white.** Pure #000/#fff is harsh. Slightly tinted neutrals feel intentional.

## The Neutral Scale

The neutral scale carries 80%+ of the interface. It must be right.

```
bg         → 0.99 lightness  (near-white)
bg-subtle  → 0.97            (section backgrounds)
bg-muted   → 0.94            (cards, wells)
surface    → 1.00            (elevated surfaces)
border     → 0.90            (subtle dividers)
border-str → 0.80            (emphasis dividers)
text-tert  → 0.60            (captions)
text-sec   → 0.45            (secondary)
text       → 0.15            (primary — near-black)
```

All neutrals carry a slight blue tint (hue 250, chroma 0.005-0.01) for a cool,
clean feel. Warm projects can shift to hue 50-60.

## Accent Selection

The default accent is a deep blue (`oklch(0.55 0.15 250)`). To customize:

1. **Pick ONE hue.** Not a gradient, not a palette — one hue number.
2. **Generate three variants** at different lightness:
   - Action: 0.55 lightness (buttons, links)
   - Hover: 0.48 lightness (darker for hover)
   - Subtle: 0.95 lightness, 0.03 chroma (tinted backgrounds)
   - Text: 0.45 lightness (when accent is used as text — must pass 4.5:1 on white)
3. **Test contrast.** Accent on white must meet WCAG AA (4.5:1 for text, 3:1 for large text/UI).

## Semantic Colors

These are fixed roles. Don't use accent color for success/error states.

| Role | OKLCH | Hue | Use |
|------|-------|-----|-----|
| Success | `oklch(0.55 0.12 155)` | Green | Confirmations, saved states |
| Warning | `oklch(0.65 0.15 80)` | Amber | Caution, soft limits |
| Error | `oklch(0.55 0.18 25)` | Red | Destructive, validation failures |
| Info | `oklch(0.55 0.10 250)` | Blue | Tips, neutral callouts |

## What NOT to Do

| Bad | Why | Good |
|-----|-----|------|
| `background: linear-gradient(135deg, #667eea 0%, #764ba2 100%)` | AI default #1. Purple gradient = instant AI tell | `background: var(--color-bg)` |
| `color: #6B7280` | Raw hex. Breaks dark mode. Breaks consistency | `color: var(--color-text-secondary)` |
| 5+ accent colors | No hierarchy. Everything competes | 1 accent + 4 semantic |
| `opacity: 0.5` on text | Breaks contrast on variable backgrounds | Use explicit lightness tokens |
| Rainbow status indicators | Red/orange/yellow/green/blue/purple | Max 4 semantic colors |

## Dark Mode

Dark mode is NOT "invert everything." It's a separate set of lightness values:

- Backgrounds get darker (0.13-0.20 lightness range)
- Text gets lighter (0.55-0.93 range)
- Accent shifts lighter (0.55 → 0.65) for sufficient contrast on dark bg
- Shadows get stronger (higher opacity) because subtle shadows vanish on dark bg
- Borders get lighter relative to background

The token file handles this with `prefers-color-scheme: dark`. Components should
never reference light/dark mode directly — just use tokens.

## Contrast Requirements (WCAG 2.2 AA)

| Element | Minimum Ratio | Token Guidance |
|---------|--------------|----------------|
| Body text | 4.5:1 | `--color-text` on `--color-bg` = ~15:1 |
| Large text (≥18px bold, ≥24px) | 3:1 | `--color-text-secondary` on `--color-bg` = ~6:1 |
| UI components (borders, icons) | 3:1 | `--color-border-strong` on `--color-bg` = ~4:1 |
| Accent as text | 4.5:1 | `--color-accent-text` on `--color-bg` = ~5.5:1 |
| Disabled text | No requirement | But must be distinguishable from enabled |
