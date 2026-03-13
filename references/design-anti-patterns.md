# AI-Generated UI Anti-Patterns

Reference for ui-design and ui-review. These are the telltale signs that an AI made
the interface. Every pattern here is banned from production output.

## Root Cause

Anthropic calls it **distributional convergence** — models trained on the statistical
center of design decisions. The result: every AI UI looks the same. Same fonts, same
colors, same layouts, same copy. Users can spot it instantly.

## The Banned List

### Visual Anti-Patterns

| # | Pattern | Why It's Bad | What to Do Instead |
|---|---------|-------------|-------------------|
| 1 | **Inter/Roboto everywhere** | Default font = default look. Screams "AI made this" | Use project font stack. If no brand font, pick ONE distinctive sans from Google Fonts (e.g., Instrument Sans, Plus Jakarta Sans, Geist) |
| 2 | **Purple gradient on white** | The single most common AI color scheme | Use restrained palette from design tokens. ONE accent color, not a gradient |
| 3 | **Uniform 8px border-radius** | Same radius on everything = no visual hierarchy | Vary radius by element: inputs (sm), cards (md), modals (lg). Use token scale |
| 4 | **Cards nested in cards** | Depth confusion. AI loves wrapping everything in bordered boxes | Flat layout with whitespace separation. Cards only for discrete content units |
| 5 | **Gray text on colored backgrounds** | Contrast failure. AI picks "muted" text that fails WCAG | Check contrast ratios. Use semantic text tokens that respect background |
| 6 | **Emoji as visual design** | Cheap substitute for real iconography | Use a coherent icon set (Lucide, Heroicons, Phosphor) or no icons at all |
| 7 | **Evenly-distributed palettes** | 5+ colors all given equal weight | Restrain to 2-3 colors max. One dominant, one accent, one neutral |
| 8 | **Uniform spacing** | Same padding/margin everywhere. No rhythm | Use spacing scale with intentional variation. More space between sections, less within |
| 9 | **Stock hero sections** | Centered heading + subtitle + CTA button + stock gradient | Design from content out. What does THIS page need to communicate? |
| 10 | **Cookie-cutter 3-column grid** | Every feature section = three equal cards side by side | Asymmetric layouts, varied content presentation, break the grid |
| 11 | **"Vibe writing" copy** | "Empowering your future with seamless solutions" | Real words. What does this actually do? Say that |

### Functional Anti-Patterns

| # | Pattern | Why It's Bad | What to Do Instead |
|---|---------|-------------|-------------------|
| 12 | **Missing error states** | Only the happy path exists | Design error, empty, loading, and partial states for every view |
| 13 | **No loading states** | Content appears with no transition | Skeleton loaders or subtle fade-in. Never a blank flash |
| 14 | **Missing keyboard navigation** | Tab order broken, no focus styles | Semantic HTML + visible focus indicators + skip links |
| 15 | **Inline styles** | `style={{color: '#2563EB'}}` hardcoded | Token references only. No raw values in component code |
| 16 | **Inconsistent components** | Button looks different on every page | Shared component library. One Button, one Input, one Card |
| 17 | **Decorative elements > function** | Floating orbs, animated gradients, particle backgrounds | Remove unless it serves the content. Decoration must justify its existence |

## Detection Strategy

For each pattern, the detection approach:

**Grep-detectable** (automated):
```
# Raw color values (should use tokens)
grep -rn '#[0-9a-fA-F]\{3,8\}' --include='*.tsx' --include='*.jsx' --include='*.css'
grep -rn 'rgb\|rgba\|hsl\|hsla' --include='*.tsx' --include='*.jsx' --include='*.css'

# Inline styles
grep -rn 'style={{' --include='*.tsx' --include='*.jsx'
grep -rn 'style="' --include='*.tsx' --include='*.jsx'

# Default fonts
grep -rn 'font-family.*Inter\|font-family.*Roboto' --include='*.css' --include='*.tsx'

# Emoji in UI code (not in comments/docs)
grep -rn '[\x{1F600}-\x{1F64F}]' --include='*.tsx' --include='*.jsx'

# Hardcoded spacing/radius
grep -rn 'padding:\s*[0-9]' --include='*.css' --include='*.tsx'
grep -rn 'border-radius:\s*[0-9]' --include='*.css' --include='*.tsx'
```

**Requires visual review** (ui-review Phase 3):
- Cards nested in cards
- Uniform spacing rhythm
- Stock hero layouts
- Cookie-cutter grids
- Copy quality ("vibe writing")
- Missing states (error, empty, loading)

## The Test

Ask this about every UI output: **"Could a human tell an AI made this?"**

If yes, it fails. Identify which patterns above are present and fix them.
