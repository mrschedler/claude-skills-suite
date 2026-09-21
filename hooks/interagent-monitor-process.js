#!/usr/bin/env node
// Process one poll payload from interagent-monitor-poll.sh.
//
// stdin: JSON object
//   { schema: "full"|"legacy", now: <iso>, stamped: [id…], watchers: [{machine,idle_secs,stale}…],
//     rows: [{event,id,title,from_agent,to_target,status,claimed_by,result,refs,
//             delivered_to,delivered_at,claimed_at,completed_at,created_at}…] }
//   (a bare array is still accepted so an old poller can drive a new process.js)
// env: PROJECT, SEEN, MACHINE, UNDELIVERED_MIN, ACK_FILE, INTERVAL_SECS
// stdout: emit lines.
//
// THE SAFETY PROPERTY THIS FILE OWNS
// ----------------------------------
// A key enters the seen-file, and an inbox id enters the ack-file, ONLY after
// fs.writeSync(1, …) returned without throwing — i.e. only after a live reader
// actually received the line. The ack-file is what the next poll stamps as
// delivered. So a poller writing into a dead pipe stamps nothing and marks
// nothing seen: the message stays pending for the live session and the sender's
// UNDELIVERED alarm stays armed. Never move an append above its write.
// Exit 1 if any write to stdout failed, so the poller can end the orphan.

'use strict';
const fs = require('fs');

const project = process.env.PROJECT || '';
const seenFile = process.env.SEEN || '';
const ackFile = process.env.ACK_FILE || '';
const sinceFile = process.env.SINCE_FILE || '';
const machine = process.env.MACHINE || '';
const undeliveredMin = Math.max(1, parseInt(process.env.UNDELIVERED_MIN || '5', 10) || 5);
const intervalSecs = Math.max(1, parseInt(process.env.INTERVAL_SECS || '5', 10) || 5);

function loadSeen() {
  try {
    return new Set(fs.readFileSync(seenFile, 'utf8').split(/\r?\n/).filter(Boolean));
  } catch (_) {
    return new Set();
  }
}

function ageMinutes(iso) {
  if (!iso) return 0;
  const t = Date.parse(iso);
  if (Number.isNaN(t)) return 0;
  return (Date.now() - t) / 60000;
}

function truncResult(s) {
  const t = String(s || '').replace(/\s+/g, ' ').trim();
  if (t.length <= 200) return t;
  return t.slice(0, 200);
}

function projectMine(refs) {
  const list = Array.isArray(refs) ? refs : [];
  const proj = list.filter((x) => x && x.type === 'project');
  if (proj.length === 0) return { mine: true, tag: 'broadcast' };
  const mine = proj.some((x) => String(x.id) === project);
  return { mine, tag: mine ? 'project=' + project : null };
}

// Spec D: the heartbeat has a reader. A receiver is "stale" when it has missed
// three of its own poll intervals; the poller computes that server-side and we
// only render it, falling back to our own interval if the row is old-shaped.
function watcherNote(map, target) {
  const w = map.get(String(target));
  if (!w) return '[watcher: none]';
  const idle = Number.isFinite(w.idle_secs) ? w.idle_secs : null;
  const stale = typeof w.stale === 'boolean'
    ? w.stale
    : (idle !== null && idle > 3 * intervalSecs);
  if (idle === null) return stale ? '[watcher: stale]' : '[watcher: live]';
  return (stale ? '[watcher: stale ' : '[watcher: live ') + idle + 's]';
}

