# Dracula and Alucard stack guide

This is the operator's map of what is installed, where to reach it, and which command owns
it. `dracula` is the local AI workstation. `alucard` is the server, media host, and
Requesty-backed business-demo machine.

For a concise, customer-demo-oriented introduction, start with
[Alucard AI demo guide](./AI_DEMO_GUIDE.md). Operators should also read
[Alucard security and exposure guide](./ALUCARD_SECURITY.md).

## The short version

On `dracula`:

```console
ai-stack-start       # start inference, n8n, and Hermes
ai-stack-health      # verify the stack and inference ingress
ai-stack-stop        # stop the complete AI stack and release model VRAM
observability-status # inspect Langfuse, Grafana, Prometheus, and exporters
containers-update    # pull rolling application images and recreate active containers
```

`modules/ai-ingress.nix` enables polkit and owns the rule, so members of the `llama` group
start and stop `ai-stack.target` without root on both hosts.

The browser interfaces are:

| Component | Address | Purpose | Current status |
| --- | --- | --- | --- |
| n8n | <http://127.0.0.1:5678> | Visual, deterministic workflows | Usable |
| Hermes | <http://127.0.0.1:9119> | Persistent autonomous agent and chat | Usable |
| Inference API | <http://127.0.0.1:8080/v1> | Stable OpenAI-compatible API | Usable |
| Langfuse | <http://127.0.0.1:13000> | Agent traces, token analysis, annotations, datasets, and evaluations | Usable |
| Grafana | <http://127.0.0.1:13001> | Machine, container, GPU, n8n, and inference metrics | Usable |
| Prometheus | <http://127.0.0.1:19091> | Metrics database and query interface | Usable |

All addresses are loopback-only: they are reachable from `dracula`, not the LAN or
internet.

## How an AI request moves

```text
OMP / OpenCode / n8n / Hermes / curl
                    │
                    ▼
       logging ingress 127.0.0.1:8080
                    │
                    ▼
          llama-swap 127.0.0.1:18080
                    │
                    ▼
     selected llama-server on a dynamic port
```

Always point clients at port `8080`. Port `18080` and the dynamic model ports are internal
implementation details. The request's `model` field selects the model; llama-swap changes
which server occupies the GPU.

Examples:

```console
omp --model dracula-local/qwen3.6-35b-a3b
opencode run -m dracula-local/qwen3.6-35b-a3b "your task"

curl http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -H 'X-AI-Caller: manual' \
  -d '{"model":"dirk-qwen3.8-27b-local","messages":[{"role":"user","content":"Say hello"}]}'
```

Available model IDs are `dirk-qwen3.8-27b-local` and `qwen3.6-35b-a3b`. Only one is resident
at a time. Dirk is the text-only default: its optional `mmproj-F16.gguf` vision projector is not
downloaded or loaded. The pinned Q4 artifact releases 2.14 GiB of model-weight VRAM compared
with the former Q5 one. Its one-slot, 32,768-token context retains the 2 GiB Qwen3.8 F16
KV-cache budget; keep that cap until this artifact has been measured live.

## What each AI component is for

### OMP and OpenCode

These are the two interactive coding harnesses. Both are configured to use the permanent
local ingress and ask before changing files or executing commands. Use both on real tasks;
their different prompts and tool loops are part of the comparison.

OMP receives the Nix-managed model and safety policy through its supported `PI_CONFIG_FILES`
overlay, built by `packages/omp-harness.nix`. The overlay scopes the picker to whichever custom
local/Requesty profiles the account was given, plus authenticated built-in `anthropic/*` and
`openai-codex/*` models. These wildcard scopes track OMP's bundled catalog; they do not freeze
or hardcode an upstream model list. Model-role assignments live in
`~/.omp/agent/config.yml`, so selections made through OMP's model picker persist. The default
plan role is `openai-codex/gpt-5.6-sol`. Its `agent.db` remains writable and holds provider
credentials; Nix never manages it, so rebuilds preserve OAuth/API-key state. Automatic
onboarding is skipped because the custom
providers are already configured; run `omp setup` explicitly only when intending to revisit
upstream's setup flow.

