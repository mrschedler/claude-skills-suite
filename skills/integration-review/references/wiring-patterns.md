# Wiring Patterns by Language & Framework

Reference for integration-review Phase 1 (surface mapping) and Phase 2 (dead wiring detection).

## Export/Import Patterns

### TypeScript / JavaScript

**Exports to track:**
```
export function X         →  grep -rn 'export function'
export const X            →  grep -rn 'export const'
export class X            →  grep -rn 'export class'
export default X          →  grep -rn 'export default'
export { X }              →  grep -rn 'export {'
module.exports            →  grep -rn 'module\.exports'
exports.X                 →  grep -rn 'exports\.'
```

**Imports to match:**
```
import { X } from        →  grep -rn 'import.*from'
import X from             →  (default import)
const X = require(        →  grep -rn 'require('
dynamic import()          →  grep -rn 'import('
```

**Framework entry points (exclude from dead wiring):**
- React: components in route files, pages/ directory, layouts
- Next.js: `default export` in `app/` or `pages/` directories
- Express/Fastify: route handler functions passed to `app.get/post/...`
- Tauri: `#[tauri::command]` functions registered in `invoke_handler`
- Test files: all exports (consumed by test runner, not import chain)

### Rust

**Exports:**
```
pub fn X                  →  grep -rn 'pub fn'
pub struct X              →  grep -rn 'pub struct'
pub enum X                →  grep -rn 'pub enum'
pub mod X                 →  grep -rn 'pub mod'
pub use X                 →  grep -rn 'pub use' (re-exports)
```

**Imports:**
```
use crate::X              →  grep -rn 'use crate::'
use super::X              →  grep -rn 'use super::'
use X::Y                  →  grep -rn 'use [a-z]'
```

**Entry points to exclude:**
- `fn main()`, `#[tokio::main]`
- `#[tauri::command]` functions
- `#[test]` functions
- Trait implementations (`impl X for Y`)

### Python

**Exports:**
```
def X(                    →  grep -rn 'def [a-z]'
class X(                  →  grep -rn 'class [A-Z]'
X = ...  (module-level)   →  module-level assignments
__all__ = [...]           →  explicit export list
```

**Imports:**
```
from X import Y           →  grep -rn 'from.*import'
import X                  →  grep -rn '^import '
```

## Dead Wiring Patterns

### Placeholder Session/ID Values

Hardcoded strings where dynamic values should be wired:

```bash
# Generic placeholders
grep -rn "'axys-server'\|'test-session'\|'default-session'\|'placeholder'" --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' --include='*.rs' --include='*.py'

# Hardcoded IDs in non-test code
grep -rn "'session-[0-9]\+'\|'conn-[0-9]\+'\|'user-[0-9]\+'" --include='*.ts' --include='*.js' --exclude-dir='test*' --exclude-dir='__test*'

# UUID/ID patterns that look hardcoded
grep -rn "'[0-9a-f]\{8\}-[0-9a-f]\{4\}-'" --include='*.ts' --include='*.js' --exclude-dir='test*' --exclude='*.test.*' --exclude='*.spec.*'
```

### Orphaned Event Handlers

```bash
# Find all event registrations
grep -rn '\.on(\|\.addEventListener(\|\.subscribe(' --include='*.ts' --include='*.tsx' --include='*.js'

# Find all event emissions — cross-reference
grep -rn '\.emit(\|\.dispatchEvent(\|\.publish(' --include='*.ts' --include='*.tsx' --include='*.js'

# Events registered but never emitted = orphaned handlers
# Events emitted but never registered = dead signals
```

### Registered but Unreachable Routes

```bash
# Express/Fastify route registrations
grep -rn 'app\.\(get\|post\|put\|delete\|patch\)(' --include='*.ts' --include='*.js'
grep -rn 'router\.\(get\|post\|put\|delete\|patch\)(' --include='*.ts' --include='*.js'

# Tauri command registrations
grep -rn 'invoke_handler' --include='*.rs'
grep -rn '#\[tauri::command\]' --include='*.rs'

# Frontend invoke calls — cross-reference with backend handlers
grep -rn 'invoke(' --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx'
```

### Tauri-Specific Wiring

```bash
# IPC commands registered in Rust but never invoked from frontend
grep -rn '#\[tauri::command\]' --include='*.rs' | sed 's/.*fn \([a-z_]*\).*/\1/'
# Cross-reference each with:
grep -rn 'invoke.*COMMAND_NAME' --include='*.ts' --include='*.tsx'

# Sidecar references in code vs tauri.conf.json
grep -rn 'sidecar\|Command::new_sidecar' --include='*.rs'
# Cross-reference with tauri.conf.json bundle.externalBin
```

### React-Specific Wiring

```bash
# Components defined but never rendered
grep -rn 'export.*function [A-Z]\|export default function [A-Z]' --include='*.tsx' --include='*.jsx'
# Cross-reference with JSX usage:
grep -rn '<ComponentName' --include='*.tsx' --include='*.jsx'

# Context providers defined but never used
grep -rn 'createContext\|React\.createContext' --include='*.tsx' --include='*.ts'
# Cross-reference with:
grep -rn 'useContext(\|<.*Provider' --include='*.tsx' --include='*.jsx'

# Custom hooks defined but never called
grep -rn 'export.*function use[A-Z]' --include='*.ts' --include='*.tsx'
# Cross-reference with usage in other files
```

## One-Way Integration Detection

Look for imports that are assigned but never used in any code path:

```bash
# TypeScript: imported but only appears on the import line
# For each import, count occurrences in the file beyond the import statement
# If count == 1 (only the import line), it's unused
```

This requires file-level analysis, not just grep. For each file:
1. List all imports
2. For each imported name, search the rest of the file for usage
3. Flag imports that appear only on the import line
