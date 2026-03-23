#!/usr/bin/env bash
# Stop hook — three-gate pattern
# Gate 0: skip if no files changed (no code work done)
# Gate 1 (first stop per project per day): block once — check docs + over-engineering
# Gate 2 (already fired): allow through via lock file

INPUT=$(cat)

# Gate 2: already fired for this project today — allow through
DIR_HASH=$(pwd | shasum -a 256 | cut -c1-8)
LOCK="/tmp/.claude-stop-hook-$(date +%Y%m%d)-${DIR_HASH}"
if [ -f "$LOCK" ]; then
  exit 0
fi

# Gate 0: if not in a git repo or no files changed, allow through silently
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  exit 0
fi
if [ -z "$(git diff --name-only HEAD 2>/dev/null)" ] && [ -z "$(git diff --name-only --cached 2>/dev/null)" ] && [ -z "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
  exit 0
fi

# Gate 1: first stop with actual changes — block once, set flag
touch "$LOCK"

cat <<'EOF'
{
  "decision": "block",
  "reason": "Before stopping, run these two checks:\n\n1. **Doc check**: Does cnotes.md, todo.md, or features.md need updating based on what you just did? If notable decisions, context changes, action items, or feature changes — update them.\n\n2. **Over-engineering check**: Review what you just wrote. Did you:\n   - Add abstractions, helpers, or utilities that are only used once? Inline them.\n   - Add error handling for scenarios that can't happen? Remove it.\n   - Add features, parameters, or configurability that wasn't requested? Remove it.\n   - Create extra files that aren't necessary? Consolidate.\n   - Add docstrings, comments, or type annotations to code you didn't change? Remove them.\n   If you find any, fix them now. If nothing to update on either check, you may stop."
}
EOF
