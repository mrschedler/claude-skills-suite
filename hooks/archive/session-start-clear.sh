#!/usr/bin/env bash
# SessionStart hook (matcher: clear)
# After /clear, inject compact file with transition framing

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')
COMPACT_FILE="$CWD/compact/claude-compact.md"

if [ -f "$COMPACT_FILE" ]; then
  echo "The previous session accomplished the following. If a next task was specified below, begin working on it. If not, ask the user what they'd like to work on next."
  echo ""
  cat "$COMPACT_FILE"
fi

exit 0
