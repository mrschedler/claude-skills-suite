#!/usr/bin/env bash
# Syncthing health for the C:\dev share, printed as one `sync=` line at SessionStart.
# Why: a machine whose Syncthing stopped keeps a stale tree; edits there get fresh
# mtimes and overwrite newer files on other machines when it reconnects
# (2026-09-29 incident, skip). Local only: 127.0.0.1 Syncthing API, 2 s timeout.
# Never prints the API key. Always exits 0.
FOLDER="${SYNC_FOLDER_ID:-dev-projects}"
CFG="${LOCALAPPDATA:-$HOME/AppData/Local}/Syncthing/config.xml"
ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

conflicts=$(find "$ROOT" -maxdepth 4 -name '*.sync-conflict-*' -not -path '*/node_modules/*' 2>/dev/null | wc -l)
key=$(grep -o '<apikey>[^<]*' "$CFG" 2>/dev/null | head -1 | cut -d'>' -f2)
if [[ -z "$key" ]]; then
  echo "sync=unknown (no Syncthing config at $CFG) conflicts_in_project=$conflicts"; exit 0
fi

api() { curl -s -m 2 -H "X-API-Key: $key" "http://127.0.0.1:8384$1"; }
status=$(api "/rest/db/status?folder=$FOLDER")
if [[ -z "$status" ]]; then
  echo "sync=WARN syncthing not responding on 127.0.0.1:8384 — tree may be stale; edits here can overwrite newer files elsewhere. conflicts_in_project=$conflicts"; exit 0
fi
conns=$(api "/rest/system/connections")

node -e '
const s = JSON.parse(process.argv[1] || "{}");
let c = {}; try { c = JSON.parse(process.argv[2] || "{}").connections || {}; } catch {}
const connected = Object.values(c).filter(x => x.connected).length;
const conflicts = Number(process.argv[3]);
const probs = [];
if (s.error) probs.push("folder error: " + s.error);
if (connected === 0) probs.push("no connected peers");
if (/error|stopped|unknown/.test(s.state || "")) probs.push("state=" + s.state); // scanning/syncing alone is normal
if ((s.needTotalItems || 0) > 0) probs.push("need=" + s.needTotalItems + " items");
if ((s.errors || 0) + (s.pullErrors || 0) > 0) probs.push("errors=" + ((s.errors || 0) + (s.pullErrors || 0)));
if (conflicts > 0) probs.push(conflicts + " sync-conflict file(s) in this project");
console.log(probs.length
  ? "sync=WARN " + probs.join("; ") + " — tree may be stale or diverged; edits here can overwrite newer files elsewhere"
  : "sync=ok peers=" + connected);
' "$status" "$conns" "$conflicts" 2>/dev/null || echo "sync=unknown (could not parse Syncthing status)"
exit 0
