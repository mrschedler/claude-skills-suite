#!/bin/bash
# Director-nudge hook for Claude Code PreToolUse on Bash|PowerShell.
# Counts shell calls per session; every 8th, prints one reminder line.
# Advisory only: never blocks, never writes stderr, always exits 0.

KEY="${CLAUDE_SESSION_ID:-$(pwd)}"
KEY="$(printf '%s' "$KEY" | tr -c 'A-Za-z0-9' '_')"
DIR="${TMPDIR:-/tmp}/claude-director-nudge"
mkdir -p "$DIR" 2>/dev/null || exit 0
COUNT_FILE="$DIR/$KEY"

N="$(cat "$COUNT_FILE" 2>/dev/null)"
case "$N" in ''|*[!0-9]*) N=0 ;; esac
N=$((N + 1))
printf '%s' "$N" > "$COUNT_FILE" 2>/dev/null
if [ $((N % 8)) -eq 0 ]; then
  echo "You are the director. Are you delegating wisely?"
fi
exit 0