A Claude or ChatGPT login taken through `/providers` inside a running session reports the
account as signed in, but its models stay out of the picker until OMP restarts: the model list
is built once at startup. Restart before suspecting the scope or the credential.

Alucard runs the harness for both founder accounts. `hosts/alucard/home.nix` is Vincenzo's and
carries the authored context plus the Requesty profile; `hosts/alucard/home-kyrill.nix` installs
the harness alone, so Kyrill's models come only from his own Claude and ChatGPT logins. The
ingress authorizes no one per user — it binds loopback and spends one shared Requesty key — so
which accounts receive that profile is the spend boundary.

OpenCode's `enabled_providers` is an allow-list. The managed configuration enables the two custom
profiles and built-in `anthropic` and `openai`, without declaring or overwriting either provider.
Its auth state remains application-owned at `~/.local/share/opencode/auth.json`; Nix never writes
that file. OpenAI's `/connect` supports ChatGPT Plus/Pro OAuth. OpenCode's Anthropic provider
requires an Anthropic API key; a Claude consumer subscription/OAuth session is not an API
credential. Use `/connect` only when that provider needs initial login or a renewed key.

Useful diagnostics:

```console
omp --version
omp config path
omp models
opencode --version
opencode models
```

### n8n

n8n is for visible, repeatable workflows: scheduled jobs, mail processing, webhooks, and
multi-step business automation. Build and test workflows in its browser UI, then move the
reviewed JSON with the single `n8n-workflows` command:

```console
n8n-workflows export /tmp/n8n-review   # dump every workflow; the destination must be empty
n8n-workflows import                   # load this host's reviewed set, publish the active ones
```

`n8n/workflows/dracula/` and `n8n/workflows/alucard/` are the per-host reviewed sources; a
bare `import` uses the directory Nix configured for the host. Imports preserve fixed IDs, so
a re-import updates in place instead of duplicating. A running n8n keeps its old trigger
state, so run `ai-stack-stop && ai-stack-start` before testing production webhooks.

Review exported JSON before committing it: workflow definitions can contain addresses,
prompts, file paths, and credential names/IDs even though credential values live encrypted in
n8n's own database. File nodes are restricted to the shared `/org` mount; use focused
subdirectories such as `/org/ai-inbox` for handoffs. Business workflows, including mail
ingestion, stay separate from the infrastructure definitions.

n8n stays containerized deliberately: its upstream ecosystem moves faster than nixpkgs, which
ships 2.32.6 while both hosts run 2.34.6. Both the application and task-runner images are
digest-pinned and started with `pull = "missing"`, so a restart cannot adopt a new upstream
build.

`n8n/workflows/dracula/provisioning-smoke.json` is an infrastructure acceptance workflow. It
is safe to leave active and verifies the local-model relay plus both external Code-node
runners; its results are not a model-quality measurement.

### Hermes

Hermes is the persistent agent path. It runs from the pinned upstream flake module
`services.hermes-agent` (`github:NousResearch/hermes-agent/v2026.8.3`) in its OCI container
mode on a digest-pinned `ubuntu:24.04` base, on both hosts. The unit is `hermes-agent.service`
and the service identity is the `hermes` user and group.

State lives on the host at `/var/lib/hermes/.hermes`, with the workspace at
`/var/lib/hermes/workspace`. The container sees that state directory mounted at `/data`, so
in-container paths are `/data/.hermes` and `/data/workspace`. `hermes` on the host PATH is the
single operator CLI and routes into the container automatically; every configured host user
gets `~/.hermes` symlinked to the shared state.

`hermes/workspace/AGENTS.md` and `hermes/workspace/SOUL.md` are the repository-owned agent
documents; both hosts install them into the workspace on activation.

