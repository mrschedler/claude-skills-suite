#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash)
# Runs deterministic linters + secret scan before Codex on git commit
# Order: Gitleaks (secrets) → Ruff/Biome/oxlint (lint) → Codex (semantic)
# Deterministic tools run in <1s. Codex only runs if linters pass.

set -euo pipefail

INPUT=$(cat)

# Extract the command being run
if command -v jq >/dev/null 2>&1; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
else
  COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")
fi

# Only intercept git commit commands
case "$COMMAND" in
  git\ commit*) ;;
  *) exit 0 ;;
esac

REPO_DIR=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
ISSUES=""

# --- Phase 1: Secret scanning (BLOCKS on any finding) ---
if command -v gitleaks >/dev/null 2>&1; then
  SECRETS_OUTPUT=$(cd "$REPO_DIR" && git diff --cached --name-only -z | xargs -0 gitleaks detect --no-banner --no-git -f json 2>/dev/null || true)
  if [ -n "$SECRETS_OUTPUT" ] && [ "$SECRETS_OUTPUT" != "[]" ] && [ "$SECRETS_OUTPUT" != "null" ]; then
    cat <<HOOKEOF
{
  "decision": "block",
  "reason": "Gitleaks detected secrets in staged files. Remove secrets before committing.\n\n$SECRETS_OUTPUT"
}
HOOKEOF
    exit 0
  fi
fi

# --- Phase 2: Deterministic linters (per-language, staged files only) ---
STAGED_FILES=$(cd "$REPO_DIR" && git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)

# Python: Ruff
if echo "$STAGED_FILES" | grep -qE '\.py$'; then
  PY_FILES=$(echo "$STAGED_FILES" | grep -E '\.py$' | sed "s|^|$REPO_DIR/|")
  if command -v ruff >/dev/null 2>&1; then
    RUFF_OUT=$(echo "$PY_FILES" | xargs ruff check --no-fix --output-format=text 2>/dev/null || true)
    if [ -n "$RUFF_OUT" ]; then
      ISSUES="${ISSUES}--- Ruff (Python) ---\n${RUFF_OUT}\n\n"
    fi
  fi
fi

# JS/TS: Biome (formatting + lint) and oxlint (additional rules)
if echo "$STAGED_FILES" | grep -qE '\.(js|jsx|ts|tsx|json)$'; then
  JSTS_FILES=$(echo "$STAGED_FILES" | grep -E '\.(js|jsx|ts|tsx|json)$' | sed "s|^|$REPO_DIR/|")
  if command -v biome >/dev/null 2>&1; then
    BIOME_OUT=$(echo "$JSTS_FILES" | xargs biome check --no-errors-on-unmatched 2>/dev/null || true)
    if echo "$BIOME_OUT" | grep -qE '(error|warning)\['; then
      ISSUES="${ISSUES}--- Biome (JS/TS) ---\n${BIOME_OUT}\n\n"
    fi
  fi
  if command -v oxlint >/dev/null 2>&1; then
    OXLINT_OUT=$(echo "$JSTS_FILES" | xargs oxlint 2>/dev/null || true)
    if echo "$OXLINT_OUT" | grep -qE '(error|warning)'; then
      ISSUES="${ISSUES}--- oxlint (JS/TS) ---\n${OXLINT_OUT}\n\n"
    fi
  fi
fi

# Shell: Semgrep (if available, lightweight patterns)
if echo "$STAGED_FILES" | grep -qE '\.(sh|bash)$'; then
  SH_FILES=$(echo "$STAGED_FILES" | grep -E '\.(sh|bash)$' | sed "s|^|$REPO_DIR/|")
  if command -v semgrep >/dev/null 2>&1; then
    SEMGREP_OUT=$(echo "$SH_FILES" | xargs semgrep scan --config auto --quiet --no-git-ignore 2>/dev/null || true)
    if [ -n "$SEMGREP_OUT" ]; then
      ISSUES="${ISSUES}--- Semgrep (Shell) ---\n${SEMGREP_OUT}\n\n"
    fi
  fi
fi

# Block if deterministic linters found issues
if [ -n "$ISSUES" ]; then
  # Escape for JSON
  ESCAPED=$(echo -e "$ISSUES" | head -80 | sed 's/"/\\"/g' | tr '\n' ' ')
  cat <<HOOKEOF
{
  "decision": "block",
  "reason": "Deterministic linters found issues in staged files. Fix before committing.\n\n$ESCAPED"
}
HOOKEOF
  exit 0
fi

# --- Phase 3: Codex semantic review (only if deterministic checks pass) ---
CODEX=$(command -v codex 2>/dev/null)
test -x "$CODEX" || CODEX="/opt/homebrew/bin/codex"
if [ ! -x "$CODEX" ] && [ -d "$HOME/.nvm/versions/node" ]; then
  CODEX=$(find "$HOME/.nvm/versions/node" -path '*/bin/codex' -type f 2>/dev/null | sort -V | tail -1)
fi
test -x "$CODEX" && export PATH="$(dirname "$CODEX"):$PATH"
GTIMEOUT="/opt/homebrew/bin/gtimeout"

if [ -x "$CODEX" ] && [ -x "$GTIMEOUT" ]; then
  LINT_OUTPUT=$("$GTIMEOUT" 30 "$CODEX" exec --ephemeral --sandbox read-only \
    --skip-git-repo-check --cd "$REPO_DIR" \
    "Review the staged git changes. Check ONLY for: 1) Logic errors 2) Security vulnerabilities (injection, hardcoded secrets) 3) Missing error handling for critical paths 4) Obvious bugs. Deterministic linters already passed — focus on semantic issues only. If everything looks fine, say CLEAN." \
    2>/dev/null || echo "CLEAN")

  if echo "$LINT_OUTPUT" | grep -qiE '(CRITICAL|SECURITY|HARDCODED.*(KEY|SECRET|TOKEN|PASSWORD))'; then
    cat <<HOOKEOF
{
  "decision": "block",
  "reason": "Codex semantic review found critical issues.\n\n$LINT_OUTPUT"
}
HOOKEOF
    exit 0
  fi
fi

# All checks passed
exit 0
