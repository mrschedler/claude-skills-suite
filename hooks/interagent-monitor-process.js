#!/usr/bin/env node
// Process one poll JSON payload from interagent-monitor-poll.sh.
// stdin: JSON array of {event,id,title,from_agent,to_target,status,claimed_by,result,
//   refs,delivered_to,delivered_at,claimed_at,completed_at,created_at}
// env: PROJECT, SEEN, MACHINE, UNDELIVERED_MIN
// stdout: emit lines; appends new seen keys to SEEN. Exit 1 if a write to stdout fails.

'use strict';
const fs = require('fs');

const project = process.env.PROJECT || '';
const seenFile = process.env.SEEN || '';
const machine = process.env.MACHINE || '';
const undeliveredMin = Math.max(1, parseInt(process.env.UNDELIVERED_MIN || '5', 10) || 5);

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

let body = '';
process.stdin.on('data', (c) => { body += c; });
process.stdin.on('end', () => {
  let rows;
  try {
    rows = JSON.parse(body || '[]');
  } catch (_) {
    return;
  }
  if (!Array.isArray(rows)) return;

  const seen = loadSeen();
  const fresh = [];
  let broken = false;

  function emit(line, key) {
    if (broken) return;
    if (key && seen.has(key)) return;
    try {
      fs.writeSync(1, line + '\n');
    } catch (_) {
      broken = true;
      return;
    }
    if (key) {
      seen.add(key);
      fresh.push(key);
    }
  }

  for (const r of rows) {
    if (broken) break;
    const event = r.event || r.kind || 'inbox';
    const id = String(r.id);

    if (event === 'inbox') {
      if (seen.has(id)) continue;
      const { mine, tag } = projectMine(r.refs);
      if (!mine) continue;
      emit(
        'INTERAGENT new #' + id + ' [' + tag + '] from ' + (r.from_agent || r.from || '?') +
          ': ' + (r.title || '') + '  -> check interagent to read + claim',
        id
      );
      continue;
    }

    if (event !== 'sent') continue;

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

    if (!r.delivered_at) {
      const age = ageMinutes(r.created_at);
      if (age >= undeliveredMin) {
        for (const T of [5, 15, 60]) {
          if (T < undeliveredMin) continue;
          if (age < T) continue;
          const key = 'ALARM-' + T + '-' + id;
          emit(
            'UNDELIVERED #' + id + ' to ' + (r.to_target || '?') +
              ' for >' + undeliveredMin + ' min — receiver not acking (old poller or offline)',
            key
          );
        }
      }
    }
  }

  if (fresh.length && seenFile) {
    try {
      fs.appendFileSync(seenFile, fresh.join('\n') + '\n');
    } catch (_) { /* ignore */ }
  }

  if (broken) process.exit(1);
});
