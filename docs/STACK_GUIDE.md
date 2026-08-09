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
ai-stack-start       # start inference, n8n, Hermes, and the Wirken trial
ai-stack-health      # verify the stack and inference ingress
ai-stack-stop        # stop the complete AI stack and release model VRAM
observability-status # inspect Langfuse, Grafana, Prometheus, and exporters
containers-update    # pull rolling application images and recreate active containers
```

The browser interfaces are:

| Component | Address | Purpose | Current status |
| --- | --- | --- | --- |
| n8n | <http://127.0.0.1:5678> | Visual, deterministic workflows | Usable |
| Hermes | <http://127.0.0.1:9119> | Persistent autonomous agent and chat | Usable |
| Wirken | <http://127.0.0.1:18790> | Governed-agent experiment and audit inspection | Experimental; no effectful work |
| Inference API | <http://127.0.0.1:8080/v1> | Stable OpenAI-compatible API | Usable |
| Langfuse | <http://127.0.0.1:13000> | Agent traces, token analysis, annotations, datasets, and evaluations | Usable |
| Grafana | <http://127.0.0.1:13001> | Machine, container, GPU, n8n, and inference metrics | Usable |
| Prometheus | <http://127.0.0.1:19091> | Metrics database and query interface | Usable |

All addresses are loopback-only: they are reachable from `dracula`, not the LAN or
internet.

## How an AI request moves

```text
OMP / OpenCode / n8n / Hermes / Wirken / curl
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
  -d '{"model":"qwen3.6-27b-local","messages":[{"role":"user","content":"Say hello"}]}'