The dashboard stays on loopback `127.0.0.1:9119`; Alucard publishes it through Tailscale Serve
at <https://alucard.tailf117a1.ts.net:29119> behind Basic Auth as `demo`. It is started by the
small local unit `hermes-dashboard.service` (`modules/hermes-dashboard.nix`) because upstream's
container mode does not supervise it. Delete that unit once `services.hermes-agent` starts the
dashboard itself.

Hermes has a deliberately restricted host view: no Docker socket, no general web or browser
toolset, manual approval for commands it classifies as dangerous, and a write-safe root of
`/data/workspace:/data/.hermes:/org`. Its one additional host surface is the shared Org tree,
mounted at `/org`. `approvals.mode = "manual"` is a dangerous-command gate, not approval of
every action: routine reads, writes below the write-safe root, and ordinary Git commits
proceed without a prompt. The write-safe root and the systemd/container confinement are the
actual boundary; the session transcript and the ingress JSONL are the audit record.

Alucard runs one shared agent for the two founders, `vincenzo` and `kyrill`, both in the
`hermes` group. Sessions separate by chat origin, but memory, skills, workspace and `/org` are
shared on purpose. This is a trusted two-person team boundary, not customer multi-tenancy, and
the dashboard is not tenant-aware. Dracula keeps a separate personal agent on the local model;
the two hosts never share state.

Hermes' `.env` is fully owned by Nix and SOPS and is rewritten on every activation. Dashboard
or QR edits to credentials are not authoritative — rotate in SOPS, as described in
[SECRETS.md](SECRETS.md).

Hermes' dashboard token analytics are a local lower-bound estimate: auxiliary calls, retries,
fallbacks, and cache writes can be missing. Grafana and the ingress JSONL are the authoritative
request, token, and cost record.

No MCP server is enabled. Introduce a real external system through a maintained n8n node or a
reviewed MCP server rather than a custom adapter.

### Hermes and n8n interoperability

Both containers mount the host Org tree read-write as `/org`, with an ACL granting the `hermes`
service identity access; n8n keeps file nodes restricted to that tree. n8n reaches Hermes'
authenticated API at `http://host.docker.internal:8642/v1` through a systemd socket proxy bound
only to n8n's private `n8n-local0` Docker bridge. Reaching host services over
`host.docker.internal` is the intended arrangement for the n8n container; port `8642` is not on
the LAN, the tailnet, or the public firewall.

On Alucard two reviewed workflows are the contract, imported with `n8n-workflows import`:

- `POST /webhook/startup/hermes-delegate`, authenticated with the `X-Startup-Token` header.
  The body must be exactly
  `{"correlation_id": "[A-Za-z0-9_-]{1,64}", "prompt": "<non-empty string>"}` and returns
  `{"status":"completed","correlation_id":...,"content":...}`. A missing or wrong token returns
  403 and never reaches Hermes; a malformed body or any extra key returns 400 with a `reason`.
- `POST /webhook/startup/hermes-inbox`, same authentication. The body must be exactly
  `{"correlation_id": same regex, "kind": "artifact"|"event", "payload": <object>}` and returns
  `{"status":"accepted", ...}` echoing those fields; malformed input returns 400. The persisted
  n8n execution is the delivery record — there is no separate queue or idempotency store.

Hermes reaches n8n through exactly one command, available on the container PATH:

```console
hermes-n8n-handoff --correlation-id ID --kind artifact|event --payload JSON
```

It reads `N8N_WEBHOOK_TOKEN` from the Hermes environment and posts only to the inbox webhook.
It is the only automatic Hermes-to-n8n path.

The credentials `startupHermesApi` (`Authorization: Bearer`, the Hermes API key) and
`startupWebhookAuth` (`X-Startup-Token`) are provisioned into n8n's encrypted store by
`n8n-credentials-sync.service` from SOPS. They are never in workflow JSON.

n8n Community Edition is a single owner-managed automation plane: it supports multiple login
users but not project, workflow, or credential sharing. Do not claim tenant isolation.

## Observability: what to look at where

The two browser tools answer different questions:

- **Langfuse** explains an AI interaction: the user turn, model generations, tool calls,
  retries, errors, token use, annotations, and later evaluation scores. OpenCode uses
  Langfuse's official rolling plugin.
