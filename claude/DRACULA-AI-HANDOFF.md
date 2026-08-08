# Dracula handoff — build the local AI machine

Goal: turn `dracula` into a **fully local, always-on AI workstation** — llama-server on the
RTX 3090, local coding agents, n8n for agentic workflows, and **a measurement layer good
enough to decide what's worth paying for later**. No remote APIs, no dependency on
`alucard`. Written 2026-08-08.

Hand this whole file to Claude Code on dracula. Read **Purpose**, **Decisions**, and **What
breaks first** before writing any Nix — they exist so you don't relitigate settled questions
or walk into known traps.

---

## ✅ STATUS: Phase 0 complete; Phase 1 clients activated 2026-08-08 — one-week trial open

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
- **Wirken sits above the workers, not beside them.** It is the operator's control surface
  and the audit boundary. That's why it comes late — it needs something to govern — and
  why it isn't optional at the end.

---

## Decisions (settled — do not relitigate)

**Full local on dracula.** No remote API for now, no communication with `alucard`. Things
can move later; they will not move during this build.

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
- **alucard** — untouched.

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

These compose (llama-swap behind LiteLLM) if it comes to that. Don't install both at once.
Pick against the requirements above, state the trade-off, and say what you'd swap to.

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
`ai-stack-start` cycle. Don't start the next until the previous one does.

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
  llama-swap is deferred until Phase 2 introduces a second local model; LiteLLM is deferred
  until remote providers, budgets, or real credential management enter scope. Clients must
  continue using port 8080 through either later change.
- OMP `17.2.11` and opencode `1.18.13` are installed declaratively from
  `hm-modules/ai-clients.nix`. OMP is a fixed-output release package in `packages/omp.nix`;
  opencode is pinned by the flake's nixpkgs lock. Both autoupdate paths are disabled or
  bypassed.
- OMP's only enabled model and every configured role point at
  `dracula-local/qwen3.6-27b-local`; its implicit `llama.cpp` discovery provider is disabled.
  Opencode's only enabled provider is `dracula-local`, and both `model` and `small_model`
  use that same alias. Both target `http://127.0.0.1:8080/v1`.
- Both use an explicit read-only-without-prompt boundary: OMP `always-ask`; opencode asks by
  default while allowing only read/search/LSP/question/skill operations explicitly. Tool
  calls that mutate the workspace or run shell commands therefore require approval.
- The acceptance prompt produced exactly one successful log record from each caller with
  `X-AI-Caller: omp` and `X-AI-Caller: opencode`. See the Phase 1 corrections below for the
  versions, hashes, and smoke-test numbers. These two trivial calls validate plumbing only;
  they do not select a harness winner.

---

### Phase 2 — evaluation harness

**Goal.** Turn accumulated traffic into an answer about which model to run.

**Build.** Harvest and curate a task set from Phase 1 logs into `eval/tasks/` in the repo.
Graders: `nixos-rebuild build` exit code for config tasks, schema validity for extraction
tasks, human judgment where nothing automatable exists — say which is which. Provider-
agnostic (targets an OpenAI-compatible endpoint, so it runs against an API unchanged).
Results committed to the repo. First comparison: Qwen3.6-27B dense vs an MoE using
`--n-cpu-moe` expert offload into the 48GB of system RAM.

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

**Open.** The MoE counterpart is not chosen yet — pick it at build time based on what fits
the RAM budget for expert offload, and record why.

**Teaches.** Whether MoE-with-offload beats dense-on-GPU for this hardware; what quality is
actually lost at Q4; how to run an eval that isn't self-deception. This phase produces the
data for the local-vs-API decision.

**Done when.** A committed results table compares at least two models on a task set drawn
from real work with speed and quality reported together, plus a paired OMP-vs-opencode
table over the same starting worktrees and Qwen model.

---

### Phase 3 — n8n + mail ingestion (the workflow case)

**Goal.** The deterministic-pipeline half of the agents-vs-workflows experiment.

