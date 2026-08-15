# Dracula handoff — build the local AI machine

Goal: turn `dracula` into a **fully local, always-on AI workstation** — llama-server on the
RTX 3090, local coding agents, n8n for agentic workflows, and **a measurement layer good
enough to decide what's worth paying for later**. No remote APIs, no dependency on
`alucard`. Written 2026-08-08.

Hand this whole file to Claude Code on dracula. Read **Purpose**, **Decisions**, and **What
breaks first** before writing any Nix — they exist so you don't relitigate settled questions
or walk into known traps.

---

## ⚠️ STATUS: Both stacks active; private access, authenticated Hermes, and CrowdSec verified

When this runs, record corrections at the bottom under **Post-execution corrections**,
following the `MAC-HANDOFF.md` convention. This file was written by a session that inspected
the repo but built nothing — assume some details are wrong.

---

## Purpose (read this first — it changes what "done" means)

This is **a prototype, not the end state.** It is a deliberate learning run before scaling
to a small-business backbone for bereit consulting, which *will* use APIs once it's clear
what works and what adds value. bereit builds AI workflows for clients, so in-house
experience with this stack is itself the return on the effort.

Three consequences that should shape every decision:

1. **The measurement layer is a deliverable, not instrumentation.** A prototype that
   doesn't produce data is a wasted prototype. If you have to choose between shipping
   another service and shipping the ability to measure the ones that exist, measure.
2. **Log everything from day one.** The evaluation task-set will be *harvested from real
   traffic*, not invented. Retrofitting logging after a month of use throws away exactly
   the data that would have made the eval meaningful. This is the single highest-leverage
   decision in the build and it costs almost nothing at Phase 0.
3. **Write down what surprised you.** The corrections section at the bottom, and eval
   results, are the actual work product. Treat post-mortems as output.

---

## Target architecture (the endgame — build toward this)

Every phase below is a horizontal slice of this stack. Nothing here is speculative except
where marked *future*.

```text
              operator interfaces
           CLI  ·  Wirken channels
                      │
   ╔══════════════════▼═══════════════════════════╗
   ║  Wirken — gateway, approvals, audit, creds    ║  Phase 5
   ╚══════════════════╤═══════════════════════════╝
                      │
      ┌───────────────┼────────────────────┐
      ▼               ▼                    ▼
    n8n            Hermes          OMP / opencode
  workflows     agent worker        coding agents
   Phase 3        Phase 4             Phase 1
      │               │                    │
      └───────────────┼────────────────────┘
                      ▼
             tools & integrations
    filesystem · ~/org · mail · MCP servers
    (Notion / Linear / Paperless — future)
                      │
   ╔══════════════════▼═══════════════════════════╗
   ║  model ingress — ONE stable address          ║  Phase 1
   ║  routing · per-caller token accounting       ║
   ╚═════════╤═══════════════════════╤════════════╝
             ▼                       ▼
      llama-server              remote APIs
   RTX 3090 · Qwen3.6-27B    (when eval justifies)
        Phase 0                  future

   measurement (Phase 2) taps the ingress:
   request logs → eval harness → model comparison → the API decision
```

Two structural properties worth stating, because they're what make the rest work:

- **Everything speaks OpenAI-compatible through one address.** Clients are configured once,
  ever. Swapping models, adding a remote provider, or inserting a proxy are all config
  changes behind the ingress. This is what makes model comparison cheap.
- **There is no universal agent wrapper.** Governance only exists where the selected runtime
  actually mediates a tool or model call. Independent workers remain bypasses until they
  use that boundary; observability must therefore cover every runtime separately.

---

## Decisions (settled — do not relitigate)

**Prefer maintained upstream containers and minimal glue.** Use an official OCI image and
its supported Compose/container configuration when one exists. Application containers
follow upstream's rolling `latest` tag and are refreshed by `container-update.timer`;
`containers-update` triggers the same operation immediately. Keep Nix responsible for
lifecycle, state mounts, secrets, networking, health, and the update schedule. Do not create
and maintain an unofficial image merely to make deployment styles look uniform. If upstream
publishes only a signed static binary, record the exception or blocker explicitly rather
than recreating its release engineering locally.

The n8n readiness probe must tolerate the interval where `docker run --pull=always` is still
downloading and has not created a container object. The main `docker run` process is
authoritative during that interval; only an existing stopped container or the ten-minute
start deadline is a readiness failure. Media Compose pulls receive a thirty-minute start
deadline for the same reason.

**Full local on dracula.** Dracula remains the local-model comparison machine. Alucard is
now the planned business-demo machine: it will inherit the same clients, workers,
governance, and observability stack while using access-limited Requesty API keys and cloud
models instead of local inference. Do not copy Dracula's local-GPU assumptions into the
shared profile, and do not put Requesty credentials in the Nix store.

**Why local, and it is not cost.** The driver is *marginal cost of zero*. Paid-per-request
inference makes every call a decision, and the stated pattern is that Vincenzo simply won't
do things he'd have to pay for per invocation. Hardware is bought; the machine runs anyway.
Optimize for **"how many experiments is he willing to run."** A prior session ran the
numbers (local coding ≈ €10/mo marginal electricity vs ≈ $53/mo on a frontier API) and they
are basically irrelevant next to the behavioral argument. Do not re-derive them to argue
for APIs.

**Out of scope, deliberately:**
- **Paperless** — its native IMAP mail rules and checksum dedupe already cover document
  ingestion. Vincenzo will do this properly later, separately.
- **Notion / Linear** — do not exist yet. Planned for when the startup runs. Build no
  integrations now, but the tool layer must make adding them a config change (Phase 4).
- **Customer-facing exposure** — Alucard's AI profile is now enabled as a loopback-only
  business demo. Authenticated public TLS, customer identities, retention/redaction policy,
  and tested restore remain separate production-readiness work.

**Wirken and Hermes are IN scope** (Phases 4 and 5). An earlier draft of this document cut
them on YAGNI grounds — "nothing here needs a gateway yet." **That reasoning was wrong for
this project** and is recorded here so it isn't repeated: YAGNI minimizes operational
surface in a production system, but this is a deliberate learning prototype whose purpose is
in-house experience that bereit can sell. Having *operated* an agent gateway with approval
gates and an audit trail is the deliverable. Clients ask about governance, not about whether
mail got triaged.

They come late in the sequence for a reason — a gateway with nothing behind it teaches
nothing, and an agent with no tools has nothing to be autonomous about — but "late" is not
"cut". Do not drop them for scope reasons without asking.

**⚠️ Reversal: a routing/ingress layer is now IN scope.** An earlier session called
LiteLLM YAGNI. That was correct when there was one backend and no API keys. It is wrong
now: the explicit requirement is comparing multiple models and accounting for local usage
against what an API would have cost. That requires a single stable ingress. See
**Measurement** below. Recorded here so the reversal isn't mistaken for drift.

**The action space today is `~/org`, not SaaS.** Vincenzo already has an org-roam workflow.
When mail ingestion lands, the useful output is org entries / roam nodes.

