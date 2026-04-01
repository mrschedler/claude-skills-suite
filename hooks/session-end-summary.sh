#!/usr/bin/env bash
# Claude Code Stop hook — session-end decision points.
# Only fires on second stop (stop_hook_active=true) to avoid running on every
# mid-conversation response. Presents reminders; actual MCP calls are the
# agent's responsibility. Always exits 0.

INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('stop_hook_active', False))" 2>/dev/null || echo "false")

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
