#!/usr/bin/env node
// interagent-monitor-process.js — turns one poll payload into stdout lines.
//
// Reads {"now": <db timestamp>, "rows": [...]} on stdin and emits:
//   INTERAGENT new #id [tag] from <who>: <title>  -> claim it, then work
//   CLAIMED   #id by <who> after <n> s
//   COMPLETED #id: <first 200 chars of result>
//   UNCLAIMED #id <title> - <n> min (receiver has not claimed: ...)
//
// NOTHING IS STAMPED. The receiving agent's `claim` is the acknowledgement;
// see the header of interagent-monitor-poll.sh for why no poller-side probe
// can prove a live reader on MSYS.
//
// ALL AGES COME FROM payload.now — the DATABASE clock. Machines in this fleet
// do not agree with each other or with the carrier, and an alarm threshold
// computed against a local clock is not a threshold.
//
// State is a PER-PROCESS directory (PROC_DIR) owned by one poller and deleted
// when it exits, so two pollers never share dedupe state:
//   start.txt  the DB clock at this poller's first successful poll
//   seen.txt   one key per line — "<id>" (inbox), "CLAIMED-<id>",
//              "COMPLETED-<id>", "ALARM-<id>-<mins>"
//
// A key is written ONLY after its line's write(2) returned without throwing.
// On EPIPE the remaining lines are dropped, nothing further is marked, and the
// process exits 9 so the poller stops. (That is orphan hygiene, not the
// correctness mechanism — the correctness mechanism is that an orphan's state
// is private and therefore steals nothing.)
//
// env: PROC_DIR (required), MACHINE, PROJECT, UNCLAIMED_MINS, BROADCAST_HOURS
'use strict';
const fs = require('fs');
const path = require('path');

const PROC_DIR = process.env.PROC_DIR;
if (!PROC_DIR) { console.error('PROC_DIR required'); process.exit(1); }
const PROJECT = process.env.PROJECT || '';
const BROADCAST_HOURS = Number(process.env.BROADCAST_HOURS || 24);
const THRESHOLDS = String(process.env.UNCLAIMED_MINS || '5,15,60')
  .split(',').map((s) => parseInt(s.trim(), 10))
  .filter((n) => Number.isFinite(n) && n > 0)
  .sort((a, b) => a - b);

const SEEN_FILE = path.join(PROC_DIR, 'seen.txt');
const START_FILE = path.join(PROC_DIR, 'start.txt');

