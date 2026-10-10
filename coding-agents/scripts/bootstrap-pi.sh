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

# Managed portable settings replace only the fields declared above; Pi-owned identity
# and release metadata remain in the existing document.
merge "$PI_AGENT_DIR/settings.json" "$PI_DEFAULT_SETTINGS" '.[0] * .[1]'
if [ -n "${PI_DECLARED_CLAUDE_BRIDGE:-}" ]; then
  merge "$PI_AGENT_DIR/claude-bridge.json" "$PI_DECLARED_CLAUDE_BRIDGE" '.[0] * .[1]'
fi
# Declared model definitions win; additional user-defined providers remain intact.
merge "$PI_AGENT_DIR/models.json" "$PI_DECLARED_MODELS" '.[0] * .[1]'
# Claude Bridge requires portable inheritance; preserve other subagent settings.
merge "$PI_AGENT_DIR/subagents.json" "$PI_DECLARED_SUBAGENTS" '.[0] * .[1]'

if [ -n "${PI_REQUESTY_KEY_FILE:-}" ]; then
  # The pi-requesty extension reads the key from models.json and discovers models itself.
  merged=$(mktemp "$PI_AGENT_DIR/models.json.XXXXXX")
  jq --rawfile key "$PI_REQUESTY_KEY_FILE" --arg url "$PI_REQUESTY_URL" '
    del(.providers["alucard-requesty"])
    | .providers.requesty = (((.providers.requesty // {}) + {
        name: "Requesty", baseUrl: $url, api: "openai-completions",
        apiKey: ($key | rtrimstr("\n"))
      }) | .models //= [])' "$PI_AGENT_DIR/models.json" > "$merged"
  chmod 600 "$merged"
  mv "$merged" "$PI_AGENT_DIR/models.json"
fi

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
# Native self-update follows the latest stable release and never enforces an old Nix pin.
if command -v pi >/dev/null 2>&1; then
  pi update self
else
  npm install -g --prefix "$HOME/.local" --ignore-scripts \
    "@earendil-works/pi-coding-agent@latest"
fi
