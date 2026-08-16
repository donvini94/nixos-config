# Alucard AI demo guide

This is the short operating guide for discussing and demonstrating the AI platform with
customers. It explains what each component does and how to reach it; it contains no passwords,
API keys, or infrastructure secrets.

## First-time access

Alucard's AI tools are private. They are not reachable from the public internet.

1. Ask the tailnet administrator to invite your company identity to Tailscale and grant you
   access to the Alucard AI services.
2. Install the [Tailscale client](https://tailscale.com/download) on your computer.
3. Sign in with the invited identity and confirm that `alucard` appears online in the client.
4. Open the links below. Some applications also require their own account; ask the platform
   administrator for an invitation rather than sharing an administrator password.

If a link does not open, check that Tailscale is connected before troubleshooting the
application. The stable server name is `alucard.tailf117a1.ts.net`. Use that full name in every
HTTPS URL: Tailscale's certificate and the Hermes host check are bound to it, so the shortened
`https://alucard:29119` address is intentionally unsupported.

## What to open

| Component | What it demonstrates | Link |
| --- | --- | --- |
| Hermes | A conversational agent that can use tools and complete multi-step work | [Open Hermes Sessions](https://alucard.tailf117a1.ts.net:29119/sessions) |
| n8n | Visual business automation and AI workflows | [Open n8n](http://alucard.tailf117a1.ts.net:25678) |
| Langfuse | Traces of model and agent activity: prompts, responses, latency, tokens, and evaluation | [Open Langfuse](http://alucard.tailf117a1.ts.net:23000) |
| Grafana | Operational view of the server, containers, request traffic, token usage, and cost | [Open Grafana](http://alucard.tailf117a1.ts.net:23001) |
| OpenAI-compatible API | Stable integration endpoint used by applications and coding agents | `http://alucard.tailf117a1.ts.net:28080/v1` |

Prometheus at `http://alucard.tailf117a1.ts.net:29091` is the raw metrics database. It is useful
for engineering diagnostics but is not normally part of a customer demo.

## The platform in one minute

Alucard provides a private, OpenAI-compatible AI platform. Applications call one stable API
instead of integrating separately with every model provider. The current model is routed
through Requesty, while the local registry controls which model IDs customers and agents are
allowed to request.

Around that API:

- Hermes demonstrates agentic work: a conversational agent that uses tools across multiple
  steps.
- n8n turns model calls and business-system actions into visual workflows.
- Langfuse explains instrumented model and agent runs. Every model call made through the
  platform API produces a trace-level record; OpenCode additionally contributes nested
  agent and tool spans.
- Grafana explains whether the infrastructure is healthy and how usage changes over time.
- Tailscale provides identity-based private network access without publishing administrative
  dashboards to the internet.

The same architecture can run with local models, hosted open-weight models, or premium frontier
models. Model selection is a policy and economics decision; applications do not have to change
their integration endpoint.

## Suggested customer-demo flow

1. Start in **Hermes** or an existing **n8n** workflow and run one useful task.
2. Open **Grafana** and connect that interaction to traffic, token use, cost, and system health.
3. For a trace-level demonstration, run an existing instrumented **OpenCode** example and open
   its trace in **Langfuse**. Do not claim that every client already provides nested traces.
4. Explain that a customer's applications can use the same `/v1` API contract while routing
   simple tasks to inexpensive open models and difficult tasks to stronger frontier models.

Do not improvise claims about benchmark superiority, guaranteed savings, compliance, data
residency, or production availability. Those require an agreed model evaluation, retention
policy, backup/restore evidence, and customer-specific architecture.

For the first Hermes demonstration, create a session and ask it to update a harmless test file
under `/org/ai-inbox`, then inspect the result and optionally hand it to an n8n workflow.
Alucard's Hermes intentionally has no general web-search or browser tool and cannot modify the
host outside its workspace and the explicitly shared Org tree. Its exact boundaries are
documented in [the stack guide](./STACK_GUIDE.md).

Alucard runs a single shared agent for the two founders rather than one agent per person. Do
not present the dashboard as multi-tenant or as customer isolation.

## Hermes Desktop

Hermes Desktop is the preferred customer-facing client. Install the official application, then
open **Settings → Gateway → Remote gateway** and enter:

- Remote URL: `https://alucard.tailf117a1.ts.net:29119`
- Username: `demo`
- Password: request it from the platform operator through the company password manager

Sign in, save, and reconnect. The desktop client then uses Alucard's models, sessions, memory,
skills, and isolated workspace. Tailscale must remain connected. Do not install Alucard's model
credential on the client.

Until the password has been placed in the company password manager, the platform operator can
retrieve it locally on either managed host without storing plaintext in this repository:

```console
cd ~/nixos-config
sops --decrypt secrets/alucard-ai.yaml | yq -r '.hermes.dashboard_password'
```

## API example

The platform administrator can issue a workload-specific credential when an external client
needs API access. Never reuse or disclose the upstream Requesty key.

```console
curl http://alucard.tailf117a1.ts.net:28080/v1/models
```

The model list is deliberately narrower than Requesty's full catalog. Calls with unregistered
model IDs are rejected locally before they can create upstream cost.

The current curated choices are:

| Use | Model |
| --- | --- |
| Cheapest default | `deepinfra/deepseek-v4-flash-0731` |
| Cheap Qwen comparison | `alibaba/qwen3.7-plus` |
| Stronger open DeepSeek | `deepinfra/deepseek-ai/DeepSeek-V4-Pro` |
| Open frontier comparison | `sference/kimi-k3` |
| Closed frontier comparisons | Gemini 3.1 Pro, Claude Sonnet 5, GPT-5.6 Terra |

The registry is the client-visible allow-list: Alucard's `/v1/models` exposes exactly these
seven IDs. Requesty's catalog reports 30-day provider retention for the selected Claude and
OpenAI routes; do not use those routes for sensitive customer data without an agreed policy.
The selected DeepSeek, Qwen, Kimi, and Gemini routes report no provider retention.

OMP and OpenCode on Alucard expose these models directly. On Dracula they appear alongside
the two local GPU models through Alucard's private tailnet ingress; the Requesty key never
leaves Alucard. Examples:

```console
omp --model alucard-requesty/alibaba/qwen3.7-plus
omp --model alucard-requesty/sference/kimi-k3
opencode run -m alucard-requesty/deepinfra/deepseek-v4-flash-0731 "your task"
```

Dracula keeps `dracula-local/dirk-qwen3.8-27b-local` as its no-cost text-only default.

## Telegram agent channel

Telegram is the mobile channel because it provides a bot identity without a dedicated SIM.
Hermes is the only Telegram front door. Access is a strict numeric allowlist of Telegram user
IDs; an account that is not on the list receives no agent response. The bot token and the
allowlist are managed as encrypted secrets by the platform operator, not through the
dashboard.

Polling is outbound, so the channel opens no inbound port and publishes nothing to the
internet.

## Troubleshooting

```console
tailscale status
curl --fail http://alucard.tailf117a1.ts.net:28080/health
```

- If Alucard is absent or offline in `tailscale status`, contact the tailnet administrator.
- If the health request succeeds but a browser UI rejects login, request an application account.
- If all tailnet links work except one application, report the component name, time, and error;
  do not send screenshots containing prompts, customer data, tokens, or credentials.

The detailed operator and security runbook is [ALUCARD_SECURITY.md](./ALUCARD_SECURITY.md).
