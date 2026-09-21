#!/usr/bin/env node
// Fake DB for interagent-monitor-poll offline tests.
//
// Reads SQL on stdin (exactly as psql would), mutates INTERAGENT_FAKE_DB JSON
// state, and prints the same single-line JSON envelope the real CTE returns.
// Never touches live pgvector.
//
// It models three things the real database does that the tests depend on:
//   1. SNAPSHOT SEMANTICS — the inbox/sent CTEs read the pre-statement snapshot,
//      so a row stamped by stamp_delivered in the SAME statement still comes
//      back with delivered_at = NULL. The old fake stamped first and reported
//      the new value, which flattered the build.
//   2. STAMP-BY-ID — only the ids handed over in ack_ids are stamped, and only
//      while delivered_at IS NULL.
//   3. AN UNMIGRATED DATABASE — with INTERAGENT_FAKE_SCHEMA=legacy the full
//      statement fails on stderr with psql's real wording and exit 1, which is
//      what the inbox-only fallback has to survive.
//
// env: INTERAGENT_FAKE_DB (required), INTERAGENT_FAKE_SCHEMA=full|legacy
'use strict';
const fs = require('fs');

const statePath = process.env.INTERAGENT_FAKE_DB;
if (!statePath) {
  console.error('INTERAGENT_FAKE_DB required');
  process.exit(1);
}
const fakeSchema = (process.env.INTERAGENT_FAKE_SCHEMA || 'full').toLowerCase() === 'legacy'
  ? 'legacy' : 'full';

