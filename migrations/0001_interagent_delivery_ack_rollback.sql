-- Rollback for 0001_interagent_delivery_ack.sql
-- Do NOT run against live pgvector unless intentionally reverting the feature.

BEGIN;

DROP TABLE IF EXISTS interagent_watchers;

ALTER TABLE interagent_assignments DROP COLUMN IF EXISTS delivered_to;
ALTER TABLE interagent_assignments DROP COLUMN IF EXISTS delivered_at;

COMMIT;
