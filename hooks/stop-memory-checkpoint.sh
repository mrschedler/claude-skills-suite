#!/usr/bin/env bash
# Stop hook — artifact DB + memory checkpoint (informational only).
# Replaces the old static echo checkpoint with context-aware prompting.
# Reads stdin for stop_hook_active flag (same pattern as stop-quality-gate.sh).
# Always exits 0 — never blocks the agent stop.

INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('stop_hook_active', False))" 2>/dev/null || echo "false")

# Second gate — already reviewed, let it through
if [ "$STOP_HOOK_ACTIVE" = "True" ] || [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# ── Check for artifact DB in current project ──
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
DB_PATH=""
if [[ -n "$GIT_ROOT" ]]; then
  DB_PATH="$GIT_ROOT/artifacts/project.db"
fi

if [[ -n "$DB_PATH" && -f "$DB_PATH" ]]; then
  # Project has an artifact DB — check for records created during this session.
  # Use a 4-hour window as a reasonable proxy for "this session."
  NEW_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM artifacts WHERE created_at >= datetime('now', '-4 hours');" 2>/dev/null || echo "0")
  TOTAL_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM artifacts;" 2>/dev/null || echo "0")

  if [[ "$NEW_COUNT" -gt 0 ]] 2>/dev/null; then
    cat <<EOF
ARTIFACT DB: $NEW_COUNT new record(s) stored this session ($TOTAL_COUNT total).
Consider: Do any key findings or decisions need to be synced to Qdrant as condensed narrative?
(The artifact DB has the detail; Qdrant carries the cross-project summary.)
Not everything needs syncing — only what a future session on a DIFFERENT project would need.
EOF
  else
    cat <<EOF
ARTIFACT DB: $TOTAL_COUNT records present, none added this session.
If significant work was done: (1) Does anything belong in Qdrant memory? (2) Did entity relationships change that Neo4j should know about?
EOF
  fi
else
  # No artifact DB — check if there were meaningful changes before nagging
  HAS_CHANGES=false
  if git rev-parse --git-dir >/dev/null 2>&1; then
    if ! git diff --quiet HEAD 2>/dev/null; then
      HAS_CHANGES=true
    elif ! git diff --cached --quiet 2>/dev/null; then
      HAS_CHANGES=true
    fi
  fi

  if [ "$HAS_CHANGES" = "true" ]; then
    echo "CHECKPOINT: Did you (1) update Qdrant memory if decisions were made? (2) update Neo4j if entity relationships changed?"
  fi
  # If no changes and no artifact DB, stay silent — don't nag on pure Q&A sessions.
fi

exit 0