let body = '';
process.stdin.on('data', (c) => { body += c; });
process.stdin.on('end', () => {
  let payload;
  try {
    payload = JSON.parse(body || '{}');
  } catch (_) {
    return;
  }

  // Accept both the new object envelope and a bare row array (old poller).
  let rows;
  let schema = 'full';
  let watcherRows = [];
  if (Array.isArray(payload)) {
    rows = payload;
  } else if (payload && typeof payload === 'object') {
    rows = Array.isArray(payload.rows) ? payload.rows : [];
    schema = payload.schema === 'legacy' ? 'legacy' : 'full';
    watcherRows = Array.isArray(payload.watchers) ? payload.watchers : [];
  } else {
    return;
  }

  // The poller's "what changed since" high-water mark is the SERVER clock, never
  // ours — the two machines' clocks are not the same. Written here rather than in
  // the shell so a poll costs exactly one `node` start.
  if (sinceFile && payload && payload.now) {
    try { fs.writeFileSync(sinceFile, String(payload.now)); } catch (_) { /* ignore */ }
  }

  const watchers = new Map();
  for (const w of watcherRows) {
    if (w && w.machine != null) watchers.set(String(w.machine), w);
  }

  const seen = loadSeen();
  const freshSeen = [];
  const freshAck = [];
  let broken = false;

  // Returns true when the line reached a live reader.
  function emit(line, key) {
    if (broken) return false;
    if (key && seen.has(key)) return false;
    try {
      fs.writeSync(1, line + '\n');
    } catch (_) {
      broken = true;
      return false;
    }
    if (key) {
      seen.add(key);
      freshSeen.push(key);
    }
    return true;
  }

  for (const r of rows) {
    if (broken) break;
    const event = r.event || r.kind || 'inbox';
    const id = String(r.id);

    if (event === 'inbox') {
      if (seen.has(id)) continue;
      const { mine, tag } = projectMine(r.refs);
      if (!mine) continue;
      const delivered = emit(
        'INTERAGENT new #' + id + ' [' + tag + '] from ' + (r.from_agent || r.from || '?') +
          ': ' + (r.title || '') + '  -> check interagent to read + claim',
        id
      );
      // Only a line that landed earns a delivery stamp on the next poll.
      if (delivered && !r.delivered_at) freshAck.push(id);
      continue;
    }

    if (event !== 'sent') continue;
    // An un-migrated database cannot answer any of the sender-side questions.
    if (schema === 'legacy') continue;

    if (r.delivered_at) {
      emit(
        'DELIVERED #' + id + ' to ' + (r.delivered_to || r.to_target || '?') +
          ' at ' + r.delivered_at,
        'DELIVERED-' + id
      );
    }

    if (r.claimed_by && (r.claimed_at || r.status === 'claimed' || r.status === 'in_progress' ||
        r.status === 'completed' || r.status === 'failed')) {
      emit('CLAIMED #' + id + ' by ' + r.claimed_by, 'CLAIMED-' + id);
    }

    if ((r.status === 'completed' || r.status === 'failed') && (r.completed_at || r.result != null)) {
      const who = r.claimed_by || r.to_target || '?';
      emit('COMPLETED #' + id + ' by ' + who + ': ' + truncResult(r.result), 'COMPLETED-' + id);
    }

    // A delivered row is never an alarm. This guard is the difference between a
    // trustworthy alarm and a cry-wolf one.
    if (!r.delivered_at) {
      const age = ageMinutes(r.created_at);
      const note = watcherNote(watchers, r.to_target);
      // 5/15/60 plus the configured first threshold, so a non-default
      // UNDELIVERED_MIN still gets its own alarm rather than waiting for 60.
      const thresholds = [...new Set([undeliveredMin, 5, 15, 60])].sort((a, b) => a - b);
      for (const T of thresholds) {
        if (T < undeliveredMin) continue;
        if (age < T) continue;
        emit(
          'UNDELIVERED #' + id + ' to ' + (r.to_target || '?') +
            ' for >' + T + ' min — receiver not acking (old poller or offline) ' + note,
          'ALARM-' + T + '-' + id
        );
      }
    }
  }

  if (freshSeen.length && seenFile) {
    try {
      fs.appendFileSync(seenFile, freshSeen.join('\n') + '\n');
    } catch (_) { /* ignore */ }
  }
  if (freshAck.length && ackFile) {
    try {
      fs.appendFileSync(ackFile, freshAck.join('\n') + '\n');
    } catch (_) { /* ignore */ }
  }

  if (broken) process.exit(1);
});