let buf = '';
process.stdin.on('data', (c) => { buf += c; });
process.stdin.on('end', () => {
  let payload;
  try { payload = JSON.parse(buf || ''); } catch (e) { process.exit(1); }
  if (!payload || typeof payload !== 'object' || !Array.isArray(payload.rows)) process.exit(1);

  const nowMs = Number.isFinite(Date.parse(payload.now)) ? Date.parse(payload.now) : Date.now();

  // First successful poll of this process: remember the DB clock, and treat
  // every claim/completion that already happened as history, not news. A
  // re-armed poller must not replay yesterday's CLAIMED/COMPLETED lines.
  let seeding = false;
  let startMs = NaN;
  try {
    startMs = Date.parse(fs.readFileSync(START_FILE, 'utf8').trim());
  } catch (e) { /* not started yet */ }
  if (!Number.isFinite(startMs)) {
    seeding = true;
    startMs = nowMs;
    try { fs.writeFileSync(START_FILE, new Date(startMs).toISOString() + '\n'); } catch (e) {}
  }

  let seen = new Set();
  try {
    seen = new Set(fs.readFileSync(SEEN_FILE, 'utf8').split(/\r?\n/).filter(Boolean));
  } catch (e) { /* first poll */ }

  const out = [];        // {keys:[...], line:<string>|null}
  const mark = (keys) => out.push({ keys, line: null });
  const emit = (keys, line) => out.push({ keys, line });

  const ms = (v) => { const t = Date.parse(v); return Number.isFinite(t) ? t : NaN; };
  const ageMin = (v) => (nowMs - ms(v)) / 60000;
  const ageHours = (v) => (nowMs - ms(v)) / 3600000;
  const projectRefs = (r) => (Array.isArray(r.refs) ? r.refs : []).filter((x) => x && x.type === 'project');
  const oneLine = (v) => String(v == null ? '' : v).replace(/\s+/g, ' ').trim().slice(0, 200);

  for (const r of payload.rows) {
    const id = String(r.id);

    // ── INBOX: pending + unclaimed mail routed here ──────────────────────────
    if (r.event === 'inbox') {
      if (seen.has(id)) continue;
      const proj = projectRefs(r);
      const isBroadcast = proj.length === 0 && String(r.to_target) === 'any';
      // Agents deliberately never claim untagged broadcasts, so a re-armed
      // poller would re-announce every one of them forever. Only fresh ones.
      if (isBroadcast && ageHours(r.created_at) > BROADCAST_HOURS) continue;
      const tag = proj.length === 0 ? 'broadcast' : 'project=' + PROJECT;
      emit([id], 'INTERAGENT new #' + id + ' [' + tag + '] from ' + (r.from_agent || '?') +
        ': ' + oneLine(r.title) + '  -> claim it (the claim IS the ack), then work');
      continue;
    }

    if (r.event !== 'sent') continue;

    // ── SENDER: what happened to mail this machine sent ─────────────────────
    if (r.claimed_at) {
      const key = 'CLAIMED-' + id;
      if (!seen.has(key)) {
        if (seeding && ms(r.claimed_at) < startMs) {
          mark([key]);                                   // history, not news
        } else {
          const secs = Math.max(0, Math.round((ms(r.claimed_at) - ms(r.created_at)) / 1000));
          emit([key], 'CLAIMED #' + id + ' by ' + (r.claimed_by || r.to_target || '?') +
            ' after ' + secs + ' s');
        }
      }
    }

    if (r.completed_at) {
      const key = 'COMPLETED-' + id;
      if (!seen.has(key)) {
        if (seeding && ms(r.completed_at) < startMs) {
          mark([key]);
        } else {
          emit(['COMPLETED-' + id], 'COMPLETED #' + id + ': ' + oneLine(r.result));
        }
      }
    }

    // ── SENDER alarms ───────────────────────────────────────────────────────
    // Broadcasts are exempt: nobody is expected to claim them.
    if (String(r.to_target) === 'any') continue;
    const unclaimed = !r.claimed_at && !r.claimed_by && r.status === 'pending';
    if (!unclaimed) continue;
    const age = ageMin(r.created_at);
    if (!Number.isFinite(age)) continue;
    const crossed = THRESHOLDS.filter((t) => age >= t);
    if (!crossed.length) continue;
    const top = crossed[crossed.length - 1];
    const topKey = 'ALARM-' + id + '-' + top;
    if (seen.has(topKey)) continue;
    // Claim every threshold this row has already passed, but say it once, at
    // the highest. A poller armed against week-old mail owes one line, not one
    // per threshold — and the next threshold still fires when it arrives.
    const keys = crossed.map((t) => 'ALARM-' + id + '-' + t);
    emit(keys, 'UNCLAIMED #' + id + ' ' + oneLine(r.title) + ' - ' + top +
      ' min (receiver has not claimed: not watching, busy, or offline)');
  }

  const written = [];
  let broken = false;
  for (const o of out) {
    if (o.line !== null) {
      try {
        fs.writeSync(1, o.line + '\n');
      } catch (e) {
        broken = true;
        break;                                    // nothing after this landed
      }
    }
    written.push(...o.keys);
  }

  if (written.length) {
    try { fs.appendFileSync(SEEN_FILE, written.join('\n') + '\n'); } catch (e) {}
  }
  process.exit(broken ? 9 : 0);
});
