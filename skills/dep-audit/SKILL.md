---
name: dep-audit
description: Audits dependency health: CVEs, outdated versions, license conflicts, abandoned packages. Auto-installs audit tools. Use before deploys or quarterly.
---

# Dependency Audit

## Purpose

Assess dependency health beyond security vulnerabilities. security-review §3 catches
supply chain *attacks* (hallucination, typosquatting, install scripts). This skill catches
dependency *decay*: packages that are outdated, abandoned, license-incompatible, bloating
the bundle, or approaching EOL. The question isn't "is this dangerous?" — it's "is this
maintainable?"

## Inputs

- Dependency manifests: `package.json`, `requirements.txt`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `Gemfile`, `composer.json`, `pom.xml`
- Lock files: `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `poetry.lock`, `Pipfile.lock`, `go.sum`, `Cargo.lock`, `Gemfile.lock`, `composer.lock`
- `project-context.md` — to understand license constraints and deployment targets
- `.npmrc`, `.yarnrc`, `.pip.conf` — package registry configuration if present

## Outputs

- **Standalone mode**: Store findings in the artifact DB:
  ```bash
  source artifacts/db.sh
  db_upsert 'dep-audit' 'findings' 'standalone' "$FINDINGS_CONTENT"
  ```
- **Multi-model mode** (called by meta-review): Store per-model findings:
  - Sonnet: `db_upsert 'dep-audit' 'findings' 'sonnet' "$CONTENT"`
  - Codex: `db_upsert 'dep-audit' 'findings' 'codex' "$CONTENT"`
  - Gemini: `db_upsert 'dep-audit' 'findings' 'gemini' "$CONTENT"`

## Instructions

### Fresh Findings Check

Before running a new scan, check if fresh findings already exist:
```bash
source artifacts/db.sh
AGE=$(db_age_hours 'dep-audit' 'findings' 'standalone')
```
If `$AGE` is non-empty and less than 24, report: "Found fresh dep-audit findings from $AGE hours ago. Reuse them? (y/n)"
If the user says yes, read findings from DB. If no record exists or user says no, proceed.

### 1. Detect Ecosystem

Scan the project root for dependency manifests to determine which ecosystems are present:
- **Node.js**: `package.json` (npm/yarn/pnpm)
- **Python**: `requirements.txt`, `pyproject.toml`, `Pipfile`, `setup.py`
- **Go**: `go.mod`
- **Rust**: `Cargo.toml`
- **Ruby**: `Gemfile`
- **PHP**: `composer.json`
- **Java/Kotlin**: `pom.xml`, `build.gradle`, `build.gradle.kts`

Multiple ecosystems may coexist (e.g., Node + Python in a monorepo). Handle each
independently.

### 2. Tool Discovery & Setup

For each detected ecosystem, check if the required audit tools are available.
If missing, attempt to install them. If installation fails, fall back to static
manifest analysis only.

Read `references/audit-checks.md` for the full tool list, install commands, and
fallback strategies per ecosystem.

**Discovery pattern** for each ecosystem:
1. Check if the primary audit tool exists (e.g., `which npm` → `npm audit`)
2. Check if supplementary tools exist (e.g., `npx license-checker --help`)
3. If a required tool is missing:
   - Attempt install via local/user-scoped method:
     - Node: `npx <tool>` (runs without global install) or `npm install -g <tool>`
     - Python: `pipx install <tool>` or `pip install --user <tool>`
     - Rust: `cargo install <tool>`
     - Go: `go install <tool>@latest`
   - If install fails (permissions, network, missing runtime), note the gap and
     proceed with available tools
4. Log which tools are available, which were installed, and which were skipped

**Never install tools globally with sudo.** Use npx, pipx, or local installs only.

### 3. Run Audit Tools

Execute audit tools for each detected ecosystem and capture output.
All ecosystems can run in parallel (separate tool chains, no conflicts).

Read `references/audit-checks.md` for exact commands and output parsing per ecosystem.

For each ecosystem, capture three categories:
- **CVE/advisory scan**: `npm audit --json`, `pip audit --format json`, `cargo audit --json`, etc.
- **Outdated dependency list**: `npm outdated --json`, `pip list --outdated --format json`, etc.
- **License scan**: `npx license-checker --json`, `pipx run pip-licenses --format json`, etc.

Pipe all outputs to temp files:
```bash
# Each ecosystem writes to /tmp/dep-audit-{ecosystem}-{check}.json
# Example (see references/audit-checks.md for all ecosystems):
npm audit --json > /tmp/dep-audit-npm-cve.json 2>&1
npm outdated --json > /tmp/dep-audit-npm-outdated.json 2>&1
npx license-checker --json > /tmp/dep-audit-npm-licenses.json 2>&1
```

If a tool fails or is unavailable, fall back to static manifest analysis for that
check category. Static analysis can still detect version pinning issues, known
problematic packages, and license declarations from package metadata.

### 4. CVE & Advisory Analysis

Parse audit tool output and dependency manifests:

- **Known CVEs**: Group by severity (critical, high, moderate, low)
- **Fix availability**: Is there a patched version? Is it a major version bump?
- **Transitive vs direct**: Is the vulnerable package a direct dependency or transitive?
- **Exploitability context**: Is the vulnerable code path actually reachable in this project?

For each CVE finding, assess whether an upgrade is straightforward (patch/minor bump)
or requires breaking changes (major bump with API changes).

### 5. Staleness & Maintenance Assessment

For each direct dependency:

- **Version gap**: How far behind latest? (1 patch = fine, 3+ majors = CRITICAL)
- **Last publish date**: Flag packages not updated in >2 years as potentially abandoned
- **Maintenance signals**: Archived repo, no recent commits, unresolved CVEs, bus factor of 1
- **EOL runtime**: Is the project using an EOL language/runtime version? (Node 16, Python 3.7, Go 1.19, etc.)
- **Deprecated packages**: Packages marked deprecated by their maintainers or registries
- **Successor packages**: If deprecated, is there an official replacement? (e.g., `request` → `undici`)

### 6. License Compatibility

Read `references/license-matrix.md` for the full compatibility matrix.

- **Project license vs dependency licenses**: Flag incompatible combinations
  - GPL dependencies in MIT/Apache projects (viral copyleft contamination)
  - AGPL dependencies in SaaS products (network copyleft trigger)
  - BSL/SSPL dependencies in commercial products
  - No-license packages (legally ambiguous — cannot safely use)
- **License drift**: Lock file shows different license than what's declared in the package
- **Multi-license packages**: Check which license applies to the version in use (some packages changed licenses between versions, e.g., Elasticsearch)

### 7. Bundle & Bloat Analysis

For frontend/Node.js projects:

- **Duplicate dependencies**: Same package at multiple versions in the dependency tree
- **Heavy imports**: Packages where the project uses <10% of exports (e.g., importing all of lodash for `_.get`)
- **Tree-shaking effectiveness**: Are imports structured for tree-shaking? (`import { x }` vs `import *`)
- **Dev dependency leakage**: Dev dependencies included in production bundle or install
- **Unnecessary polyfills**: Polyfills for features supported by all target browsers/runtimes

### 8. Produce Findings

Write findings with this structure per finding:

```
## [SEVERITY] Finding Title

