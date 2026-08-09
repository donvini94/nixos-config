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
| `wirken/vault_passphrase` | Wirken | Unlocks the encrypted credential vault | Vault-encryption root; follow upstream migration procedure |
| `wirken/ingress_token` | Wirken and inference ingress | Authenticates/attributes Wirken model calls | Coordinated service rotation |
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

Alucard uses the separate encrypted `secrets/alucard-ai.yaml`. Its n8n, Wirken, Langfuse,
and Grafana values have been generated independently from Dracula. The operator-supplied
Requesty key is encrypted there and is exposed at runtime only to the port-8080 ingress.

| SOPS key group | Consumer | Rule |
| --- | --- | --- |
| `requesty/api_key` | Port-8080 ingress only | Set a monthly spend limit; optionally attach a matching Access List; never distribute to clients |
| `n8n/*` | Alucard n8n and runners | Independent encryption root and runner token |
| `wirken/*` | Alucard Wirken and ingress attribution | Independent vault passphrase and local-only attribution token |
| `hermes/dashboard_password` | Hermes browser and Desktop login | Share through a password manager; rotate when demo access changes |
| `hermes/dashboard_password_hash` | Hermes authentication runtime | Regenerate whenever the demo password changes; plaintext is not exposed to the service |
| `hermes/dashboard_session_secret` | Hermes login-session signing | Planned rotation signs every Hermes client out |
| `langfuse/*` | Alucard Langfuse project and dependencies | Independent databases, cryptographic roots, project, and administrator |
| `grafana/admin_password` | Alucard Grafana bootstrap | Independent administrator password |

Signal linking state is not a SOPS scalar. It lives at
`/var/lib/signal-cli/signal-cli/data`, contains the linked device's cryptographic identity,
and must be protected like a password. Agent account numbers and sender allowlists will be
added to SOPS only after the operator chooses whether Hermes, Wirken, or separate Signal
accounts/groups own the channel.

Edit it without printing values:

```console
sops secrets/alucard-ai.yaml
```

Retrieve the Hermes demo password only when placing it into a password manager:

```console
sops --decrypt secrets/alucard-ai.yaml | yq -r '.hermes.dashboard_password'
```

Do not copy Dracula's project keys or administrative passwords. Prefer one Alucard workload
key with a spending limit and optional matching Requesty Access List; create additional keys only
when a real workload or customer isolation boundary requires separate revocation and cost
ownership. Label keys so Requesty's records can be reconciled with Langfuse and ingress
callers. Customer machines need their own age recipient, credentials, retention policy,
and documented revocation owner.
