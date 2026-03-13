# Accessibility Checklist

Reference for ui-design and ui-review. Accessibility is non-negotiable — public-facing
apps must comply with WCAG 2.1 Level AA (legally required as of 2026 for public agencies).
This checklist covers the issues AI-generated code most commonly misses.

## The 10 AI-Generated A11y Failures

These are the accessibility bugs that LLM-generated UI code produces most often:

### 1. Missing alt text on images
```tsx
// BAD
<img src="/hero.png" />

// GOOD
<img src="/hero.png" alt="Dashboard overview showing three active projects" />

// GOOD (decorative)
<img src="/divider.svg" alt="" role="presentation" />
```

### 2. Div soup instead of semantic HTML
```tsx
// BAD — screen reader sees nothing
<div class="nav"><div class="item">Home</div></div>

// GOOD — screen reader announces navigation
<nav aria-label="Main"><a href="/">Home</a></nav>
```

**Rule**: Use `<nav>`, `<main>`, `<section>`, `<aside>`, `<header>`, `<footer>`,
`<article>`, `<button>`, `<a>` before reaching for `<div>`.

### 3. No visible focus indicators
```css
/* BAD — removes focus for everyone */
*:focus { outline: none; }

/* GOOD — custom focus that's visible */
:focus-visible {
  outline: 2px solid var(--color-accent);
  outline-offset: 2px;
}
```

### 4. Click handlers on divs instead of buttons
```tsx
// BAD — not keyboard accessible, no role, no focus
<div onClick={handleSubmit}>Submit</div>

// GOOD
<button onClick={handleSubmit}>Submit</button>
```

### 5. Color as sole indicator
```tsx
// BAD — colorblind users can't tell valid from invalid
<input style={{ borderColor: isValid ? 'green' : 'red' }} />

// GOOD — icon + text + color
<input aria-invalid={!isValid} />
{!isValid && <span role="alert">Required field</span>}
```

### 6. Missing form labels
```tsx
// BAD
<input type="email" placeholder="Email" />

// GOOD
<label htmlFor="email">Email</label>
<input id="email" type="email" placeholder="you@example.com" />
```

### 7. No skip link
```tsx
// Add as first focusable element in the page
<a href="#main-content" className="sr-only focus:not-sr-only">
  Skip to main content
</a>
```

### 8. Inaccessible modals
```tsx
// Required for modals:
// - role="dialog" and aria-modal="true"
// - Focus trapped inside while open
// - Escape key closes
// - Focus returns to trigger element on close
// - aria-labelledby pointing to modal title

// Use Radix Dialog, Headless UI Dialog, or <dialog> element
```

### 9. Missing aria-live for dynamic content
```tsx
// Toast notifications, form errors, loading status
<div role="alert" aria-live="assertive">
  {error && <p>{error.message}</p>}
</div>

// Less urgent updates
<div aria-live="polite">
  {results.length} results found
</div>
```

### 10. Touch targets too small
```css
/* Minimum 44x44px touch target (WCAG 2.5.8) */
button, a, [role="button"] {
  min-height: 44px;
  min-width: 44px;
}
```

## Media Query Respect

Every UI must honor these user preferences:

```css
/* Motion sensitivity */
@media (prefers-reduced-motion: reduce) {
  * { animation-duration: 0ms !important; transition-duration: 0ms !important; }
}

/* High contrast needs */
@media (prefers-contrast: more) {
  /* Increase border visibility, remove subtle backgrounds */
}

/* Dark mode preference */
@media (prefers-color-scheme: dark) {
  /* Handled by design tokens automatically */
}
```

## Testing Commands

```bash
# Check for missing alt text
grep -rn '<img' --include='*.tsx' --include='*.jsx' | grep -v 'alt='

# Check for div click handlers (should be button)
grep -rn 'onClick' --include='*.tsx' --include='*.jsx' | grep '<div'

# Check for outline: none (focus removal)
grep -rn 'outline:\s*none\|outline:\s*0' --include='*.css' --include='*.tsx'

# Check for placeholder-only inputs (no label)
grep -rn 'placeholder=' --include='*.tsx' --include='*.jsx' -A2 | grep -v 'label\|Label\|aria-label'
```

## Quick Audit Protocol

For ui-review, run in this order:
1. **Landmarks**: Does the page have `<main>`, `<nav>`, `<header>`?
2. **Headings**: Is there one `<h1>`? Do heading levels skip (h1→h3)?
3. **Images**: Do all `<img>` have `alt`?
4. **Forms**: Do all inputs have visible labels?
5. **Interactive**: Are all clickables `<button>` or `<a>`?
6. **Focus**: Tab through the page — is every control reachable? Is focus visible?
7. **Color**: Remove all color — is everything still understandable?
8. **Motion**: Enable reduce-motion — do animations stop?
