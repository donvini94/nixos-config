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
application. The stable server name is `alucard.tailf117a1.ts.net`.

## What to open

| Component | What it demonstrates | Link |
| --- | --- | --- |
| Hermes | A conversational agent that can use tools and complete multi-step work | [Open Hermes Sessions](https://alucard.tailf117a1.ts.net:29119/sessions) |
| Wirken | Experimental governed-agent UI and signed audit-chain inspection; effectful browser tools are not yet usable | [Open Wirken](http://alucard.tailf117a1.ts.net:28790) |
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

- Hermes and Wirken demonstrate two styles of agentic work.
- n8n turns model calls and business-system actions into visual workflows.
- Langfuse explains fully instrumented model and agent runs. Today, OpenCode has detailed
  traces; other clients still have aggregate ingress metrics and complete JSONL records.
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
4. Open **Wirken** when the discussion turns to governed execution, approvals, audit evidence,
   or separating model access from credentials and tools.
5. Explain that a customer's applications can use the same `/v1` API contract while routing
   simple tasks to inexpensive open models and difficult tasks to stronger frontier models.

Do not improvise claims about benchmark superiority, guaranteed savings, compliance, data
residency, or production availability. Those require an agreed model evaluation, retention
policy, backup/restore evidence, and customer-specific architecture.

For the first Hermes demonstration, create a session and ask it to write a short Markdown plan
inside its workspace, then inspect the result in **Files**. Alucard's Hermes intentionally has no
general web-search/browser tool and cannot modify the host outside its isolated workspace. See
the [Hermes operator guide](../hermes/README.md) for the exact boundaries.

## Hermes Desktop

Hermes Desktop is the preferred customer-facing client. Install the official application, then
open **Settings → Gateway → Remote gateway** and enter:

- Remote URL: `https://alucard.tailf117a1.ts.net:29119`
- Username: `demo`
- Password: request it from the platform operator through the company password manager

Sign in, save, and reconnect. The desktop client then uses Alucard's models, sessions, memory,
skills, and isolated workspace. Tailscale must remain connected. Do not install Alucard's model
credential on the client.

## API example

The platform administrator can issue a workload-specific credential when an external client
needs API access. Never reuse or disclose the upstream Requesty key.

```console
curl http://alucard.tailf117a1.ts.net:28080/v1/models
```

The model list is deliberately narrower than Requesty's full catalog. Calls with unregistered
model IDs are rejected locally before they can create upstream cost.

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
