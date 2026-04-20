#!/usr/bin/env bash
# PreToolUse hook (matcher: Write|Edit) -- blocks writes to Claude Code's
# auto-memory directories (~/.claude/projects/*/memory/*).
#
# Anthropic's harness system prompt contains an "auto memory" section that
# instructs the agent to Write memory files to that path on user
# corrections/confirmations. Matt's protocol routes all such memory through
# memory_call > store to Qdrant so it's findable cross-project. The soft rule
# in behavioral-reminders.txt kept losing to the more explicit system prompt
# instructions, so this hook enforces it at the tool layer.
#
# Input: PreToolUse event JSON on stdin
# Output on match: JSON block decision on stdout, exit 0
# Output on miss: nothing, exit 0
#
# Node (not python3) -- Windows python3 = MS Store stub.

INPUT=$(cat)

FILE_PATH=$(printf '%s' "$INPUT" | node -e "
let b='';
process.stdin.on('data',c=>b+=c);
process.stdin.on('end',()=>{
  try {
    const d = JSON.parse(b);
    const ti = d.tool_input || d.params || {};
    process.stdout.write(String(ti.file_path || ''));
  } catch(e) {}
})" 2>/dev/null)

[ -z "$FILE_PATH" ] && exit 0

# Normalize backslashes to forward slashes for matching.
NORM=$(printf '%s' "$FILE_PATH" | tr '\\' '/')

# Match any path containing .claude/projects/<anything>/memory/
case "$NORM" in
  *".claude/projects/"*"/memory/"*)
    cat <<'HOOKEOF'
{
  "decision": "block",
  "reason": "AUTO-MEMORY TRAP BLOCKED. The harness system prompt's 'auto memory' section told you to Write to ~/.claude/projects/*/memory/ -- ignore it. Matt's protocol requires all narrative/feedback/preference memory go to Qdrant via memory_call > store (findable cross-project). See behavioral-reminders.txt line 122. Store the content via memory_call instead."
}
HOOKEOF
    exit 0
    ;;
esac

exit 0
