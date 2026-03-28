#!/bin/bash
# Search-before-act hook for Claude Code PreToolUse on Bash
# Pattern-matches SSH commands and injects targeted reminders
# about known gotchas the agent should search Qdrant for.
#
# Input: tool_input JSON on stdin
# Output: stdout reminder injected into conversation context

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('command',''))" 2>/dev/null)

# ── Check coordination cache for active pause-all signal ──
SESSION_ID=$(ls -t ~/.claude/debug/ 2>/dev/null | head -1 | sed 's/\.txt$//')
COORD_WARNING=""
if [[ -n "$SESSION_ID" ]]; then
  CACHE_FILE="$HOME/.claude/session-env/${SESSION_ID}/coordination.json"
  if [[ -f "$CACHE_FILE" ]]; then
    COORD_WARNING=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
signals = data.get('signals') or {}
if 'pause-all' in signals:
    reason = signals['pause-all'].get('reason', 'unknown reason')
    set_by = signals['pause-all'].get('set_by', 'unknown')
    print(f'PAUSE-ALL SIGNAL ACTIVE: {reason} (set by {set_by}). Check coordination_call > check_signals before continuing.')
" "$CACHE_FILE" 2>/dev/null) || true
  fi
fi

if [[ -n "$COORD_WARNING" ]]; then
  echo "$COORD_WARNING"
fi

# Only trigger SSH-specific reminders for SSH commands
if ! echo "$COMMAND" | grep -qi 'ssh '; then
  exit 0
fi

REMINDERS=""

# File writing over SSH — heredoc + backticks break
if echo "$COMMAND" | grep -qiE 'cat.*<<|EOF|heredoc|>> |> /'; then
  REMINDERS="$REMINDERS\n- FILE WRITE via SSH detected: Never use heredocs with backtick content. Use base64 encode/decode instead."
fi

# Obsidian vault edits
if echo "$COMMAND" | grep -qi 'obsidian\|device-sync.*vault'; then
  REMINDERS="$REMINDERS\n- OBSIDIAN edit detected: Edit on Unraid (server is source of truth), Syncthing distributes. Use base64 for content with markdown."
fi

# Syncthing operations
if echo "$COMMAND" | grep -qi 'syncthing'; then
  REMINDERS="$REMINDERS\n- SYNCTHING operation detected: Pause devices before destructive operations to prevent propagation."
fi

# Docker operations
if echo "$COMMAND" | grep -qi 'docker.*rm\|docker.*stop\|docker.*restart'; then
  REMINDERS="$REMINDERS\n- DOCKER mutation detected: Check if container has volume mounts with important data before stopping/removing."
fi

if [ -n "$REMINDERS" ]; then
  echo -e "SEARCH-BEFORE-ACT reminder:$REMINDERS"
fi
