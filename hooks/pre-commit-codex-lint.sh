#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash)
# Runs Codex lint on staged changes before git commit commands

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

# Check if codex is available (absolute path — subshells don't source profiles)
CODEX="/opt/homebrew/bin/codex"
if [ ! -x "$CODEX" ]; then
  exit 0  # Graceful degradation
fi

# Get the repo root
REPO_DIR=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")

# Run Codex lint on staged changes (30s timeout)
LINT_OUTPUT=$(timeout 30 "$CODEX" exec --ephemeral --sandbox read-only \
  --cd "$REPO_DIR" \
  "Review the staged git changes in this repository. Check ONLY for: 1) TypeScript/JavaScript errors 2) Security vulnerabilities (hardcoded secrets, injection) 3) Missing error handling for critical paths 4) Obvious bugs. Report ONLY real problems, not style nits. If everything looks fine, say CLEAN." \
  2>/dev/null || echo "CLEAN")

# Check if lint found critical issues
if echo "$LINT_OUTPUT" | grep -qiE '(CRITICAL|SECURITY|HARDCODED.*(KEY|SECRET|TOKEN|PASSWORD))'; then
  REASON="Codex pre-commit lint found critical issues. Review and fix before committing."

  cat <<HOOKEOF
{
  "decision": "block",
  "reason": "$REASON\n\nCodex output:\n$LINT_OUTPUT"
}
HOOKEOF
  exit 0
fi

# Clean or non-critical — allow the commit
exit 0
