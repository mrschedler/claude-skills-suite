---
name: ui-review
description: Audits UI for AI anti-patterns, token violations, a11y failures, and inconsistency. Use before frontend deploys or after UI sprints.
---

# UI Review

Catch AI-generated UI before it ships. This review lens detects the visual and
structural patterns that make interfaces look machine-generated — hardcoded colors,
default fonts, missing states, broken accessibility, and inconsistent component
usage across views. It complements completeness-review (which finds stubs) and
integration-review (which finds dead wiring) by focusing specifically on what the
user sees.

## Inputs

- The full codebase (frontend files: `*.tsx`, `*.jsx`, `*.css`, `*.scss`, `*.module.css`)
- `project-context.md` — for project-specific design system, brand, stack
- Shared design system references from `../../references/`
- `features.md` — to verify UI completeness per feature

## Outputs

See `references/review-lens-framework.md` for the shared output pattern.
Lens name for DB operations: `ui-review`

## Instructions

### Fresh Findings Check

See `references/review-lens-framework.md`. Lens: `ui-review`.

### Phase 1: Token Compliance Audit

Scan all frontend files for raw values that should use design tokens:

1. **Raw colors** — hex (`#xxx`, `#xxxxxx`), `rgb()`, `rgba()`, `hsl()`, `hsla()` in component files. Each must be replaced with `var(--color-*)`.
2. **Raw spacing** — hardcoded `padding`, `margin`, `gap` values in px/rem that don't map to the `--space-*` scale.
3. **Raw radius** — hardcoded `border-radius` values instead of `--radius-*` tokens.
4. **Raw font sizes** — hardcoded `font-size` instead of `--text-*` scale.
5. **Inline styles** — `style={{}}` or `style=""` in JSX/HTML.
6. **Raw shadows** — hardcoded `box-shadow` instead of `--shadow-*` tokens.

```bash
# Automated detection
grep -rn '#[0-9a-fA-F]\{3,8\}' --include='*.tsx' --include='*.jsx' --include='*.css' | grep -v 'node_modules\|dist\|build\|\.d\.ts'
grep -rn 'style={{' --include='*.tsx' --include='*.jsx' | grep -v 'node_modules'
grep -rn 'border-radius:\s*[0-9]' --include='*.css' --include='*.tsx' | grep -v 'var(--'
```

Exclude: `design-tokens.css` itself, config files, SVG attributes, test files.

### Phase 2: Anti-Pattern Detection

Read `../../references/design-anti-patterns.md` for the full catalog. Check for:

1. **Default fonts** — Inter or Roboto as the ONLY font with no display variant.
2. **Gradient backgrounds** — `linear-gradient`, `radial-gradient` on page/section backgrounds.
3. **Cards in cards** — nested bordered containers creating depth confusion.
4. **Uniform spacing** — same padding/margin value used more than 10 times with no variation.
5. **Emoji as icons** — emoji characters used in UI elements (not content).
6. **Cookie-cutter layouts** — 3-column equal-width grids repeated across pages.
7. **Generic copy** — marketing-speak placeholders that survived into production.
8. **Excessive color count** — more than 4 distinct accent/brand colors (excluding semantic).

### Phase 3: Visual State Completeness

For each interactive or data-displaying component:

1. **Interactive states** — verify: default, hover, focus-visible, active, disabled.
2. **Data states** — verify: loading (skeleton/spinner), empty (helpful message), error (actionable message), populated (actual content).
3. **Responsive states** — verify the component works at mobile (320px), tablet (768px), desktop (1280px) widths. Check for horizontal overflow, text truncation, touch targets.

Flag components that only implement the happy-path populated state.

### Phase 4: Accessibility Scan

Read `../../references/design-a11y.md` for the full checklist. Automated checks:

```bash
# Missing alt text
grep -rn '<img' --include='*.tsx' --include='*.jsx' | grep -v 'alt='

# Div click handlers (should be button)
grep -rn 'onClick' --include='*.tsx' --include='*.jsx' | grep '<div'

# Focus removal
grep -rn 'outline:\s*none\|outline:\s*0' --include='*.css' --include='*.tsx'

# Placeholder-only inputs (no label)
grep -rn 'placeholder=' --include='*.tsx' --include='*.jsx' -B2 | grep -v 'label\|Label\|aria-label\|htmlFor'
```

