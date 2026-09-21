#!/usr/bin/env bash
# PSQL wrapper: SQL on stdin → fake-db.js → JSON on stdout
set -uo pipefail
DIR=$(cd "$(dirname "$0")" && pwd)
node "$DIR/fake-db.js"
