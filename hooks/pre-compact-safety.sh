#!/usr/bin/env bash
# PreCompact hook — Safety net
# If meta-compact ran recently (compact file < 5 min old), do nothing.
# Otherwise extract last assistant messages as fallback context.
# Cannot block compaction — always exits 0.

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')
COMPACT_FILE="$CWD/compact/claude-compact.md"
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""')

# Check if compact file was modified in last 5 minutes
if [ -f "$COMPACT_FILE" ]; then
  NOW=$(date +%s)
  # macOS stat format
  MTIME=$(stat -f %m "$COMPACT_FILE" 2>/dev/null)
  # Linux fallback
  [ -z "$MTIME" ] && MTIME=$(stat -c %Y "$COMPACT_FILE" 2>/dev/null)
  if [ -n "$MTIME" ]; then
    AGE=$(( NOW - MTIME ))
    if [ "$AGE" -lt 300 ]; then
      exit 0
    fi
  fi
fi

# meta-compact didn't run — create fallback
mkdir -p "$CWD/compact"

MESSAGES="(transcript not available)"
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  MESSAGES=$(tail -100 "$TRANSCRIPT" | jq -r 'select(.role == "assistant") | .content[:500] // empty' 2>/dev/null | tail -5)
fi

cat > "$COMPACT_FILE" <<COMPEOF
# AUTO-SAVED CONTEXT — $(date '+%Y-%m-%d %H:%M')

> meta-compact did not run before compaction. This is a fallback snapshot.
> Run the meta-compact skill at next opportunity for proper state preservation.

## Last Assistant Messages

$MESSAGES
COMPEOF

exit 0
