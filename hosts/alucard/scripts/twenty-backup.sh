#!/usr/bin/env bash
set -euo pipefail
stage=${1:?staging directory required}
env_file=${2:?Twenty environment file required}
export DOCKER_HOST=unix:///var/run/docker.sock
# Freeze application writes so uploaded files and the database describe the same moment.
trap 'docker unpause twenty-server twenty-worker >/dev/null' EXIT
docker pause twenty-server twenty-worker >/dev/null
docker exec twenty-db pg_dump -U twenty -d twenty --format=custom --no-owner > "$stage/twenty.dump"
test -s "$stage/twenty.dump"
docker cp twenty-server:/app/packages/twenty-server/.local-storage "$stage/files"
docker exec twenty-redis redis-cli SAVE >/dev/null
docker cp twenty-redis:/data/dump.rdb "$stage/redis.rdb"
install -m 0600 "$env_file" "$stage/twenty.env"
# Validate the dump's directory before sending it offsite; a restore is tested separately.
docker exec -i twenty-db pg_restore --list < "$stage/twenty.dump" >/dev/null
