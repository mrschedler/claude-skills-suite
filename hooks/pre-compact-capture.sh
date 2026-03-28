#!/usr/bin/env bash
# PreCompact hook — capture context before compaction
# Saves a lightweight snapshot of what the agent was working on.
# Runs alongside behavioral-reminders.txt injection.
# Always exits 0 — never blocks compaction.

SNAPSHOT_DIR=~/.claude/shell-snapshots
mkdir -p "$SNAPSHOT_DIR"

SNAPSHOT_FILE="$SNAPSHOT_DIR/pre-compact-$(date +%Y%m%d-%H%M%S).md"

{
  echo "# Pre-Compact Context Snapshot — $(date '+%Y-%m-%d %H:%M')"
  echo ""
  echo "## Working Directory"
  echo "$(pwd)"
  echo ""

  # Git state if in a repo
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "## Git State"
    echo "Branch: $(git branch --show-current 2>/dev/null)"
    echo ""
    echo "### Recent commits"
    git log --oneline -5 2>/dev/null || true
    echo ""
    echo "### Uncommitted changes"
    git diff --stat 2>/dev/null || true
    git diff --cached --stat 2>/dev/null || true
    echo ""
  fi

  echo "## Modified files (last 30 min)"
  find . -maxdepth 3 -name '*.py' -o -name '*.ts' -o -name '*.js' -o -name '*.md' 2>/dev/null | \
    xargs ls -lt --time-style=+%s 2>/dev/null | \
    head -10 || true

} > "$SNAPSHOT_FILE" 2>/dev/null

# Keep only last 5 snapshots
ls -t "$SNAPSHOT_DIR"/pre-compact-*.md 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true

echo "Context snapshot saved. After compaction, check $SNAPSHOT_FILE if you need to recall what you were working on."

exit 0
