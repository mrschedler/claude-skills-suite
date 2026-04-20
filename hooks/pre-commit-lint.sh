#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash) — deterministic linting on git commit
# Runs before every git commit command.
# Phase 1: gitleaks secret scan (BLOCKS on any finding)
# Phase 2: ruff/biome/oxlint lint (BLOCKS on errors)
# All tools are optional — gracefully skips if not installed.
# Works on Windows Git Bash.

set -euo pipefail

INPUT=$(cat)

# Extract the command being run. Node (not python3 — MS Store stub on Windows).
COMMAND=$(printf '%s' "$INPUT" | node -e "let b='';process.stdin.on('data',c=>b+=c);process.stdin.on('end',()=>{try{const d=JSON.parse(b);process.stdout.write(String((d.tool_input&&d.tool_input.command)||d.command||''))}catch(e){}})" 2>/dev/null)

# Only intercept git commit commands
case "$COMMAND" in
  git\ commit*) ;;
  *) exit 0 ;;
esac

REPO_DIR=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
ISSUES=""

# --- Phase 1: Secret scanning (BLOCKS on any finding) ---
if command -v gitleaks >/dev/null 2>&1; then
  STAGED=$(cd "$REPO_DIR" && git diff --cached --name-only 2>/dev/null || true)
  if [ -n "$STAGED" ]; then
    SECRETS_OUTPUT=$(cd "$REPO_DIR" && gitleaks detect --no-banner --no-git --staged -f json 2>/dev/null || true)
    if [ -n "$SECRETS_OUTPUT" ] && [ "$SECRETS_OUTPUT" != "[]" ] && [ "$SECRETS_OUTPUT" != "null" ]; then
      cat <<HOOKEOF
{
  "decision": "block",
  "reason": "Gitleaks detected secrets in staged files. Remove secrets before committing.\n\n$(echo "$SECRETS_OUTPUT" | head -20 | sed 's/"/\\"/g' | tr '\n' ' ')"
}
HOOKEOF
      exit 0
    fi
  fi
fi

# --- Phase 2: Deterministic linters (staged files only) ---
STAGED_FILES=$(cd "$REPO_DIR" && git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)

# Python: Ruff
if echo "$STAGED_FILES" | grep -qE '\.py$'; then
  PY_FILES=$(echo "$STAGED_FILES" | grep -E '\.py$' | while read -r f; do echo "$REPO_DIR/$f"; done)
  if command -v ruff >/dev/null 2>&1; then
    RUFF_OUT=$(echo "$PY_FILES" | xargs ruff check --no-fix --output-format=text 2>/dev/null || true)
    if [ -n "$RUFF_OUT" ]; then
      ISSUES="${ISSUES}--- Ruff (Python) ---\n${RUFF_OUT}\n\n"
    fi
  fi
fi

# JS/TS: Biome or oxlint (whichever is available)
if echo "$STAGED_FILES" | grep -qE '\.(js|jsx|ts|tsx)$'; then
  JSTS_FILES=$(echo "$STAGED_FILES" | grep -E '\.(js|jsx|ts|tsx)$' | while read -r f; do echo "$REPO_DIR/$f"; done)
  if command -v biome >/dev/null 2>&1; then
    BIOME_OUT=$(echo "$JSTS_FILES" | xargs biome check --no-errors-on-unmatched 2>/dev/null || true)
    if echo "$BIOME_OUT" | grep -qE '(error|warning)\['; then
      ISSUES="${ISSUES}--- Biome (JS/TS) ---\n${BIOME_OUT}\n\n"
    fi
  elif command -v oxlint >/dev/null 2>&1; then
    OXLINT_OUT=$(echo "$JSTS_FILES" | xargs oxlint 2>/dev/null || true)
    if echo "$OXLINT_OUT" | grep -qE '(error|warning)'; then
      ISSUES="${ISSUES}--- oxlint (JS/TS) ---\n${OXLINT_OUT}\n\n"
    fi
  fi
fi

# Block if linters found issues
if [ -n "$ISSUES" ]; then
  ESCAPED=$(echo -e "$ISSUES" | head -60 | sed 's/"/\\"/g' | tr '\n' ' ')
  cat <<HOOKEOF
{
  "decision": "block",
  "reason": "Linters found issues in staged files. Fix before committing.\n\n$ESCAPED"
}
HOOKEOF
  exit 0
fi

# All checks passed
exit 0
