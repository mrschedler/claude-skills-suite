#!/usr/bin/env bash
# SessionStart hook — fast local context snapshot.
# Transport-agnostic: no SSH, no MCP, no network calls.
# Output is consumed by agents, not humans.
# Always exits 0.

export PATH="/c/Users/matts/AppData/Local/Microsoft/WinGet/Packages/SQLite.SQLite_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

echo "cwd=$(pwd)"
echo "git_root=${GIT_ROOT:-none}"

if [[ -n "$GIT_ROOT" ]]; then
  [[ -f "$GIT_ROOT/GROUNDING.md" ]] && echo "grounding=true" || echo "grounding=false NO_GROUNDING: Run /project-organize"

  DB="$GIT_ROOT/artifacts/project.db"
  if [[ -f "$DB" ]]; then
    COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM artifacts;" 2>/dev/null || echo "0")
    echo "artifact_db=${COUNT}_records"
    sqlite3 "$DB" "SELECT skill || '/' || phase || '/' || label || ' (' || created_at || ')' FROM artifacts ORDER BY id DESC LIMIT 3;" 2>/dev/null
  fi
fi

exit 0
