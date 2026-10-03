# Major upgrade of the PostgreSQL cluster before the new server first starts. Runs with
# OLD_BIN, NEW_BIN, OLD_DATA, NEW_DATA and DUMP_DIR set. The old data directory is copied,
# never modified; the new one appears under its final name only after pg_upgrade succeeds,
# so a failed run leaves no cluster for postgresql.service to start empty.

umask 077
socket=$(mktemp -d)
staging="$NEW_DATA.upgrading"
chown postgres:postgres "$socket"
pg() { runuser -u postgres -- "$@"; }

rm -rf -- "$staging"

# Read the old cluster's encoding and locale and keep a plain dump beside it.
pg "$OLD_BIN/pg_ctl" -D "$OLD_DATA" -o "-c listen_addresses='' -k $socket" -w start
trap 'pg "$OLD_BIN/pg_ctl" -D "$OLD_DATA" -m fast -w stop || true' EXIT
read -r encoding collate ctype < <(
  pg "$OLD_BIN/psql" -h "$socket" -d postgres -tA -F ' ' \
    -c "select pg_encoding_to_char(encoding), datcollate, datctype from pg_database where datname = 'template1'"
)
install -d -m 0700 "$DUMP_DIR"
pg "$OLD_BIN/pg_dumpall" -h "$socket" > "$DUMP_DIR/dumpall-$(date +%F-%H%M%S).sql"
pg "$OLD_BIN/pg_ctl" -D "$OLD_DATA" -m fast -w stop
trap - EXIT

install -d -m 0700 -o postgres -g postgres "$staging"
pg "$NEW_BIN/initdb" -D "$staging" --encoding="$encoding" --lc-collate="$collate" --lc-ctype="$ctype"
cd "$staging" || exit
pg "$NEW_BIN/pg_upgrade" \
  --old-datadir="$OLD_DATA" --new-datadir="$staging" \
  --old-bindir="$OLD_BIN" --new-bindir="$NEW_BIN" \
  --socketdir="$socket"
cd / || exit
mv -- "$staging" "$NEW_DATA"
touch "$NEW_DATA/.analyze-pending"
chown postgres:postgres "$NEW_DATA/.analyze-pending"
