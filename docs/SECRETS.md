# AI stack secret inventory

This file documents names and lifecycle only. It must never contain secret values.
Encrypted source values live in `secrets/dracula-ai.yaml`; sops-nix decrypts them into
the memory-backed `/run/secrets` tree during activation. They do not enter the Nix store,
Docker images, Compose files, or `/var/lib` application state.

## Dracula inventory

| SOPS key | Consumer | Purpose | Rotation class |
| --- | --- | --- | --- |
| `n8n/encryption_key` | n8n | Encrypts stored n8n credentials | Data-encryption root; do not casually rotate |
| `n8n/runner_auth_token` | n8n and task runners | Authenticates runner registration | Coordinated service rotation |
| `hermes/api_server_key` | Hermes agent API | Bearer key for Hermes' loopback automation API | Coordinated service rotation |
| `langfuse/postgres_password` | Langfuse and Postgres | Application database login | Database migration required |
| `langfuse/clickhouse_password` | Langfuse and ClickHouse | Analytics database login | Database migration required |
| `langfuse/redis_auth` | Langfuse and Redis | Queue/cache authentication | Coordinated stack rotation |
| `langfuse/minio_root_password` | Langfuse and MinIO | Object-storage access | Coordinated stack rotation |
| `langfuse/salt` | Langfuse | Hashes API keys | Persistent cryptographic root; do not casually rotate |
| `langfuse/encryption_key` | Langfuse | Encrypts stored integration credentials | Persistent cryptographic root; do not casually rotate |
| `langfuse/nextauth_secret` | Langfuse | Signs and validates login sessions | Planned rotation logs users out |
| `langfuse/project_public_key` | OpenCode and Langfuse | Identifies the initialized tracing project | Rotate through Langfuse, then update SOPS |
| `langfuse/project_secret_key` | OpenCode and Langfuse | Authenticates trace ingestion | Rotate through Langfuse, then update SOPS |
| `langfuse/admin_password` | Initial Langfuse administrator | First-boot account password | Change in Langfuse; SOPS is bootstrap only |
| `grafana/admin_password` | Initial Grafana administrator | First-boot account password | Change in Grafana; SOPS is bootstrap only |