- **Grafana** explains the machines and services: CPU, RAM, disk, Docker-container memory,
  RTX 3090 utilization and VRAM, n8n runtime metrics, request rate, input/output token rate,
  Requesty cost, average latency, and time to first token. The provisioned **AI and machine
  overview** dashboard is the starting point.

Langfuse v4 is observations-first, so API consumers should use
`/api/public/v2/observations`, not the removed legacy `/api/public/traces` endpoint. The
OpenCode plugin does not populate `providedModelName`, so the ingress model label remains the
reliable model dimension.

Docker 29 keeps its embedded containerd socket at `/run/docker/containerd/containerd.sock`;
the cAdvisor container is explicitly pointed there. Without that argument the scrape target is
deceptively green but contains only the host root cgroup, so verify
`count(container_last_seen) > 1` after changes.

Coverage is deliberately honest. The ingress proxy emits one Langfuse generation observation
per `/v1/chat/completions` and `/v1/responses`, tagged `source=ai-ingress`, carrying model,
caller, environment, status, latency, TTFT, token usage, and cost details. Export is
asynchronous and best-effort: if Langfuse is down the inference call still succeeds and the
proxy only logs a non-fatal error. Those observations are the cross-client coverage for OMP,
Hermes, and n8n. OpenCode additionally runs its own Langfuse plugin for nested agent and tool
traces; never sum OpenCode plugin cost and ingress cost for billing, because both describe the
same call. Grafana's ingress metrics are the authoritative aggregate.

n8n has no native Langfuse tracing integration. Use its own execution history and Prometheus
metrics, then instrument the important production workflows explicitly rather than installing
an unreviewed community node globally.

Every ingress record carries a `cost` object, `{actual_usd, estimated_usd, source}`, where
`source` is `provider`, `registry-estimate`, or `unavailable`. A provider-reported cost is
never replaced by the local list-price estimate, and Dracula's local models have no list price,
so they report `unavailable` rather than a fake $0. The Prometheus series follow the same
split: `ai_ingress_cost_usd_total` is provider-reported actual cost and
`ai_ingress_estimated_cost_usd_total` is the list-price estimate. Never sum the two.

Prometheus keeps up to 90 days or 20 GB, whichever limit it reaches first. Langfuse keeps
its application data in Docker volumes. The ingress JSONL remains the complete,
provider-independent record of what each client actually sent and received; Langfuse is the
inspection, annotation, dataset, and experiment UI. Langfuse datasets and evaluations are
used for demonstrations — there is no local evaluation harness and no synthetic-task quality
gate in this repository.

Log in to Langfuse as `vincenzo@istbereit.de` and Grafana as `admin`. Retrieve the generated
passwords locally without placing them in shell history:

```console
sops --decrypt secrets/dracula-ai.yaml | yq -r '.langfuse.admin_password'
sops --decrypt secrets/dracula-ai.yaml | yq -r '.grafana.admin_password'
```

Check the stack and individual scrape targets with:

```console
observability-status
sudo docker compose --env-file /run/secrets/rendered/observability.env \
  --project-directory /var/lib/observability-stack logs -f langfuse-web
curl -fsS http://127.0.0.1:19091/-/ready
curl -fsS http://127.0.0.1:8080/metrics | grep '^ai_ingress_'
```

Prompts, responses, tool arguments, and tool output may contain customer or company data.
All current UIs bind only to loopback. Before any customer deployment is remotely exposed,
put it behind authenticated TLS, define trace retention and deletion, test backups and
restores, and decide which fields must be redacted at ingestion.

Vincenzo's account is in the `docker` group on both hosts, which is root-equivalent. A
harness or agent running as that user is not contained by any container boundary here, so
do not describe it as sandboxed.

The encrypted secret inventory, consumers, generated runtime files, and rotation cautions
are documented in [SECRETS.md](SECRETS.md). Read it before changing any SOPS value: several
bootstrap values cannot be rotated merely by editing the encrypted file.

