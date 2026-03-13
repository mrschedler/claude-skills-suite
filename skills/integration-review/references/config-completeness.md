# Config & Environment Completeness Checklist

Reference for integration-review Phase 3 (config and environment completeness)
and Phase 5 (bundle and build completeness).

## Environment Variable Audit

### Step 1: Extract All Env Var References from Code

```bash
# JavaScript/TypeScript
grep -rn 'process\.env\.\|process\.env\[' --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' | grep -v node_modules | grep -v dist

# Rust
grep -rn 'env::var\|env::var_os\|std::env::var\|dotenvy' --include='*.rs'

# Python
grep -rn 'os\.environ\|os\.getenv\|environ\.get\|environ\[' --include='*.py'

# Docker/compose
grep -rn '\${[A-Z_]\+}\|^\s*[A-Z_]\+=\|environment:' docker-compose*.yml Dockerfile* .env*

# Generic env() helper patterns
grep -rn "env(\|getEnv(\|loadEnv(" --include='*.ts' --include='*.js' --include='*.py' --include='*.rs'
```

### Step 2: Extract All Documented Env Vars

```bash
# From .env.example
grep -v '^\s*#\|^\s*$' .env.example 2>/dev/null | cut -d= -f1

# From .env.template / .env.sample
grep -v '^\s*#\|^\s*$' .env.template .env.sample 2>/dev/null | cut -d= -f1

# From docker-compose env_file references
grep -rn 'env_file' docker-compose*.yml
```

### Step 3: Cross-Reference

For each env var found in code:
- [ ] Exists in `.env.example` (or equivalent)
- [ ] Has a documented default or description
- [ ] Has an empty-string fallback in code (per security rules: `process.env.X || ''`)
- [ ] Is not a hardcoded secret (flag as CRITICAL if `= 'sk-...'` or `= 'password'` etc.)

For each env var in `.env.example`:
- [ ] Is actually used in code (flag dead config if not)
- [ ] Default value is appropriate (not a real secret, not a production URL)

## Config File Audit

### Application Config

```bash
# Find config files
find . -name 'config.*' -o -name '*.config.*' -o -name 'settings.*' -o -name '.env*' | grep -v node_modules | grep -v dist

# Find config reads
grep -rn 'config\.\|settings\.\|getConfig\|loadConfig' --include='*.ts' --include='*.js' --include='*.py' --include='*.rs' | head -50
```

For each config key defined:
- [ ] Is consumed by application code
- [ ] Has a sensible default
- [ ] Is documented (in config file comments or README)

For each config read in code:
- [ ] The key exists in the config source
- [ ] Type matches expectation (string vs number vs boolean)

### Feature Flags

```bash
# Find feature flag definitions
grep -rn 'feature.*flag\|featureFlag\|feature_flag\|FEATURE_\|FF_' --include='*.ts' --include='*.js' --include='*.py' --include='*.rs' --include='*.json' --include='*.yml'

# Find feature flag checks
grep -rn 'isEnabled\|isFeatureEnabled\|hasFeature\|feature_enabled' --include='*.ts' --include='*.js' --include='*.py' --include='*.rs'
```

For each feature flag:
- [ ] Has a definition with default value
- [ ] Has at least one check in code
- [ ] Is documented (what it controls, when to enable)
- [ ] Dead flags are removed (flag defined but never checked)

## Bundle & Build Config Audit

### Tauri

```bash
# Check tauri.conf.json for bundle completeness
# Look for: bundle.externalBin, bundle.resources, bundle.icon
cat src-tauri/tauri.conf.json | jq '.bundle'

# Find sidecar references in Rust code
grep -rn 'Command::new_sidecar\|sidecar' --include='*.rs'

# Cross-reference: every sidecar in code must be in bundle.externalBin
# Cross-reference: every resource file used must be in bundle.resources
```

Tauri checklist:
- [ ] Every `Command::new_sidecar("name")` has a matching entry in `bundle.externalBin`
- [ ] External binaries have correct target triple suffixes (e.g., `name-x86_64-apple-darwin`)
- [ ] Every static asset loaded at runtime is in `bundle.resources`
- [ ] `bundle.icon` paths exist on disk
- [ ] `allowlist` in tauri.conf.json covers all IPC commands used

### package.json

```bash
# Check bin entries
cat package.json | jq '.bin'
# Verify each bin target file exists

# Check files/main/exports
cat package.json | jq '.main, .module, .exports, .files'
# Verify referenced files exist

# Check scripts reference existing commands
cat package.json | jq '.scripts'
```

### Cargo.toml

```bash
# Check binary targets
grep -A2 '\[\[bin\]\]' Cargo.toml
# Verify each binary's path exists

# Check build dependencies
grep -A5 '\[build-dependencies\]' Cargo.toml
```

### Docker

```bash
# Find all COPY directives
grep -n 'COPY\|ADD' Dockerfile*

# Find all files the app reads at runtime (config, migrations, assets, etc.)
# Cross-reference: every runtime file must be COPYed into the container

# Check multi-stage builds — files from build stage must be copied to runtime stage
grep -n 'FROM.*AS\|COPY --from' Dockerfile*
```

Docker checklist:
- [ ] All runtime config files are COPYed
- [ ] Migration files are included (if app runs migrations on startup)
- [ ] Static assets are included
- [ ] `.dockerignore` doesn't exclude needed files
- [ ] Health check endpoint exists and is configured

### CI/CD Artifacts

```bash
# GitHub Actions
grep -rn 'upload-artifact\|download-artifact\|actions/cache' .github/workflows/
# Verify artifact names match between upload and download steps

# GitLab CI
grep -rn 'artifacts:' .gitlab-ci.yml
```

## Secret Reference Audit

```bash
# Vault paths in code
grep -rn 'vault\|VAULT_\|services/' --include='*.ts' --include='*.js' --include='*.py' --include='*.rs' --include='*.yml' | grep -v node_modules

# AWS SSM/Secrets Manager
grep -rn 'ssm\|secretsmanager\|AWS_SECRET' --include='*.ts' --include='*.js' --include='*.py'

# Hardcoded secrets (CRITICAL findings)
grep -rn 'sk-\|password.*=.*["\x27][^"\x27]\{8,\}["\x27]\|token.*=.*["\x27][^"\x27]\{8,\}["\x27]\|apikey\|api_key.*=.*["\x27]' --include='*.ts' --include='*.js' --include='*.py' --include='*.rs' -i | grep -v '\.env\|test\|mock\|example\|spec'
```

For each secret reference:
- [ ] Secret exists in the referenced store (Vault, SSM, etc.)
- [ ] Not hardcoded in source code
- [ ] Has a documented path/name
- [ ] Rotation policy is defined (if applicable)
