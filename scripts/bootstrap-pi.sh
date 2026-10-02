#!/usr/bin/env bash
set -euo pipefail
umask 077

mkdir -p "$PI_AGENT_DIR/upstream/amos-web-fetch"
merged=''
trap 'if [ -n "$merged" ]; then rm -f "$merged"; fi' EXIT

merge() {
  local target=$1 declared=$2 filter=$3
  if [ ! -e "$target" ]; then
    install -m 600 "$declared" "$target"
  else
    merged=$(mktemp "$target.XXXXXX")
    jq -s "$filter" "$target" "$declared" > "$merged"
    chmod 600 "$merged"
    mv "$merged" "$target"
  fi
}

# Settings are defaults; Pi owns all existing choices, including native packages.
merge "$PI_AGENT_DIR/settings.json" "$PI_DEFAULT_SETTINGS" '.[1] * .[0]'
# Declared model definitions win; additional user-defined providers remain intact.
merge "$PI_AGENT_DIR/models.json" "$PI_DECLARED_MODELS" '.[0] * .[1]'

web="$PI_AGENT_DIR/upstream/amos-web-fetch"
needs_install=0
if [ ! -d "$web/node_modules" ] || ! cmp -s "$PI_WEB_LOCK" "$web/package-lock.json"; then
  needs_install=1
fi
install -m 600 "$PI_WEB_INDEX" "$web/index.ts"
install -m 600 "$PI_WEB_PACKAGE" "$web/package.json"
install -m 600 "$PI_WEB_LOCK" "$web/package-lock.json"
if [ "$needs_install" -eq 1 ]; then
  (cd "$web" && npm ci --ignore-scripts)
fi

export PATH="$HOME/.local/bin:$PATH"
if [ "$(pi --version 2>/dev/null || true)" != "$PI_VERSION" ]; then
  npm install -g --prefix "$HOME/.local" --ignore-scripts "@earendil-works/pi-coding-agent@$PI_VERSION" \
    || echo "Cannot install Pi $PI_VERSION (offline?)" >&2
fi