**The coding harnesses are oh-my-pi (OMP) and opencode, compared deliberately.** Implement
both in Phase 1, not Phase 0. [OMP](https://github.com/can1357/oh-my-pi) is a Pi fork with a
substantially richer coding harness: hash-anchored edits, LSP/DAP integration, persistent
code execution, subagents, and explicit custom OpenAI-compatible providers.
[opencode](https://opencode.ai/docs/) is the second real daily-use harness and the
comparison arm. Package pinned versions of both with Nix; do not use OMP's curl installer
or either tool's autoupdater as machine configuration. Stock Pi is not part of the initial
build.

This choice sharpens the measurement requirement. The write-up [The Right Harness Is All
You Need](https://hkinsley.com/reflections/right-harness-is-all-you-need) reports a large,
model-dependent harness effect on Terminal-Bench v2.1: OMP moved DeepSeek-V4-Flash 0731
from 44/89 to 64/89 solved tasks, but moved the tested GLM-5.2 quant only from 61/89 to
65/89, while using more turns, time, and tokens. That is evidence that **model × harness is
an interaction**, not evidence that OMP automatically makes Qwen better for this repo.
During model comparisons, pin the selected harness version, prompts, enabled tools, role
routing, and configuration. The OMP-vs-opencode comparison must hold the model constant and
report total task tokens/time, not just one-call generation speed. Because tool surfaces
are the thing being compared, do not pretend they can be made identical; instead hold the
task, starting worktree, permissions, model, context budget, and success oracle constant,
and record each harness's native tool/prompt configuration.

**Agents vs. workflows — a measurement frame, not a filter.** Vincenzo observed he keeps
inventing *agentic workflows* but few real *agent* use cases. The distinction is real:

- **Workflow** — you can draw the flowchart; branching is enumerable. → n8n + one
  structured-output LLM call. Debuggable, replayable, cheap.
- **Agent** — branching factor too high to enumerate, and wrong steps are cheap to undo.
  → agent loop with tools.

Most business automation is the first kind; coding is genuinely the second. **Use this to
decide what to measure in each phase, not to decide what to skip.** Phase 3 builds the
workflow case and Phase 4 builds the agent case *deliberately*, so the two can be compared
on the same task with real data. The productive version of Vincenzo's observation is a
hypothesis to test — "agency buys less than it costs for my back-office work" — and the
build should be able to confirm or refute it. You cannot learn to recognize agent-shaped
problems without having run an agent; skipping Phase 4 would make the observation
self-fulfilling.

---

## Facts verified 2026-08-08 (trust these, re-check if the tree moved)

- `nixpkgs.config.cudaSupport = true` is **already set globally** on dracula
  (`hosts/dracula/default.nix:24`). `pkgs.llama-cpp` is therefore CUDA-enabled with no
  override needed. Do not add a redundant `cudaSupport` override.
- CUDA binary caches are configured: `cuda-maintainers.cachix.org`
  (`hosts/dracula/default.nix`) and `cache.nixos-cuda.org` (`flake.nix:11`). A CUDA
  llama-cpp build should come from cache. **Verify before starting** — if it wants to
  compile from source that's hours, and you should say so rather than proceed.
- `pkgs.llama-cpp` resolves to `llama-cpp-10273`.
- `modules/gaming.nix` is imported by dracula (`hosts/dracula/default.nix:12`) — Steam,
  Proton, Wine. See the VRAM conflict below.
- sops-nix is in use: `secrets/dmbs.yaml`, `secrets/secrets.nix`, `.sops.yaml`. Secrets
  land in `/run/secrets/*`. Use this. **Never** create a plaintext secrets directory.
- Docker is enabled (`hosts/dracula/services.nix:28`) and the user is in the `docker` group
  (`hosts/dracula/default.nix:43`). Docker group is root-equivalent — so an agent running
  as this user is *not* sandboxed, whatever else you configure. Don't claim otherwise.
- `nixos-rebuild switch` is **permitted** as of 2026-08-08. Build, then switch, then paste
  real output. Announce before switching; don't ask permission.

### Hardware budget

24 GB VRAM, 48 GB system RAM.

**The 48 GB matters more than an earlier session claimed.** For a *dense* model, CPU
offload collapses throughput and you should keep everything on GPU. But for **MoE** models,
llama.cpp's `--n-cpu-moe` / `-ot` expert offload pushes rarely-hit expert tensors to system
RAM while keeping attention on the GPU — which is what makes a much larger MoE runnable at
usable speed. Given "compare dense vs MoE" is an explicit goal, this is the mechanism that
makes the comparison interesting rather than trivially VRAM-bound.

### Qwen3.6-27B specifics (the Phase 0 model)

Hybrid attention — 64 layers mixing gated attention (24 Q / 4 KV heads, head_dim 256) with
linear attention (48 V / 16 QK, head_dim 128). Linear-attention layers carry **constant**
state, so the KV cache does **not** grow the way a standard GQA 27B would. That's how a 27B
claims 262k native context.

Do not assume standard GQA arithmetic. **Derive the real full-vs-linear layer ratio from the
model's `config.json` and show the VRAM arithmetic before choosing `--ctx-size`.**

GGUF sizes ([unsloth/Qwen3.6-27B-GGUF](https://huggingface.co/unsloth/Qwen3.6-27B-GGUF)):

| Quant | Size | VRAM left of 24GB |
|---|---|---|
| UD-Q3_K_XL | 14.5 GB | 9.5 GB |
| IQ4_XS | 15.4 GB | 8.6 GB |
| Q4_K_M | 16.8 GB | 7.2 GB |
| UD-Q4_K_XL | 17.6 GB | 6.4 GB |
| Q5_K_M | 19.5 GB | 4.5 GB — too tight |

**Start with Q4_K_M.** Quality/headroom sweet spot for coding. If measured context proves
too tight, drop to IQ4_XS and re-measure rather than guessing.

---

## Measurement (the part that makes this prototype worth running)

Vincenzo wants to answer four questions. They need different machinery — don't conflate
them.

| Question | Needs |
|---|---|
| How much do I actually use, on what? | request logging with caller attribution |
| What would this have cost on an API? | token counts × a versioned price table |
| Is model X better than model Y for *my* work? | eval harness over real tasks |
| Dense vs MoE? | the above, with quantization held constant |

### Ingress: one address, forever

Every client — coding agents, n8n, ad-hoc curl — points at **one** OpenAI-compatible
endpoint for the life of this project. Models change behind it; clients never get
reconfigured. This is what makes model comparison a config change instead of a migration,
and it's why the ingress goes in at Phase 1, before real usage starts.

Requirements for whatever fills that slot:
- OpenAI-compatible, so every client works unmodified
- per-request log: timestamp, caller, model, prompt tokens, completion tokens, latency,
  TTFT — and the **full prompt/response payloads** (see Purpose #2)
- swap the backing model without touching clients
- able to route to a remote API later without touching clients
- exportable usage data (JSONL or a queryable DB — not a dashboard-only black box)

**Candidates — evaluate and report before installing anything:**
- **llama-swap** — on-demand model load/unload keyed by model name. Serves multi-model
  comparison directly: swapping models becomes a request parameter rather than a service
  restart, which matters a lot when running the same eval across several models.
  (Its idle-unload feature is *not* a selling point here — `ai-stack-stop` covers VRAM
  release. Judge it on comparison ergonomics and logging only.)
- **LiteLLM proxy** — richer accounting and native multi-provider support; the better
  answer once APIs enter the picture. Heavier: spend tracking generally wants Postgres.
- **A thin custom logging proxy** — ~100 lines, exactly the log schema wanted, no
  dependencies. Viable, and honest for a prototype.

The selected local path is the thin logging proxy at the permanent client-facing address,
with llama-swap behind it for model residency and routing. LiteLLM remains deferred until
remote APIs require its provider accounting and credential surface. Do not add LiteLLM on
top merely to duplicate working local behavior.

### Metrics

llama-server exposes Prometheus metrics via `--metrics`. Enable it at Phase 0 — it costs a
flag. `services.prometheus` and `services.grafana` are native NixOS modules if you want
retention and graphs, but **do not build a dashboard before there's data worth graphing.**
Note that llama-server metrics have no caller attribution — that's the ingress log's job.

### Cost comparison

Token counts × price table = "this would have cost €X". Keep the price table as **versioned
data, not code** — it goes stale monthly. Include the cache-hit rate assumption explicitly,
since cached input is 50–100× cheaper than a miss and it dominates the arithmetic for
agentic coding.

### Evaluation — where you will fool yourself

Be adversarial about this section. It's the easiest place in the build to generate
convincing nonsense.

1. **Public benchmarks are near-useless here.** MMLU/HumanEval numbers are already
   published, contaminated, and tell you nothing about whether a model can edit *this*
   NixOS config. Don't run lm-eval-harness. If you want a framework, **promptfoo**
   (YAML-defined cases against OpenAI-compatible endpoints, side-by-side comparison
   tables) or **inspect-ai** (more rigorous) fit better.
2. **The eval set comes from real traffic.** Harvest actual requests from the ingress log
   into a task file. Invented tasks measure your imagination, not the workload.
3. **This repo has a genuine automated oracle**: `nixos-rebuild build --flake .#dracula`
   exits non-zero if the config is broken. That's a real pass/fail grader for a whole
   class of coding tasks — most people evaluating coding models don't have one. Use it.
4. **The dense-vs-MoE confound**: the two won't fit the same way in 24 GB, so the naive
   comparison silently varies quantization *and* architecture at once. Either hold quant
   constant and accept a size difference, or hold VRAM constant and accept a quant
   difference — but state which, because otherwise the result means nothing.
5. **Measure speed and quality together.** tok/s, TTFT, and task success. For agentic
   loops doing 50 calls, a model that's 3× faster at 90% quality may win outright. A
   quality-only comparison will pick the wrong model for this workload.
6. **Provider-agnostic from the start.** If the harness targets an OpenAI-compatible
   endpoint, the same eval runs against an API the day a key exists — and *that* is the
   local-vs-API comparison Vincenzo actually wants. Don't couple it to llama-server.

---

## Portability — this must move to a rented inference server later

Stated goal: everything in the repo so the stack moves to a proper rented AI inference box
without a rebuild-from-scratch. Correct instinct, but "everything in repo" needs a line
through it, because two different things are being conflated.

**Config → repo. State → never.**

| In repo | Never in repo |
|---|---|
| module definitions, service units | GGUF weights (~17GB; `.git` is already 160M) |
| `services.localLlama` option values per host | raw request/response logs |
| n8n workflows, exported as JSON | n8n SQLite DB, Prometheus TSDB |
| eval task sets (curated) and eval *results* | anything under `/var/lib/llama` |
| API price tables | |
| sops-encrypted secrets (already correct) | decrypted secrets |

The raw logs are the sharp edge. They will contain forwarded mail and, later, bereit client
material — and the remote is `git@github.com:DerDoni/nixos-config.git`. Client data does not
go to GitHub, private or not. `.gitignore` currently catches `*.log` only; JSONL request
logs would sail straight past it. **Add explicit ignores at Phase 0**, before the first log
line is written.

**What actually makes this portable is not file location — it's that the module isn't
hardcoded to dracula.** A `modules/llama.nix` that bakes in 3090 assumptions (24GB budget,
Q4_K_M, `--parallel 2`, coexisting with Steam) has to be rewritten for an H100 box. Write
it as a **NixOS module with a real options block**:

```nix
services.localLlama = {
  enable = true;
  model = { repo = "unsloth/Qwen3.6-27B-GGUF"; file = "...Q4_K_M.gguf"; sha256 = "..."; };
  contextSize = 65536;
  parallelSlots = 2;
  # ...
};
```

Then a future `hosts/inference-box/` sets different values and imports the same module.
That is the portability lever. Everything else is filing.

Two consequences worth internalizing:

- **Don't plan to migrate the weights.** Pin repo + revision + filename + hash in the
  module and re-download on the new host. Reproducible beats copying 17GB, and it's less
  work.
- **n8n workflows are config wearing a state costume.** They live in SQLite at runtime, but
  they're authored artifacts. Export them to `n8n/workflows/*.json` in the repo with a
  script, and treat the repo as source of truth. Same for eval task sets: harvested from
  logs, curated, committed. Eval *results* are small and are the prototype's actual output
  — commit those too.

Secrets already work correctly for this: sops-nix keeps them encrypted in-repo, and a new
host just needs its age key added to `.sops.yaml`. No change needed.

**One economic note for when that rental happens.** A rented A100/H100-class box is a large
*fixed* cost (roughly €500–1500/month). The zero-marginal-cost property survives — which is
the property that actually drives this project — but the baseline moves enough that the
"local vs API" comparison becomes live again rather than academic. The eval data this
prototype produces is precisely what should decide it. That's the whole point of running
the prototype; don't let the measurement layer slip.

---

## Lifecycle: one off/on switch, and it IS the recovery path

**Architect for this from Phase 0 — it is a cross-cutting constraint, not a convenience.**

The only gaming-related requirement is the ability to turn the entire AI stack off and back
on. No VRAM arbiter, no game detection, no idle-unload heuristics. Do not build those.

The important part is the second half of the requirement: **stopping and restarting the
stack must use the exact same path as recovering after the machine has been off for days.**
One mechanism, not two.

This is [crash-only design](https://web.stanford.edu/~candea/papers/crashonly/crashonly.html)
(Candea & Fox, HotOS 2003). The usual architecture has a graceful-shutdown path and a
separate recovery path, where recovery is only exercised during a real outage — which is
exactly when you discover it doesn't work. Collapsing them means every stop/start
*is* a recovery drill, run several times a week for free.

### What this requires

1. **A single `ai-stack.target`.** Every service is `PartOf=` it. `systemctl stop
   ai-stack.target` takes the whole thing down; `start` brings it back; boot uses the same
   target. The dependency graph is declared once and used by both boot and manual start.
   Two convenience wrappers — `ai-stack-start` / `ai-stack-stop` — and nothing else. Do not
   add per-service aliases; they create a second control surface that drifts.

2. **Stop means kill.** No service may depend on graceful shutdown for correctness. Test
   with `systemctl kill -s KILL`, not `systemctl stop` — if the stack only survives a
   polite shutdown, it will not survive a power cut, and you've built the two-path system
   this section exists to prevent.

3. **No manual post-boot steps, ever.** Anything requiring "run this once after boot" is a
   bug, not a runbook entry. That includes model loading, DB migrations, and cache warming.

4. **No startup ordering dependencies.** `After=` is not readiness. Rather than gating n8n
   on the inference endpoint being healthy, make each service **retry independently** when
   its dependency is absent. That's both more crash-only and exactly the behaviour needed
   on a cold boot, where startup order is not guaranteed anyway.

5. **NVIDIA + suspend is a known hazard.** A CUDA context does not reliably survive
   suspend/resume. Do not try to make it. Add a unit `After=suspend.target` that restarts
   `ai-stack.target` unconditionally — under crash-only rules you restart rather than hope
   state survived. (This is separate from the no-suspend requirement below: the box
   shouldn't suspend on idle, but it must recover correctly if it ever does.)

6. **SQLite needs WAL.** When n8n arrives (Phase 3), its DB must be in WAL mode or a
   `SIGKILL` mid-write can corrupt it. That would violate rule 2 silently — the stack comes
   back up and the workflows are gone.

7. **VRAM must actually return.** `ai-stack-stop` has to leave `nvidia-smi` showing no
   compute processes. A leaked context or zombie holding VRAM means gaming still breaks and
   the switch is a lie. Verify this explicitly, not by inference.

### The "off for days" case specifically

Coming back after a week differs from a 10-minute gaming stop in ways that will bite:

- **Mail backlog burst.** n8n's first poll after a week finds hundreds of messages at once.
  Decide the batching/rate-limit behaviour deliberately rather than discovering it.
- **systemd timers with `Persistent = true`** fire all missed runs on boot — a thundering
  herd of catch-up work. Vincenzo already uses this pattern (`hm-modules/email.nix:103`).
  Decide per timer whether catch-up is wanted; for most agent work it isn't.
- **Log rotation** catching up on a week of gap.
- **Clock/NTP resync** before anything time-sensitive runs.

### Consequence for the Phase 1 ingress choice

llama-swap's idle-unload was listed above partly as a VRAM-management win. That argument is
now **void** — a clean stack-level off switch covers it. Judge the ingress candidates on
model comparison and usage accounting only.

---

## What breaks first

1. **VRAM contention with gaming.** A resident model holds ~16.8 GB of 24 GB; modern games
   at 4K want 10–16 GB. These cannot coexist. Solved by `ai-stack-stop` — see "Lifecycle".
   The failure mode to actually watch for is a *stopped* unit that hasn't released VRAM;
   verify with `nvidia-smi`, not with `systemctl status`.

2. **The desktop suspending kills the service.** "Always-on" is a new requirement this box
   has never had. `powerManagement.enable = true` is set
   (`hosts/dracula/hardware.nix:73`) and nothing inhibits idle suspend. Check
   `systemd-logind` / `systemd.sleep` and caelestia's idle behavior (see the
   `project_caelestia_idle` memory), then explicitly decide: the box does not suspend.
   Screen blank and lock are fine.

3. **`--parallel N` divides the context.** In llama-server `-c` is the **total** KV budget
   split across slots — `--parallel 2` with `-c 65536` gives each request 32k, not 65k.
   Most likely silent misconfiguration in the build. State the per-slot number in a
   comment.

4. **One model, two workloads.** Coding wants long context and quality; workflow extraction
   wants low latency. You cannot run two models in 24 GB simultaneously (this is llama-swap's
   other argument). Tune for coding; let the workflow step be slower.

5. **Logging volume.** Full prompt/response capture on an agentic coding workload is
   gigabytes per week. Plan rotation and retention at Phase 0 rather than discovering it
   when `/var` fills. Note also that mail content will eventually land in these logs —
   keep them out of any repo and off Syncthing.

6. **Reboots.** Kernel updates happen; every service must come back unattended. Verify with
   an actual reboot, not by reading the unit file.

7. **`agent@istbereit.de`** — Vincenzo is creating it. Not a blocker for Phases 0–2.

---

## Phases

Each phase ends in a working, verified thing that survives a reboot and an `ai-stack-stop` /
`ai-stack-start` cycle. Construction may overlap observation: the Phase 1 OMP/opencode week
continues while multi-model switching and the Phase 2 evaluation machinery are built. Only
the final model/harness conclusions remain gated on enough real traffic; do not delay stack
construction merely to let a calendar interval elapse.

Every phase attaches its services to `ai-stack.target`, keeps config in the repo and state
out of it, and logs through the ingress. Those are not per-phase decisions.

---

### Phase 0 — inference + instrumentation

**Goal.** A local OpenAI-compatible endpoint on the 3090, instrumented from the first
request, with the lifecycle switch in place.

**Build.** `modules/llama.nix` as a parameterized module (`services.localLlama.*`);
llama-server with Qwen3.6-27B Q4_K_M; `--metrics`; full request/response logging with
rotation; `ai-stack.target` + wrappers; suspend-resume restart unit; no-idle-suspend.

**Teaches.** Real VRAM/context arithmetic on hybrid-attention models; what tok/s and TTFT
this hardware actually delivers; log volume under real load.

**Done when.** The full verification list in the prompt below passes with pasted output,
including `SIGKILL` recovery and a cold reboot.

---

### Phase 1 — model ingress + coding agents

**Goal.** One stable address every client uses forever, and two attributable coding
harnesses behind it.

**Build.** Choose the ingress against the requirements in **Measurement** — report the
comparison and the trade-off *before* installing. Then install and configure
[oh-my-pi](https://github.com/can1357/oh-my-pi) and [opencode](https://opencode.ai/docs/)
as coding harnesses (pure client configuration, no persistent services):

- Package pinned OMP and opencode releases through Nix. Do not pipe network installers into
  a shell; disable application-managed updates.
- Manage `~/.omp/agent/models.yml` and `config.yml` declaratively. Define one custom
  `openai-completions` provider whose `baseUrl` is the stable ingress `/v1` address, whose
  model ID is the stable llama `--alias`, and whose context window reflects the **32,768
  token per-slot** limit rather than the server's misleading total `-c 65536`.
- Point every OMP model role at the local provider initially, or disable unused auxiliary
  roles. Do not allow an implicit cloud fallback, OAuth provider, or bundled remote model
  to violate the full-local decision.
- Manage opencode's global `~/.config/opencode/opencode.json` declaratively. Define one
  provider using `@ai-sdk/openai-compatible` and the same ingress `/v1` address; point both
  `model` and `small_model` at the local alias so lightweight tasks cannot silently select
  a remote model. Set `enabled_providers` to only that provider, `share = "disabled"`, and
  `autoupdate = false`.
- Establish separate caller attribution before the first real sessions. Prefer custom
  headers if the pinned clients support them; otherwise give each harness a dedicated
  ingress credential mapping to callers `omp` and `opencode`. Treat two correctly
  attributed log records as an ingress acceptance test—the Phase 2 task set depends on it.
- Record each pinned client version and a hash of its effective harness configuration
  alongside every harvested eval task. Start with deliberate tool and permission sets;
  adding LSP, debugger, browser, subagents, MCP, or persistent code execution changes the
  harness and must be recorded as such.
- Set an explicit, equivalent high-level approval boundary in both clients instead of
  comparing OMP's and opencode's defaults. Record approval prompts and operator
  interventions as friction; they are part of the harness result.
- Use both for real work, but do not infer a winner from different tasks. For a paired
  comparison, replay the same harvested task from the same clean git worktree against the
  same model and oracle. Randomize execution order and report prompt-cache hits, since the
  second run may otherwise inherit a speed advantage.

Do not install stock Pi in the initial Phase 1 implementation. OMP inherits Pi's core;
opencode is the independent comparison harness.

**Why ingress before agents.** Real usage starts here, and the eval task-set is harvested
from real traffic. Point clients at llama-server directly and you either lose the first
weeks of data or re-point every client later.

**Teaches.** Whether a local 27B is actually sufficient for day-to-day agentic coding, and
how much the OMP-vs-opencode harness choice changes success, speed, token use, retries, and
operator friction. Model sufficiency remains the single most consequential question in the
prototype because it decides whether the rented-inference-server plan is worth pursuing.

**Done when.** A week of real coding has run through it and the logs contain attributable
per-caller token counts for both harnesses, both effective versions/configs are recorded,
and no model request silently leaves dracula.

**Implementation checkpoint (2026-08-08).** The Phase 1 starting point is active, but the
one-week done criterion is deliberately still open:

- The Phase 0 thin logging proxy remains the stable ingress at `127.0.0.1:8080`. It won on
  exact full-payload JSONL, TTFT, caller attribution, and zero additional runtime state.
  Pinned llama-swap `v247` now sits behind it at `127.0.0.1:18080`, launching the selected
  llama-server on ports beginning at 18100. LiteLLM is deferred until remote providers,
  budgets, or real credential management enter scope. Clients remain on port 8080.
- OMP `17.2.11` and opencode `1.18.13` are installed declaratively from
  `hm-modules/ai-clients.nix`. OMP is a fixed-output release package in `packages/omp.nix`;
  opencode is pinned by the flake's nixpkgs lock. Both autoupdate paths are disabled or
  bypassed.
- OMP enables both `dracula-local/qwen3.6-27b-local` and
  `dracula-local/qwen3.6-35b-a3b`, while every automatic role still defaults to the dense
  model; its implicit `llama.cpp` discovery provider is disabled. Opencode's only enabled
  provider is `dracula-local`, exposes both aliases, and keeps both `model` and
  `small_model` on the dense default. Both target `http://127.0.0.1:8080/v1`.
- Both use an explicit read-only-without-prompt boundary: OMP `always-ask`; opencode asks by
  default while allowing only read/search/LSP/question/skill operations explicitly. Tool
  calls that mutate the workspace or run shell commands therefore require approval.
- The acceptance prompt produced successful attributed records with `X-AI-Caller: omp` and
  `X-AI-Caller: opencode`. Opencode also launched a concurrent background request, which is
  harness overhead rather than noise to discard. See the Phase 1 corrections below for the
  versions, hashes, and smoke-test numbers. These trivial calls validate plumbing only;
  they do not select a harness winner.
- `ai-usage-summary --caller omp --caller opencode` reports seven-day per-harness request,
  error, incomplete-stream, missing-usage, token, latency, and TTFT aggregates without
  printing request or response content. Use `--since all`, an ISO timestamp, or `--json`
  when harvesting the trial.

---

### Phase 2 — evaluation harness

**Goal.** Turn accumulated traffic into an answer about which model to run.

**Build.** The model-switching substrate can be built while Phase 1 traffic accumulates.
Harvest and curate a task set from Phase 1 logs into `eval/tasks/` in the repo.
Graders: `nixos-rebuild build` exit code for config tasks, schema validity for extraction
tasks, human judgment where nothing automatable exists — say which is which. Provider-
agnostic (targets an OpenAI-compatible endpoint, so it runs against an API unchanged).
Results committed to the repo. The selected first MoE is Qwen3.6-35B-A3B UD-Q3_K_M,
fully GPU-offloaded without the optional vision projector. Both it and the dense 27B use a
65,536-token total context over two slots: 32,768 tokens per request.

Phase 2 has two orthogonal comparisons. First, hold Qwen3.6-27B, quantization, task,
starting worktree, permissions, and oracle constant while comparing OMP with opencode.
Second, hold one chosen harness version/config constant for dense-vs-MoE. If the curated
task set is small enough, a 2×2 model × harness run is better because it exposes the
interaction directly; otherwise state which harness was used for the model comparison.
Report success, elapsed time, total tokens across the complete agent loop, tool retries,
cache hits, and surprising actions. Extra test-time compute is part of a harness's cost,
not noise to normalize away.

**Read the "Evaluation — where you will fool yourself" section before designing this.** The
dense-vs-MoE quantization confound is the trap that will silently invalidate the result.

Run two model comparisons. The practical 3090 comparison uses the best viable build of
each architecture: dense 27B Q4_K_M versus MoE 35B-A3B UD-Q3_K_M initially, with
UD-IQ4_XS as the next fit test if Q3 leaves enough headroom. The controlled comparison uses
comparable quantization and context settings to separate architecture gains from
quantization gains. Do not start with the 22.1 GB UD-Q4_K_M MoE or load its roughly 0.9 GB
vision projector; either would consume the headroom needed for KV/runtime/desktop use.

**Teaches.** Whether MoE-with-offload beats dense-on-GPU for this hardware; what quality is
actually lost at Q4; how to run an eval that isn't self-deception. This phase produces the
data for the local-vs-API decision.

**Done when.** A committed results table compares at least two models on a task set drawn
from real work with speed and quality reported together, plus a paired OMP-vs-opencode
table over the same starting worktrees and Qwen model.

---

### Phase 3 — n8n + mail ingestion (the workflow case)

**Goal.** The deterministic-pipeline half of the agents-vs-workflows experiment.

**Build.** Use the rolling official n8n image plus the matching official external
`n8nio/runners` sidecar. n8n 2.32.6 warns that running outside a container is deprecated,
and its current documentation recommends Docker for most self-hosting and external task
runners for production. The previous claim that the native NixOS module was categorically
better is obsolete. Keep orchestration declarative through `virtualisation.oci-containers`
and systemd; do not introduce an unmanaged Compose directory. SQLite remains in WAL mode
(see Lifecycle rule 6). Encryption and runner keys come from sops and never enter the Nix
store. Bind the editor/metrics port to localhost, put n8n and its runner on a private Docker
bridge, and expose the permanent AI ingress to that bridge through a container-only systemd
socket proxy. Workflows are exported to `n8n/workflows/*.json` in the repo as source of
truth. First workflow: mail forwarded to `agent@istbereit.de` → structured extraction
through the ingress → org entry in `~/org`.

**Workflow scope.** The reusable n8n platform is part of this phase. The exact business
workflow, including mail ingestion and its credentials, is intentionally deferred to a
separate workflow-building session; it is not an infrastructure blocker.

**Watch for.** The backlog burst on first poll after downtime (see Lifecycle), and timer
`Persistent=` catch-up behaviour.

**Teaches.** How much of "agentic" mail handling is really deterministic plumbing plus one
extraction call. Establishes the baseline that Phase 4 must beat.

**Platform done when.** n8n, its external runners, persistence, workflow provisioning,
restricted org output, local-model ingress, metrics, and lifecycle recovery pass live
acceptance. A specific mail workflow gets its own later acceptance criterion: mail lands
in `~/org` unattended and survives a stack restart and a week of accumulated mail.

---

### Phase 4 — Hermes (the agent case)

**Goal.** Run a real autonomous agent, deliberately, and find out where agency earns its
cost. This is a designed experiment, not an installation.

**Build.** Hermes as a persistent worker attached to `ai-stack.target`, using the ingress
for inference. Isolated workspace under `/var/lib` with git for rollback. Tool access via
MCP where possible — the tool layer is the reusable part and should make adding Notion,
Linear, or a Paperless client later a config change rather than a code change.

**Implementation checkpoint (2026-08-09).** The infrastructure slice is active. The pinned
official Hermes Agent release, persistent gateway, loopback dashboard, Git-backed workspace,
local inference attribution, and host confinement passed live acceptance. The first real
agent-vs-workflow experiment remains pending because the corresponding production n8n
business workflow was deliberately deferred to its own session; do not confuse a successful
smoke test with the comparison this phase exists to produce. See **Phase 4 Hermes deployment
checkpoint** under Post-execution corrections for measured evidence and approval semantics.

**Scope the first experiment.** Point it at a sandboxed workspace, *not* at `~/org` or the
nixos-config checkout, until its behaviour is understood. Give it a task where the
deterministic version already exists (the Phase 3 mail workflow is ideal) so the comparison
is direct: same task, agent vs workflow, measured on tokens, latency, success rate, and
how often it does something surprising.

**Teaches.** The hypothesis under test is Vincenzo's own: *agency buys less than it costs
for back-office work*. Confirm or refute it with data. Also produces the concrete
experience — "here is what an autonomous worker did unsupervised for a week" — that clients
actually ask about.

**Done when.** The agent-vs-workflow comparison is written up with numbers, and the
surprising-behaviour log is non-empty and understood.

---

### Phase 5 — Wirken (gateway, approvals, audit)

**Goal.** Put a governance layer over the workers and operate it. This is the phase with
the highest commercial transfer value for bereit.

**Build.** Wirken (https://github.com/gebruder/wirken) as an operator-facing governed
agent runtime alongside Hermes, n8n, and the coding agents: per-channel isolation,
graduated approval tiers, encrypted credential vault, and a hash-chained per-session audit
log. Use its own security model rather than wrapping it in homemade confirmation scripts.
Credentials migrate from ad-hoc sops env files into its vault where that makes sense —
decide deliberately, since sops is already working.

**Architecture correction (2026-08-09).** Upstream Wirken is not a transparent policy
proxy that can govern an independent Hermes, n8n, OMP, or OpenCode process. Its approval,
tool, credential, channel, and audit enforcement applies to agents constructed inside the
Wirken runtime. Those existing clients can still call the permanent inference ingress or
their own tools without passing through Wirken. Phase 5 therefore adds one real governed
agent path and measures it; it must not claim that the other paths are governed until they
are actually migrated to an upstream-supported Wirken runtime or connector. Do not build a
fake universal wrapper to satisfy the old diagram.

**Implementation checkpoint (updated 2026-08-15).** The module pins the latest
published signed release, Wirken v1.17.0. The
official x86_64 musl binary's Ed25519 release signature and signed SHA-256 manifest were
verified before its Nix hash was recorded. The declarative service seeds the custom local
provider and fail-closed `exec-only` sandbox, bootstraps an ingress credential into the
encrypted vault through systemd credentials, pins the sandbox container by digest, binds
WebChat to upstream's loopback-only port 18790, and attaches the gateway to
`ai-stack.target`. The audit public key is captured once into a root-owned directory outside
Wirken's data directory; a timer verifies signed chains against that anchor every six hours.
The upstream headless age-vault CLI requires a TTY and ignores its documented passphrase
environment variable in this release, so a no-transcript Expect bridge feeds the systemd
credential over a private pseudo-terminal. Acceptance tests proved both successful unlock
and wrong-passphrase failure without exposing the submitted value.

**Live checkpoint and blocker (2026-08-09).** The second activation completed and left the
gateway, vault bootstrap, rolling official Docker exec image, loopback WebChat, and external
audit anchor active. A no-tool WebChat turn returned exactly `WIRKEN_PHASE5_OK`; the
permanent ingress attributed it to caller `wirken`, model `qwen3.6-27b-local`, HTTP 200,
1,404 prompt + 42 completion = 1,446 tokens, 2,311 ms TTFT, and 3,554 ms total latency.
The first effectful test exposed an upstream defect: `AgentFactory` constructs the live
agent with the canonical session ID as its `agent_id`, while `SseApprovalGate` assumes the
field is the base agent ID and appends `/webchat/webchat-default` again. It cannot find the
registered SSE sender, logs `no live SSE stream`, and fails closed with an approval timeout.
The signed v1.17.0 source still contains the same code. This is a failed governance
acceptance test, not a configuration issue; do not patch or wrap it locally.

Source review on 2026-08-15 also confirmed that both `ask` construction paths open the audit
database with `SqliteSessionLog::open`, not `open_with_signer`. The terminal approval gate works,
but CLI events are only hash-chained and do not emit signed chain heads. This explains Alucard's
strict verifier finding a valid five-event `default` chain with no head. Do not weaken
`--require-signed`, claim those CLI events are signed, or ship a private fork to conceal the gap.

Upstream publishes signed native binaries only—its release workflow has no Dockerfile,
container artifact, or image-publish job. Creating an unofficial Wirken image would retain
the vault/TTY and Docker-socket requirements while adding image maintenance, so it is
explicitly rejected. Wirken remains a desired component; keep the current native trial for
learning and audit inspection, but do not call it the governed operator path or migrate
credentials/tools into it. A production deployment is gated on an official upstream image
and a working approval path. Do not introduce Open WebUI as a replacement. Langfuse is the
cross-runtime observability/evaluation UI and remains entirely separate from approvals.

**Credential decision.** sops remains the machine-bootstrap root for the vault passphrase
and the local inference-attribution token. Provider and connector credentials added later
belong in Wirken's encrypted vault; duplicating them in sops is unnecessary unless another
non-Wirken service also needs the same credential. The inference token is an attribution
mechanism, not authentication: the logging proxy maps a matching bearer value to caller
`wirken`, while clients capable of `X-AI-Caller` continue using their explicit identity.

**Why last.** You have to feel the problem before the solution teaches you anything. By
Phase 5 there is a real agent doing real things with real credentials, and the approval
tiers will be tuned against actual annoyance and actual near-misses rather than guesses.
If Phase 4 produces no uncomfortable moments, that is itself a finding worth recording.

**Note the honest limit.** The user is in the `docker` group and Docker group membership is
root-equivalent. Wirken's isolation is meaningful for *auditability and approval*, not for
containing a determined process on this box. Do not overclaim this to clients.

**Teaches.** What agent governance costs in daily friction, which approval tiers are worth
the interruption, and what an audit trail is actually good for — the questions clients will
ask.

**Platform done when.** The governed Wirken path reaches local inference with correct
attribution, approval and sandbox behavior are exercised, the operator-pinned audit log
verifies, and `ai-stack-stop` terminates it with the rest of the stack. The longer
experiment is done after the friction has been tuned over at least a week of real use and
each other agent path has either been migrated to real Wirken enforcement or explicitly
accepted and documented as a bypass.

---

### Beyond

Remote API providers behind the ingress once Phase 2's data justifies the spend. Notion and
Linear when the startup runs. Migration to a rented inference server — see **Portability**;
the module parameterization done in Phase 0 is what makes that a config change.

---

## The Phase 0 prompt

Paste from here down.

```markdown
Build Phase 0 of the local AI machine on dracula: llama-server on the RTX 3090 serving
Qwen3.6-27B over an OpenAI-compatible endpoint, instrumented from the start.

Read claude/DRACULA-AI-HANDOFF.md in full first — especially "Purpose", "Decisions",
"Facts verified", "Measurement", and "What breaks first". It records settled decisions and
known traps. Then read CLAUDE.md for the repo's module conventions.

## Scope

ONE deliverable: llama-server running, instrumented, verified, surviving a reboot. Do NOT
install n8n, oh-my-pi, opencode, llama-swap, LiteLLM, Wirken, or Hermes — those are later
phases.
Do not create ~/agent. Do not build a Grafana dashboard.

## Constraints

- Branch `feat/llama-server`. The tree must be clean before you start — if it isn't, stop
  and tell me.
- New module `modules/llama.nix`, imported by `hosts/dracula/default.nix`. Follow the
  opt-in pattern of `modules/nvidia.nix`.
- **Write it as a real NixOS module with an options block** (`services.localLlama.*`:
  model repo/file/hash, contextSize, parallelSlots, bind address, log paths). Hardware
  values live in `hosts/dracula/`, not in the module. This stack moves to a rented
  inference server later — see "Portability". A module hardcoded to a 3090 has to be
  rewritten; a parameterized one just gets new values.
- Pin the model by repo + revision + filename + hash so a new host reproduces it by
  download rather than by copying 17GB.
- **Add `.gitignore` entries for the log paths and `/var/lib` artifacts before writing the
  first log line.** Current `.gitignore` catches `*.log` only, and the remote is a GitHub
  repo that must never receive request payloads.
- systemd **system** service. Unprivileged (DynamicUser or a dedicated user),
  `StateDirectory`, `Restart=on-failure`. State in `/var/lib/llama` — never in the repo,
  never in $HOME.
- Model weights at `/var/lib/llama/models`. Download Q4_K_M from unsloth/Qwen3.6-27B-GGUF.
  Tell me the size before pulling ~17GB.
- Bind `127.0.0.1` only. No firewall hole — everything consuming this runs on the same box.
- `nixpkgs.config.cudaSupport = true` is already global on dracula. No redundant override.
- Secrets, if any, via existing sops-nix. No plaintext secret files.

## Before writing code, report

1. Whether `pkgs.llama-cpp` comes from the CUDA binary caches or wants to build from
   source, plus closure size. **If it wants to compile from source, STOP and tell me.**
2. The full-vs-linear attention layer ratio from the model's config.json, and the resulting
   VRAM arithmetic: weights + KV at your chosen `-c` + compute buffer, against 24GB. Show
   the numbers. `-c` is split across `--parallel` slots — state the per-slot context.
3. Whether dracula currently suspends on idle, and what you propose so it doesn't.
4. Your logging plan: what fields, what format, where, and the rotation/retention policy.
   Full prompt/response payloads are required — see Purpose #2 in the handoff. Estimate
   weekly volume under heavy agentic coding.
5. A 5-line plan.

## Must include

- `--metrics` enabled (Prometheus endpoint). Do not build a dashboard yet.
- Request logging with full payloads, rotated. This is not optional — the Phase 2 eval set
  is harvested from it.
- `--parallel 2` minimum, with `-c` sized so each slot is usable. Justify in a comment.
- `--alias` set to a stable model name clients can target.
- A health check.
- **An `ai-stack.target` with the service `PartOf=` it, plus `ai-stack-start` /
  `ai-stack-stop` wrappers.** Even with one service, establish the target now — later
  phases attach to it, and it is the single control surface. Read the "Lifecycle" section:
  stop/start must be the same path as cold-boot recovery, the service must survive
  `SIGKILL`, and there must be no manual post-boot steps.
- A unit that restarts `ai-stack.target` `After=suspend.target` — a CUDA context does not
  reliably survive resume.
- Whatever it takes to keep the box awake as always-on infrastructure.

## Verification — paste real output, not claims

`nixos-rebuild switch` is permitted. Announce before switching, then run it.

1. `nixos-rebuild build --flake .#dracula`
2. `nixos-rebuild switch --flake .#dracula`
3. `systemctl status` for the unit
4. `curl` against `/v1/chat/completions` with the actual response body
5. `curl` against `/metrics` showing real token counters
6. The request log after a few calls, proving payloads and token counts are captured
7. `nvidia-smi` showing the model resident, with the real MiB figure
8. `ai-stack-stop`, then `nvidia-smi` proving **zero** compute processes and VRAM actually
   released — not "the unit reports inactive"
9. `ai-stack-start`, then re-run 3–7 to prove it comes back
10. `systemctl kill -s KILL` on the service, then start again — it must recover identically.
    If it only survives a polite `stop`, the design is wrong; fix it, don't document it.
11. **Reboot the machine**, then re-run 3–7 to prove cold boot needs no manual step
12. Measured tokens/sec and TTFT on a non-trivial generation
13. A long-context request near your stated `-c` limit that does NOT OOM

Do not mark any check passed unless its output is in your handoff. If a check can't be run,
say which and why. Commit to the branch when green.

## Handoff back

Append to claude/DRACULA-AI-HANDOFF.md under "Post-execution corrections": what was wrong
in this document as written, the measured numbers (VRAM, context, tok/s, TTFT, log volume),
and anything that surprised you. That section is a deliverable — the next machine gets built
from it.
```

---

## Post-execution corrections

Phase 0 is running and survived a real reboot, target stop/start, and standalone `SIGKILL`.
Several details were wrong or incomplete as written:

1. **The first downloader checksum command quoted `$partial` literally.** The 15.66 GiB
   download completed, but `sha256sum` tried to open a file named `$partial`. Use `printf`
   with the path as a separate shell argument. The corrected downloader resumed the
   complete partial, verified SHA-256
   `5ed60d0af4650a854b1755bd392f9aef4872643dc25a254bc68043fa638392a0`, and promoted it.
2. **Hashing 15.66 GiB on every recovery made the recovery path needlessly slow.** A full
   hash took about 42 seconds. The downloader now writes a verified-SHA marker after the
   required full verification; later starts compare the pinned hash to that marker. Warm
   stop/start is healthy in 3.5–4.1 seconds. A standalone `SIGKILL`, including the explicit
   five-second `RestartSec`, recovered in 9.05 seconds.
3. **`StateDirectoryMode` does not repair modes of an existing nested log directory.** The
   first `logs/` directory remained `0700`, so even an operator in the `llama` group could
   not harvest it. Logger startup now idempotently enforces directory `0750` and JSONL
   `0640`; `services.localLlama.operators` grants deliberate read access.
4. **A 64 KiB buffered read makes SSE TTFT equal total latency.** The first proxy measured
   2.72 seconds for both. Reading SSE line-by-line produced real measurements: 344.7 ms
   TTFT and 3.61 seconds total latency on the verification request. Non-streaming TTFT is
   necessarily response-complete time; use streaming for TTFT comparisons.
5. **Stopping a target can return before propagated `PartOf=` stop jobs settle.** An
   immediate sample still showed llama holding 20,218 MiB while the service was
   `deactivating`. `ai-stack-stop` now waits for terminal service states. It returned after
   224–231 ms with no llama process. The Phase 0 unit deliberately used `SIGKILL`, so llama
   ended in `failed`; the wrapper accepted that terminal state. The multi-model service
   now uses SIGTERM for normal cgroup shutdown while preserving `Restart=on-failure` and a
   final timeout kill for actual failure recovery.
6. **"Zero compute processes" is not literally attainable on this desktop while Signal is
   open.** After stack stop, llama was absent and 21,372 MiB GPU memory was free, but
   Signal's Electron GPU process retained 155–199 MiB. The correct assertion here is zero
   *AI* compute processes and complete release of llama's approximately 20.2 GiB.
7. **Cold and warm model loads are very different.** After a real reboot, services started
   unattended at 20:48:21 and llama became ready at 20:49:00: about 39 seconds, dominated
   by reading 15.7 GiB from disk. A warm start from page cache was about 3.5–4.1 seconds.
8. **The default chat template spends output tokens on reasoning.** A 256-token test ended
   with only `reasoning_content` and empty visible content. For deterministic short checks,
   pass `chat_template_kwargs.enable_thinking=false`; normal coding-agent policy remains a
   later client decision.

### Measured Phase 0 numbers

- llama.cpp: `llama-cpp-10273`, fetched from `cache.nixos-cuda.org` (378.5 MiB package,
  1.2 GiB recursive closure); no source build.
- Model: Qwen3.6-27B Q4_K_M, 16,817,244,384 bytes (15.66 GiB), revision
  `82d411acf4a06cfb8d9b073a5211bf410bfc29bf`.
- Architecture from `config.json`: 64 layers = 16 full-attention + 48 linear-attention
  (1:3). Configured total context is 65,536 with two slots; llama.cpp confirmed 32,768
  tokens per slot.
- VRAM: llama process 20,202 MiB immediately after load and 20,224 MiB after the 30k
  request. This implies roughly 4.5 GiB beyond the 15.66 GiB GGUF for KV, compute, and
  runtime buffers. Total GPU usage varies with desktop applications.
- Normal warmed generation: 39.2–41.7 tok/s, with short-prompt processing varying from
  45 to 142 tok/s. One post-reboot cold first request measured only 22.0 generation tok/s;
  do not use the first request after boot as the steady-state benchmark.
- Long-context oracle: a 30,015-token prompt in a 32,768-token slot completed without OOM
  or truncation in 32.97 seconds; prompt processing was 911.8 tok/s, generation 53.1 tok/s,
  and llama held 20,224 MiB.
- Logging: `/var/lib/llama/logs/requests.jsonl` persisted across reboot and contained full
  request/response payloads, caller, status, model, usage, latency, and streaming TTFT.
  After 90 build-verification records (including the 60,009-character long prompt), it was
  166,253 bytes. The earlier 2–10 GiB/week heavy-coding estimate remains unvalidated; keep
  the 1 GiB/daily rotation and measure a real week in Phase 1.
- Cold reboot: `ai-stack.target`, inference, and logger all returned automatically; a
  post-reboot request returned `COLD BOOT OK`, Prometheus showed 19 prompt and 5 generated
  tokens, and the same request appeared in the persisted JSONL log.

### Phase 1 ingress and harness corrections

1. **The existing thin proxy is the permanent client-facing ingress.** It retains exact
   JSONL/TTFT/caller measurement at port 8080. Once the second model was selected,
   llama-swap became justified behind it at port 18080: routing and residency change while
   measurement and clients do not. LiteLLM still waits for remote paid providers; do not
   repoint clients when it eventually enters.
2. **OMP's release executable cannot be packaged with ordinary `patchelf`/strip fixups.**
   It is a Bun single-file executable whose application lives in an appended trailer.
   Rewriting or stripping the ELF left a working Bun runtime but destroyed OMP. The Nix
   package now preserves the upstream bytes exactly and uses a wrapper around Nix's glibc
   loader. The installed payload still hashes to the upstream SHA-256
   `b864d5ec59133761b95b387ad28377a54da5459b5aaa7e5a34e82b0595350ba3`.
3. **OMP discovers llama.cpp automatically at port 8080.** Merely defining the attributed
   custom provider produced a duplicate un-attributed local choice. Setting
   `disabledProviders: [llama.cpp]` leaves exactly the custom `dracula-local` model.
4. **Both clients support explicit custom headers.** No bearer-token mapping or secrets are
   needed for loopback attribution. OMP sets the header on its custom provider; opencode
   sets it in the OpenAI-compatible provider options.
5. **One visible harness turn is not necessarily one model request.** The opencode smoke
   run launched its visible 9,729-token request and a concurrent lightweight/background
   stream consistent with title generation. The latter was canceled when the CLI exited,
   before llama-server emitted `[DONE]` or usage. New proxy records include
   `stream_completed`, `client_disconnected`, and `proxy_error`; `ai-usage-summary` counts
   incomplete and missing-usage requests separately so this overhead cannot disappear from
   the comparison.
6. **The single model option is now a registry.** Each `services.localLlama.models.<id>`
   entry pins repository, revision, filename, SHA-256, display name, aliases, total context,
   parallel slots, GPU layers, and extra llama-server arguments. Generated downloaders
   retain resumable downloads plus verified-hash markers; generated runners re-check the
   selected artifact before exec. `ExecStartPre` prepares the complete registry so a cold
   boot never depends on a manual model-fetch command.
7. **The switching path preserves the measurement boundary.** OMP/opencode/API requests
   still enter the logging proxy on 8080. It forwards to pinned llama-swap `v247` on 18080;
   llama-swap reads `model` and starts the matching pinned llama-server on dynamic ports
   from 18100. The generated config was accepted by llama-swap and `/v1/models` returned
   both IDs before activation. Runtime swapping and crash recovery are now verified below.
8. **A per-invocation OpenCode model was not initially a complete selection.** `-m` changed
   the primary agent, but title generation still used the statically configured dense
   `small_model`. During the first MoE smoke test, OpenCode launched a 61-second dense title
   request concurrently; llama-swap correctly serialized it, leaving the visible MoE
   request waiting about 61 seconds. The managed wrapper now maps the requested model to
   `small_model`, summary, and compaction for that process and disables automatic titles.
   An immediate retest produced one MoE request in 599 ms with no dense background request.
9. **Normal target stop must not use the crash signal.** `KillSignal=SIGKILL` released the
   model reliably but left an intentional `ai-stack-stop` in `failed`. The unit now uses
   SIGTERM for normal cgroup shutdown, retains the ten-second timeout and systemd's final
   SIGKILL cleanup, and still uses `Restart=on-failure` for genuine crashes.

### Pinned Phase 2 model registry

- Former dense default: `dirk-qwen3.8-27b-local`,
  `peculiar-ragdoll/Dirk-Qwen3.8-27B-GGUF` revision
  `027902e9811019480b8b074aed93fa6084f782a9`,
  `Dirk-Qwen3.8-27B-UD-Q5_K_XL.gguf`, SHA-256
  `9ea3ab209250fa74f1dd04a7d3ba60f9d346a5752c5c357d48e71df648586898`.
- MoE candidate: `qwen3.6-35b-a3b`, `unsloth/Qwen3.6-35B-A3B-GGUF` revision
  `a483e9e6cbd595906af30beda3187c2663a1118c`,
  `Qwen3.6-35B-A3B-UD-Q3_K_M.gguf`, 16,600,710,112 bytes, SHA-256
  `1b715841683f960bd9a49f008181bd910ee169b78d4cf465b6fde7f4d929ff99`.
- The retained MoE has 40 layers, 256 experts with 8 selected per token, and 262,144 native
  context.
- Dirk has 64 main layers with a 16-layer full-attention cadence plus one MTP layer. Its
  validated 32,768-token single-slot cap reserves 2 GiB for F16 KV cache on the 24 GiB RTX
  3090. At the measured 2.6 GiB desktop load, the former 49,152-token / 3 GiB allocation OOMed.
  The old generic Hermes 64,000-context assertion was removed because it constrained all models
  without reflecting their actual VRAM budgets.
- llama-swap: official `v247` Linux amd64 archive, SHA-256
  `4001a068dc1dd154513919a31cc009d4f544426d2040bd02fbf33d90240c17df`.

### Multi-model activation evidence

- Both pinned GGUFs downloaded, passed SHA-256 verification, and retained verified-hash
  markers. At router idle no llama-server was resident; `/v1/models` through permanent
  port 8080 listed both IDs.
- Dense request `phase2-dense-swap` selected port 18100 and returned HTTP 200. Cold
  load-plus-response was 4,860 ms with 4,750 ms TTFT; llama held 20,216 MiB. llama.cpp
  confirmed two 32,768-token slots and measured 38.52 generation tokens/s on the tiny
  acceptance response.
- MoE request `phase2-moe-swap` removed the dense process, selected port 18101, and returned
  HTTP 200. Cold swap-plus-response was 5,988 ms with 5,950 ms TTFT; llama held 17,246 MiB.
  It also confirmed two 32,768-token slots and measured 111.55 generation tokens/s on the
  tiny response. These numbers prove fit and routing, not quality or steady-state speed.
- A request back to the dense alias removed the MoE process and left only dense resident.
  `ai-stack-stop` removed every llama process and listener; `ai-stack-start` restored the
  ingress and router with no model resident, as expected for on-demand loading.
- A standalone router SIGKILL changed its main PID from 39909 to 40060, incremented
  `NRestarts` to one, removed the resident child, and recovered `/health` plus both model
  aliases through the unchanged logger. A subsequent dense request reloaded port 18100.

### Phase 2 evaluator checkpoint

- Langfuse is deliberately **not** the source-of-truth evaluator. Its current self-hosted
  stack adds web and worker containers plus PostgreSQL, ClickHouse, Redis/Valkey, and object
  storage. It provides valuable traces, datasets, annotations, scores, and comparison UI,
  but does not create clean git worktrees or run repository-specific build oracles. It is
  now deployed as the trace, visualization, annotation, and experiment sink; evaluation
  must remain
  reproducible without it. See the official [self-hosting architecture](https://langfuse.com/self-hosting),
  [experiment model](https://langfuse.com/docs/evaluation/core-concepts), and
  [OpenTelemetry endpoint](https://langfuse.com/integrations/native/opentelemetry).
- `eval/ai_eval.py` runs each task from a pinned revision in a disposable git worktree,
  selects OMP/OpenCode and the model explicitly, executes deterministic command or human
  oracles, captures complete patches and harness artifacts, and joins all ingress requests
  with `X-AI-Eval-Run`. `matrix` randomizes a seeded model × harness order while remaining
  sequential on the one-GPU machine; `report` renders committed-table-ready Markdown.
- `eval/harvest.py` lists candidates without payloads and copies only a selected last user
  message into ignored `eval/drafts/`. Curation must inspect secrets, reconstruct the true
  starting commit, and add task-specific oracles before moving a task to `eval/tasks/`.
- The synthetic `write-file-smoke` acceptance task passed in a disposable worktree and was
  cleaned up. On OMP+dense it took 71.977 seconds and eight model requests: 156,419 prompt
  tokens, 883 completion tokens, and 118,256 cached prompt tokens. That intentionally
  surprising overhead validates why the evaluator counts the complete agent loop. The
  smoke task is invented infrastructure testing and is excluded from quality conclusions.
- Raw artifacts live under ignored `eval/.runs/`; only curated tasks and reviewed results
  belong in git. `--auto-approve` is explicit and is not a security sandbox, even though
  the worktree is disposable.

### Phase 3 deployment correction and checkpoint

- Native n8n 2.32.6 initially passed live acceptance: loopback-only editor and broker,
  `/healthz`, real Prometheus metrics, SQLite WAL enforced by `ExecStartPost`, and both
  JavaScript and Python runners registered. A complete `ai-stack-stop` took 245 ms and
  removed all five services/listeners; `ai-stack-start` restored them in 4,356 ms.
- That same startup emitted n8n's deprecation warning for non-container deployment. The
  official documentation now recommends Docker for most self-hosting and a separate
  `n8nio/runners` sidecar for production Code-node isolation. This supersedes the original
  native-only instruction before any workflows or credentials have been created.
- The replacement uses official n8n and runners 2.32.6 OCI indexes pinned respectively to
  `sha256:5f7856f4fc7cd935230f7596e39fdb3d5eda0e379c5b40b699b9c0eb35ebd0bf`
  and `sha256:9c9ddc41410b56650605f44c3af6366abb467c33176569be371ccc5f476439fc`.
  The images are on a fixed private bridge; only `127.0.0.1:5678` is published. A systemd
  socket on the bridge proxies container requests to the unchanged `127.0.0.1:8080`
  inference boundary without exposing that boundary on the LAN.
- Migration is copy-only: the native `/var/lib/private/n8n/.n8n` remains untouched while
  the official `/home/node/.n8n` layout uses `/var/lib/n8n-container`. The same sops key is
  mounted read-only. The runner receives only its root-only rendered auth environment and
  no database, secret-key, or org-directory mount.
- The live container deployment reports n8n 2.32.6, both JavaScript and Python runners
  registered, `/healthz/readiness` healthy, real Prometheus metrics, SQLite `wal`, and
  `PRAGMA quick_check=ok`. Both container root filesystems are read-only, all capabilities
  are dropped, and only bounded tmpfs paths remain writable outside the explicit n8n state
  and org-inbox mounts. Only `127.0.0.1:5678` is published to the host.
- The bridge-only inference relay returned HTTP 200 for `/health` and `/v1/models` from
  inside n8n; both pinned model aliases were visible through the unchanged logger. The
  fixed `n8n-local0` bridge is the only firewall interface allowed to reach its
  `172.30.0.1:8080` relay socket. Port 8080 remains loopback-only everywhere else.
- Complete target stop took 658 ms and left zero n8n containers or AI listeners. Start to
  full ingress+n8n readiness took 7,863 ms. Every service reported `Result=success` after
  adding exit 143 as the runner launcher's normal Docker-stop status.
- A real n8n-container SIGKILL changed the main and dependent runner container IDs,
  incremented `docker-n8n.service`'s restart counter, restored readiness and relay access,
  and re-registered both runners. A separate runner SIGKILL changed only its container ID,
  incremented only its restart counter, and re-registered both runner types in 3.1 seconds.
- The first activation that introduced the stable bridge converged but returned status 4:
  `basic.target -> sockets.target -> n8n-ai-ingress.socket -> n8n-docker-network.service
  -> basic.target`. The socket now disables only its implicit default dependencies and
  retains its explicit `After=/Requires=` on the bridge. Static unit verification is clean;
  the corrected generation activated successfully on its first attempt with no cycle log
  and no failed units.
- `n8n-workflows-import` and `n8n-workflows-export` are thin container-boundary wrappers
  around n8n's official CLI. Import validates every JSON file, imports drafts, and then uses
  `publish:workflow` for reviewed definitions with `active: true`; regular SQLite mode
  rejects the otherwise documented `--activeState=fromJson` flag. Export streams files out
  of the container tmpfs into a new, never-overwritten review directory. A complete
  import/export round trip preserved the tracked workflow ID and active state.
- The tracked `Dracula / Provisioning smoke` webhook imported and published, survived a
  complete target restart, executed its Code node using the external JavaScript runner,
  and returned JSON successfully. Its extended path called the dense model through the
  bridge-only relay. The ingress recorded caller `n8n:dracula-provisioning-smoke`, HTTP 200,
  23 prompt + 32 completion = 55 tokens, and 30,993 ms cold-load-plus-generation latency.
  This is infrastructure evidence only; it is excluded from model-quality evaluation.
- A subsequent acceptance run exercised both external runner languages in one persisted
  production execution. The response reported `javascript_runner=ok` and
  `python_runner=ok`; n8n's execution counter increased, and its workflow-duration metric
  carried workflow ID `draculaProvisioningSmoke`, mode `webhook`, and status `success`.
  The same request produced a warm ingress record with caller
  `n8n:dracula-provisioning-smoke`, HTTP 200, 55 total tokens, and 5,791 ms latency.
- Runtime mount inspection confirms that n8n can write its state and `/org-inbox`, its two
  secret mounts are read-only, and the external runner has zero mounts: it cannot see n8n
  state, the org inbox, or secret files. The tracked workflow has neither credential
  references nor secret-like fields.
- Phase 3's reusable platform is complete. Vincenzo intentionally deferred exact business
  workflows, including the production mail workflow, to a separate session. When that is
  built, do not place the mailbox password or exported decrypted credentials in workflow
  JSON or git.

### Phase 4 Hermes deployment checkpoint

- Hermes uses the official rolling `nousresearch/hermes-agent:latest` container. Its gateway
  and dashboard share one container and the upstream s6 supervisor, matching the tier-one
  deployment instead of adapting Hermes' user-service lifecycle to NixOS system units.
- `hermes-agent.service` is a thin Compose owner attached to `ai-stack.target`. State remains
  at `/var/lib/hermes/.hermes` and mounts at the official `/opt/data` boundary; the workspace
  remains `/var/lib/hermes/workspace` and mounts at `/workspace`. The dashboard binds only to
  host loopback on port 9119, with Alucard exposed privately through authenticated Tailscale
  Serve. The container gets neither the Docker socket nor arbitrary host filesystem mounts.
- The workspace initializer created branch `main` and committed the managed `AGENTS.md` and
  `SOUL.md` baseline. A real Hermes tool call subsequently reported `HOME_BLOCKED` for
  `/home/vincenzo/nixos-config/flake.nix` and `WORKSPACE_WRITABLE` for its own repository.
- Native dashboard WebSocket session `20260809_085118_6107d7` returned exactly
  `HERMES_PHASE4_OK` through the permanent ingress. Cold model load plus the turn took
  45.36 seconds. The authoritative JSONL record attributes caller `hermes`, model
  `qwen3.6-27b-local`, HTTP 200, 12,805 prompt + 27 completion tokens, 42,580 ms TTFT, and
  43,420 ms request latency. Hermes' browser analytics independently showed the same first
  call, then accumulated tool and cache-use data across the boundary tests.
- The dashboard WebSocket rejects unauthenticated connections even on loopback; its SPA
  injects an ephemeral session token. The failed unauthenticated probe returned HTTP 403,
  while the authenticated browser-equivalent path succeeded.
- `approvals.mode=manual` does **not** mean every tool call or every effectful workspace
  action asks the operator. Upstream documents it as prompting for terminal commands that
  match dangerous-command patterns. Read-only terminal checks, `write_file`/`patch` inside
  `HERMES_WRITE_SAFE_ROOT`, and ordinary `git add`/`git commit` all ran without an approval
  event. The write-safe-root hard limit and systemd service confinement are therefore the
  security boundary; describe manual approvals only as a risk-pattern gate.
- Hermes itself created and committed `/var/lib/hermes/workspace/SURPRISES.md`. Commit
  `f773807` recorded the initial observation; follow-up commit `5050782` corrected the
  approval semantics after the write-and-commit test. The runtime repository finished
  clean, so rollback and surprising-behavior logging are functioning rather than merely
  documented.
- No MCP server is enabled yet because no external integration is in scope. The upstream
  MCP client is packaged and `services.hermes-agent.mcpServers` is the declarative extension
  point for established adapters when Notion, Linear, Paperless, or another real tool is
  introduced. Do not build a bespoke adapter first.
- Phase 4 infrastructure is ready for use, but the phase's scientific conclusion is not
  complete. Once the real deterministic n8n workflow exists, run the same task through
  Hermes and report tokens, latency, success, operator interventions, and surprising
  actions. Until then, the records above are acceptance evidence only.

### Observability deployment checkpoint (active, 2026-08-09)

- `modules/observability.nix` and the official-container Compose project under
  `observability/` add two complementary layers. Langfuse v4 owns LLM/agent traces,
  annotations, datasets, and experiment views. Prometheus and Grafana own host, Docker,
  NVIDIA GPU, n8n, and ingress time-series metrics. Langfuse does not replace the committed
  worktree evaluator or the complete JSONL source record.
- Langfuse follows its current official low-scale topology and compatibility versions:
  `langfuse:4`, `langfuse-worker:4`, Postgres 17, ClickHouse 25.12, Redis 7, and
  Chainguard MinIO. Monitoring uses the official rolling Grafana, Prometheus,
  node-exporter, cAdvisor, and NVIDIA DCGM exporter images. The shared daily container
  updater recreates the active Compose project with current images.
- Every browser and metrics listener is loopback-only. Langfuse is on port 13000, Grafana
  on 13001, and Prometheus on 19091. Prometheus retention is bounded to 90 days or 20 GB.
  The provisioned Grafana overview covers CPU, RAM, disk, containers, GPU/VRAM, n8n, AI
  request/token rate, latency, and TTFT.
- The stable logging ingress now exports `ai_ingress_*` Prometheus counters and summaries
  labeled by caller and model while preserving llama-swap's existing metrics. This gives
  OMP, OpenCode, n8n, Hermes, Wirken, and manual calls the same token/latency trend path.
- OpenCode enables OpenTelemetry plus Langfuse's official rolling observability plugin and
  receives the headlessly initialized project keys from SOPS. OMP nested tool spans are
  intentionally not claimed until the community Pi extension is proven compatible with
  the OMP fork; n8n has no native Langfuse tracing integration and retains its own metrics
  and execution history until important workflows are explicitly instrumented.
- Hermes remains covered by its native token dashboard, ingress metrics, and JSONL. Its
  bundled `observability/langfuse` plugin requires a pip-installed SDK, while its sealed
  upstream Nix package rejects the SDK's overlapping HTTP/Pydantic closure. Keep nested
  Hermes Langfuse tracing disabled until upstream exposes a compatible dependency group;
  do not bypass the collision guard or create a mutable service environment.
- Dracula's live acceptance passed after activation. The system has no failed units, all 11
  observability containers are running, Langfuse reports v4.6.0 healthy, Grafana reports
  its database healthy, and every Prometheus target is up: ingress, containers, n8n, node,
  NVIDIA DCGM, and Prometheus itself. DCGM reports the RTX 3090 and its VRAM, temperature,
  and utilization rather than a synthetic or empty target.
- A real OpenCode `OBSERVABILITY_OK` turn produced an HTTP 200 ingress record with 9,667
  prompt + 53 completion tokens, 9.809 seconds total latency, and 8.424 seconds TTFT.
  Langfuse v4 independently exposed three observations for the same turn—an agent, a user
  event, and a generation with 9,720 total tokens. The plugin did not populate
  `providedModelName`, so model attribution still comes from the ingress label. Langfuse v4
  removed the legacy trace-list API; use `/api/public/v2/observations` and group by trace ID.
- The first activation exposed three configuration errors while preserving the other
  containers: Compose v5 translated generic `gpus: all` into a missing AMD CDI device,
  optional Nix string indentation produced invalid Prometheus YAML, and
  `vincenzo@localhost` failed Langfuse's email validation. The correction requests the
  host's real `nvidia.com/gpu=all` CDI device (independently proven with `nvidia-smi`),
  generates Prometheus configuration with Nix's YAML formatter and validates it with
  `promtool`, and initializes `vincenzo@istbereit.de`. The corrected activation passed.
- `docs/SECRETS.md` inventories every SOPS key, runtime rendering, consumer, rotation
  class, backup boundary, and the future Alucard/customer separation rule without storing
  values. Cryptographic roots and first-boot database/application credentials are not
  rotated by merely editing SOPS.
- Alucard imports and enables the reusable business-demo profile. It reuses the complete
  clients/workers/governance/observability surface and routes the permanent logged ingress
  to `https://router.requesty.ai/v1`. Use Requesty's
  maintained routing, access lists, spending limits, and analytics instead of adding a
  redundant gateway by default. The first locally registered route is
  `deepinfra/deepseek-v4-flash-0731`; authenticated HTTPS exposure and tested trace
  backup/retention/redaction policy remain gates for customer-facing use.
- Syncthing previously copied `.git` between Dracula and Alucard and left Alucard's branch
  ref pointing at an object that had not arrived. Commit `0455d96` excludes `/.git` both in
  `.stignore` and in Alucard's declarative Syncthing folder. Alucard was repaired without
  replacing its working tree by importing a complete Git bundle, preserving its matching
  edits in a temporary stash, and fast-forwarding to `0455d96`; the exact flake build that
  originally failed now succeeds. Future commits must move through Git, not Syncthing.
- The Alucard business-demo profile is enabled in `hosts/alucard/ai.nix`. It reuses n8n,
  Hermes, Wirken, Langfuse/Grafana, OMP/OpenCode, and
  the permanent port-8080 ingress but injects a root-only Requesty workload key upstream.
  Requesty cost and `x-requesty-*` routing metadata are preserved; Prometheus exposes
  `ai_ingress_cost_usd_total`. Machine-specific non-Requesty secrets are generated in the
  separate encrypted `secrets/alucard-ai.yaml`. The ingress requires each configured model
  to exist in the authenticated catalog, exposes only the local registry from `/v1/models`,
  and rejects unregistered calls before Requesty. The upstream key may remain catalog-wide;
  a matching Requesty Access List is optional defense in depth.
- Alucard's live acceptance passed for the Requesty ingress, OMP, OpenCode, n8n, Hermes,
  Wirken, Langfuse, Grafana, and all five Prometheus scrape targets. A green cAdvisor target
  initially exposed only the root cgroup because Docker 29's embedded containerd socket is
  `/run/docker/containerd/containerd.sock`, not cAdvisor's default. A disposable probe with
  the explicit endpoint exposed all 42 running containers. After switching the Compose
  correction, Prometheus reports 40 non-root named container series and both the containerd
  and Docker cAdvisor factories register successfully.
- Every live Alucard AI API, UI, and exporter backend is loopback-only except the
  systemd-isolated Hermes listener described above, and no AI port is in the global firewall
  or public reverse proxy. Host assertions protect the configurable bind addresses and global
  firewall boundary. Dracula's `ai-admin` SSH profile remains the break-glass path. Tailscale
  Serve is now the active multi-device private access plane for the AI and media-administration
  stacks; Tailscale Funnel remains explicitly prohibited.

### Private access, demo client, and security checkpoint (active, 2026-08-09)

- Alucard's AI, observability, and ARR administration interfaces are published only to the
  tailnet through explicit Tailscale Serve mappings. The stable links and local fallback ports
  are recorded in `docs/AI_DEMO_GUIDE.md` and `docs/ALUCARD_SECURITY.md`. Public probes of the
  Hermes backend and tailnet frontend ports were closed/filtered. The full
  `alucard.tailf117a1.ts.net` name is required for the HTTPS certificate and Hermes Host check;
  the shortened hostname is not an equivalent HTTPS origin.
- Hermes' official authentication gate uses a SOPS-managed password hash and session-signing
  secret. Authenticated live acceptance passed for password login, the session API, the full
  43-provider model picker, the configured-only picker, and a WebSocket `101` upgrade. The
  configured path exposed only `custom:dracula-local` and selected
  `deepinfra/deepseek-v4-flash-0731`. The official Hermes Desktop package is installed on
  Dracula and documented as the customer-facing client; the browser UI and TUI remain useful
  operator alternatives.
- OMP was updated to v17.2.12. Nix policy now uses upstream's supported `PI_CONFIG_FILES`
  overlay while OMP's global settings file remains writable, and `OMP_SKIP_SETUP` suppresses
  automatic onboarding for the already-configured provider. Plain `omp` calls succeeded on
  both hosts using their managed defaults, with HTTP 200 ingress records attributed to `omp`:
  `qwen3.6-27b-local` on Dracula and `deepinfra/deepseek-v4-flash-0731` on Alucard.
- CrowdSec 1.7.8 consumes sshd journal and nginx access records with community sharing and
  community blocklist pulls disabled. The firewall bouncer is active in both `INPUT` and
  Docker's `DOCKER-USER` chain. A real nginx-derived decision was verified in the live
  `crowdsec-blacklists-0` ipset, proving the detection-to-remediation path rather than only
  configuration presence. `crowdsec-admin` runs the official `cscli` inside the required
  systemd DynamicUser state namespace; direct invocation of the NixOS wrapper is incompatible
  with the bouncer module's private state-directory layout.
- Current post-switch health showed zero failed systemd units on both hosts. All Alucard
  tailnet probes for Hermes, ingress, n8n, Langfuse, Grafana, Wirken, Prometheus, and the ARR
  administration services returned successful application responses, and every Prometheus
  target was up, including CrowdSec.

### Security, Requesty choice, and messaging checkpoint (active, 2026-08-09)

- Alucard activated ModSecurity with pinned OWASP CRS 4.25.1 LTS, nginx request and connection
  limits, bounded request bodies, consistent low-risk headers, explicit 404s for four dead
  backends, and a loopback-bound/hardened Keycloak unit. From Dracula, the normal Jellyfin path
  returned HTTP 302, the traversal/shell WAF probe returned HTTP 403, Keycloak returned HTTP
  302 through public HTTPS, and its raw port 38080 was closed over the tailnet. A hot reload
  initially exposed a libmodsecurity 3.0.16 / PCRE2 10.47 JIT cleanup crash. Alucard now uses
  libmodsecurity's maintained interpreter fallback while keeping standard nginx reloads and
  systemd hardening. Three consecutive reloads, a full restart, normal HTTP 200, malicious
  HTTP 403, zero new coredumps, and zero failed units passed live acceptance.
- CrowdSec gains the maintained Jellyfin brute-force collection and reads Jellyfin's systemd
  journal. Existing firewall remediation remains unchanged and already has live evidence.
- `lib/requesty-models.nix` contains a 2026-08-09 authenticated-catalog snapshot covering
  cheap DeepSeek/Qwen, stronger DeepSeek, Kimi K3, and three current frontier comparisons.
  Alucard enforces the registry. Dracula exposes it to OMP/OpenCode over the private Alucard
  Tailscale ingress while preserving its local models and local default; Dracula receives no
  Requesty credential. Live `/v1/models`, `omp models`, and `opencode models` checks exposed all
  seven Requesty entries and both Dracula-local entries; OMP 17.2.12 used its writable config
  path without repeating onboarding.
- Signal was deferred because no dedicated account exists. Telegram is now the selected first
  mobile channel. Hermes now uses the upstream `messaging` Nix variant and a domain-filtered
  loopback proxy for only Telegram API plus Nous managed onboarding. Its dashboard QR flow
  persists the token and numeric owner allowlist in Hermes' protected application state.
  Pairing and the allowed-DM path passed live on 2026-08-15: the exact `TELEGRAM_OK` test
  created a Telegram-sourced session and two `hermes`-attributed Requesty calls returned HTTP
  200 from `deepinfra/deepseek-v4-flash-0731`. `/model` also returned its chooser; only
  denied-user acceptance remains. Its initial `custom:dracula-local` display was a stale name
  in persistent Hermes configuration, not a Dracula route. Activation now safely renames that
  provider to `custom:alucard-requesty` while preserving the model catalog.
  Wirken's Telegram adapter is
  not enabled because its released documentation says it responds to all private messages and
  sender identity is audited rather than authorized. One bot must never feed both agents.
- Hermes Telegram onboarding initially failed for two NixOS-integration reasons: the custom
  dashboard inherited managed mode and rejected its own runtime writes, and its restart action
  cleanly stopped the system gateway while `Restart=on-failure` left it down. The dashboard is
  now allowed to own runtime channel settings, Nix still wins for declared config keys, and the
  system gateway uses upstream-style `Restart=always`. Do not add a second user gateway.
- A follow-up live check found the upstream dashboard restart can also start a standalone
  gateway before systemd recovers. The system service now uses Hermes' supported
  `gateway run --replace` mode to reclaim the lock, and the writable dashboard sets
  `HERMES_SKIP_CHMOD=1` so it cannot narrow shared state from `2770` to `0700`.
- Native Hermes was superseded immediately afterward: the official rolling Docker image is
  now the deployment source of truth, with gateway and dashboard sharing its supported s6
  supervisor and existing state mounted at `/opt/data`. Nix only prepares state, injects
  dashboard secrets, and owns Compose lifecycle/update integration. This is the portable
  customer deployment baseline; do not restore the native NixOS Hermes service.
- Hermes and Wirken initially rejected their Tailscale browser host/origin. Alucard now uses
  loopback-only nginx compatibility proxies behind Tailscale Serve. They validate each exact
  HTTPS tailnet origin before translating to the upstream-required loopback origin. Live checks
  returned HTTP 200 for both UIs and 403 for foreign origins; unauthenticated Hermes config and
  session APIs still return 401.
- CrowdSec state ownership was normalized after the NixOS module's DynamicUser migration left
  nested state inaccessible. The stale bouncer registration whose key was already absent was
  deleted and recreated through the upstream unit. CrowdSec, its authenticated firewall
  bouncer, and nginx are active with zero failed units.
- Wirken v1.17.0 is the current signed binary release. Its binary checksum and signed release
  manifest were verified before the Nix hash was updated. Both gateways and audit timers are
  active, and their WebChat roots return HTTP 200. Dracula's anchored verification passes;
  Alucard's last strict run correctly reports the historical CLI-only `default` session with no
  signed head. No-tool chat is usable. The
  known WebChat effectful-approval defect remains upstream. For the observation week,
  `wirken-admin ask --message "..."` can exercise the released interactive stdin approval gate,
  but its events are hash-chained without signed chain heads. Do not create an unofficial image,
  weaken strict verification, or maintain a local source patch.
- `wirken-admin doctor` passed live on Alucard: provider, vault, adapter registry, MCP signing,
  signed audit chain, Docker runtime, and alarm log were healthy. No channel is configured yet.
  The latest root-daemon Trivy baseline scanned 40 image references and exported 178 critical,
  2,309 high, and one archive failure through node-exporter. The scanner now invokes rootless
  Docker as its owning user and exports immutable image IDs, which includes Onyx and eliminates
  the multi-tag MinIO failure. A post-switch scan is still required to record the combined
  baseline. All six Prometheus targets are up; per-image remediation remains a production gate.

### DNS and agent-integration checkpoint (active, 2026-08-15)

- Alucard's intermittent post-activation outage was isolated to DNS, not routing or firewalling:
  public IP traffic worked while Tailscale's resolver logged `no upstream resolvers set` and
  returned `SERVFAIL`. Alucard now enables `systemd-resolved` with explicit Cloudflare and
  Quad9 fallbacks so MagicDNS has a supported split-DNS manager and stable public upstreams.
- Hermes and n8n now share `/home/vincenzo/org` as `/org`, with host ACLs granting Hermes
  access and n8n file nodes confined to that mount. Hermes policy permits only reviewed n8n
  production webhooks on localhost, not general network or host access.
- n8n can trigger Hermes through the official authenticated OpenAI-compatible API. Hermes
  binds `127.0.0.1:8642`; a socket proxy exposes it only on n8n's private Docker bridge, and
  each host has an independent SOPS-managed `hermes/api_server_key`. No public or tailnet
  listener was added. Exact workflows remain separate reviewable/exported artifacts.
- Hermes gives its persistent `/opt/data/.env` precedence over process environment. The first
  API acceptance probe exposed that an older application-owned key shadowed the new SOPS key.
  Activation now atomically reconciles only `API_SERVER_KEY` into `.env`, preserves messaging
  credentials, and keeps the key out of Docker's inspectable container environment.

### Measured Phase 1 starting point

- OMP: `17.2.11`; opencode: `1.18.13`.
- Effective SHA-256 hashes: OMP `config.yml`
  `cb7bc8cde0a5b594cac860ec21bed3d90b50d86eb6f6a6602e949d31eb1beae9`, OMP
  `models.yml` `f897bcc0ba11a28e254e1a48f46c564e75fe810e1d3ac34b30cdcc36ab581cb2`,
  opencode `opencode.json`
  `ae01628eeb5635f0638166301724a8e60ebabac309503456171d4c44a12bbb10`.
- Paired no-tools smoke prompt: `Reply with exactly HARNESS_OK and nothing else.` Both
  returned `HARNESS_OK` against `qwen3.6-27b-local` with HTTP 200.
- OMP log record at `2026-08-08T19:09:50Z`: caller `omp`, 3,776 prompt + 33 completion =
  3,809 tokens, 3,881 ms TTFT, 4,862 ms total latency.
- Opencode log record at `2026-08-08T19:10:04Z`: caller `opencode`, 9,666 prompt + 63
  completion = 9,729 tokens, 10,469 ms TTFT, 12,803 ms total latency.
- Opencode also produced a second attributed HTTP 200 stream: 13,392 ms latency, 10,925 ms
  TTFT, no terminal `[DONE]`, and no usage block because the client disconnected. The
  starting-point aggregate is therefore OMP 1 request / 3,809 known tokens versus opencode
  2 requests / 9,729 known tokens / 1 incomplete stream / 1 missing-usage record.
- The prompt is far too small to compare quality, and the clients carry different native
  system prompts. The token/latency difference is useful proof that the harness itself is
  now observable, not evidence that OMP has won. Complete the week of real work, then run
  paired clean-worktree tasks before drawing that conclusion.

### Client-provider visibility correction (2026-08-15)

- OMP 17.2.12's `enabledModels` is a selection scope, not a provider declaration. Generating it
  only from the custom profiles hid already-authenticated bundled Anthropic and OpenAI Codex
  models from the interactive picker even though `omp models` could discover them. The managed
  overlay now retains the custom profiles and adds only `anthropic/*` and `openai-codex/*`;
  upstream's bundled catalog supplies the concrete model IDs, so this does not pin a stale list
  or expose unrelated providers. OMP authentication remains in the writable
  `~/.omp/agent/agent.db`, outside Nix-managed configuration and the Nix store.
- OpenCode 1.18.13 treats `enabled_providers` as an allow-list. The generated configuration now
  permits custom local/Requesty profiles plus the built-in `anthropic` and `openai` providers,
  without declaring either built-in provider or writing auth state. Its application-owned OAuth/API
  state is `~/.local/share/opencode/auth.json`, which activation must preserve. OpenAI supports
  ChatGPT Plus/Pro OAuth through `/connect`; OpenCode's Anthropic provider supports an API key,
  not a Claude consumer-account OAuth subscription. Do not bridge or copy OMP credentials into
  OpenCode; authenticate each client through its supported flow.

### Former Dirk Qwen3.8 Q5 dense-default change (historical, 2026-08-15)

- The dense Qwen3.6 registry entry is replaced by
  `dirk-qwen3.8-27b-local`. It pins
  `peculiar-ragdoll/Dirk-Qwen3.8-27B-GGUF` revision
  `027902e9811019480b8b074aed93fa6084f782a9`,
  `Dirk-Qwen3.8-27B-UD-Q5_K_XL.gguf` (20,218,188,864 bytes,
  SHA-256 `9ea3ab209250fa74f1dd04a7d3ba60f9d346a5752c5c357d48e71df648586898`).
  The model card declares Apache-2.0, Qwen3.8-27B / Qwen3.5 hybrid architecture, and
  llama.cpp compatibility. Nixpkgs' llama.cpp `b10273` recognizes both `qwen35` and MTP
  tensors.
- Directly parsed GGUF v3 metadata confirms `general.architecture=qwen35`,
  `qwen35.context_length=262144`, 24 Q / 4 KV heads of 256 dimensions,
  `full_attention_interval=4`, one MTP prediction layer, and the embedded
  `qwen3.8-froggeric-v22` chat template. The primary tensor encoding is Q5_K (275 tensors);
  dynamic quantization also uses Q6_K, Q4_K, Q8_0, and F32 tensors. The upstream
  `general.file_type=14` label does not match the filename, so it must not be used to identify
  the quantization; the pinned SHA-256 and tensor map are authoritative.
- This is deliberately text-only. The repository's separate optional
  `mmproj-F16.gguf` is neither registered nor downloaded, so no vision projector consumes
  VRAM. The existing `qwen3.6-35b-a3b` MoE registry entry remains selectable.
- The initial 49,152-token cap failed live: its 3 GiB F16 KV allocation OOMed with 2.6 GiB
  already occupied by Dracula's desktop. The validated 32,768-token, one-slot cap requires
  2 GiB ($16 \times 4 \times 256 \times 2 \times 2 \times 32{,}768$ bytes). Its loaded
  `llama-server` used 20,786 MiB and left 709 MiB GPU memory free. This is the largest
  validated cap; preserve one slot and reduce it if concurrent desktop load makes it unstable.
- The downloader verified the pinned artifact. A direct ingress completion completed with
  `b10273-a6aa6f5` (179 prompt tokens in 480 ms; 16 generated tokens at 29.18 tokens/s);
  both OMP and OpenCode explicitly selected Dirk successfully. Switching to
  `qwen3.6-35b-a3b` and back also succeeded. Inspect the caller-attributed ingress JSONL and
  repeat the Hermes/Wirken smokes before treating longer agent workloads as proven.

### Dirk Q4 default transition (live-verified, 2026-08-15)

- `dirk-qwen3.8-27b-local` now pins the same immutable repository revision
  `027902e9811019480b8b074aed93fa6084f782a9` to
  `Dirk-Qwen3.8-27B-UD-Q4_K_XL.gguf` (17,923,404,864 bytes, SHA-256
  `405359214aa8bd77b1af70121bc2d7878f3395b73dea16ae362ce71fa56b248e`).
  Q4 is 2.14 GiB smaller than the former Q5 artifact.
- The downloader SHA-256 check passed. The one-slot, 32,768-token cap retained its 2 GiB
  F16 KV-cache budget. With Dracula's desktop active, Q4 used 20,895 MiB of the RTX 3090's
  24,576 MiB and left 3,229 MiB free; `llama-server` itself held 18,798 MiB. Do not raise
  context or concurrency without another live measurement.
- A direct caller-attributed ingress completion and an explicit OMP selection both returned
  `4`. Swapping to `qwen3.6-35b-a3b` and back to Q4 returned HTTP 200; no failed unit remained.
  OpenCode verification remains intentionally deferred at the user's direction.
