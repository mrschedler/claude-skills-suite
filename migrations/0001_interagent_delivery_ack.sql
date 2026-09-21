-- Migration: interagent delivery ack (pickup stamp + watchers heartbeat)
-- Additive only. Do NOT apply to live pgvector until Opus verifier review.
-- Safe for old pollers/gateway: nullable columns, no renames, no NOT NULL.

BEGIN;

ALTER TABLE interagent_assignments
  ADD COLUMN IF NOT EXISTS delivered_to VARCHAR(64),
  ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS interagent_watchers (
  machine VARCHAR(64) NOT NULL,
  project VARCHAR(128) NOT NULL,
  pid INT,
  last_poll_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (machine, project)
);

COMMIT;

-- ---------------------------------------------------------------------------
-- ROLLBACK (run manually if needed; not applied by this file)
-- ---------------------------------------------------------------------------
-- BEGIN;
-- DROP TABLE IF EXISTS interagent_watchers;
-- ALTER TABLE interagent_assignments DROP COLUMN IF EXISTS delivered_to;
-- ALTER TABLE interagent_assignments DROP COLUMN IF EXISTS delivered_at;
-- COMMIT;