**Category**: CVE/Advisory | Outdated | Abandoned/Unmaintained | License Conflict |
  Bundle Bloat | Duplicate Dependency | EOL Runtime | Upgrade Complexity
**Package**: package-name@current-version → recommended-version
**Location**: manifest file path (e.g., package.json, requirements.txt)
**Ecosystem**: npm | pip | cargo | go | gem | composer | maven/gradle

**Problem**: What the dependency issue is.

**Impact**: What happens if this isn't addressed — security exposure, maintenance burden,
  legal risk, or performance cost.

**Evidence**: Audit tool output, version comparison, or license conflict detail.

**Recommendation**: Specific upgrade path, replacement package, or mitigation.
  Include the target version and any breaking changes to expect.
```

Severity levels:
- **CRITICAL** — Known exploitable CVE with no workaround, EOL runtime with no security patches, or GPL contamination in a proprietary project
- **HIGH** — CVE with available fix, package abandoned with no replacement, or 3+ major versions behind
- **MEDIUM** — Moderate CVE (not directly exploitable), 1-2 major versions behind, license ambiguity
- **LOW** — Minor staleness, duplicate dependencies, bundle optimization opportunities

### 9. Summarize

End with:
- **Ecosystem summary**: Which ecosystems were audited, which tools ran successfully
- **Tool availability report**: Which audit tools were available, installed on-the-fly, or skipped
- **CVE summary**: Count by severity, how many have available fixes
- **Staleness summary**: Count of outdated direct dependencies by severity band
- **License summary**: Any conflicts found, overall license hygiene
- **Bundle summary**: Estimated savings from dedup/tree-shaking (frontend only)
- **Overall health verdict**: BLOCK (critical CVEs or license violations) | REVIEW (outdated, abandoned) | HEALTHY

## Execution Mode

- **Standalone**: Spawn the `review-lens` agent (`subagent_type: "review-lens"`) with this skill's lens instructions and input files. Stores findings as `db_upsert 'dep-audit' 'findings' 'standalone'`.
- **Via meta-review**: The `review-lens` agent runs Sonnet review, while Codex (`/codex`) and Gemini (`/gemini`) run in parallel with the same prompt. Each stores findings under label `sonnet`/`codex`/`gemini`. The meta-review skill handles synthesis.

## References (on-demand)

Read these files only when needed:
- `references/audit-checks.md` — Per-ecosystem audit tool commands, install instructions, output parsing, and fallback strategies
- `references/license-matrix.md` — License compatibility matrix covering MIT, Apache-2.0, GPL-2.0, GPL-3.0, LGPL-2.1, LGPL-3.0, AGPL-3.0, MPL-2.0, BSL-1.1, SSPL, and Unlicense

## Examples

```
User: Audit our dependencies before the release.
→ Full audit: detect ecosystems, discover/install tools, run audits, analyze CVEs,
  staleness, licenses, bundle. Report BLOCK/REVIEW/HEALTHY.
```

```
User: Are any of our packages vulnerable?
→ Emphasis on CVE & Advisory Analysis (§4). Run audit tools, report findings with fix paths.
```

```
User: Check our license compliance.
→ Emphasis on License Compatibility (§6). Read license-matrix.md. Flag conflicts.
```

```
User: Our node_modules is huge. What can we trim?
→ Emphasis on Bundle & Bloat Analysis (§7). Check duplicates, heavy imports, dev leakage.
```

```
User: We haven't updated deps in a year. How bad is it?
→ Emphasis on Staleness & Maintenance Assessment (§5). Flag abandoned, deprecated,
  EOL packages. Provide upgrade roadmap sorted by risk.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
