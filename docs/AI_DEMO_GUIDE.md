# Alucard platform guide

This is the walkthrough for a founder: what runs, where to reach it, why it exists, how to
show it to a customer, and how to use it for our own work. It contains no passwords, API keys,
or infrastructure secrets.

The companion documents are [STACK_GUIDE.md](./STACK_GUIDE.md) (the operator's map: every unit,
path, and command), [ALUCARD_SECURITY.md](./ALUCARD_SECURITY.md) (exposure and recovery), and
[SECRETS.md](./SECRETS.md) (who owns which credential).

## Why any of this exists

Three reasons, in order of how much they matter to the business:

1. **We sell AI integration, so we have to run one.** A demo on someone else's SaaS proves
   nothing about our ability to deploy, secure, instrument, and operate a system. This platform
   is the reference implementation we point at.
2. **We need the leverage ourselves.** A two-person company cannot staff a back office. The
   same components that make a customer demo also do our document intake, automation, and
   research.
3. **Cost and provenance have to be visible.** Every model call through the platform is
   recorded with caller, tokens, latency, and cost. That is the difference between "AI is
   expensive" as a feeling and a number we can point at per workflow.

The deliberate architectural choice: **one OpenAI-compatible endpoint** that everything speaks
to. Applications integrate once. Which model actually answers is a policy and economics
decision we change without touching any client.

## Getting access

Nothing here is on the public internet except the sites listed under *Company services*.
Everything else requires Tailscale.

