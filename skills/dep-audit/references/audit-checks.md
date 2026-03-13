# Per-Ecosystem Audit Tool Commands

Reference for dep-audit §2 (Tool Discovery) and §3 (Run Audit Tools).
Each ecosystem section covers: required tools, discovery, install, audit commands,
output parsing, and fallback strategies.

## Node.js (npm / yarn / pnpm)

### Tool Discovery

```bash
# Primary tools (usually pre-installed with Node)
which npm && npm --version
which yarn && yarn --version
which pnpm && pnpm --version

# Supplementary tools
npx license-checker --version 2>/dev/null
npx npm-check-updates --version 2>/dev/null
```

### Install Missing Tools

```bash
# license-checker — no global install needed, npx runs it directly
# npm-check-updates — same, npx handles it
# If npm itself is outdated:
npm install -g npm@latest
```

### Audit Commands

```bash
# CVE scan
npm audit --json > /tmp/dep-audit-npm-cve.json 2>&1
# Or for yarn:
yarn audit --json > /tmp/dep-audit-yarn-cve.json 2>&1
# Or for pnpm:
pnpm audit --json > /tmp/dep-audit-pnpm-cve.json 2>&1

# Outdated packages
npm outdated --json > /tmp/dep-audit-npm-outdated.json 2>&1

# License scan
npx license-checker --json --production > /tmp/dep-audit-npm-licenses.json 2>&1

# Interactive upgrade suggestions (parse only, don't apply)
npx npm-check-updates --jsonUpgraded > /tmp/dep-audit-npm-upgrades.json 2>&1
```

### Output Parsing

**npm audit JSON structure:**
```json
{
  "vulnerabilities": {
    "package-name": {
      "severity": "high",
      "via": [{ "title": "CVE description", "url": "https://..." }],
      "fixAvailable": true | { "name": "pkg", "version": "1.2.3" },
      "isDirect": true | false
    }
  }
}
```

**npm outdated JSON structure:**
```json
{
  "package-name": {
    "current": "1.0.0",
    "wanted": "1.2.3",
    "latest": "2.0.0",
    "type": "dependencies" | "devDependencies"
  }
}
```

### Fallback (no tools available)

Parse `package.json` and `package-lock.json` directly:
- Extract dependency versions from lock file
- Compare against known vulnerable versions (check npm advisory API if network available)
- Read `license` field from each package's entry in node_modules or lock file metadata

## Python (pip / poetry / pipenv)

### Tool Discovery

```bash
which pip && pip --version
which pip3 && pip3 --version
which pipx && pipx --version
which poetry && poetry --version

# Supplementary tools
pip audit --help 2>/dev/null
pip-licenses --version 2>/dev/null
```

### Install Missing Tools

```bash
# pip-audit
pipx install pip-audit 2>/dev/null || pip install --user pip-audit

# pip-licenses
pipx install pip-licenses 2>/dev/null || pip install --user pip-licenses

# safety (alternative CVE scanner)
pipx install safety 2>/dev/null || pip install --user safety
```

### Audit Commands

```bash
# CVE scan
pip-audit --format json --output /tmp/dep-audit-pip-cve.json 2>&1
# Or with safety:
safety check --json > /tmp/dep-audit-pip-safety.json 2>&1
# Or with poetry:
poetry audit --json > /tmp/dep-audit-poetry-cve.json 2>&1

# Outdated packages
pip list --outdated --format json > /tmp/dep-audit-pip-outdated.json 2>&1
# Or with poetry:
poetry show --outdated --format json > /tmp/dep-audit-poetry-outdated.json 2>&1

# License scan
pip-licenses --format json --with-urls > /tmp/dep-audit-pip-licenses.json 2>&1
```

### Output Parsing

**pip-audit JSON structure:**
```json
[
  {
    "name": "package-name",
    "version": "1.0.0",
    "vulns": [
      { "id": "PYSEC-2024-XXX", "fix_versions": ["1.0.1"], "description": "..." }
    ]
  }
]
```

**pip list --outdated JSON structure:**
```json
[
  { "name": "package", "version": "1.0.0", "latest_version": "2.0.0", "latest_filetype": "wheel" }
]
```

### Fallback

Parse `requirements.txt` / `pyproject.toml` / `Pipfile.lock` directly:
- Extract pinned versions
- Flag unpinned dependencies (`package>=1.0` without upper bound)
- Check for `==` pins on very old versions