## Usage and troubleshooting

The ingress log is the authoritative record across clients:

```console
ai-usage-summary
ai-usage-summary --caller omp --caller opencode
journalctl -u local-llama-logger.service -f
```

The summary window defaults to the last seven days; pass `--since all`, an ISO-8601
timestamp, or `--json` when harvesting a complete trial. It aggregates requests, errors,
incomplete streams, missing-usage records, tokens, latency, and TTFT without printing
request or response content.

Callers are attributed solely by the `X-AI-Caller` request header; a request that omits it is
recorded as `unattributed`. Set the header in every new client rather than expecting the
ingress to infer an identity from a credential.

Full request records are stored in `/var/lib/llama/logs/requests.jsonl` and rotated daily.
They include prompts and responses, so treat them as sensitive data.
They must never reach Git or Syncthing. `.gitignore` excludes `*.jsonl`, `var/lib/llama/`,
and `n8n/exports/`; the remote is a GitHub repository that must never receive request
payloads.

Useful service checks:

```console
systemctl --no-pager status ai-stack.target
systemctl --no-pager status docker-n8n.service hermes-agent.service hermes-dashboard.service
docker ps --filter name=hermes-agent
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
```

Models load on demand, so the first request after a boot or a model swap pays the full GGUF
read from disk—tens of seconds cold against seconds warm. Never quote a first-request
latency as steady-state throughput.

`ai-stack-stop` is also the recovery path: every stop/start exercises the same code as a
cold boot, and no service may need a manual post-boot step. Confirm the GPU actually came
back with `nvidia-smi` rather than `systemctl status`—a unit reported inactive while still
holding VRAM is the failure mode worth looking for. Desktop applications keep small
allocations of their own, so the assertion is that no AI compute process remains. A CUDA
context does not reliably survive suspend, so `ai-stack-resume` restarts `ai-stack.target`
after `suspend.target` instead of assuming the context is intact.

## Container updates

Container versions are changed through reviewed Git, not by a timer pulling a mutable tag.
`renovate.json` uses Renovate's Docker Compose, Nix/flake, and GitHub Actions managers plus a
small regex manager for Nix-held OCI defaults. It asks Renovate to preserve readable tags while
adding an immutable digest (`image:tag@sha256:…`) and to update that digest if the tag moves.
It groups the Langfuse web/worker pair and n8n/task-runner pair; unrelated applications stay in
separate PRs. It opens at most two PRs per hour and five concurrently, during the Berlin
weekday 22:00–24:00 window. Automerge is disabled.

Every image in `observability/docker-compose.yml` is digest-pinned, as are the n8n
application and task-runner images and the Hermes container base.

`container-update.timer` is disabled by default. After merging a digest PR, rebuild the intended
host, then restart only its already-active application units:

```console
containers-update
```

The command waits while pinned images download and services pass their health checks. A stopped
stack remains stopped. Git revert plus rebuild restores the previous digest; do not run
`containers-update` against an unreviewed or unpinned image change.

### Enable Renovate

