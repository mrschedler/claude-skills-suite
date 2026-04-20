#!/bin/bash
# Search-before-act hook for Claude Code PreToolUse on Bash
# Pattern-matches SSH commands and injects targeted reminders
# about known gotchas the agent should search Qdrant for.
#
# Input: tool_input JSON on stdin
# Output: stdout reminder injected into conversation context

INPUT=$(cat)
# JSON parse via node (python3 on Windows resolves to the MS Store stub).
COMMAND=$(printf '%s' "$INPUT" | node -e "let b='';process.stdin.on('data',c=>b+=c);process.stdin.on('end',()=>{try{const d=JSON.parse(b);process.stdout.write(String((d.tool_input&&d.tool_input.command)||d.command||''))}catch(e){}})" 2>/dev/null)

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

exit 0
