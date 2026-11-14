# Deploy origin's default branch; roll back and alert when the switch or health check fails.
# Env: FLAKE, CHAT_ID, TOKEN_FILE.
profile=/nix/var/nix/profiles/system

notify() {
  curl -fsS --max-time 20 \
    --config <(printf 'url = "https://api.telegram.org/bot%s/sendMessage"\n' "$(< "$TOKEN_FILE")") \
    --data-urlencode "chat_id=$CHAT_ID" --data-urlencode "text=alucard auto-deploy: $1" >/dev/null ||
    echo "telegram notification failed" >&2
}

failed_units() { systemctl --failed --plain --no-legend | awk '{print $1}' | sort; }

rollback() {
  notify "$1; rolling back"
  nix-env --profile "$profile" --rollback
  /nix/var/nix/profiles/system/bin/switch-to-configuration switch
  exit 1
}

before=$(readlink -f "$profile")
failed_before=$(failed_units)

nixos-rebuild switch --refresh --flake "$FLAKE" || rollback "switch failed"

[ "$(readlink -f "$profile")" = "$before" ] && exit 0

# Containers need time to pull, start and pass their own healthchecks.
for _ in $(seq 30); do
  sleep 10
  new=$(comm -13 <(echo "$failed_before") <(failed_units))
  gluetun=$(docker inspect -f '{{.State.Health.Status}}' gluetun 2>/dev/null || true)
  qbit=$(docker inspect -f '{{.State.Status}}' qbittorrent 2>/dev/null || true)
  [ -z "$new" ] && [ "$gluetun" = healthy ] && [ "$qbit" = running ] && break
done
[ -z "$new" ] && [ "$gluetun" = healthy ] && [ "$qbit" = running ] ||
  rollback "health check failed (new failed units: ${new:-none}; gluetun: ${gluetun:-missing}; qbittorrent: ${qbit:-missing})"

notify "deployed $(readlink -f "$profile" | sed 's|.*/||')"