let sql = '';
process.stdin.on('data', (c) => { sql += c; });
process.stdin.on('end', () => {
  // --- schema probe -------------------------------------------------------
  if (/information_schema\.columns/.test(sql) && /THEN 'full' ELSE 'legacy'/.test(sql)) {
    process.stdout.write(fakeSchema + '\n');
    return;
  }

  const wantsFull = /'schema',\s*'full'/.test(sql);

  // --- an unmigrated database rejects the full statement ------------------
  if (wantsFull && fakeSchema === 'legacy') {
    process.stderr.write('ERROR:  column a.delivered_to does not exist\nLINE 1: ...\n');
    process.exit(1);
  }

  const state = JSON.parse(fs.readFileSync(statePath, 'utf8'));
  state.assignments = state.assignments || [];
  state.watchers = state.watchers || [];

  // A literal may contain SQL-escaped quotes ('' for '), so the body is
  // "not-a-quote OR a doubled quote" — [^']* stops at the first half of a ''
  // and silently mis-parses the value.
  const LIT = String.raw`'((?:[^']|'')*)'`;
  const m = sql.match(new RegExp(LIT + String.raw`::text\s+AS\s+machine`));
  const p = sql.match(new RegExp(LIT + String.raw`::text\s+AS\s+project`));
  const pidM = sql.match(/(\d+)::int\s+AS\s+pid/);
  const sentM = sql.match(/(\d+)::int\s+AS\s+sent_hours/);
  const intervalM = sql.match(/(\d+)::int\s+AS\s+interval_secs/);
  const ackM = sql.match(/ARRAY\[([^\]]*)\]::bigint\[\]/);
  const sinceM = sql.match(/'([^']*)'::timestamptz\s+AS\s+since/);

  const machine = m ? m[1].replace(/''/g, "'") : '';
  const project = p ? p[1].replace(/''/g, "'") : '';
  const pid = pidM ? parseInt(pidM[1], 10) : 0;
  const sentHours = sentM ? parseInt(sentM[1], 10) : 72;
  const intervalSecs = intervalM ? parseInt(intervalM[1], 10) : 5;
  const ackIds = ackM
    ? ackM[1].split(',').map((s) => s.trim()).filter(Boolean).map((s) => String(parseInt(s, 10)))
    : [];
  const sinceRaw = sinceM ? sinceM[1] : '-infinity';
  const since = sinceRaw === '-infinity' ? -Infinity : Date.parse(sinceRaw);

  const now = state.now ? Date.parse(state.now) : Date.now();
  const nowIso = new Date(now).toISOString();

  function refsOf(a) {
    return Array.isArray(a.context_refs) ? a.context_refs : (a.refs || []);
  }
  function projectMatch(a) {
    const refs = refsOf(a);
    const proj = refs.filter((x) => x && x.type === 'project');
    if (proj.length === 0) return true;
    return proj.some((x) => String(x.id) === project);
  }
  function ttlOk(a) {
    if (a.ttl_hours == null) return true;
    return Date.parse(a.created_at) > now - a.ttl_hours * 3600 * 1000;
  }
  function withinSent(a) {
    return Date.parse(a.created_at) > now - sentHours * 3600 * 1000;
  }
  function trunc(v) {
    return v == null ? null : String(v).slice(0, 200);   // left(result, 200)
  }
  function row(event, a) {
    const r = {
      event,
      id: a.id,
      title: a.title || '',
      from_agent: a.from_agent,
      to_target: a.to_target,
      status: a.status,
      claimed_by: a.claimed_by || null,
      result: trunc(a.result),
      refs: refsOf(a),
      claimed_at: a.claimed_at || null,
      completed_at: a.completed_at || null,
      created_at: a.created_at
    };
    if (wantsFull) {
      r.delivered_to = a.delivered_to || null;
      r.delivered_at = a.delivered_at || null;
    }
    return r;
  }

  // (1) SNAPSHOT: capture what the SELECTs will see, BEFORE any mutation.
  const snapshot = state.assignments.map((a) => ({ ...a }));

  // --- legacy statement: inbox only, no stamping, no watchers --------------
  if (!wantsFull) {
    const rows = snapshot
      .filter((a) => a.status === 'pending' &&
        (a.to_target === machine || a.to_target === 'any') &&
        ttlOk(a) && !a.archived && projectMatch(a))
      .map((a) => row('inbox', a));
    fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
    process.stdout.write(JSON.stringify({
      schema: 'legacy', now: nowIso, stamped: [], watchers: [], rows
    }) + '\n');
    return;
  }

  // (2) upsert_watcher heartbeat
  const wi = state.watchers.findIndex((w) => w.machine === machine && w.project === project);
  const watcher = { machine, project, pid, interval_secs: intervalSecs, last_poll_at: nowIso };
  if (wi >= 0) state.watchers[wi] = watcher;
  else state.watchers.push(watcher);

  // (3) stamp_delivered — ONLY the acked ids, and only if still unstamped
  const stamped = [];
  for (const a of state.assignments) {
    if (!ackIds.includes(String(a.id))) continue;
    if (a.delivered_at) continue;
    a.delivered_to = machine;
    a.delivered_at = nowIso;
    stamped.push(a.id);
  }

  // (4) the SELECTs, against the pre-mutation snapshot
  const rows = [];
  for (const a of snapshot) {
    if (a.status === 'pending' && (a.to_target === machine || a.to_target === 'any') &&
        ttlOk(a) && !a.archived && projectMatch(a)) {
      rows.push(row('inbox', a));
    }
  }
  for (const a of snapshot) {
    if (a.from_agent !== machine || !withinSent(a) || a.archived) continue;
    const changed = Math.max(
      Date.parse(a.created_at) || 0,
      a.delivered_at ? Date.parse(a.delivered_at) : 0,
      a.claimed_at ? Date.parse(a.claimed_at) : 0,
      a.completed_at ? Date.parse(a.completed_at) : 0
    );
    if (a.delivered_at && !(changed >= since)) continue;
    rows.push(row('sent', a));
  }

  // (5) watchers_out — the staleness reader's input
  const targets = new Set(rows.filter((r) => r.event === 'sent').map((r) => String(r.to_target)));
  const watchers = state.watchers
    .filter((w) => targets.has(String(w.machine)))
    .map((w) => {
      const idle = Math.round((now - Date.parse(w.last_poll_at)) / 1000);
      const iv = Math.max(w.interval_secs == null ? intervalSecs : w.interval_secs, 1);
      return { machine: w.machine, idle_secs: idle, stale: idle > 3 * iv };
    });

  fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
  process.stdout.write(JSON.stringify({
    schema: 'full', now: nowIso, stamped, watcher_upserts: 1, watchers, rows
  }) + '\n');
});