## Go

### Tool Discovery

```bash
which go && go version
which govulncheck && govulncheck -version 2>/dev/null
```

### Install Missing Tools

```bash
# govulncheck (official Go vulnerability scanner)
go install golang.org/x/vuln/cmd/govulncheck@latest
```

### Audit Commands

```bash
# CVE scan (govulncheck analyzes call graphs, not just dependencies)
govulncheck -json ./... > /tmp/dep-audit-go-cve.json 2>&1

# Outdated modules
go list -m -u -json all > /tmp/dep-audit-go-outdated.json 2>&1

# License scan (no standard tool — use go-licenses)
go install github.com/google/go-licenses@latest 2>/dev/null
go-licenses csv ./... > /tmp/dep-audit-go-licenses.csv 2>&1
```

### Output Parsing

**govulncheck JSON:** Reports vulnerable functions actually called in your code
(not just present in dependency tree). Key fields: `osv` (CVE details), `modules`
(affected module versions), `packages` (affected packages), `functions` (called
vulnerable functions).

### Fallback

Parse `go.mod` and `go.sum` directly:
- Extract module versions
- Flag modules with `/v0.` versions (pre-stability)
- Check for replace directives pointing to local paths (may indicate vendored forks)

## Rust

### Tool Discovery

```bash
which cargo && cargo --version
cargo audit --version 2>/dev/null
cargo license --version 2>/dev/null
```

### Install Missing Tools

```bash
cargo install cargo-audit
cargo install cargo-license
cargo install cargo-outdated
```

### Audit Commands

```bash
# CVE scan
cargo audit --json > /tmp/dep-audit-cargo-cve.json 2>&1

# Outdated crates
cargo outdated --format json > /tmp/dep-audit-cargo-outdated.json 2>&1

# License scan
cargo license --json > /tmp/dep-audit-cargo-licenses.json 2>&1
```

### Fallback

Parse `Cargo.toml` and `Cargo.lock` directly:
- Extract crate versions from lock file
- Flag yanked versions (marked in lock file metadata)
- Check for `*` version requirements

## Ruby

### Tool Discovery

```bash
which bundle && bundle --version
which bundler-audit && bundler-audit --version 2>/dev/null
```

### Install Missing Tools

```bash
gem install bundler-audit
bundler-audit update  # Update advisory database
```

### Audit Commands

```bash
# CVE scan
bundler-audit check --format json > /tmp/dep-audit-gem-cve.json 2>&1

# Outdated gems
bundle outdated --parseable > /tmp/dep-audit-gem-outdated.txt 2>&1

# License scan (use license_finder)
gem install license_finder 2>/dev/null
license_finder --format json > /tmp/dep-audit-gem-licenses.json 2>&1
```

### Fallback

Parse `Gemfile` and `Gemfile.lock` directly.

## PHP

### Tool Discovery

```bash
which composer && composer --version
composer audit --help 2>/dev/null
```

### Install Missing Tools

```bash
# composer audit is built-in since Composer 2.4
composer self-update
```

### Audit Commands

```bash
# CVE scan (built-in since Composer 2.4)
composer audit --format json > /tmp/dep-audit-composer-cve.json 2>&1

# Outdated packages
composer outdated --format json --direct > /tmp/dep-audit-composer-outdated.json 2>&1

# License scan
composer licenses --format json > /tmp/dep-audit-composer-licenses.json 2>&1
```

### Fallback

Parse `composer.json` and `composer.lock` directly.

## General Fallback Strategy

When no ecosystem-specific tools are available:

1. **Static manifest analysis**: Parse dependency files to extract package names and versions
2. **Registry API checks** (if network available):
   - npm: `https://registry.npmjs.org/{package}`
   - PyPI: `https://pypi.org/pypi/{package}/json`
   - crates.io: `https://crates.io/api/v1/crates/{crate}`
3. **Advisory database checks** (if network available):
   - GitHub Advisory Database: `https://github.com/advisories`
   - OSV: `https://api.osv.dev/v1/query`
4. **Lock file metadata**: Many lock files contain integrity hashes, resolved URLs,
   and sometimes license information — extract what's available
5. **Report the gap**: Always note which checks were skipped due to missing tools
   so the user knows the audit is incomplete
