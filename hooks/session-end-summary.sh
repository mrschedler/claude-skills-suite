#!/usr/bin/env bash
# Claude Code Stop hook — session-end decision points.
# Only fires on second stop (stop_hook_active=true) to avoid running on every
# mid-conversation response. Presents reminders; actual MCP calls are the
# agent's responsibility. Always exits 0.

INPUT=$(cat)
# JSON parse via node (python3 on Windows resolves to the MS Store stub).
STOP_HOOK_ACTIVE=$(printf '%s' "$INPUT" | node -e "let b='';process.stdin.on('data',c=>b+=c);process.stdin.on('end',()=>{try{const d=JSON.parse(b);process.stdout.write(String(d.stop_hook_active||false))}catch(e){}})" 2>/dev/null)

if [ "$STOP_HOOK_ACTIVE" != "True" ] && [ "$STOP_HOOK_ACTIVE" != "true" ]; then
  exit 0
fi

# ── Uncommitted changes check ──
DIRTY_COUNT=0
if git rev-parse --git-dir >/dev/null 2>&1; then
  DIRTY_COUNT=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
fi

echo "session_end=true"
echo "action=store_session_summary | memory_call > store"
echo "action=deregister_coordination | coordination_call > deregister_session"
echo "action=post_mattermost_summary"
[[ "$DIRTY_COUNT" -gt 0 ]] && echo "uncommitted_files=$DIRTY_COUNT action=github_sync"

exit 0
