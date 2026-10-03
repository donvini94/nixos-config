#!/usr/bin/env bash
set -euo pipefail

conf="$MAILCOW_DIR/mailcow.conf"
changed=0

ensure_setting() {
  key=$1
  value=$2

  if grep -Fxq "$key=$value" "$conf"; then
    return
  fi
  if grep -q "^$key=" "$conf"; then
    sed -i "\\|^$key=|c\\$key=$value" "$conf"
  else
    printf '\n%s=%s\n' "$key" "$value" >>"$conf"
  fi
  changed=1
}

test -f "$conf"
ensure_setting HTTP_BIND 127.0.0.1
ensure_setting HTTPS_BIND 127.0.0.1
ensure_setting SKIP_LETS_ENCRYPT y

if [ "$changed" -eq 1 ]; then
  echo "applying Mailcow reverse-proxy network policy"
  cd "$MAILCOW_DIR"
  docker compose up -d
fi
