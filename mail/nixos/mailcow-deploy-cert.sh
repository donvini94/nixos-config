#!/usr/bin/env bash
set -euo pipefail

conf="$MAILCOW_DIR/mailcow.conf"

if [ ! -d "$MAILCOW_SSL_DIR" ]; then
  echo "mailcow ssl directory $MAILCOW_SSL_DIR not found — is mailcow installed?" >&2
  exit 1
fi
if [ ! -r "$MAILCOW_ACME_DIR/fullchain.pem" ]; then
  echo "ACME certificate $MAILCOW_ACME_DIR/fullchain.pem is unavailable" >&2
  exit 1
fi

# Mailcow's own ACME client would overwrite these files on its next run.
# It cannot succeed here anyway (nginx owns :80), so it must be off.
if ! grep -qE '^SKIP_LETS_ENCRYPT=y' "$conf" 2>/dev/null; then
  echo "WARNING: SKIP_LETS_ENCRYPT is not set to 'y' in $conf." >&2
  echo "         mailcow may overwrite the certificate deployed here." >&2
fi

# Idempotent: only touch mailcow when the certificate actually changed,
# so a rebuild does not bounce the mail server for nothing.
if cmp -s "$MAILCOW_ACME_DIR/fullchain.pem" "$MAILCOW_SSL_DIR/cert.pem"; then
  echo "mailcow already has the current certificate"
  exit 0
fi

echo "deploying $MAILCOW_DOMAIN certificate into mailcow"
install -m 0644 -o root -g root "$MAILCOW_ACME_DIR/fullchain.pem" "$MAILCOW_SSL_DIR/cert.pem"
install -m 0600 -o root -g root "$MAILCOW_ACME_DIR/key.pem" "$MAILCOW_SSL_DIR/key.pem"

cd "$MAILCOW_DIR"
# Compose *service* names, which are stable across mailcow releases —
# unlike container names, which carry the project prefix.
read -r -a reload_services <<<"$MAILCOW_RELOAD_SERVICES"
docker compose restart "${reload_services[@]}"
echo "mailcow certificate updated"