Install the maintained [Renovate GitHub App](https://github.com/apps/renovate) for this private
repository, granting repository contents and pull-request access only. It needs no host
credential, Docker socket, or runtime-container access. Review the onboarding dependency
dashboard and require the repository's Nix build workflow in branch protection before merging
any Renovate PR. If the GitHub App is unavailable for the organization, run the maintained
Renovate container externally with a least-privilege GitHub App token; never add that token to
Nix, SOPS plaintext, or this repository.

Run locally without credentials only for configuration checks:

```console
renovate-config-validator renovate.json
LOG_LEVEL=debug renovate --dry-run=full donvini94/nixos-config
```

The dry run requires read access to the private repository and must report Compose images,
the n8n, Trivy, and Hermes base-image Nix defaults, `flake.lock`, GitHub Actions, and the
llama-swap release. The llama-swap manager intentionally changes only its release version:
regenerate its fixed-output Nix hash in the same PR before its required build can pass. Model
pins and SOPS-encrypted files are deliberately outside Renovate's regex scope.

Renovate proposes updates. Trivy/scanners identify vulnerabilities. Nix builds, smoke tests,
and human review decide whether an update is safe. These are complementary controls.

### Moving configuration between machines

`nixos-config` moves between machines by Git alone. It is deliberately not a Syncthing
folder: syncing a working tree while each machine keeps its own `.git` produces a stale
`HEAD` against already-current files, which reads as phantom modifications, and syncing
`.git` itself can land a branch ref before its objects arrive and corrupt the database.
Both failure modes were observed on this folder before it was withdrawn: a `.git/index`
conflict on 2026-08-08 froze the MacBook's `HEAD` for eight days and left 106
`*.sync-conflict-*` artifacts in `.git`.

The decisive argument is narrower than corruption. A flake reads only Git-tracked files, so
a change Syncthing delivers but nobody commits is invisible to `nixos-rebuild --flake`. That
is not a theoretical gap: `hm-modules/omp.nix` was present on both desktops and excluded
from every rebuild for two weeks because it was untracked. Syncthing was moving files the
builder could not read.

Every machine therefore needs push and fetch access to the remote, including Alucard, which
deploys from its own checkout. If Nix reports `object not found`, repair the object database
before rebuilding — do not reset or reclone over uncommitted files.

## Media stack on Alucard

The media automation applications run as the `media-stack.service` Compose project. The
user-facing services are:

| Component | Address | Purpose |
| --- | --- | --- |
| Jellyfin | <https://stream.dumusstbereitsein.de> | Watch the media library |
| Seerr | <https://requests.dumusstbereitsein.de> | Request movies and series |
| Komga | <https://comics.istbereit.de> | Read comics and manga |

The remaining media-automation interfaces are loopback-only on Alucard; their ports and
tailnet URLs are inventoried in
[Alucard security and exposure guide](./ALUCARD_SECURITY.md). Reach one through an SSH tunnel
when Tailscale is unavailable, for example:

```console
ssh -L 18989:127.0.0.1:18989 alucard
```

Then open <http://127.0.0.1:18989> locally. `containers-update` on Alucard pulls all rolling
Compose images and recreates the active media stack.

## Business-demo stack on Alucard

The reusable profile is enabled in `hosts/alucard/ai.nix`. It builds the same operator
experience—OMP, OpenCode, n8n, Hermes, Langfuse, Grafana, and the stable logged
ingress—while inference goes to Requesty's OpenAI-compatible router instead of a local GPU.
Alucard's minimal Home Manager profile installs only the two coding harnesses, not Dracula's
desktop configuration.

Requesty is already the maintained routing product, so the default plan does not add another
gateway merely to proxy it. Alucard uses `https://router.requesty.ai/v1`, SOPS-managed
Requesty credentials, spending limits, and explicit `provider/model` or `policy/name` IDs. The
key is loaded into the loopback ingress with a systemd credential and injected upstream; OMP,
OpenCode, n8n, and Hermes never receive the Requesty key. The local Nix registry is the
client-visible allow-list even when
the Requesty key can access the full catalog: unregistered model calls receive HTTP 403
before reaching Requesty, and `/v1/models` exposes only registered IDs. A matching Requesty
[Access List](https://docs.requesty.ai/features/access-lists) is optional defense in depth;
separate keys remain the boundary for revocation, customer isolation, and cost ownership.
Requesty's cost and provider-routing analytics complement Langfuse's agent traces and the
local Grafana machine/container view. Requesty's response cost and `x-requesty-*` provider,
cache, latency, and request-ID metadata are retained in the sensitive ingress JSONL.

The shared registry in `lib/requesty-models.nix` is the client-visible catalog: the cheap
DeepSeek V4 Flash default, Qwen 3.7 Plus, DeepSeek V4 Pro, Kimi K3, and three closed frontier
comparisons. OMP receives its per-million token prices. Re-check IDs, capabilities, prices,
and provider retention against Requesty's authenticated
[`GET /v1/models`](https://docs.requesty.ai/api-reference/endpoint/models-list) catalog before
changing it. The customer-facing model table lives in
[Alucard AI demo guide](./AI_DEMO_GUIDE.md).

Dracula's OMP and OpenCode expose the same Requesty registry through
`http://alucard.tailf117a1.ts.net:28080/v1` over Tailscale while retaining both local GPU
models and the local dense default. No Requesty credential is installed on Dracula.

Use the initial model through the unchanged ingress:

```console
omp --model alucard-requesty/deepinfra/deepseek-v4-flash-0731
opencode run -m alucard-requesty/deepinfra/deepseek-v4-flash-0731 "your task"

curl http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -H 'X-AI-Caller: manual' \
  -d '{"model":"deepinfra/deepseek-v4-flash-0731","messages":[{"role":"user","content":"Say hello"}]}'
```

### Messaging transport

Telegram is the mobile channel on Alucard. Hermes enforces a strict numeric user allowlist and
polls outbound, so no public webhook and no inbound firewall port are required. Supported
messaging adapters egress through the domain-filtered proxy on loopback port `18084`, whose
allowlist is exactly `api.telegram.org` and `setup.hermes-agent.nousresearch.com`. General web
and browser toolsets stay disabled.

The bot token and the allowlist live in SOPS as `hermes/telegram_bot_token` and
`hermes/telegram_allowed_users`. The allowlist is comma-separated and structurally
multi-value, so the second founder's numeric ID can be appended once it is known; never use
`*`. Nix rewrites Hermes' `.env` on every activation, so a token entered in the dashboard or
created through its QR onboarding is not authoritative and is overwritten on the next switch.
Rotate in SOPS. Revoke a compromised bot with BotFather `/revoke`, then put the replacement
token in SOPS.

Keep BotFather group joining disabled until a specific group ID and sender policy are
reviewed.

### Requesty deployment checklist

1. In Requesty, create an `alucard-demo` project or workload key, set its monthly spend
   limit, and optionally attach a matching Access List or create reviewed fallback policies.
2. Run `sops secrets/alucard-ai.yaml` on Dracula or Alucard and replace only
   `requesty.api_key`. The other machine-specific service secrets are already generated.
3. Put the allowed model/policy IDs, display names, context limits, and output limits in the
   registry in `lib/requesty-models.nix`, then select a default.
4. Build, switch, and verify `/v1/models` through port `8080` before sending a paid prompt.

Startup authenticates to Requesty's model-list endpoint and requires every locally
registered model to exist in the key's returned catalog. A placeholder key or missing model
fails closed before the ingress accepts traffic; a broader key is narrowed locally.

The AI browser and API listeners are deliberately loopback-only.

From Dracula, start the declarative private tunnel:

```console
ssh -N ai-admin
```

Keep that terminal open and use these local addresses:

| Alucard component | Address on Dracula |
| --- | --- |
| n8n | <http://127.0.0.1:25678> |
| Requesty-backed API | <http://127.0.0.1:28080/v1> |
| Hermes | <http://127.0.0.1:29119> |
| Langfuse | <http://127.0.0.1:23000> |
| Grafana | <http://127.0.0.1:23001> |
| Prometheus | <http://127.0.0.1:29091> |

The alternate local ports avoid collisions with Dracula's own stack. Stop the tunnel with
Ctrl-C. From a different computer without the `ai-admin` SSH profile, use equivalent `-L`
arguments or copy that profile; do not publish these ports in nginx or the host firewall.

SSH remains the break-glass fallback. Tailscale is the multi-device private access plane for
both AI and media-administration services; enrollment steps, every tailnet port, the exposure
inventory, and the hardening work register are maintained in
[Alucard security and exposure guide](./ALUCARD_SECURITY.md). Keep every backend on localhost
and **never enable Tailscale Funnel**, which is the public-internet feature.

Authenticated HTTPS and tested backup/restore, retention, deletion, and redaction policies
are mandatory before presenting the interfaces as a customer service. Dracula remains the
local-model comparison machine; Alucard is the business demo.
