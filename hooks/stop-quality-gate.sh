#!/usr/bin/env bash
# Stop hook — over-engineering self-review gate (Trevor's two-gate pattern)
# Only blocks when files were actually modified (git dirty or untracked changes).
# Skips the check for pure diagnostic/explanation responses — reduces noise.
# Second stop (stop_hook_active=true): always passes through.

INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('stop_hook_active', False))" 2>/dev/null || echo "false")

# Second gate — already reviewed, let it through
if [ "$STOP_HOOK_ACTIVE" = "True" ] || [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# Check if any files were modified (staged, unstaged, or untracked new files)
# If the working tree is clean, skip the review — nothing to over-engineer
HAS_CHANGES=false
if git rev-parse --git-dir >/dev/null 2>&1; then
  if ! git diff --quiet HEAD 2>/dev/null; then
    HAS_CHANGES=true
  elif ! git diff --cached --quiet 2>/dev/null; then
    HAS_CHANGES=true
  fi
fi

if [ "$HAS_CHANGES" = "false" ]; then
  exit 0
fi

# Files were changed — block and force self-review
cat <<'EOF'
{
  "decision": "block",
  "reason": "Files were modified. Before stopping, run these checks:\n\n1. **Over-engineering check**: Review what you just wrote. Did you:\n   - Add abstractions, helpers, or utilities only used once? Inline them.\n   - Add error handling for scenarios that can't happen? Remove it.\n   - Add features, parameters, or configurability that wasn't requested? Remove it.\n   - Create extra files that aren't necessary? Consolidate.\n   - Add docstrings, comments, or type annotations to code you didn't change? Remove them.\n\n2. **GROUNDING.md check**: If this project has a GROUNDING.md, does 'Current State' need updating based on what you did?\n\nIf you find issues, fix them now. If everything is clean, you may stop."
}
EOF
