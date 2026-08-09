# Dracula and Alucard stack guide

This is the operator's map of what is installed, where to reach it, and which command owns
it. `dracula` is the local AI workstation. `alucard` is the server and media host.

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
| Langfuse | <http://127.0.0.1:13000> | Agent traces, token analysis, annotations, datasets, and evaluations | Ready after next switch |
| Grafana | <http://127.0.0.1:13001> | Machine, container, GPU, n8n, and inference metrics | Ready after next switch |
| Prometheus | <http://127.0.0.1:19091> | Metrics database and query interface | Ready after next switch |

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
  average latency, and time to first token. The provisioned **Local AI and machine
  overview** dashboard is the starting point.

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

Log in to Langfuse as `vincenzo@localhost` and Grafana as `admin`. Retrieve the generated
passwords locally without placing them in shell history:

```console
sops --decrypt secrets/dracula-ai.yaml | yq -r '.langfuse.admin_password'
sops --decrypt secrets/dracula-ai.yaml | yq -r '.grafana.admin_password'
```

Check the stack and individual scrape targets with:

```console
observability-status
docker compose --project-directory /var/lib/observability-stack logs -f langfuse-web
curl -fsS http://127.0.0.1:19091/-/ready
curl -fsS http://127.0.0.1:8080/metrics | grep '^ai_ingress_'
```

Prompts, responses, tool arguments, and tool output may contain customer or company data.
All current UIs bind only to loopback. Before any customer deployment is remotely exposed,
put it behind authenticated TLS, define trace retention and deletion, test backups and
restores, and decide which fields must be redacted at ingestion.

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

The reusable observability module is already imported on Alucard but intentionally disabled
until the AI stack and its secrets are defined there. The target is the same operator
experience—OMP, OpenCode, n8n, Hermes, Wirken, Langfuse, Grafana, and the stable logged
ingress—while inference goes to Requesty's OpenAI-compatible router instead of a local GPU.

Requesty is already the maintained routing product, so the default plan does not add another
gateway merely to proxy it. Alucard will use `https://router.requesty.ai/v1`, SOPS-managed
Requesty keys with model access lists and spending limits, and explicit provider/model IDs.
Requesty's cost and provider-routing analytics complement Langfuse's agent traces and the
local Grafana machine/container view.

Before enabling this profile, the operator must provide the Requesty keys and select the
demo model allow-list and fallback policies. The implementation must then generalize the
current port-8080 ingress backend, preserve per-caller attribution, keep secrets out of the
Nix store, and expose the browser UIs only through an authenticated HTTPS reverse proxy or
an SSH tunnel. Dracula remains the local-model comparison machine; Alucard becomes the
customer-facing business demo.
