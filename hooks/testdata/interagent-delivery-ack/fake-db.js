#!/usr/bin/env node
// Fake DB for interagent-monitor-poll offline tests.
// Reads SQL on stdin (from poller), mutates INTERAGENT_FAKE_DB JSON state,
// prints the same JSON event array shape the real CTE returns.
'use strict';
const fs = require('fs');

const statePath = process.env.INTERAGENT_FAKE_DB;
if (!statePath) {
  console.error('INTERAGENT_FAKE_DB required');
  process.exit(1);
}

let sql = '';
process.stdin.on('data', (c) => { sql += c; });
process.stdin.on('end', () => {
  const state = JSON.parse(fs.readFileSync(statePath, 'utf8'));
  state.assignments = state.assignments || [];
  state.watchers = state.watchers || [];

  const m = sql.match(/'([^']*)'::text\s+AS\s+machine/);
  const p = sql.match(/'([^']*)'::text\s+AS\s+project/);
  const pidM = sql.match(/(\d+)::int\s+AS\s+pid/);
  const undelM = sql.match(/(\d+)::int\s+AS\s+undelivered_min/);
  const sentM = sql.match(/(\d+)::int\s+AS\s+sent_hours/);
  const intervalM = sql.match(/(\d+)::int\s+AS\s+interval_secs/);

  const machine = m ? m[1].replace(/''/g, "'") : '';
  const project = p ? p[1].replace(/''/g, "'") : '';
  const pid = pidM ? parseInt(pidM[1], 10) : 0;
  const sentHours = sentM ? parseInt(sentM[1], 10) : 72;
  const now = state.now ? Date.parse(state.now) : Date.now();
  const nowIso = new Date(now).toISOString();

  // upsert watcher
  const wi = state.watchers.findIndex((w) => w.machine === machine && w.project === project);
  const watcher = { machine, project, pid, last_poll_at: nowIso };
  if (wi >= 0) state.watchers[wi] = watcher;
  else state.watchers.push(watcher);

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
    const created = Date.parse(a.created_at);
    return created > now - a.ttl_hours * 3600 * 1000;
  }
  function withinSent(a) {
    const created = Date.parse(a.created_at);
    return created > now - sentHours * 3600 * 1000;
  }

  // stamp undelivered matching inbox
  for (const a of state.assignments) {
    if (a.status !== 'pending') continue;
    if (!(a.to_target === machine || a.to_target === 'any')) continue;
    if (!ttlOk(a)) continue;
    if (a.delivered_at) continue;
    if (a.archived) continue;
    if (!projectMatch(a)) continue;
    a.delivered_to = machine;
    a.delivered_at = nowIso;
  }

  const events = [];
  for (const a of state.assignments) {
    if (a.status === 'pending' && (a.to_target === machine || a.to_target === 'any') &&
        ttlOk(a) && !a.archived && projectMatch(a)) {
      events.push(row('inbox', a));
    }
  }
  for (const a of state.assignments) {
    if (a.from_agent === machine && withinSent(a) && !a.archived) {
      events.push(row('sent', a));
    }
  }

  function row(event, a) {
    return {
      event,
      id: a.id,
      title: a.title || '',
      from_agent: a.from_agent,
      to_target: a.to_target,
      status: a.status,
      claimed_by: a.claimed_by || null,
      result: a.result == null ? null : a.result,
      refs: refsOf(a),
      delivered_to: a.delivered_to || null,
      delivered_at: a.delivered_at || null,
      claimed_at: a.claimed_at || null,
      completed_at: a.completed_at || null,
      created_at: a.created_at
    };
  }

  fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
  // silence unused
  void undelM; void intervalM;
  process.stdout.write(JSON.stringify(events));
});
