#!/usr/bin/env bash
# SessionStart hook (matcher: compact)
# After compaction, re-inject compact file as continuation context

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')
COMPACT_FILE="$CWD/compact/claude-compact.md"

if [ -f "$COMPACT_FILE" ]; then
  echo "You were working on the following task. Continue from where you left off. Here is your preserved context:"
  echo ""
  cat "$COMPACT_FILE"
fi

exit 0
