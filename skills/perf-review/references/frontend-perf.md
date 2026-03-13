# Frontend Performance Anti-Pattern Catalog

Reference for perf-review §6. Organized by framework with Core Web Vitals impact notes.

## React-Specific Patterns

### Unnecessary Re-Renders

**Detection signals:**
- Components without `React.memo` that receive object/array/function props (new reference every render)
- Inline object/array literals in JSX props: `style={{ color: 'red' }}`, `options={[1,2,3]}`
- Inline arrow functions as event handlers: `onClick={() => handleClick(id)}`
- Context providers wrapping large subtrees with frequently changing values
- State lifted too high — parent re-renders causing all children to re-render
- Missing `key` prop or using array index as key on dynamic lists

```tsx
// BAD — creates new object every render, causing child to re-render
function Parent() {
  const [count, setCount] = useState(0)
  return <Child style={{ margin: 10 }} onClick={() => setCount(c => c + 1)} />
}

// GOOD — stable references
const style = { margin: 10 }
function Parent() {
  const [count, setCount] = useState(0)
  const handleClick = useCallback(() => setCount(c => c + 1), [])
  return <Child style={style} onClick={handleClick} />
}
```

**When NOT to flag:**
- Components that render rarely (routes, modals, settings pages)
- Components with trivial render cost (pure text, simple layouts)
- `useMemo`/`useCallback` on cheap operations (the hook itself has overhead)

### State Management Anti-Patterns

- **Over-use of global state**: Putting form state, UI state, or ephemeral state in Redux/Zustand when local state would suffice — forces unnecessary subscriber re-renders
- **Missing selector optimization**: `useSelector(state => state)` instead of selecting specific slices
- **Derived state stored as state**: Computing values in useEffect and storing them when `useMemo` would work without the extra render cycle

### Effect Anti-Patterns

```tsx
// BAD — sets state in effect that triggers another render
useEffect(() => {
  setFilteredItems(items.filter(i => i.active))
}, [items])

// GOOD — derive inline
const filteredItems = useMemo(() => items.filter(i => i.active), [items])
```

## Vue-Specific Patterns

### Reactivity Overhead

- **Large reactive objects**: Making entire API responses reactive when only a few fields are used
- **Deep watching**: `watch(obj, cb, { deep: true })` on large objects — use specific property watches
- **Computed without cache benefit**: Computed properties that always return new objects/arrays (defeats caching)
- **v-if vs v-show**: Using `v-if` for frequently toggled elements (destroys/recreates DOM vs CSS toggle)

### List Rendering

```vue
<!-- BAD — missing key or index key on dynamic list -->
<div v-for="item in items">{{ item.name }}</div>

<!-- GOOD — stable unique key -->
<div v-for="item in items" :key="item.id">{{ item.name }}</div>
```

## Svelte-Specific Patterns

- **Reactive statement overuse**: `$:` blocks that trigger on unrelated state changes
- **Large component files**: Svelte compiles per-component — large files produce large JS output
- **Missing transition optimization**: Transitions on list items without `|local` modifier

## Framework-Agnostic Patterns

### Bundle Size

**Detection signals:**
- Importing entire libraries for single functions:
  ```javascript
  // BAD — imports entire lodash (~70KB min)
  import _ from 'lodash'
  const result = _.get(obj, 'a.b.c')

  // GOOD — tree-shakeable import (~1KB)
  import get from 'lodash/get'
  ```
- Missing dynamic imports for route-level code splitting:
  ```javascript
  // BAD — eager import of all routes
  import Settings from './pages/Settings'

  // GOOD — lazy load routes
  const Settings = lazy(() => import('./pages/Settings'))
  ```
- Large dependencies for small use cases (moment.js for date formatting, date-fns is lighter)
- Polyfills for features with >95% browser support (check browserslist config)
- CSS-in-JS runtime in production (consider extraction at build time)

**Quantitative thresholds:**
- Initial JS bundle > 200KB (gzipped): investigate splitting
- Single vendor chunk > 100KB (gzipped): investigate tree-shaking
- Any single dependency > 50KB (gzipped): evaluate alternatives

### Images & Media

- **Missing lazy loading**: Images below the fold loading eagerly (use `loading="lazy"`)
- **Missing srcset/sizes**: Single resolution images served to all screen densities
- **Uncompressed formats**: Using PNG/JPEG where WebP/AVIF would reduce size 30-50%
- **Missing width/height**: Images without dimensions cause layout shift (CLS impact)
- **Large hero images**: Above-the-fold images > 200KB not preloaded

### Layout & Rendering

- **Layout thrashing**: Reading layout properties then writing styles in the same frame
  ```javascript
  // BAD — forces layout recalculation per iteration
  elements.forEach(el => {
    const height = el.offsetHeight  // Read (triggers layout)
    el.style.height = height + 10 + 'px'  // Write (invalidates layout)
  })

  // GOOD — batch reads, then batch writes
  const heights = elements.map(el => el.offsetHeight)
  elements.forEach((el, i) => {
    el.style.height = heights[i] + 10 + 'px'
  })
  ```
- **Forced synchronous layout**: Accessing `offsetWidth`, `scrollHeight`, etc. after style changes
- **Expensive CSS selectors**: Deep nesting, universal selectors, attribute selectors on large DOMs
- **Missing `will-change`**: Animated elements without compositor hints (triggers paint, not composite)
- **Large DOM**: > 1,500 nodes visible at once — consider virtualization (react-window, tanstack-virtual)

### Core Web Vitals Impact Reference

| Anti-Pattern | LCP | FID/INP | CLS |
|---|---|---|---|
| Large unoptimized images | HIGH | — | — |
| Render-blocking JS/CSS | HIGH | — | — |
| Missing code splitting | HIGH | MEDIUM | — |
| Layout thrashing | — | HIGH | — |
| Unnecessary re-renders | — | HIGH | — |
| Missing image dimensions | — | — | HIGH |
| Font loading without `font-display` | — | — | HIGH |
| Dynamic content injection | — | — | HIGH |

### Font Loading

- **Missing `font-display: swap`**: Text invisible until font loads (FOIT)
- **Too many font weights/styles**: Each variant is a separate download
- **Missing `preload` for critical fonts**: Fonts discovered late in the cascade
- **Web fonts for icon-only use**: Consider inline SVG instead

### Third-Party Scripts

- **Undeferred analytics/tracking**: Loading analytics synchronously blocks rendering
- **Chat widgets loading on every page**: Lazy-load to pages where users actually need them
- **Missing `async` on non-critical scripts**: Blocks parsing/rendering
- **No resource hints**: Missing `dns-prefetch` or `preconnect` for third-party origins