Manual checks:
1. **Semantic structure** — does the page use `<main>`, `<nav>`, `<header>`, `<section>`?
2. **Heading hierarchy** — one `<h1>`, no skipped levels?
3. **Skip link** — present as first focusable element?
4. **ARIA roles** — modals have `role="dialog"`, alerts have `role="alert"`?
5. **Contrast** — text/background combinations meet 4.5:1 (normal) or 3:1 (large text)?

### Phase 5: Cross-Component Consistency

1. **Button variants** — are buttons consistent across views? Same padding, radius, font weight?
2. **Spacing rhythm** — do sections use consistent spacing tokens, or does every page invent its own?
3. **Color usage** — is the accent color used consistently for the same semantic purpose (CTAs, links)?
4. **Typography** — are heading sizes consistent across pages at the same hierarchy level?
5. **Component reuse** — are there duplicate components (two different Card implementations, two Modal wrappers)?

### Phase 6: Produce Findings

Format each finding:

```
## [SEVERITY] Finding Title

**Category**: Token Violation | Anti-Pattern | Missing State | A11y Failure | Inconsistency
**Location**: file/path:line

**What exists**: The current code/styling.

**What's wrong**: Which specific anti-pattern, violation, or failure this triggers.

**Evidence**: The raw value, the missing state, the a11y failure, the inconsistency.

**Impact**: What the user experiences — broken a11y, AI-looking UI, inconsistent feel.

**Fix**: Specific change — which token to use, which element to swap, which state to add.
```

Severity levels:
- **CRITICAL** — Accessibility failure blocking WCAG AA compliance (missing labels, no keyboard access, color-only indicators), hardcoded credentials in frontend code
- **HIGH** — Raw color/spacing values throughout (design system not used), missing error/loading states on critical flows, multiple AI anti-patterns on user-facing pages
- **MEDIUM** — Inconsistent component usage across views, minor token violations, missing responsive handling, cosmetic anti-patterns (uniform spacing, default fonts)
- **LOW** — Single-instance token violations, aspirational improvements (better empty states, animation refinement), minor inconsistencies

### Summarize

End with:
- Count by category (Token Violation, Anti-Pattern, Missing State, A11y Failure, Inconsistency)
- Count by severity
- AI slop score — how many of the 17 anti-patterns are present (0/17 is perfect)
- Top 5 most visible issues (the ones users will notice first)
- Overall assessment: does this UI look intentionally designed, or does it look AI-generated?

## Execution Mode

See `references/review-lens-framework.md`. Lens: `ui-review`.

## References (on-demand)

Read these from the shared `../../references/` directory when needed:
- `design-tokens.css` — The token vocabulary to audit against
- `design-anti-patterns.md` — Full catalog of 17 AI slop patterns with detection commands
- `design-typography.md` — Font rules, banned fonts, pairing guidelines
- `design-colors.md` — Palette rules, contrast requirements, OKLCH guidance
- `design-a11y.md` — WCAG 2.2 checklist, 10 common AI a11y failures, testing commands

## Examples

```
User: Review the frontend before we deploy.
-> Full 6-phase review. Token audit, anti-pattern scan, state completeness,
   a11y check, consistency audit. Produce prioritized findings.
```

```
User: This dashboard looks like AI made it. What's wrong?
-> Emphasis on Phase 2 (anti-patterns). Identify which of the 17 patterns are
   present. Also check Phase 1 (tokens) since raw values enable the slop look.
```

```
User: Check accessibility on the new forms.
-> Emphasis on Phase 4 (a11y). Focus on form-specific checks: labels, error
   messages, required indicators, keyboard navigation. Also Phase 3 for error
   state completeness.
```

```
User: Run ui-review after the UI sprint.
-> Post-sprint audit. All phases with emphasis on Phase 5 (consistency) since
   sprint work tends to drift from established patterns.
```

---

Before completing, read and follow `../../references/review-lens-framework.md` and `../../references/cross-cutting-rules.md`.
