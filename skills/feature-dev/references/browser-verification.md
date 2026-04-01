# Browser Verification (UI Stories)

Use Playwright MCP for UI story verification.

## Method Selection

**Functional testing (is the element there?):**
- `browser_snapshot` — returns accessibility tree (token-efficient)
- Check for element presence, text content, structure

**Visual testing (does it look right?):**
- `browser_screenshot` — captures visual appearance
- Check layout, styling, visual regressions

## Workflow

```
1. browser_navigate to URL
2. browser_snapshot to see page structure
3. browser_click, browser_type as needed
4. browser_snapshot again to confirm changes
5. browser_screenshot if visual check needed
```

Document verification results in the artifact DB story completion record.
