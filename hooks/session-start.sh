#!/usr/bin/env bash
# SessionStart hook
# Injects compact file (if exists) and project awareness files into new sessions.
# Covers: post-compact continuation, post-clear transition, and fresh startup.

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // "."' 2>/dev/null || echo ".")

# --- Compact file injection ---
COMPACT_FILE="$CWD/compact/claude-compact.md"
if [ -f "$COMPACT_FILE" ]; then
  # Check how old the compact file is
  NOW=$(date +%s)
  MTIME=$(stat -f %m "$COMPACT_FILE" 2>/dev/null)
  [ -z "$MTIME" ] && MTIME=$(stat -c %Y "$COMPACT_FILE" 2>/dev/null)

  if [ -n "$MTIME" ]; then
    AGE=$(( NOW - MTIME ))
    if [ "$AGE" -lt 300 ]; then
      # Fresh compact (< 5 min) — this is a continuation after /compact
      echo "Continuing from previous context. Here is your preserved state:"
    else
      # Older compact — previous session's state
      echo "The previous session accomplished the following. Resume or ask what's next:"
    fi
  else
    echo "Previous session state found:"
  fi

  echo ""
  cat "$COMPACT_FILE"
  echo ""
  echo "---"
  echo ""
fi

# --- Project awareness files ---
for FILE in project-context.md coterie.md todo.md; do
  if [ -f "$CWD/$FILE" ]; then
    echo "=== $FILE ==="
    cat "$CWD/$FILE"
    echo ""
  fi
done

exit 0