**Build.** Native `services.n8n` module — **not** a container; the module exists and
containerizing on a host that has it is strictly worse. SQLite in WAL mode (see Lifecycle
rule 6). Encryption key via sops → `EnvironmentFile`, never in the Nix store. Bind
localhost. Workflows exported to `n8n/workflows/*.json` in the repo as source of truth.
First workflow: mail forwarded to `agent@istbereit.de` → structured extraction through the
ingress → org entry in `~/org`.

**Blocked on.** The mailbox existing. Vincenzo is creating it.

**Watch for.** The backlog burst on first poll after downtime (see Lifecycle), and timer
`Persistent=` catch-up behaviour.

**Teaches.** How much of "agentic" mail handling is really deterministic plumbing plus one
extraction call. Establishes the baseline that Phase 4 must beat.

**Done when.** Mail lands in `~/org` unattended, and the workflow survives a stack restart
and a week of accumulated mail.

---

### Phase 4 — Hermes (the agent case)

**Goal.** Run a real autonomous agent, deliberately, and find out where agency earns its
cost. This is a designed experiment, not an installation.

**Build.** Hermes as a persistent worker attached to `ai-stack.target`, using the ingress
for inference. Isolated workspace under `/var/lib` with git for rollback. Tool access via
MCP where possible — the tool layer is the reusable part and should make adding Notion,
Linear, or a Paperless client later a config change rather than a code change.

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

**Build.** Wirken (https://github.com/gebruder/wirken) as the operator-facing control surface in front of Hermes, n8n, and the
coding agents: per-channel isolation, graduated approval tiers, encrypted credential vault,
hash-chained per-session audit log. Use its own security model rather than wrapping it in
homemade confirmation scripts. Credentials migrate from ad-hoc sops env files into its
vault where that makes sense — decide deliberately, since sops is already working.

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

**Done when.** Every agent path runs through Wirken, the audit log verifies, an emergency
stop works, and the friction has been tuned over at least a week of real use.

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
   224–231 ms with no llama process. Because stop deliberately uses `SIGKILL`, llama ends
   in `failed`; the wrapper accepts that terminal state. Do not add `SuccessExitStatus=KILL`:
   doing so prevents the required `Restart=on-failure` recovery after a standalone kill.
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

1. **The existing thin proxy is the correct Phase 1 ingress.** llama-swap has the best
   local multi-model switching ergonomics, but adding it for one model would introduce a
   daemon without replacing the required exact JSONL/TTFT logger. LiteLLM has stronger
   multi-provider accounting, budgets, and key management, but that operational surface is
   premature while every request is loopback-local. Add llama-swap behind the stable proxy
   when Phase 2 adds the second model. Reconsider LiteLLM as the front door when remote paid
   providers enter; do not repoint clients.
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

### Measured Phase 1 starting point

- OMP: `17.2.11`; opencode: `1.18.13`.
- Effective SHA-256 hashes: OMP `config.yml`
  `2282a72181d1212d5510762f4004df0d3df053a8646c17bebf2b556efb982cda`, OMP
  `models.yml` `0f6004411ce8992929f08f7318ad981230a5bd39578c055451a258dd6a660d7c`,
  opencode `opencode.json`
  `4f434eb720aa705adaddfdcadd61476074ff76b8dcda29cd779f2d3ffb1ea61e`.
- Paired no-tools smoke prompt: `Reply with exactly HARNESS_OK and nothing else.` Both
  returned `HARNESS_OK` against `qwen3.6-27b-local` with HTTP 200.
- OMP log record at `2026-08-08T19:09:50Z`: caller `omp`, 3,776 prompt + 33 completion =
  3,809 tokens, 3,881 ms TTFT, 4,862 ms total latency.
- Opencode log record at `2026-08-08T19:10:04Z`: caller `opencode`, 9,666 prompt + 63
  completion = 9,729 tokens, 10,469 ms TTFT, 12,803 ms total latency.
- The prompt is far too small to compare quality, and the clients carry different native
  system prompts. The token/latency difference is useful proof that the harness itself is
  now observable, not evidence that OMP has won. Complete the week of real work, then run
  paired clean-worktree tasks before drawing that conclusion.
