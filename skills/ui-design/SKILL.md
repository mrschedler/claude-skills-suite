---
name: ui-design
description: Generates UI components and pages following the project design system. Use when building frontend, creating components, or styling interfaces.
---

# UI Design

Generate UI code that looks intentionally designed, not AI-generated. This skill
exists because LLMs default to the statistical center of design decisions —
producing Inter font, purple gradients, cards-in-cards, and uniform spacing that
users instantly recognize as AI slop. This skill forces aesthetic direction before
code generation and enforces the project design system throughout.

## Inputs

- The target component/page requirements (from user or work unit)
- `project-context.md` — for project-specific brand, stack, and constraints
- Shared design system references (loaded on demand from `../../references/`)

## Outputs

- UI component/page code following the design system
- Token-only styling (no raw color/spacing/radius values)
- Accessible markup (semantic HTML, ARIA where needed)

## Instructions

### Phase 1: Load Design Context

Before writing any UI code:

1. Read `../../references/design-tokens.css` to understand the available token vocabulary.
2. Read `../../references/design-anti-patterns.md` to internalize what NOT to do.
3. Check if the project has its own design overrides (custom font, custom accent color, brand guidelines). If `project-context.md` specifies a design system, that overrides the defaults.

### Phase 2: Establish Direction

Before generating code, commit to a direction for this component/page:

1. **Content first.** What information does this view communicate? Write that down before any styling decisions.
2. **Hierarchy.** What's the ONE thing the user should see first? Second? Third? Design flows from this.
3. **Density.** Is this a dense dashboard, a sparse landing page, or a focused form? This determines spacing rhythm.
4. **Existing patterns.** Does the project already have similar components? Match them. Consistency beats novelty.

If generating a full page or significant component, state the direction in a brief comment before the code:
```
/* Direction: sparse layout, strong heading hierarchy, single accent color for CTAs */
```

### Phase 3: Generate Code

Write the component/page code following these rules:

**Styling:**
- All colors via `var(--color-*)` tokens. Zero raw hex, rgb, hsl, or oklch in components.
- All spacing via `var(--space-*)` tokens or Tailwind spacing classes mapped to the scale.
- All radius via `var(--radius-*)` tokens.
- All typography via `var(--text-*)`, `var(--font-*)`, `var(--leading-*)`, `var(--tracking-*)`.
- No inline `style={{}}` attributes. Use className/CSS modules/Tailwind.
- No gradients on backgrounds unless the user explicitly requests one.

**Markup:**
- Semantic HTML first: `<nav>`, `<main>`, `<section>`, `<button>`, `<a>` before `<div>`.
- All interactive elements are `<button>` or `<a>`, never `<div onClick>`.
- All `<img>` have `alt` text (empty `alt=""` only for decorative images with `role="presentation"`).
- All form inputs have visible `<label>` elements.
- Focus styles present on all interactive elements via `:focus-visible`.

**Layout:**
- Use CSS Grid or Flexbox. No floats, no absolute positioning for layout.
- Responsive by default. Mobile-first breakpoints.
- Content width constrained by `--max-w-prose` (text) or `--max-w-content` (layout).

**States:**
- Every interactive component defines: default, hover, focus, active, disabled states.
- Every data-displaying component defines: loading, empty, error, populated states.
- Never generate only the happy path.

### Phase 4: Anti-Pattern Check

Before presenting the output, scan for these (read `../../references/design-anti-patterns.md` for the full list):

1. Any raw color values? Replace with tokens.
2. Any inline styles? Move to className.
3. Cards nested in cards? Flatten.
4. Uniform spacing everywhere? Add rhythm variation.
5. Generic copy ("Get started today", "Seamless experience")? Replace with real content or clear placeholder markers.
6. Emoji used as design elements? Remove.
7. More than 2 font families? Reduce.
8. Default Inter/Roboto with no display font? Add the project's display font for headings.

If any anti-pattern is found, fix it before showing the code.

### Phase 5: Accessibility Verification

Quick check against `../../references/design-a11y.md`:

1. Is there semantic structure (`<main>`, heading hierarchy)?
2. Do all images have `alt`?
3. Do all inputs have labels?
4. Are all clickables buttons/links?
5. Are focus styles present?
6. Does color convey information without an alternative indicator?

Fix any failures before presenting.

## References (on-demand)

Read these from the shared `../../references/` directory when needed:
- `design-tokens.css` — OKLCH design tokens, spacing scale, type scale, shadows, motion
- `design-anti-patterns.md` — 17 AI slop patterns with detection and fixes
- `design-typography.md` — Font stacks, type scale, weight rules, banned fonts, pairings
- `design-colors.md` — Palette principles, neutral scale, accent selection, contrast requirements
- `design-a11y.md` — WCAG 2.2 checklist, the 10 most common AI a11y failures, testing commands

## Examples

```
User: Build me a settings page for the app.
-> Load design context. Establish direction: focused form layout, grouped sections,
   restrained use of accent color for save actions. Generate with token-only styling,
   semantic form markup, all states (loading, saving, error, success). Anti-pattern
   and a11y check before presenting.
```

```
User: Create a data table component.
-> Load design context. Direction: dense layout, strong column headers, subtle row
   borders, hover state. Generate with responsive horizontal scroll, sortable
   headers as buttons (not divs), empty state, loading skeleton. Check for raw
   values and a11y.
```

```
User: Style this dashboard — it looks AI-generated.
-> Read anti-patterns reference. Identify which of the 17 patterns are present.
   Fix each: replace uniform spacing with rhythm, swap default font for project
   display font, reduce color count, flatten nested cards, add real content.
```

```
User: Add a modal for user profile editing.
-> Load tokens. Direction: focused overlay, minimal fields, clear primary/secondary
   actions. Generate with <dialog> or Radix Dialog, focus trap, escape-to-close,
   aria-labelledby, form labels, error states. Token-only styling.
```

---

Before completing, read and follow `../../references/cross-cutting-rules.md`.