1. Ask Vincenzo to invite your identity to the tailnet and grant access to Alucard.
2. Install the [Tailscale client](https://tailscale.com/download), sign in, confirm `alucard`
   shows online.
3. Use the full name `alucard.tailf117a1.ts.net` in every URL. Tailscale's certificate and
   Hermes' host check are bound to it, so `https://alucard:29119` is intentionally unsupported.
4. Some applications need their own account. Ask for an invitation; do not share an admin
   password.

You also have a shell account on Alucard (`kyrill`, in the `wheel` and `hermes` groups). That
matters more than it sounds — see *Hermes is shared on purpose*.

If a link fails, check Tailscale before troubleshooting the application.

## What runs, and where

### The AI platform (tailnet only)

| Component | What it is for | Where |
| --- | --- | --- |
| Hermes | Persistent agent that uses tools over multiple steps and remembers | [Sessions](https://alucard.tailf117a1.ts.net:29119/sessions) |
| n8n | Visual automation: schedules, webhooks, multi-step business workflows | [n8n](http://alucard.tailf117a1.ts.net:25678) |
| Langfuse | Per-call traces: prompt, response, tokens, latency, cost | [Langfuse](http://alucard.tailf117a1.ts.net:23000) |
| Grafana | Aggregate view: traffic, tokens, spend, machine and container health | [Grafana](http://alucard.tailf117a1.ts.net:23001) |
| Model API | The stable integration endpoint every client uses | `http://alucard.tailf117a1.ts.net:28080/v1` |

Prometheus (`:29091`) is the raw metrics database behind Grafana. Engineering only; not part of
a demo.

### Company services (public, behind their own logins)

| Service | What it is for | Where |
| --- | --- | --- |
| Keycloak | Single sign-on identity for our services | `auth.dumusstbereitsein.de` |
| Paperless-ngx | Document management: OCR, tagging, correspondents, full-text search | `paperless.dumusstbereitsein.de` |
| WebDAV inbox | Scan-to-folder drop point that feeds Paperless | `webdav.istbereit.de` |
| Onyx | Chat and search over ingested company documents | `chat.dumusstbereitsein.de` |
| Actual Budget | Finance and budgeting | `budget.istbereit.de` |
| Mailcow | Company mail | `mail.istbereit.de` |
| File sharing | Large-file sharing (10 GB request limit) | `files.dumusstbereitsein.de` |
| Docker registry | Our own container images | `registry.dumusstbereitsein.de` |

One honest caveat: **Onyx runs its own model servers and does not go through our ingress.** Its
usage does not appear in Langfuse, Grafana, or our cost numbers. It is a useful tool, but when
we talk about "everything is instrumented" we mean the platform above, not Onyx.

### Media and personal (not part of the business story)

Jellyfin (`stream.`), Navidrome (`music.`), Calibre-Web (`read.`), Komga (`comics.`), Jellyseerr
(`requests.`), plus the download automation behind the VPN. Keep these out of customer demos.

### Dracula

Vincenzo's workstation runs the same shape with two local GPU models instead of a hosted
provider, and its own separate Hermes agent. It is where models get tested at zero marginal
cost before we point a customer at a paid route.

## Hermes is shared on purpose

Alucard runs **one** Hermes agent for both of us, not one per person. Conversations separate by
where they come from (your Telegram chat is not my Telegram chat), but memory, skills, the
workspace, and the `/org` company tree are deliberately shared. Something I teach it, you get.

This is a two-person trusted-team boundary. It is **not** customer isolation, and we must never
present it as multi-tenant. If we ever onboard someone who is not mutually trusted, they get a
separate agent instance, not an account on this one.

Three ways to reach the same agent:

- **Browser** — the Sessions link above.
- **Terminal** — SSH to Alucard and run `hermes`. It routes into the agent container
  automatically and shares the same sessions and memory as the browser.
- **Telegram** — the mobile path, restricted to a numeric allowlist. *Your ID is not on the
  list yet*; send it to Vincenzo and it takes one config change.

Hermes has no general web browsing or web search in this deployment, and it cannot touch the
host outside its workspace and `/org`. That is a deliberate boundary, not a missing feature.

## Your first thirty minutes

1. **Connect Tailscale**, open Grafana, and just look. This is what "we operate it" means.
2. **Open Hermes Sessions** and give it a real task: *"Read /org/ai-inbox, summarise anything
   from the last week into a short Markdown brief, and write it to /org/briefs."* Watch it plan,
   use the terminal and file tools, and ask for approval on anything risky.
3. **SSH in and run `hermes`** on the same task. Confirm it is the same agent with the same
   memory — that is the point.
4. **Open n8n** and look at `Startup / Hermes delegate`. That workflow is the machine-to-machine
   path: a validated webhook that hands work to Hermes and returns the answer.
5. **Open Langfuse**, find the calls you just made, and read one trace: prompt, response,
   tokens, latency, cost, and which client made it.
6. **Run `ai-usage-summary`** over SSH to see what your half-hour cost. It is usually cents.

## Demonstrating value to a customer

The demo is not "look, a chatbot". Everyone has one. The demo is **the boring parts nobody else
shows**: attribution, cost, traces, boundaries, and the fact that it survives a reboot.

A flow that lands:

1. **Start with their problem, not our stack.** Pick something in their back office with a
   document or a form in it.
2. **Run one useful task in Hermes**, out loud, including an approval prompt. Multi-step tool
   use is the thing that separates this from a chat window.
3. **Show the same capability as a workflow in n8n.** This is what an integration in their
   company would actually look like: a webhook, a schema, a repeatable run, an execution
   history.
4. **Open Langfuse on the call they just watched.** Prompt, response, tokens, latency, cost.
   "You will know what every automation costs you, per run."
5. **Open Grafana.** Same numbers aggregated by caller and model. "And this is the monthly view
   your finance person gets."
6. **Close on model choice.** The same `/v1` endpoint routes cheap open models for volume work
   and frontier models for hard work. Their applications never change.

What not to say: no benchmark superiority claims, no guaranteed savings percentages, no
compliance or data-residency promises, no production-availability commitments. Each of those
needs an agreed evaluation, a retention policy, restore evidence, and a customer-specific
architecture. Saying them casually is how we lose a deal at procurement.

## Using it for ourselves

This is where the platform pays for itself before any customer does.

### Available today

**Document back office.** Scan or drop a document into the WebDAV inbox; Paperless OCRs, tags,
and files it by correspondent. It is searchable immediately. Our taxonomy is version-controlled
and reprovisioned from the repository, so the filing rules are code, not somebody's habit.

**Automation glue.** n8n connects the pieces: schedules, webhooks, mail triggers, and calls into
Hermes. Workflows live in the repository as reviewed JSON and are deployed with
`n8n-workflows import`, so an automation is a reviewable change rather than something one of us
clicked together at midnight.

**Agent delegation with a real contract.** n8n can hand work to Hermes over a validated webhook
and get a structured answer back; Hermes can push a result to n8n with one command. Both
directions validate their input and reject malformed calls, so an automation fails loudly
instead of doing something surprising.

**Coding acceleration.** OMP and OpenCode both run against the shared endpoint, so our own
development is measured the same way as everything else. Cheap models do bulk work, expensive
models do hard work, and Grafana shows what each pattern actually costs.

**Cost discipline.** Every call is attributed to a caller. When something gets expensive we can
tell which workflow, which model, and which client did it — and the model registry rejects any
model ID we have not deliberately allowed, so a typo cannot invent upstream spend.

### Worth building next, in rough order of payoff

These are proposals, not existing features. Each is a small n8n workflow plus a Hermes prompt:

1. **Invoice and contract intake.** New document in Paperless → n8n extracts the key fields →
   Hermes drafts a one-paragraph summary and a suggested action → both land in `/org` and ping
   Telegram. Turns filing into a decision queue.
2. **Weekly operations digest.** Scheduled Hermes run over `/org`, recent Paperless additions,
   and the usage summary → one short brief every Monday.
3. **Proposal drafting with model tiering.** Cheap model drafts, frontier model polishes, both
   traced. This doubles as a live cost story for customers because we can show our own numbers.
4. **Inbox triage.** Mail rules feed n8n, Hermes proposes replies as drafts, a human sends. Never
   auto-send.

The reason these are cheap to build is that the hard part is already done: identity, storage,
OCR, an instrumented model endpoint, an agent with memory, and a scheduler that all share one
`/org` tree.

## What it costs and how we know

Model spend runs through Requesty. Setting a monthly spend limit on the key is part of the
deployment checklist in [STACK_GUIDE.md](./STACK_GUIDE.md) — confirm it is actually set in the
Requesty console before pointing a customer workload at it. Two independent numbers
are recorded per call: what the provider actually billed, and what our own price list says it
should have cost. They are never mixed, so a provider pricing change shows up as a divergence
instead of hiding.

```console
ssh alucard ai-usage-summary            # last 7 days by caller and model
ssh alucard ai-usage-summary --json     # same, machine-readable
```

Dracula's local models report no cost at all rather than a fake zero — running them is
electricity, not billing.

## The curated model list

`/v1/models` exposes exactly seven IDs. Anything else is rejected locally before it can create
upstream cost.

| Use | Model |
| --- | --- |
| Cheapest default | `deepinfra/deepseek-v4-flash-0731` |
| Cheap Qwen comparison | `alibaba/qwen3.7-plus` |
| Stronger open DeepSeek | `deepinfra/deepseek-ai/DeepSeek-V4-Pro` |
| Open frontier comparison | `sference/kimi-k3` |
| Closed frontier comparisons | Gemini 3.1 Pro, Claude Sonnet 5, GPT-5.6 Terra |

The selected Claude and OpenAI routes report 30-day provider retention. **Do not put sensitive
customer data through those two without an agreed policy.** The DeepSeek, Qwen, Kimi, and Gemini
routes report no provider retention.

```console
curl http://alucard.tailf117a1.ts.net:28080/v1/models
omp --model alucard-requesty/alibaba/qwen3.7-plus
opencode run -m alucard-requesty/deepinfra/deepseek-v4-flash-0731 "your task"
```

## Hermes Desktop

The preferred client for a customer-facing demo. Install the official application, then
**Settings → Gateway → Remote gateway**:

- Remote URL: `https://alucard.tailf117a1.ts.net:29119`
- Username: `demo`
- Password: from the company password manager

Tailscale must stay connected. Never install our model credential on a client machine — the
Requesty key never leaves Alucard.

## Boundaries worth knowing before a customer asks

- Hermes has no web search or browser, and cannot leave its workspace and `/org`.
- Dangerous terminal commands prompt for approval; ordinary reads and writes inside its own
  tree do not.
- The agent API and dashboard listen on loopback only and are reachable exclusively over
  Tailscale.
- n8n Community Edition is a single owner-managed automation plane. It supports multiple login
  users but not per-project sharing or RBAC, so it is not a tenant boundary.
- Model calls to the Claude and OpenAI routes leave our infrastructure and are retained by the
  provider for 30 days.

## Known gaps right now

- **Your Telegram ID is not in the allowlist yet.** Send it to Vincenzo.
- **The Mullvad subscription has expired**, so the VPN tunnel is down and qBittorrent will not
  start. Nothing else is affected; this is deliberate fail-closed behaviour, not a bug.

## Troubleshooting

```console
tailscale status
curl --fail http://alucard.tailf117a1.ts.net:28080/health
ssh alucard ai-stack-health
```

- Alucard missing or offline in `tailscale status` → tailnet access problem, not an app problem.
- Health check passes but a UI rejects login → you need an account for that application.
- One application broken, everything else fine → report the component, the time, and the error.
  Never send screenshots containing prompts, customer data, tokens, or credentials.
