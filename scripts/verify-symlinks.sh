#!/usr/bin/env bash
# verify-symlinks.sh -- Detect and repair Claude config symlinks that
# Claude Desktop/Code updates have overwritten with regular files.
#
# Root cause: the Claude apps use atomic writes (write-new-file + rename)
# which replaces the symlink with whatever they wrote. This silently breaks
# the zero-drift config wiring (see Qdrant: "claude config wiring pattern").
#
# Invocation:
#   - From hooks/session-prewarm.sh on every Claude Code session start
#   - From scripts/claude-desktop-launcher.bat before starting Claude Desktop
#
# Output: one key=value line. Always exits 0.
# Transport-agnostic: no SSH, no MCP, no network.
#
# Safety: only deletes a file if it is NOT a symlink AND the intended target
# exists AND the link path is inside one of the expected Claude config roots.

SKILLS_SUITE="${SKILLS_SUITE_DIR:-/c/dev/claude-skills-suite}"
CLAUDE_HOME="${CLAUDE_HOME:-/c/Users/matts/.claude}"
CLAUDE_APPDATA="${CLAUDE_APPDATA:-/c/Users/matts/AppData/Roaming/Claude}"

# link_path|target_path|type (F=file, D=directory)
LINKS=(
  "$CLAUDE_HOME/settings.json|$SKILLS_SUITE/config/code/settings.json|F"
  "$CLAUDE_HOME/CLAUDE.md|$SKILLS_SUITE/config/code/CLAUDE.md|F"
  "$CLAUDE_HOME/behavioral-reminders.txt|$SKILLS_SUITE/config/code/behavioral-reminders.txt|F"
  "$CLAUDE_HOME/skills|$SKILLS_SUITE/skills|D"
  "$CLAUDE_APPDATA/claude_desktop_config.json|$SKILLS_SUITE/config/desktop/claude_desktop_config.json|F"
)

checked=0
ok=0
repaired=0
failed=0
detail=""

add_detail() {
  detail="${detail}${detail:+,}$1"
}

for entry in "${LINKS[@]}"; do
  IFS='|' read -r link target type <<< "$entry"
  checked=$((checked+1))
  name=$(basename "$link")

  # Target must exist before we create a link to it. Missing target means
  # something deeper is wrong (skills-suite moved or not cloned yet).
  if [[ ! -e "$target" ]]; then
    failed=$((failed+1))
    add_detail "${name}:no-target"
    continue
  fi

  # Already a symlink? Done.
  if [[ -L "$link" ]]; then
    ok=$((ok+1))
    continue
  fi

  # Safety guard: refuse to touch anything outside the two known roots.
  case "$link" in
    "$CLAUDE_HOME"/*|"$CLAUDE_APPDATA"/*) ;;
    *)
      failed=$((failed+1))
      add_detail "${name}:outside-known-root"
      continue
      ;;
  esac

  # Convert to Windows paths for mklink.
  link_win=$(cygpath -w "$link")
  target_win=$(cygpath -w "$target")

  # Remove the regular file/dir that replaced the link.
  if [[ -e "$link" ]]; then
    rm -rf "$link" 2>/dev/null
  fi

  # Recreate the link. mklink /D for directories, no flag for files.
  if [[ "$type" == "D" ]]; then
    MSYS_NO_PATHCONV=1 cmd /c mklink /D "$link_win" "$target_win" >/dev/null 2>&1
  else
    MSYS_NO_PATHCONV=1 cmd /c mklink "$link_win" "$target_win" >/dev/null 2>&1
  fi

  if [[ -L "$link" ]]; then
    repaired=$((repaired+1))
    add_detail "${name}:repaired"
  else
    failed=$((failed+1))
    add_detail "${name}:repair-failed"
  fi
done

if [[ $repaired -eq 0 && $failed -eq 0 ]]; then
  echo "symlinks_ok=${ok}/${checked}"
else
  echo "symlinks_ok=${ok}/${checked} repaired=${repaired} failed=${failed} detail=${detail}"
fi

exit 0
