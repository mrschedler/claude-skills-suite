#!/usr/bin/env bash
# db.sh — Artifact store helper for skill suite projects.
#
# Usage: source artifacts/db.sh   (from project root)
#
# Functions:
#   db_init                           — create DB + schema if not exists
#   db_write   SKILL PHASE LABEL CONTENT  — insert new record
#   db_upsert  SKILL PHASE LABEL CONTENT  — replace existing record (delete + insert)
#   db_read    SKILL PHASE [LABEL]        — fetch most recent matching content
#   db_read_all SKILL [PHASE]             — fetch all matching content rows (newline-sep headers)
#   db_exists  SKILL PHASE [LABEL]        — exits 0 if any matching record exists
#   db_age_hours SKILL PHASE [LABEL]      — echo hours since most recent record (or empty if none)
#   db_search  QUERY                      — FTS5 full-text search, returns skill|phase|label|snippet
#   db_list                               — show all records (id|skill|phase|label|created_at)
#
# Artifact DB location: artifacts/project.db (relative to project root)
# Requires: sqlite3, xxd (both available on macOS by default)

_DB="${PROJECT_DB:-$(git rev-parse --show-toplevel 2>/dev/null)/artifacts/project.db}"

db_init() {
  mkdir -p "$(dirname "$_DB")"
  sqlite3 "$_DB" <<'SQL'
CREATE TABLE IF NOT EXISTS artifacts (
  id         INTEGER PRIMARY KEY,
  skill      TEXT NOT NULL,
  phase      TEXT NOT NULL DEFAULT '',
  label      TEXT NOT NULL DEFAULT '',
  content    TEXT NOT NULL,
  created_at TEXT DEFAULT (datetime('now'))
);
CREATE VIRTUAL TABLE IF NOT EXISTS artifacts_fts USING fts5(
  skill, phase, label, content,
  content='artifacts', content_rowid='id'
);
CREATE TRIGGER IF NOT EXISTS artifacts_ai AFTER INSERT ON artifacts BEGIN
  INSERT INTO artifacts_fts(rowid, skill, phase, label, content)
  VALUES (new.id, new.skill, new.phase, new.label, new.content);
END;
CREATE TRIGGER IF NOT EXISTS artifacts_ad AFTER DELETE ON artifacts BEGIN
  INSERT INTO artifacts_fts(artifacts_fts, rowid, skill, phase, label, content)
  VALUES ('delete', old.id, old.skill, old.phase, old.label, old.content);
END;
CREATE TRIGGER IF NOT EXISTS artifacts_au AFTER UPDATE ON artifacts BEGIN
  INSERT INTO artifacts_fts(artifacts_fts, rowid, skill, phase, label, content)
  VALUES ('delete', old.id, old.skill, old.phase, old.label, old.content);
  INSERT INTO artifacts_fts(rowid, skill, phase, label, content)
  VALUES (new.id, new.skill, new.phase, new.label, new.content);
END;
SQL
}

# Escape single quotes for safe SQL interpolation
_db_esc() { printf '%s' "${1//\'/\'\'}"; }

db_write() {
  # Insert new record. Does NOT replace existing — use db_upsert for that.
  local skill="$1" phase="$2" label="$3" content="$4"
  db_init
  local hex; hex=$(printf '%s' "$content" | xxd -p | tr -d '\n')
  sqlite3 "$_DB" "INSERT INTO artifacts(skill,phase,label,content) VALUES('$(_db_esc "$skill")','$(_db_esc "$phase")','$(_db_esc "$label")',cast(x'$hex' as text));"
}

db_upsert() {
  # Delete any existing record with matching skill+phase+label, then insert.
  local skill="$1" phase="$2" label="$3" content="$4"
  db_init
  local hex; hex=$(printf '%s' "$content" | xxd -p | tr -d '\n')
  sqlite3 "$_DB" "
    DELETE FROM artifacts
      WHERE skill='$(_db_esc "$skill")'
        AND phase='$(_db_esc "$phase")'
        AND label='$(_db_esc "$label")';
    INSERT INTO artifacts(skill,phase,label,content)
      VALUES('$(_db_esc "$skill")','$(_db_esc "$phase")','$(_db_esc "$label")',cast(x'$hex' as text));
  "
}

