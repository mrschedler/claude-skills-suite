#!/usr/bin/env bash
# verify-setup.sh — Check all prerequisites for Claude Code hooks.
# Run in Git Bash on Windows. Informational only; always exits 0.
# Usage: bash ~/.claude/verify-setup.sh

# Ensure HOME is set (Git Bash sometimes doesn't export it)
: "${HOME:=$(cd ~ && pwd)}"

PASS=0
FAIL=0
REMEDIATION=""

check() {
  local label="$1"
  local ok="$2"
  local advice="$3"

  if [[ "$ok" == "true" ]]; then
    echo "[OK]   $label"
    ((PASS++))
  else
    echo "[FAIL] $label"
    ((FAIL++))
    REMEDIATION="${REMEDIATION}\n  - ${label}: ${advice}"
  fi
}

echo "=== Claude Code Hook Prerequisites ==="
echo ""

# ── 1. python3 available (needed by session-end-summary.sh + search-before-act.sh)
if command -v python3 &>/dev/null; then
  PY_VER=$(python3 --version 2>&1)
  check "python3 available ($PY_VER)" "true"
else
  check "python3 available" "false" \
    "Install Python 3 and ensure 'python3' is on PATH. Git Bash may need an alias in ~/.bashrc: alias python3=python"
fi

# ── 2. SSH config has "deepthought" host entry
if grep -qi 'Host.*deepthought' "$HOME/.ssh/config" 2>/dev/null; then
  check "SSH config has 'deepthought' host entry" "true"
else
  check "SSH config has 'deepthought' host entry" "false" \
    "Add a Host deepthought block to ~/.ssh/config pointing to 192.168.0.129 with IdentityFile ~/.ssh/claude_unraid"
fi

# ── 3. SSH key exists
if [[ -f "$HOME/.ssh/claude_unraid" ]]; then
  check "SSH key ~/.ssh/claude_unraid exists" "true"
else
  check "SSH key ~/.ssh/claude_unraid exists" "false" \
    "Generate or copy the claude_unraid private key to ~/.ssh/claude_unraid (must match authorized_keys on Unraid)"
fi

# ── 4. SSH can connect to deepthought (quick connectivity test)
if ssh -o ConnectTimeout=5 -o BatchMode=yes deepthought "echo ok" &>/dev/null; then
  check "SSH connects to deepthought" "true"
else
  check "SSH connects to deepthought" "false" \
    "Verify Unraid (192.168.0.129) is reachable, sshd is running, and claude_unraid key is in /root/.ssh/authorized_keys on Unraid"
fi

# ── 5. Syncthing Obsidian vault exists
if [[ -d "$HOME/Syncthing/Obsidian-Vault" ]]; then
  NOTE_COUNT=$(find "$HOME/Syncthing/Obsidian-Vault" -name '*.md' 2>/dev/null | head -50 | wc -l)
  check "Syncthing Obsidian vault exists ($NOTE_COUNT+ notes)" "true"
else
  check "Syncthing Obsidian vault exists at ~/Syncthing/Obsidian-Vault/" "false" \
    "Install Syncthing and configure it to sync the Obsidian vault from Unraid to ~/Syncthing/Obsidian-Vault/"
fi

# ── 6. Hook scripts exist and are executable
for SCRIPT in session-prewarm.sh session-end-summary.sh search-before-act.sh; do
  FULL="$HOME/.claude/$SCRIPT"
  if [[ -f "$FULL" && -x "$FULL" ]]; then
    check "Hook script $SCRIPT exists and is executable" "true"
  elif [[ -f "$FULL" ]]; then
    check "Hook script $SCRIPT is executable" "false" \
      "Run: chmod +x $FULL"
  else
    check "Hook script $SCRIPT exists" "false" \
      "Script missing at $FULL — sync ~/.claude from another machine or recreate it"
  fi
done

# ── 7. Gateway reachable via SSH+docker
if ssh -o ConnectTimeout=5 -o BatchMode=yes deepthought \
    "docker inspect homelab-mcp-gateway --format '{{.State.Status}}'" 2>/dev/null | grep -q 'running'; then
  check "MCP Gateway container running on deepthought" "true"
else
  check "MCP Gateway container running on deepthought" "false" \
    "Ensure homelab-mcp-gateway container is running on Unraid. Check with: ssh deepthought docker ps | grep gateway"
fi

# ── Summary ─────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL))
echo ""
echo "=== $PASS/$TOTAL checks passed ==="

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Remediation needed:"
  echo -e "$REMEDIATION"
fi

exit 0
