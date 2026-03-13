#!/usr/bin/env bash
# Stop hook — two-gate pattern
# Gate 1 (first stop): block — check docs + over-engineering
# Gate 2 (stop_hook_active=true): allow through

INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

cat <<'EOF'
{
  "decision": "block",
  "reason": "Before stopping, run these two checks:\n\n1. **Doc check**: Does cnotes.md, todo.md, or features.md need updating based on what you just did? If notable decisions, context changes, action items, or feature changes — update them.\n\n2. **Over-engineering check**: Review what you just wrote. Did you:\n   - Add abstractions, helpers, or utilities that are only used once? Inline them.\n   - Add error handling for scenarios that can't happen? Remove it.\n   - Add features, parameters, or configurability that wasn't requested? Remove it.\n   - Create extra files that aren't necessary? Consolidate.\n   - Add docstrings, comments, or type annotations to code you didn't change? Remove them.\n   If you find any, fix them now. If nothing to update on either check, you may stop."
}
EOF