```

Available model IDs are `qwen3.6-27b-local` and `qwen3.6-35b-a3b`. Only one is resident at
a time.

## What each AI component is for

### OMP and OpenCode

These are the two interactive coding harnesses. Both are configured to use the permanent
local ingress and ask before changing files or executing commands. Use both on real tasks;
their different prompts and tool loops are part of the comparison.

OMP receives the Nix-managed model and safety policy through its supported `PI_CONFIG_FILES`
overlay. Its own `~/.omp/agent/config.yml` remains a normal writable file for settings that OMP
persists. Automatic onboarding is skipped because the provider is already configured; run
`omp setup` explicitly only when you intend to revisit upstream's setup flow. Useful diagnostics:

```console
omp --version
omp config path
omp models
```

### n8n

n8n is for visible, repeatable workflows: scheduled jobs, mail processing, webhooks, and
multi-step business automation. Build and test workflows in its browser UI. Use
`n8n-workflows-export` to create a reviewable export and `n8n-workflows-import` to load the
repository's reviewed workflows. See [the n8n guide](../n8n/README.md).

### Hermes

Hermes is the persistent agent path. Its state is under `/var/lib/hermes/.hermes` and its
workspace is `/var/lib/hermes/workspace`. It has a deliberately restricted host view and
manual approval for commands that Hermes classifies as dangerous. See
[the Hermes guide](../hermes/README.md).

### Wirken

Wirken is wanted in the final stack, but its present deployment is a native, signed v1.13
binary because upstream publishes no official container. Normal WebChat inference works.
Effectful WebChat tools do not: an upstream session-ID defect prevents the approval prompt
from reaching the browser, so the request times out and fails closed. Do not give this trial
production credentials or use it for effectful work.

The current native service remains available for learning about its vault and signed audit
chain while the upstream container and approval path are unresolved. It is not replaced by
Open WebUI. See [the Wirken guide](../wirken/README.md).

## Observability: what to look at where

The two browser tools answer different questions:

- **Langfuse** explains an AI interaction: the user turn, model generations, tool calls,
  retries, errors, token use, annotations, and later evaluation scores. OpenCode uses
  Langfuse's official rolling plugin.
- **Grafana** explains the machines and services: CPU, RAM, disk, Docker-container memory,
  RTX 3090 utilization and VRAM, n8n runtime metrics, request rate, input/output token rate,
  Requesty cost, average latency, and time to first token. The provisioned **AI and machine
  overview** dashboard is the starting point.

The live acceptance test on 2026-08-09 verified every Prometheus target, including the RTX
3090 DCGM exporter, and sent a real OpenCode request through port `8080`. Langfuse v4
recorded the turn as an agent observation, a user-message event, and a generation with
9,720 total tokens; ingress metrics independently recorded 9,667 input and 53 output
tokens. Langfuse v4 is observations-first, so API consumers should use
`/api/public/v2/observations`, not the removed legacy `/api/public/traces` endpoint. The
OpenCode plugin did not populate `providedModelName` in this smoke trace, so the ingress
model label remains the reliable model dimension until that integration improves.

Alucard's acceptance verified the five non-GPU targets—ingress, containers, n8n, node, and
Prometheus—and a real Requesty-backed OpenCode trace. Docker 29 keeps its embedded
containerd socket at `/run/docker/containerd/containerd.sock`; the cAdvisor container is
explicitly pointed there. Without that argument the scrape target is deceptively green but
contains only the host root cgroup, so verify `count(container_last_seen) > 1` after changes.

Coverage is deliberately honest. OMP and n8n already appear in ingress token/latency
metrics because all model calls pass port `8080`; their complete prompts and responses are
also in the JSONL log. OMP does not yet have nested tool-span tracing because the available
Pi integration is community-maintained and compatibility with the OMP fork must be tested.
n8n has no native Langfuse tracing integration; use n8n's own execution history and
Prometheus metrics now, then explicitly instrument the important production workflows
rather than installing an unreviewed community node globally. Hermes remains covered by
its own token dashboard plus ingress metrics and JSONL. Its bundled Langfuse plugin expects
a pip-installed SDK, but the sealed upstream Nix package rejects that SDK's overlapping
HTTP and Pydantic dependency closure. Nested Hermes traces therefore remain disabled until
upstream provides a compatible dependency group; do not bypass its collision guard.

Prometheus keeps up to 90 days or 20 GB, whichever limit it reaches first. Langfuse keeps
its application data in Docker volumes. The ingress JSONL remains the complete,
provider-independent source of truth for model evaluation; Langfuse is the inspection,
annotation, dataset, and experiment UI, not a replacement for reproducible task graders.

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

Full request records are stored in `/var/lib/llama/logs/requests.jsonl` and rotated daily.
They include prompts and responses, so treat them as sensitive data.

Useful service checks:

```console
systemctl --no-pager status ai-stack.target
systemctl --no-pager status docker-n8n.service hermes-agent.service wirken.service
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
```

## Container updates

Application containers declared in this repository use upstream rolling tags. Where an
official Compose file pins a supported major for a stateful dependency, such as Langfuse's
Postgres, Redis, and ClickHouse versions, this repository follows that compatibility-tested
major instead of independently jumping to an incompatible `latest` image.
`container-update.timer` checks daily at 04:00 with up to 30 minutes of random delay. A
missed run does not fire during the next NixOS activation. It recreates only stacks that are
already active; a deliberately stopped stack stays stopped and pulls its current image when
it is next started.

Run an update immediately on either host with:

```console
containers-update
```

The command waits while images download and services pass their health checks. A first pull
or a large upstream image can take several minutes; do not interrupt it merely because no
container is visible yet.

Inspect the schedule and the last update:

```console
systemctl list-timers container-update.timer
journalctl -u container-update.service
```

This policy favors fast access to upstream releases over reproducible image versions. State
is stored on host-mounted volumes, but a breaking upstream migration is still possible. Back
up application state before intentionally forcing an update during important work.

NixOS and native CLI packages are separate from application-container updates. Update their
locked inputs explicitly so the Git diff remains reviewable:

```console
cd /home/vincenzo/nixos-config
nix flake update
git diff -- flake.lock
sudo nixos-rebuild switch --flake .#dracula   # or .#alucard on the server
```

### Moving configuration between machines

The `nixos-config` working directory is shared by Syncthing, but `/.git` is explicitly
ignored. Synchronizing Git's internal refs and object files can produce a branch ref before
the corresponding object arrives and corrupt the repository. Commits must move through a
Git remote, `git bundle`, or another Git transport; Syncthing is only allowed to move
working-tree files. If Nix reports `object not found`, repair the object database before
rebuilding—do not reset or reclone over uncommitted files.

## Media stack on Alucard

The media automation applications run as the `media-stack.service` Compose project. The
user-facing services are:

| Component | Address | Purpose |
| --- | --- | --- |
| Jellyfin | <https://stream.dumusstbereitsein.de> | Watch the media library |
| Seerr | <https://requests.dumusstbereitsein.de> | Request movies and series |
| Komga | <https://comics.istbereit.de> | Read comics and manga |

The remaining automation interfaces are loopback-only on Alucard: qBittorrent `18080`,
Sonarr `18989`, Radarr `17878`, Prowlarr `19696`, Bazarr `16767`, SABnzbd `19090`, and
Kapowarr `15656`. Reach them through an SSH tunnel when administration is needed, for
example:

```console
ssh -L 18989:127.0.0.1:18989 alucard
```

Then open <http://127.0.0.1:18989> locally. `containers-update` on Alucard pulls all rolling
Compose images and recreates the active media stack.

## Business-demo stack on Alucard

The reusable profile is enabled in `hosts/alucard/ai.nix`. It builds the same operator
experience—OMP, OpenCode, n8n, Hermes, Wirken, Langfuse, Grafana, and the stable logged
ingress—while inference goes to Requesty's OpenAI-compatible router instead of a local GPU.
Alucard's minimal Home Manager profile installs only the two coding harnesses, not Dracula's
desktop configuration.

Requesty is already the maintained routing product, so the default plan does not add another
gateway merely to proxy it. Alucard will use `https://router.requesty.ai/v1`, SOPS-managed
Requesty credentials, spending limits, and explicit `provider/model` or `policy/name` IDs.
The key is loaded into the loopback ingress with a
systemd credential and injected upstream; OMP, OpenCode, n8n, Hermes, and Wirken never
receive the Requesty key. The local Nix registry is the client-visible allow-list even when
the Requesty key can access the full catalog: unregistered model calls receive HTTP 403
before reaching Requesty, and `/v1/models` exposes only registered IDs. A matching Requesty
[Access List](https://docs.requesty.ai/features/access-lists) is optional defense in depth;
separate keys remain the boundary for revocation, customer isolation, and cost ownership.
Requesty's cost and provider-routing analytics complement Langfuse's agent traces and the
local Grafana machine/container view. Requesty's response cost and `x-requesty-*` provider,
cache, latency, and request-ID metadata are also retained in the sensitive ingress JSONL;
cost is exported as `ai_ingress_cost_usd_total` for the Grafana dashboard.

The shared registry in `lib/requesty-models.nix` was checked against Requesty's authenticated
[`GET /v1/models`](https://docs.requesty.ai/api-reference/endpoint/models-list) catalog on
2026-08-09. It contains the cheap DeepSeek V4 Flash default, Qwen 3.7 Plus, DeepSeek V4 Pro,
Kimi K3, and three closed frontier comparisons. OMP receives the catalog's current per-million
token prices. Re-check IDs, capabilities, prices, and retention before changing this registry.

Dracula's OMP and OpenCode expose the same Requesty registry through
`http://alucard.tailf117a1.ts.net:28080/v1` over Tailscale while retaining both local GPU
models and the local dense default. No Requesty credential is installed on Dracula. Live
acceptance on 2026-08-09 confirmed `omp models` and `opencode models` expose the full combined
catalog; OMP uses its writable `~/.omp/agent` state and no longer repeats initial setup.

Use the initial model through the unchanged ingress:

```console
omp --model alucard-requesty/deepinfra/deepseek-v4-flash-0731
opencode run -m alucard-requesty/deepinfra/deepseek-v4-flash-0731 "your task"

curl http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -H 'X-AI-Caller: manual' \
  -d '{"model":"deepinfra/deepseek-v4-flash-0731","messages":[{"role":"user","content":"Say hello"}]}'
```

### Signal transport

Alucard uses the official signal-cli 0.14.7 native release under `signal-cli.service`.
The unit remains skipped until `/var/lib/signal-cli/signal-cli/data/accounts.json` exists,
so a rebuild never creates a partially authorized messaging surface. Once linked with
`signal-link`, one daemon exposes two local transports:

- `http://127.0.0.1:18083` for Hermes' supported Signal adapter;
- `/run/signal-cli/signal-cli.sock` for Wirken's supported Signal adapter.

The HTTP endpoint is never published by the firewall or Tailscale Serve. The Unix socket is
owned by the `signal-cli` group. Signal account state contains impersonation-capable keys and
must be treated as a secret backup. Sender allowlists are mandatory and agent-specific.

Wirken's upstream administrative CLI is available through `wirken-admin`; the launcher enters
the correct service account/state namespace and unlocks the encrypted vault through a systemd
credential. After linking, `wirken-admin channel add signal` registers the released adapter.
Use a dedicated Signal group for Wirken and reserve approved DMs for Hermes so the two agents
never consume the same conversation. See [the Wirken guide](../wirken/README.md) for approval
registration and the remaining live acceptance test.

### Container vulnerability visibility

Alucard runs Aqua Trivy's official rolling container daily and after the manual
`containers-scan` command. It scans distinct images running in both the root Docker daemon and
Vincenzo's rootless daemon from local Docker archives, retains root-only JSON reports, and
publishes aggregate and per-image counts through node-exporter's textfile collector. Grafana
shows critical, high, per-image, failure, and scan-age panels. The scanner never receives a
Docker socket. This complements update automation: pulling a newer image and proving that the
deployed image has no known fixed critical issue are separate operations.

Deployment checklist:

1. In Requesty, create an `alucard-demo` project or workload key, set its monthly spend
   limit, and optionally attach a matching Access List or create reviewed fallback policies.
2. Run `sops secrets/alucard-ai.yaml` on Dracula or Alucard and replace only
   `requesty.api_key`. The other machine-specific service secrets are already generated.
3. Put the allowed model/policy IDs, display names, context limits, and output limits in the
   registry at the top of `hosts/alucard/ai.nix`, then select a default.
4. Build, switch, and verify `/v1/models` through port `8080` before sending a paid prompt.

Startup authenticates to Requesty's model-list endpoint and requires every locally
registered model to exist in the key's returned catalog. A placeholder key or missing model
fails closed before the ingress accepts traffic; a broader key is narrowed locally.

The AI browser and API listeners are deliberately loopback-only and their ports are not
opened in Alucard's global firewall or public reverse proxy. Hermes alone binds a wildcard
socket so its authentication gate is active, but systemd accepts only loopback peers. Host
assertions reject any other non-loopback AI listener or any AI port in the global firewall.

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
| Wirken | <http://127.0.0.1:28790> |
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
