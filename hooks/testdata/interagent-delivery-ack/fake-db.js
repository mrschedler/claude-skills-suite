#!/usr/bin/env node
// Fake DB for the interagent monitor's offline tests.
//
// Reads the poll SQL on stdin exactly as psql would, applies the same
// predicates against INTERAGENT_FAKE_DB (a JSON file), and prints the single
// json_build_object envelope the real statement returns. It NEVER touches live
// pgvector and opens no socket.
//
// It models two things the tests depend on:
//   1. THE DATABASE OWNS THE CLOCK. `now` comes from state.now if present, so
//      an arm can put the fake clock ten days ahead of the machine and catch a
//      process.js that ages rows against Date.now().
//   2. A HOP THAT FAILS LOOKS LIKE A HOP THAT FAILS. If the file named by
//      INTERAGENT_FAKE_FAIL_FILE exists, it writes psql's wording to stderr and
//      exits 1 — no stdout at all. Arms create and remove that file to drive a
//      failure/recovery sequence mid-loop.
//
// This build stamps nothing and has no watcher table: the receiving agent's
// claim is the acknowledgement.
//
// env: INTERAGENT_FAKE_DB (required), INTERAGENT_FAKE_FAIL_FILE (optional)
'use strict';
const fs = require('fs');

const statePath = process.env.INTERAGENT_FAKE_DB;
if (!statePath) { console.error('INTERAGENT_FAKE_DB required'); process.exit(1); }

let sql = '';
process.stdin.on('data', (c) => { sql += c; });
process.stdin.on('end', () => {
  const failFile = process.env.INTERAGENT_FAKE_FAIL_FILE;
  if (failFile && fs.existsSync(failFile)) {
    process.stderr.write('ssh: connect to host deepthought port 22: Connection timed out\n');
    process.exit(1);
  }

  // psql ignores `--` comments, and so must we: the poller's SQL carries a
  // comment that names the predicates below, and matching on comment text
  // rather than on the statement would let a reverted predicate pass.
  sql = sql.replace(/--[^\n]*/g, '');

  const state = JSON.parse(fs.readFileSync(statePath, 'utf8'));
  const assignments = state.assignments || [];

  // A literal may carry SQL-escaped quotes ('' for '), so the body is
  // "not-a-quote OR a doubled quote".
  const LIT = String.raw`'((?:[^']|'')*)'`;
  const m = sql.match(new RegExp(LIT + String.raw`::text AS machine`));
  const p = sql.match(new RegExp(LIT + String.raw`::text AS project`));
  const sh = sql.match(/(\d+)::int AS sent_hours/);
  const machine = m ? m[1].replace(/''/g, "'") : '';
  const project = p ? p[1].replace(/''/g, "'") : '';
  const sentHours = sh ? parseInt(sh[1], 10) : 72;

  const now = state.now ? Date.parse(state.now) : Date.now();
  const nowIso = new Date(now).toISOString();

  const refsOf = (a) => (Array.isArray(a.context_refs) ? a.context_refs : (a.refs || []));
  const projectMatch = (a) => {
    const proj = refsOf(a).filter((x) => x && x.type === 'project');
    return proj.length === 0 || proj.some((x) => String(x.id) === project);
  };
  // The TTL predicate is READ OUT OF THE SQL, not assumed, so that reverting
  // the durable-todo guard in the poller is visible here. Without the
  // `ttl_hours IS NULL` arm, make_interval(hours => NULL) is NULL, the
  // comparison is UNKNOWN, and every todo (ttl_hours IS NULL) is silently
  // dropped — exactly what happened on 2026-09-20.
  const ttlNullKept = /ttl_hours IS NULL/.test(sql);
  const ttlOk = (a) => {
    if (a.ttl_hours == null) return ttlNullKept;
    return Date.parse(a.created_at) > now - a.ttl_hours * 3600 * 1000;
  };
  const row = (event, a) => ({
    event,
    id: a.id,
    title: a.title || '',
    from_agent: a.from_agent,
    to_target: a.to_target,
    status: a.status,
    claimed_by: a.claimed_by || null,
    result: event === 'sent' && a.result != null ? String(a.result).slice(0, 200) : null,
    refs: refsOf(a),
    claimed_at: a.claimed_at || null,
    completed_at: a.completed_at || null,
    created_at: a.created_at
  });

  const rows = [];
  for (const a of assignments) {
    if (a.status === 'pending' && !a.claimed_by &&
        (a.to_target === machine || a.to_target === 'any') &&
        ttlOk(a) && projectMatch(a)) {
      rows.push(row('inbox', a));
    }
  }
  for (const a of assignments) {
    if (a.from_agent !== machine) continue;
    if (!(Date.parse(a.created_at) > now - sentHours * 3600 * 1000)) continue;
    rows.push(row('sent', a));
  }

  process.stdout.write(JSON.stringify({ now: nowIso, rows }) + '\n');
});
