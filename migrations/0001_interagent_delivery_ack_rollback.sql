-- Rollback for 0001_interagent_delivery_ack.sql
--
-- Do NOT run against live pgvector unless intentionally reverting the feature,
-- and REVERT THE CODE FIRST. A new poller left running against the rolled-back
-- schema notices on its next poll and falls back to inbox-only with one visible
-- WARN line — it does not go silent — but it stops acking delivery, so the
-- sender's view degrades. Old pollers are unaffected either way.
--
--   ssh deepthought 'docker exec -i pgvector psql -U postgres homelab -v ON_ERROR_STOP=1 -f -' \
--     < migrations/0001_interagent_delivery_ack_rollback.sql

BEGIN;

DROP INDEX IF EXISTS idx_ia_undelivered;
DROP INDEX IF EXISTS idx_ia_pending_target;
DROP INDEX IF EXISTS idx_ia_from_created;

DROP TABLE IF EXISTS interagent_watchers;

ALTER TABLE interagent_assignments DROP COLUMN IF EXISTS delivered_to;
ALTER TABLE interagent_assignments DROP COLUMN IF EXISTS delivered_at;

COMMIT;
