#!/usr/bin/env bash
set -euo pipefail

# n8n's node user must be able to read the mounted credentials.
container_uid=1000
creds="$RUNTIME_DIRECTORY/credentials.json"
umask 077

jq -n \
  --rawfile hermes_key "$CREDENTIALS_DIRECTORY/hermes_api_key" \
  --rawfile webhook_token "$CREDENTIALS_DIRECTORY/n8n_webhook_token" \
  '[
    {
      id: "startupHermesApi",
      name: "Startup Hermes API",
      type: "httpHeaderAuth",
      data: { name: "Authorization", value: ("Bearer " + ($hermes_key | rtrimstr("\n"))) }
    },
    {
      id: "startupWebhookAuth",
      name: "Startup webhook token",
      type: "httpHeaderAuth",
      data: { name: "X-Startup-Token", value: ($webhook_token | rtrimstr("\n")) }
    }
  ]' > "$creds"
chown "$container_uid" "$creds"
chmod 0400 "$creds"

# Run offline while n8n is stopped; import:credentials upserts by ID.
docker run --rm \
  --name n8n-credentials-sync \
  --network none \
  --user "$container_uid:$container_uid" \
  --volume "$N8N_STATE_DIRECTORY":/home/node/.n8n \
  --volume "$N8N_ENCRYPTION_KEY_FILE":/run/secrets/n8n_encryption_key:ro \
  --volume "$creds":/tmp/credentials.json:ro \
  "$N8N_IMAGE" \
  import:credentials --input=/tmp/credentials.json