db_read() {
  # Return content of the most recent record matching skill+phase[+label].
  local skill="$1" phase="$2" label="${3:-}"
  db_init
  if [[ -n "$label" ]]; then
    sqlite3 "$_DB" "SELECT content FROM artifacts
      WHERE skill='$(_db_esc "$skill")' AND phase='$(_db_esc "$phase")' AND label='$(_db_esc "$label")'
      ORDER BY id DESC LIMIT 1;"
  else
    sqlite3 "$_DB" "SELECT content FROM artifacts
      WHERE skill='$(_db_esc "$skill")' AND phase='$(_db_esc "$phase")'
      ORDER BY id DESC LIMIT 1;"
  fi
}

db_read_all() {
  # Return content of all records matching skill[+phase], oldest-first.
  # Each record's content is printed; records are separated by a blank line.
  local skill="$1" phase="${2:-}"
  db_init
  if [[ -n "$phase" ]]; then
    sqlite3 -separator $'\n---\n' "$_DB" "SELECT content FROM artifacts
      WHERE skill='$(_db_esc "$skill")' AND phase='$(_db_esc "$phase")'
      ORDER BY id ASC;"
  else
    sqlite3 -separator $'\n---\n' "$_DB" "SELECT content FROM artifacts
      WHERE skill='$(_db_esc "$skill")'
      ORDER BY id ASC;"
  fi
}

db_exists() {
  # Exit 0 (success) if any matching record exists, exit 1 otherwise.
  local skill="$1" phase="$2" label="${3:-}"
  db_init
  local count
  if [[ -n "$label" ]]; then
    count=$(sqlite3 "$_DB" "SELECT COUNT(*) FROM artifacts
      WHERE skill='$(_db_esc "$skill")' AND phase='$(_db_esc "$phase")' AND label='$(_db_esc "$label")';")
  else
    count=$(sqlite3 "$_DB" "SELECT COUNT(*) FROM artifacts
      WHERE skill='$(_db_esc "$skill")' AND phase='$(_db_esc "$phase")';")
  fi
  [[ "$count" -gt 0 ]]
}

db_age_hours() {
  # Echo the number of hours since the most recent matching record was created.
  # Echoes nothing if no record exists.
  local skill="$1" phase="$2" label="${3:-}"
  db_init
  local ts
  if [[ -n "$label" ]]; then
    ts=$(sqlite3 "$_DB" "SELECT created_at FROM artifacts
      WHERE skill='$(_db_esc "$skill")' AND phase='$(_db_esc "$phase")' AND label='$(_db_esc "$label")'
      ORDER BY id DESC LIMIT 1;")
  else
    ts=$(sqlite3 "$_DB" "SELECT created_at FROM artifacts
      WHERE skill='$(_db_esc "$skill")' AND phase='$(_db_esc "$phase")'
      ORDER BY id DESC LIMIT 1;")
  fi
  [[ -z "$ts" ]] && return
  # Compute difference in hours using sqlite3 (avoids date command portability issues)
  sqlite3 "$_DB" "SELECT CAST((julianday('now') - julianday('$(_db_esc "$ts")')) * 24 AS INTEGER);"
}

db_search() {
  # FTS5 full-text search. Returns rows of: skill | phase | label | snippet
  local query="$1"
  db_init
  sqlite3 "$_DB" "SELECT skill, phase, label,
    snippet(artifacts_fts, 3, '[', ']', '...', 20)
    FROM artifacts_fts
    WHERE artifacts_fts MATCH '$(_db_esc "$query")'
    ORDER BY rank;"
}

db_list() {
  # List all artifact records — metadata only, no content.
  db_init
  sqlite3 "$_DB" "SELECT id, skill, phase, label, created_at FROM artifacts ORDER BY created_at DESC;"
}
