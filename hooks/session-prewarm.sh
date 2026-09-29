#!/usr/bin/env bash
# SessionStart hook — fast local context snapshot.
# Transport-agnostic: no SSH, no MCP; only local calls (sync-health.sh reads 127.0.0.1 Syncthing).
# Output is consumed by agents, not humans.
# Always exits 0.

export PATH="/c/Users/matts/AppData/Local/Microsoft/WinGet/Packages/SQLite.SQLite_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

echo "cwd=$(pwd)"
echo "git_root=${GIT_ROOT:-none}"

# Stale-tree guard: warns when Syncthing is down/behind or the project has sync conflicts.
[[ -x /c/dev/claude-skills-suite/hooks/sync-health.sh ]] && \
  /c/dev/claude-skills-suite/hooks/sync-health.sh "$GIT_ROOT"

# Claude Desktop/Code updates periodically overwrite our config symlinks
# with regular files (atomic write pattern). Detect and auto-repair here
# so the zero-drift config wiring stays intact across app updates.
[[ -x /c/dev/claude-skills-suite/scripts/verify-symlinks.sh ]] && \
  /c/dev/claude-skills-suite/scripts/verify-symlinks.sh

if [[ -n "$GIT_ROOT" ]]; then
  [[ -f "$GIT_ROOT/GROUNDING.md" ]] && echo "grounding=true" || echo "grounding=false NO_GROUNDING: Run /project-organize"

  DB="$GIT_ROOT/artifacts/project.db"
  if [[ -f "$DB" ]]; then
    COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM artifacts;" 2>/dev/null || echo "0")
    echo "artifact_db=${COUNT}_records"
    sqlite3 "$DB" "SELECT skill || '/' || phase || '/' || label || ' (' || created_at || ')' FROM artifacts ORDER BY id DESC LIMIT 3;" 2>/dev/null
  fi
fi

# Session janitor nudge (local-only; agent acts via MCP). Full tiers live in
# behavioral-reminders SESSION JANITOR + skills/rehydrate Step 8.
echo "action=session_janitor"
echo "reminder=After rehydrate: apply memory auto-heals (quota 5). Supersede/update/confirm/tag gunk only. Never delete without Matt. Opt out: /rehydrate --no-hygiene."

exit 0
