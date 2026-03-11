---
name: browser-review
description: Visual QA via browser MCP tools (Playwright/browser-use). Use when reviewing UI, checking for visual bugs, or inspecting a web interface after frontend changes.
---

# Browser Review

Perform thorough visual QA by navigating a web interface, taking screenshots
between every action, and reviewing each screenshot for regressions, design
compliance, layout issues, accessibility problems, and visual bugs.

## Inputs

- **Target URL** or an already-active browser session
- **Design specs** (optional) — Figma URL, design tokens file, style guide,
  or verbal description of expected appearance
- **Viewport sizes** (optional) — specific breakpoints to test. Default:
  desktop (1440x900), tablet (768x1024), mobile (375x812)

## Outputs

- Visual QA findings with screenshot references. Each finding includes what
  is wrong, where it appears, expected vs actual, and severity.
- Summary verdict: ship-ready, needs fixes, or blocked.

## Exit Condition

All visible screens and states have been reviewed, findings are documented
with screenshot evidence, and a summary verdict is delivered.

## Prerequisites

At least one browser MCP toolset is available. Check for:
- **Playwright**: `browser_navigate`, `browser_snapshot`, `browser_take_screenshot`
- **browser-use**: `browse`, `browse_screenshot`, `browse_extract`

If neither is available, tell the user to connect a browser MCP and stop.
Do not attempt to review without visual tools.

## Instructions

### 1. Establish Baseline

Navigate to the target URL (or confirm the current browser state if a
session is already active). Take an initial screenshot before any
interaction. This is the baseline — all subsequent screenshots are compared
against it to identify deltas.

```
Playwright: browser_navigate -> browser_take_screenshot
browser-use: browse (navigate) -> browse_screenshot
```

### 2. Systematic Page Review

Review the initial screenshot against the design review checklist (below).
Document every issue found. Then systematically navigate through the
application:

- **Primary navigation** — click through each nav item, take a screenshot
  after each transition
- **Interactive elements** — hover states, focus states, active states for
  buttons, links, form inputs
- **Form flows** — empty state, validation errors, success state
- **Empty states** — pages with no data
- **Error states** — trigger 404, permission denied, or network error if
  possible
- **Loading states** — if the app has async data, capture the loading
  indicator

Between every navigation or interaction, take a screenshot and review the
delta from the previous state.

### 3. Responsive Testing

If viewport sizes were specified (or using defaults), resize the browser
and repeat the review at each breakpoint:

```
Playwright: browser_resize -> browser_take_screenshot
```

Focus on:
- Content reflow and text wrapping
- Navigation collapse (hamburger menu behavior)
- Touch target sizes (minimum 44x44px)
- Image scaling and cropping
- Horizontal scrolling (should not exist unless intentional)

### 4. Design Compliance Check

If design specs are available (Figma URL, design tokens, style guide),
compare each screenshot against the spec:

- **Colors** — do they match the design tokens? Use the Figma MCP
  (`get_design_context`, `get_variable_defs`) if a Figma URL is provided
- **Typography** — correct font family, size, weight, line height
- **Spacing** — margins and padding match the design system grid
- **Components** — do interactive elements match their spec (button
  variants, input styles, card layouts)

Without design specs, use general best-practice standards instead and note
that no design spec was available for comparison.

### 5. Accessibility Spot Check

Visual accessibility issues that can be caught from screenshots:

- **Color contrast** — text against background meets WCAG AA (4.5:1 for
  normal text, 3:1 for large text). Flag anything that looks low-contrast
- **Focus indicators** — tab through interactive elements and verify visible
  focus rings
- **Text readability** — minimum 16px body text, adequate line spacing,
  no text over busy backgrounds
- **Alt text** — use browser_snapshot or browse_extract to check that images
  have alt attributes
- **Keyboard navigation** — use browser_press_key (Tab, Enter, Escape) and
  verify the interface is navigable without a mouse
- **Landmarks** — check for semantic HTML structure (header, main, nav,
  footer) via DOM inspection

### 6. Document Findings

For each issue found, record:

```
## [SEVERITY] Finding Title

**Type**: Layout | Typography | Color | Component | Accessibility | Responsive | State
**Location**: Page/route + element description
**Screenshot**: Reference to the screenshot where this was observed

**Expected**: What it should look like (from design spec or best practice)
**Actual**: What it actually looks like

**Recommendation**: Specific fix suggestion
```

Severity levels:
- **CRITICAL** — Blocks usage. Broken layout, unreadable text, inaccessible
  primary flow
- **HIGH** — Significant visual defect visible to all users
- **MEDIUM** — Noticeable issue that degrades perceived quality
- **LOW** — Minor polish item or enhancement suggestion

### 7. Summary Verdict

End with a summary:

```
## Visual QA Summary

| Severity | Count |
|---|---|
| Critical | N |
| High | N |
| Medium | N |
| Low | N |

**Verdict**: Ship-ready / Needs fixes before ship / Blocked — critical issues

**Top 3 Issues**:
1. ...
2. ...
3. ...
```

- **Ship-ready** — zero critical or high issues, any medium/low are cosmetic
- **Needs fixes** — one or more high issues, or 3+ medium issues
- **Blocked** — any critical issue exists

## Design Review Checklist

Use this checklist for every screenshot review. Not every item applies to
every screenshot — use judgment.

**Typography**
- Font family matches design system
- Font sizes are consistent and hierarchical
- Line height provides comfortable reading
- No orphaned words or awkward line breaks in headings

**Spacing**
- Consistent padding within components
- Consistent margins between components
- Adequate whitespace — nothing feels cramped or floating
- Alignment to grid (if design system uses one)

**Color**
- Background/foreground contrast meets WCAG AA
- Brand colors used consistently
- No unexpected color shifts (wrong theme, stale CSS)
- Hover/active states have visible color change

**Layout**
- No overlapping elements
- No unexpected horizontal scroll
- Content fills available space appropriately
- Responsive breakpoints transition cleanly

**Components**
- Buttons have all states: default, hover, active, disabled, loading
- Form inputs show: empty, filled, focused, error, disabled
- Cards/lists handle variable content length
- Empty states have helpful messaging (not blank screens)
- Loading indicators present where async data loads

**Accessibility**
- Focus indicators visible on all interactive elements
- Skip-to-content link present
- Color is not the only differentiator (icons, patterns, labels)
- Interactive elements have adequate touch targets

## Examples

```
User: Check if the new dashboard page looks right.
--> Navigate to the dashboard URL. Take screenshot. Review against the
    checklist. Test responsive breakpoints. Document findings. Deliver
    verdict.
```

```
User: I just pushed a CSS refactor. Can you do a visual QA pass?
--> Navigate to the app root. Systematically click through all major routes,
    screenshotting each. Compare against previous known-good state (if
    available) or check for obvious regressions. Focus on layout breakage
    and color consistency since CSS was refactored.
```

```
User: Does the mobile view look right? Check on iPhone dimensions.
--> Resize browser to 375x812. Navigate through primary flows. Screenshot
    each screen. Focus on responsive issues: touch targets, text wrapping,
    nav collapse, horizontal scroll.
```

```
User: Compare the implementation against this Figma design. [Figma URL]
--> Use Figma MCP to pull design context and variable definitions. Navigate
    to the implementation. Take screenshots. Side-by-side comparison against
    Figma specs for colors, typography, spacing, and component fidelity.
    Document every deviation.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
