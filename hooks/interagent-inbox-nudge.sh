#!/usr/bin/env bash
# UserPromptSubmit hook — interagent inbox PUSH (surfacing layer).
#
# WHY ─────────────────────────────────────────────────────────────────────────
# interagent is a pull-only, MACHINE-keyed mailbox. Two Claude Code sessions on
# one machine (e.g. dell-xps) share one inbox and only notice new mail when a
# human says "go check interagent". This hook removes that human relay by
# reminding the agent to drain its inbox on its own turns — turning pull into
# push-on-activity. For an actively-working session that is effectively immediate.
#
# ARCHITECTURE (why this is a nudge, not a fetch) ──────────────────────────────
# Hooks in this suite are LOCAL-ONLY: no SSH / MCP / HTTP (CLAUDE.md guardrail,
# butterfly-wings blast radius). A shell `command` hook also cannot invoke an MCP
# tool — interagent_call lives in the agent, not the CLI. So this hook does NOT
# fetch the inbox. It emits an action-reminder (same pattern as
# session-end-summary.sh's `action=...` lines) and the AGENT performs
# interagent_call > inbox / claim over MCP. Network stays on the agent side; the
# hook stays local, fast, and fail-open. True idle-reaction (no turn required) is
# the optional Monitor layer — see README-interagent-push.md.
#
# ROUTING (machine inbox -> per-session) ───────────────────────────────────────
# interagent targets a machine, not a session. To stop one session draining
# another same-machine session's mail, messages are tagged by PROJECT in
# context_refs: {type:"project", id:"<project-key>"}. The project key is the git
# root basename, else the cwd basename. The reminder tells the agent to claim
# only messages tagged for THIS project (plus untagged broadcasts) and skip mail
# tagged for other projects.
#
# THROTTLE ─────────────────────────────────────────────────────────────────────
# Fires at most once per INTERVAL seconds, tracked by a local timestamp file in a
# NON-synced runtime dir, so an active session is not nagged every prompt.
#
# Always exits 0. No output = no injection. Never blocks the user's turn.

INTERVAL=120  # seconds between nudges per project

# ── Project key: git root basename, else cwd basename ──
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -n "$GIT_ROOT" ]]; then
  PROJECT=$(basename "$GIT_ROOT")
else
  PROJECT=$(basename "$(pwd)")
fi

# ── Machine name from the non-synced .machine-id (fleet-portable) ──
MACHINE=$(sed -n 's/^machine:[[:space:]]*//p' /c/dev/.machine-id 2>/dev/null | head -1)
MACHINE=${MACHINE:-unknown}

# ── Throttle via a local, NON-synced timestamp file ──
# LOCALAPPDATA is per-machine and outside the Syncthing share, so runtime state
# never propagates to other machines. Fall back to TEMP, then /tmp.
STATE_DIR=$(printf '%s' "${LOCALAPPDATA:-${TEMP:-/tmp}}/claude-interagent" | tr '\\' '/')
mkdir -p "$STATE_DIR" 2>/dev/null
TS_FILE="$STATE_DIR/nudge-${PROJECT}.ts"

NOW=$(date +%s 2>/dev/null || echo 0)
LAST=0
[[ -f "$TS_FILE" ]] && LAST=$(cat "$TS_FILE" 2>/dev/null || echo 0)
[[ "$LAST" =~ ^[0-9]+$ ]] || LAST=0

if [[ "$NOW" -gt 0 ]] && (( NOW - LAST < INTERVAL )); then
  exit 0
fi
printf '%s' "$NOW" > "$TS_FILE" 2>/dev/null

cat <<EOF
INTERAGENT inbox check (machine=${MACHINE}, project=${PROJECT}):
- Call interagent_call > inbox {machine: "${MACHINE}"}.
- Surface + claim messages whose context_refs include {type:"project", id:"${PROJECT}"} (or one addressed to this specific session). Also surface untagged/broadcast messages, but do NOT claim those — leave them visible to sibling sessions.
- SKIP messages tagged for a different project: they belong to another session on this machine.
- If nothing matches, stay silent (do not narrate an empty inbox), then continue the user's task.
EOF

exit 0