Langfuse documents `SALT`, `NEXTAUTH_SECRET`, and the 256-bit `ENCRYPTION_KEY` as distinct
cryptographic inputs. The headless `LANGFUSE_INIT_*` values create missing resources on
first startup; changing them later does not mutate the existing user, project, or API keys.
See the official [configuration reference](https://langfuse.com/self-hosting/configuration)
and [headless-initialization guide](https://langfuse.com/self-hosting/administration/headless-initialization).

## Rendered runtime files

sops-nix creates these root- or user-readable views under `/run/secrets`:

| Runtime file | Contents and consumer |
| --- | --- |
| `/run/secrets/rendered/n8n-runner.env` | Runner authentication environment for the n8n sidecar |
| `/run/secrets/rendered/hermes.env` | Secret half of Hermes' `.env`; rewritten on every activation |
| `/run/secrets/rendered/observability.env` | Langfuse dependencies, project bootstrap, and Grafana bootstrap |
| `/run/secrets/rendered/opencode-langfuse.json` | OpenCode Langfuse project credentials; owned by `vincenzo` |

The individual non-rendered values also exist beneath `/run/secrets/<service>/<name>`.
Rendered files are ephemeral and recreated during activation. Never copy them to the
repository, a home directory, a support ticket, shell history, or chat.

## Safe operator commands

Edit the encrypted file in place:

```console
cd /home/vincenzo/nixos-config
sops secrets/dracula-ai.yaml
```

Inspect one value only when necessary; this prints the value to the terminal:

```console
sops --decrypt secrets/dracula-ai.yaml | yq -r '.grafana.admin_password'
```

After a valid, coordinated change:

```console
sudo nixos-rebuild switch --flake .#dracula
```

Do not implement a database or application-key rotation by changing SOPS and rebuilding.
For example, the Postgres image uses `POSTGRES_PASSWORD` to initialize a new database; it
does not rewrite the password inside an existing database volume. Likewise, Langfuse's
headless administrator password and project keys are initialization inputs. Change the
live application/database first using its supported procedure, update SOPS in the same
maintenance window, then recreate and verify every consumer.

## Backup and compromise rules

- Back up the encrypted YAML and application data, but store the SOPS age private key
  separately. Neither is useful for disaster recovery without the other.
- Do not back up `/run/secrets`; it is a generated plaintext runtime view.
- Langfuse data spans Postgres, ClickHouse, MinIO, and Redis Docker volumes. A copy of the
  encrypted YAML alone is not an application backup.
- If a secret may have appeared in logs, terminal capture, chat, or git history, treat it
  as compromised: revoke or rotate it at the owning service, update SOPS, restart all
  consumers, and verify old credentials fail.

## Alucard and customer machines

Alucard uses the separate encrypted `secrets/alucard-ai.yaml`. Its n8n, Hermes, Langfuse,
and Grafana values have been generated independently from Dracula. The operator-supplied
Requesty key is encrypted there and is exposed at runtime only to the port-8080 ingress.

| SOPS key group | Consumer | Rule |
| --- | --- | --- |
| `requesty/api_key` | Port-8080 ingress only | Set a monthly spend limit; optionally attach a matching Access List; never distribute to clients |
| `n8n/encryption_key`, `n8n/runner_auth_token` | Alucard n8n and runners | Independent encryption root and runner token |
| `n8n/webhook_token` | n8n `startupWebhookAuth` credential and Hermes' `hermes-n8n-handoff` | Shared `X-Startup-Token`; the two sides must agree or the inbox webhook returns 403 |
| `hermes/dashboard_password` | Hermes browser and Desktop login | Share through a password manager; rotate when demo access changes |
| `hermes/dashboard_password_hash` | Hermes authentication runtime | Regenerate whenever the demo password changes; plaintext is not exposed to the service |
| `hermes/dashboard_session_secret` | Hermes login-session signing | Planned rotation signs every Hermes client out |
| `hermes/api_server_key` | Hermes agent API and n8n's `startupHermesApi` credential | Bearer key for the delegate workflow's call into Hermes |
| `hermes/telegram_bot_token` | Hermes Telegram channel | Revoke through BotFather `/revoke`, then store the replacement here |
| `hermes/telegram_allowed_users` | Hermes Telegram channel | Comma-separated numeric Telegram IDs; append a founder's ID when known, never `*` |
| `langfuse/*` | Alucard Langfuse project and dependencies | Independent databases, cryptographic roots, project, and administrator |
| `grafana/admin_password` | Alucard Grafana bootstrap | Independent administrator password |

Nix and SOPS own the secret half of Hermes' `.env` at `/var/lib/hermes/.hermes/.env`, and the
upstream module rewrites that file on every activation instead of reconciling single keys.
Credentials entered in the Hermes dashboard or produced by its QR onboarding are therefore not
authoritative and are overwritten on the next switch: rotate in SOPS and rebuild. Both
`startupHermesApi` and `startupWebhookAuth` reach n8n's encrypted credential store through
`n8n-credentials-sync.service`, which imports them with n8n's own CLI; the values never appear
in workflow JSON, argv, logs, or this repository.

Edit it without printing values:

```console
sops secrets/alucard-ai.yaml
```

Retrieve the Hermes demo password only when placing it into a password manager:

```console
sops --decrypt secrets/alucard-ai.yaml | yq -r '.hermes.dashboard_password'
```

### Adding the second founder to the Hermes Telegram allowlist

`hermes/telegram_allowed_users` is a comma-separated list of **numeric** Telegram user IDs, not
usernames. It currently holds one ID. The service is already usable by both founders over SSH
and the shared `hermes` CLI; this only adds the second Telegram chat origin, which Hermes keeps
as a conversation history separate from the first.

Kyrill obtains his own numeric ID by sending `/start` to `@userinfobot` in Telegram, or by
running `/whoami` against the stack's own bot once he is allowlisted. Then, from Dracula:

```console
cd ~/nixos-config
current=$(sops --decrypt --extract '["hermes"]["telegram_allowed_users"]' secrets/alucard-ai.yaml)
printf '%s,%s' "$current" "<kyrill-numeric-id>" | jq -Rs . \
  | sops set secrets/alucard-ai.yaml '["hermes"]["telegram_allowed_users"]' --value-stdin
```

That never prints the existing value. The leaf must stay a single string. If it becomes a YAML
list — `sops set` handed a JSON array, or a hand-edit under `sops secrets/alucard-ai.yaml` — the
next switch dies in `sops-install-secrets` with `secret hermes/telegram_allowed_users ... is not
valid: the value of key 'hermes' is not a string`. Confirm the shape, then deploy:

```console
sops --decrypt --output-type json secrets/alucard-ai.yaml \
  | jq -r '.hermes.telegram_allowed_users
           | if type == "string" and test("^[0-9]+(,[0-9]+)*$")
             then "\(split(",") | length) allowlisted id(s)"
             else "BAD SHAPE: \(type)" end'
ssh alucard 'cd ~/nixos-config && sudo nixos-rebuild switch --flake .#alucard'
```

`BAD SHAPE: array` is repaired in place, without printing any ID, by joining the entries back
into one scalar:

```console
sops --decrypt --output-type json secrets/alucard-ai.yaml \
  | jq '.hermes.telegram_allowed_users | join(",")' \
  | sops set secrets/alucard-ai.yaml '["hermes"]["telegram_allowed_users"]' --value-stdin
```

The switch rewrites `/var/lib/hermes/.hermes/.env` and restarts `hermes-agent.service`, so no
dashboard step is involved. Verify that the new ID actually reached the container:

```console
ssh alucard 'docker --host unix:///run/docker.sock exec hermes-agent \
  sh -c "grep -c \"^TELEGRAM_ALLOWED_USERS=\" /data/.hermes/.env"'
```

Then have Kyrill message the bot and confirm a Telegram-sourced session appears while Vincenzo's
existing history stays separate. An unlisted account must still get no response — that is the
control this list enforces, so never widen it to `*` and never set `GATEWAY_ALLOW_ALL_USERS`.

Do not copy Dracula's project keys or administrative passwords. Prefer one Alucard workload
key with a spending limit and optional matching Requesty Access List; create additional keys only
when a real workload or customer isolation boundary requires separate revocation and cost
ownership. Label keys so Requesty's records can be reconciled with Langfuse and ingress
callers. Customer machines need their own age recipient, credentials, retention policy,
and documented revocation owner.

## Alucard document management (Paperless-ngx)

Paperless is not part of the AI stack and does not use `secrets/alucard-ai.yaml`. Its scalars
live in the default `secrets/dmbs.yaml`; its taxonomy PII lives in a dedicated
`secrets/paperless.yaml`.

| SOPS key | File | Consumer | Rotation class |
| --- | --- | --- | --- |
| `paperless/password` | `dmbs.yaml` | Paperless `admin` superuser; also how `paperless-provision` obtains an API token | Change in Paperless, then update SOPS |
| `paperless/restic_password` | `dmbs.yaml` | `paperless-offsite-backup.service` | **Backup-encryption root — rotating it orphans every existing snapshot** |
| *(whole file)* | `paperless.yaml` | `paperless-provision.service` | Correspondent names, IMAP hosts, app passwords |

`secrets/paperless.yaml` is consumed as a whole document (`key = ""`), so it is mounted at
`/run/secrets/paperless-private` owned by the `paperless` user, mode `0400`. The restic
password is deliberately kept out of that file: the service user must not hold the key to
its own backups.

Two structural rules for `secrets/paperless.yaml`:

- **Records, not maps.** sops encrypts YAML values but leaves keys in plaintext, so a map
  keyed by correspondent would publish those names in a public repo. Use a list of records;
  see `paperless/private.example.yaml`.
- **Passwords are IMAP app passwords, not account passwords.** Gmail removed "less secure
  app access" in March 2025 and iCloud never allowed the Apple ID password in third-party
  clients. Revoke at the provider (Google account → App passwords, appleid.apple.com), not
  in Paperless.

Edit without printing values:

```console
sops secrets/paperless.yaml
```

After changing a mail password, push it explicitly — the API returns passwords as asterisks,
so the reconciler cannot detect the change on its own:

```console
sudo paperless-provision --sync-passwords
```
