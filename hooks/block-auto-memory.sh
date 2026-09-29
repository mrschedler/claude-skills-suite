#!/usr/bin/env bash
# PreToolUse hook (matcher: Write|Edit|write|search_replace) -- blocks writes
# to harness auto-memory dirs (~/.claude/projects/*/memory/* and ~/.grok/memory/).
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
    const ti = d.tool_input || d.toolInput || d.params || {};
    process.stdout.write(String(ti.file_path || ti.path || ''));
  } catch(e) {}
})" 2>/dev/null)

[ -z "$FILE_PATH" ] && exit 0

# Normalize backslashes to forward slashes for matching.
NORM=$(printf '%s' "$FILE_PATH" | tr '\\' '/')

# Match Claude auto-memory dir OR Grok native memory dir.
case "$NORM" in
  *".claude/projects/"*"/memory/"*|*".grok/memory/"*)
    cat <<'HOOKEOF'
{
  "decision": "deny",
  "reason": "AUTO-MEMORY TRAP BLOCKED. Do not write ~/.claude/projects/*/memory/ or ~/.grok/memory/. Matt's protocol routes all narrative/feedback/preference memory to Qdrant via memory_call > store (findable cross-project). See behavioral-reminders.txt. Store the content via gateway__memory_call instead."
}
HOOKEOF
    exit 0
    ;;
esac

exit 0
