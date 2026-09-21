-- Migration: interagent delivery ack (pickup stamp + watchers heartbeat)
--
-- Additive and idempotent. Safe for old pollers and the gateway: nullable
-- columns, no renames, no NOT NULL on an existing table, no defaults (so the
-- ALTER is a catalog-only change — ACCESS EXCLUSIVE for microseconds, no table
-- rewrite). Re-running it is a no-op.
--
-- APPLY THIS BEFORE DEPLOYING THE CODE. In the reverse order the new pollers sit
-- on an old schema: they degrade to inbox-only with one visible WARN line rather
-- than going silent, but the delivery ack is simply absent until this lands.
-- See the DEPLOY section of hooks/README-interagent-push.md.
--
--   ssh deepthought 'docker exec -i pgvector psql -U postgres homelab -v ON_ERROR_STOP=1 -f -' \
--     < migrations/0001_interagent_delivery_ack.sql

BEGIN;

ALTER TABLE interagent_assignments
  ADD COLUMN IF NOT EXISTS delivered_to VARCHAR(64),
  ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS interagent_watchers (
  machine       VARCHAR(64)  NOT NULL,
  project       VARCHAR(128) NOT NULL,
  pid           INT,
  interval_secs INT,
  last_poll_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  PRIMARY KEY (machine, project)
);

-- Added separately so a database that already has the table from an earlier run
-- of this migration picks the column up too. The staleness reader needs it: a
-- watcher is stale after three of ITS OWN poll intervals, not the reader's.
ALTER TABLE interagent_watchers
  ADD COLUMN IF NOT EXISTS interval_secs INT;

-- Every poller runs these predicates every few seconds.
-- Sender side: from_agent = me, bounded by created_at.
CREATE INDEX IF NOT EXISTS idx_ia_from_created
  ON interagent_assignments (from_agent, created_at DESC);

-- Receiver side: the pending inbox for one target.
CREATE INDEX IF NOT EXISTS idx_ia_pending_target
  ON interagent_assignments (to_target)
  WHERE status = 'pending';

-- The alarm scan walks this machine's sent rows that are still unstamped.
CREATE INDEX IF NOT EXISTS idx_ia_undelivered
  ON interagent_assignments (from_agent)
  WHERE delivered_at IS NULL;

COMMIT;

-- Rollback lives in 0001_interagent_delivery_ack_rollback.sql.
-- Revert the CODE first, then the migration (see the DEPLOY notes).
