#!/usr/bin/env bash
# PSQL wrapper for the offline suite: SQL on stdin -> fake-db.js -> JSON stdout.
# Stands in for `ssh deepthought "docker exec -i pgvector psql ... -f -"`.
set -uo pipefail
DIR=$(cd "$(dirname "$0")" && pwd)
exec node "$DIR/fake-db.js"
