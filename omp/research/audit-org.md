# Instruction-file audit — `~/org/.omp/`

## Summary

| File | Lines | Est. cuttable | Notes |
|---|---|---|---|
| `.omp/AGENTS.md` | 375 | **30–40 (8–11%)** | Dense and mostly load-bearing. The real win here is **correctness, not volume**: 4 contradictions and 3 verified-stale facts. |
| `.omp/rules/aisec-prose.md` | 25 | 0 | Keep. One live defect: the prose bans a construction no condition can trigger. |
| `.omp/rules/aisec-generated-region.md` | 25 | 0 | All 3 conditions verified against markers `gen.mjs` actually emits. Clean. |
| `.omp/rules/aisec-ratification.md` | 20 | 0 | Condition fires; scope is the only file carrying the key. Clean. |
| `.omp/rules/aisec-zero-vs-dash.md` | 18 | 0 | Condition fires 193×; scope is exactly the one file with scores. Clean. |
| *(ref)* `~/nixos-config/omp/AGENTS.md` | 155 | — | Not audited by me. |

**Verdict on the two questions asked up front:**

1. **Redundancy against the global config is LOW.** I looked for it and largely did not find it. The global file governs register, critique, code standards and docs-verification; the org file governs deliverable prose, the practice, and the repo. The only near-collisions are false friends (see *Keep*). I am not going to manufacture overlap that isn't there. One genuine item at `:66`.
2. **The 'Research standard' section is a *drifting copy*, not a useful index.** Four specifics disagree with the skill. Lines 85–90 (the pointer) are a good index; lines 92–96 (the "standing method decisions" paragraph) are the drift and should go.

---

## Contradictions

### C1 — Ratification state of the catalogue (highest severity: makes the agent under-claim ratified work)

> `.omp/AGENTS.md:92-94` — "coverage unit is the **primitive**, grouped by asset domain and projected onto three planes (**A1–E12 ratified; F/G/H/J candidate groups await V's ratification**)."

versus

> `.agents/skills/ai-security-research/references/coverage-model.md:36-38` — "## Ratified catalogue — 24 primitives in 6 areas … **Ratified in full on 2026-08-06.**"
> `.agents/skills/ai-security-research/SKILL.md:60` — "`check.mjs` pins the catalogue invariants — **24 primitives**, sequential permanent ids…"

**Verified against the store**, not inferred: `reports/ai_security_matrix/data/catalogue.json` has `"ratified": "2026-08-06"` and exactly 24 primitives — `A1 A2 B3 B4 B5 C6 C7 C8 D9 D10 E11 E12 F13 F14 F15 F16 G17 G18 H19 H20 H21 J22 J23 J24` — across 6 areas (`id, obs, mod, dat, pos, ass`). `roam/main/agentic_identity.org:9` also refers to F13–J24 as ratified content living in the hub.

**Why it conflicts:** an agent reading AGENTS.md will treat F13–J24 as unratified candidates and refuse to score against them, or will re-propose a ratification that already happened. `check.mjs` pins 24 as an invariant, so the AGENTS.md claim is not merely stale, it is contradicted by an executable gate.

**Which wins:** the skill + the store. AGENTS.md must be corrected. Suggested replacement, if the paragraph is kept at all: `coverage unit is the primitive — 24 in 6 areas, ratified 2026-08-06, projected onto three planes (Govern / Enforce / Detect).` Better still: delete the paragraph (see X12) so there is only one copy to drift.

### C2 — The prose gate routes to an agent that does not exist

> `.omp/AGENTS.md:73-75` — "Note: the former `prose-reviewer` agent (`~/.claude/agents/prose-reviewer.md`) **no longer exists**. The prose gate is currently the `aisec-prose` rule plus a manual pass…"

versus

> `.agents/skills/ai-security-research/SKILL.md:62` — "**6. Prose.** Every substantive text passes the `prose-reviewer` agent, then the grep sweep it prescribes."
> `.agents/skills/ai-security-research/references/output-contracts.md:142` — "Run the `prose-reviewer` agent on every substantive text … **Self-review does not satisfy this gate.**"
> also `kickoff-prompt.md:33`, `kickoff-practice-build.md:18`

**Verified:** `~/.claude/agents/prose-reviewer.md` is absent from the filesystem.

**Why it conflicts:** SKILL.md declares six gates, all mandatory, and gate 6 is unsatisfiable. `output-contracts.md:142` explicitly forecloses the only remaining option ("self-review does not satisfy this gate"), so an agent that follows the skill literally is blocked; an agent that follows AGENTS.md silently skips a declared gate. Four files point at the corpse.

**Which wins:** AGENTS.md is factually right about the world. But the fix is upstream in the skill, not a note in AGENTS.md — see Open question Q4. AGENTS.md should state what the gate *is* in one line and drop the tombstone.

### C3 — Required evidence attributes: four vs six

> `.omp/AGENTS.md:94-95` — "Evidence discipline is a **per-claim record for all claim types** — source, tier, status, as-of — with negatives logged."

versus

> `.agents/skills/ai-security-research/references/evidence-standard.md:47` — `| Claim | Source URL | Tier | Status | As-of | Verified by |`
> `.agents/skills/ai-security-research/SKILL.md:47` — "Every claim carries source URL, evidence tier, capability status, and an as-of date."

**Why it conflicts:** three files, three shapes. AGENTS.md and SKILL.md both name four attributes; the normative table in `evidence-standard.md` has six columns, adding `Claim` and **`Verified by`**. `Verified by` is the one that matters — it is provenance of the *check*, not of the source, and it cannot be reconstructed later. An agent following AGENTS.md produces cells that `evidence-standard.md` considers defective.

**Which wins:** `evidence-standard.md:47` is the normative table. AGENTS.md should not enumerate the attributes at all — enumerate-and-drift is the failure mode. Point at the file.

### C4 — "The four guardrails police this" — only three do

> `.omp/AGENTS.md:185-186` — "**The four `.omp/rules/aisec-*.md` guardrails police this**: generated regions, ratified dates …, and `0` versus an absent key…"
> `.omp/AGENTS.md:8` — "`.omp/rules/` (**conditional guardrails for the AI-security matrix machinery**)."

versus

> `.omp/rules/aisec-prose.md:9-15` — scope is `**/*.org`, `**/*.typ`, `**/*.md` repo-wide; subject is banned prose constructions.

**Verified:** `.omp/rules/` contains exactly 4 files; 3 concern matrix machinery (`generated-region`, `ratification`, `zero-vs-dash`), 1 does not (`prose`).

**Why it conflicts:** line 185 promises four policemen and then lists three beats; line 8 mislabels the whole directory as matrix machinery, which invites an agent to assume `aisec-prose` only fires under `reports/ai_security_matrix/` when in fact it fires on every `.org`/`.typ`/`.md` write in the repo — including the one it is editing. **Fix:** "three of the four `.omp/rules/aisec-*.md` guardrails police this" at `:185`; at `:8`, "conditional guardrails — matrix machinery and deliverable prose".

### C5 — The writing standard violates its own enforced rule (self-inflicted, low severity but worth one line)

> `.omp/rules/aisec-prose.md:22` — bans "epigram closers — the neat inverted sentence that ends a section"

versus

> `.omp/AGENTS.md:55` — "Length is a correctness property: **an artefact nobody finishes has failed.**"
> `.omp/AGENTS.md:38-39` — "**the best review is the one actually done.**"

The rule's scope includes `**/*.md`, so editing AGENTS.md trips it. Both quoted clauses are exactly the construction being banned. Not a behavioural contradiction (the ban is aimed at deliverables) but it is a credibility leak in the file that teaches the ban, and both clauses are zero-behaviour anyway — see X6 and X4.

### C6 — Terminology drift: "asset domain" vs "six areas" (soft)

> `.omp/AGENTS.md:92` — "grouped by **asset domain** and projected onto three planes"

versus

> `coverage-model.md:24-28` — a three-altitude table: level 1 three planes, level 2 **six areas** ("the diagnosis — which part of the estate the conversation is about"), level 3 24 primitives.

AGENTS.md invents a term ("asset domain") for the skill's "area", and omits the middle altitude entirely — which is the one the skill says is the *client discussion unit*. Falls under vague-directive: a concrete version exists (six named areas, verified in `catalogue.json`). Resolved by cutting the paragraph (X12).

---

## Cuts

### `.omp/AGENTS.md`

| file:line | category | text (truncated) | why it goes |
|---|---|---|---|
| `:22` | historic | "Restructured 2026-04-04; these decisions are settled." | Pure provenance; instructs nothing. "Settled" only matters where re-litigation actually happens, and `:39` already says **"Do not re-expand them"** for that case. Cut whole line. |
| `:24-27` | historic | "**278 tags were consolidated to ~25** … previously useless from case inconsistency (LLM/llm/LLMs), synonyms (ac/amiconsult), and topic explosion." | The count and the failure history change no decision. **Compressed instruction:** "Canonical lowercase tags live in `roam/main/tags.org` — check it before inventing one; max 3–4 per note. Person and product names are links, not tags." ("~25" is *accurate* — verified 25 tags in `tags.org` — but the number is not actionable and will rot.) Saves ~2 lines. |
| `:30-31` | historic | "`notes.org` was merged into `roam/main/reading_list.org` — it had been a link graveyard with no processing workflow." | Dead migration note. The whole actionable residue is already at `:34` ("New reading material → `reading_list.org` with a TODO state"). **Caveat, verified:** `gtd/notes.org` still exists as a 3-line tombstone pointing at Reading List — see Q1 before deleting the sentence, since the file's continued existence is the only reason a reader might be confused. |
| `:37-39` | historic + zero-behaviour | "weekly is 3 sections **(down from a 30-minute template)** … **He never filled in the elaborate versions; the best review is the one actually done.**" | Current shapes are useful; the delta, the biographical excuse and the aphorism are not. **Compressed:** "Review templates are deliberately small — daily 2 questions plus a process checklist, weekly 3 sections, monthly moderate plus a Vision 2028 check. **Do not re-expand them.**" Saves ~2 lines. |
| `:43-44` | historic | "SailPoint, VAC, acGPT, and Agentic Identity were the most under-linked nodes, **with 20+ dailies referencing SailPoint work at zero links**." | Dated audit result from a one-off census. The instruction is complete at `:41-43`. Saves 2 lines. |
| `:48-49` | zero-behaviour | "Slop signals inattention and costs credibility." | Cannot lose an argument. Nothing in the file could contradict it and no draft is written differently because of it. The bullets below do all the work. |
| `:55` | zero-behaviour / epigram | "Length is a correctness property: an artefact nobody finishes has failed." | Epigram closer — the exact construction `aisec-prose.md:22` bans. "Length is a correctness property" is also unactionable without a number; the actionable cap lives in `output-contracts.md:14` (`## Length`). Cut the sentence, keep the two-audiences bullet. |
| `:66` | redundancy | "Say each point once. Vary sentence shape. Write plain declaratives." | Two of three are already in the enforcing copy: `aisec-prose.md:24` ("Use plain declaratives") and `output-contracts.md:110` ("Say each point once"). **Survivor: `aisec-prose.md`** — it fires at write time. **But move "Vary sentence shape" into `aisec-prose.md`'s bullet list first**; it exists nowhere else and it is the one genuinely new instruction on this line. |
| `:73-75` | historic | "Note: the **former** `prose-reviewer` agent (`~/.claude/agents/prose-reviewer.md`) **no longer exists** … recreate it as an OMP agent if an automated gate is wanted again." | A tombstone plus a speculative future. **Compressed instruction:** "The prose gate is the `aisec-prose` rule plus a manual pass; there is no reviewer agent." (Keep the negative — it is load-bearing precisely *because* four skill files still route to it, see C2.) Saves 2 lines. |
| `:79` | redundancy | "Thorough beats fast." | Restated concretely by the next clause ("No time-boxing that drops coverage") and duplicated at `SKILL.md:18`. Survivor: the concrete clause. |
| `:92-96` | **redundancy + contradiction source** | "Standing method decisions: coverage unit is the **primitive** … (A1–E12 ratified; F/G/H/J candidate groups await V's ratification). Evidence discipline is … source, tier, status, as-of … Requirements catalogue is **ours first**; the thesis derives from it with attribution." | **The single highest-value cut in the file.** This paragraph is the source of C1, C3 and C6 — three of the four contradictions — and every fact in it is normatively owned elsewhere: catalogue state by `catalogue.json` + `coverage-model.md:36`, evidence shape by `evidence-standard.md:47`, thesis derivation **already stated inside AGENTS.md itself at `:229-232`**. `:85-90` (the pointer to the skill) is a good index and survives. Saves 5 lines and removes the drift surface. |
| `:110` | historic | "This is where the value is: **it surfaced that Zenity had repositioned twice, each time into a bigger and more contested market.**" | Borderline — it is the proof the instruction pays off, and Zenity is a live partner. **Compress rather than cut:** "This is where the value is — it caught a partner repositioning twice into successively more contested markets." Drops the dated specific, keeps the demonstration. Saves ~1 line. |
| `:162-163` | zero-behaviour | "**Standard:** output at the level of someone who speaks at security conferences and is invited onto major vendors' podcasts." | Unfalsifiable self-image; no draft is measurable against it, and `:141-142` already sets audience calibration concretely ("Lead AI Security Consultant"). **Keep the second half** (`:163-164`, "Every deliverable adaptable to a customer- or partner-facing document with minimal effort") — that one *is* testable and it is what `lint-external.mjs` exists to check. Saves 2 lines. |
| `:168-173` | historic | "The original agentic-identity work **has been widened** to AI Security as a whole … **What moved in scope** at the higher altitude … everything the architecture figure **used to draw** below the identity line." | Narrates a transition instead of stating the current state. **Compressed, present tense:** "Scope is AI Security as a whole, not the identity slice: prompt-injection defence, model alignment and red-teaming, data classification and DLP, MCP tool catalogs. Recommend vendor *combinations* covering all threats." Saves ~3 lines. |
| `:188` | redundancy | "(a `0` is a finding about the vendor; omission is an admission about us — **this confusion once produced 57 wrong zeros**)" | Triplicated: `aisec-zero-vs-dash.md:11-17` and `coverage-model.md:32-34`. **Survivor: the rule** — it fires at the moment of the mistake, which is the only place a war story earns its keep. Reduce `:187-188` to "…and `0` versus an absent key." Saves 1 line. |
| `:194-195` | historic | "**The original send was targeted at the week of 2026-08-10**; check this directory for actual state before treating anything here as pending." | The date is dead. **Verified current state:** the directory holds `sailpoint_review_pack.typ/.pdf` and `zenity_review_pack.typ/.pdf` (built 2026-08-17), plus copied `brand.typ`/`report.typ`/`logo.png`. **Compressed:** "Check this directory for actual state before treating anything here as pending." Saves 1 line. |
| `:245` | historic | "— **misreading it as positioning has caused two correction cycles**." | The incident count adds nothing to the directive it trails, which is already emphatic ("**internal execution notes, never as external positioning**"). Cut the clause. |
| `:371` | zero-behaviour | "— **layout holds**." | Reassurance. The actionable part (Gotham falls back to Helvetica/Arial elsewhere) precedes it. |
| `:373-375` | **stale factual** | "Two known gaps: `card()` … awaiting V's house treatment, and **the existing documents under `reports/*` were never migrated to import the template — they still carry their own copied preambles.**" | **Half false, verified.** Four files *do* import `_template` now: `agentic_identity_market_comparison_2026/comparison.typ`, and `agentic_identity_reference_architecture_2026/{agent_flow,ai_security_reference_architecture,reference_architecture}.typ`. Three directories still carry copied `brand.typ`: `ai_security_partner_review_2026/`, `iam_for_ai_workshop_2026/`, `metro_org_data_poc/`. **Rewrite naming those three** rather than sweeping all of `reports/*`. (`card()` claim is *true* — verified still the generic `grau-7` / 12pt / radius-3pt block at `brand.typ:119-125`; see Q5.) |

### Stale factual claims — separately, because these are corrections not cuts

| file:line | claim | verified reality |
|---|---|---|
| `:370` | "Typst 0.14.2" | **`typst --version` → 0.15.1.** Stale by a minor version. |
| `:93` | "F/G/H/J candidate groups await V's ratification" | **`catalogue.json` → `"ratified": "2026-08-06"`, all 24 primitives present.** See C1. |
| `:374-375` | "documents under `reports/*` were never migrated" | **4 files migrated, 3 directories not.** See table above. |
| `:73` | `~/.claude/agents/prose-reviewer.md` | **Absent** — the file is correct that it is gone; the *skill* is the stale party. See C2. |
| `:185` | "The four … guardrails police this" | **Three do.** See C4. |
| `:86` | `.agents/skills/ai-security-research/` | **Correct.** Today's move landed. Grepped `.omp/` and `.agents/` for `.claude/skills` — **zero hits.** No stale pointer survives anywhere. |
| `:180` | `.claude/workflows/agentic-market-watch.js` | **Exists.** But it and `.claude/settings.local.json` are now the *only* things left under `.claude/` — see Q2. |

**Every other path claim in the file checks out.** I verified, not guessed: `reports/ai_security_matrix/` and all six named scripts (`gen.mjs`, `check.mjs`, `ratify.mjs`, `brief.mjs`, `lint-external.mjs`, `matrix.html`) plus all six named `data/*.json` — all present (there are two extras the file does not mention: `slotting-log.json`, `lib/`); `reports/_template/` with `brand.typ`, `report.typ`, `deck.typ`, `logo.png`, `example-report.typ`, `example-deck.typ` and both PDFs; `reports/agentic_identity_reference_architecture_2026/` including `reference_architecture.typ`, `agent_flow.typ`, `architecture.typ`, `arch_A`–`arch_E`, prospect and sales decks, `pitch_guide.org`; `reports/ai_security_partner_review_2026/`; and every named roam node (`agentic_identity.org`, `agentic_identity_market_watch.org`, `tags.org`, `reading_list.org`, `bereit_consulting.org`, `hewitech.org`), plus `gtd/projects.org` and `gtd/inbox.org`. The `brand.typ` inventory at `:357-359` is exact — all eight colour tokens (`ac-gelb/orange/pink/lila`, `schwarz`, `grau-60`, `grau-7`, `weiss`) and all eight components (`callout`, `keyfinding`, `recommendation`, `term`, `score-cell`, `asof`, `chip`, `card`) exist; `report.typ` exports `part()` as claimed; `deck.typ` exports `slide`, `divider`, `statement`, `persona` as claimed. Gotham **is** installed (`GothamSSm`). The hub-node claims at `:175` ("12 primitives A–E, T1–T13, 15 profiled vendors") match `agentic_identity.org:68` ("12 primitives across 5 groups"), T1–T13 present, and `:9` ("the fifteen scored identity vendors"). `:178-179` matches `agentic_identity_market_watch.org:14` ("Design — five principles"), `:21` Cadence, `:51` Watchlist.

### Missing concrete path (vague directive)

| file:line | text | fix |
|---|---|---|
| `:176` | "the AI-Security node **sits above and alongside it**" | The file never names it. **It is `roam/main/ai_security.org`** — verified present, and `agentic_identity.org:9` calls it "the hub across all six control areas", `coverage-model.md:38` makes it authoritative for F13–J24. Two sibling nodes are also unnamed and authoritative: `roam/main/ai_security_catalogue_extension.org` (ratification evidence) and `roam/main/ai_security_research_log.org` (`SKILL.md:35`, the run record). The §Scope and artefacts bullet list omits all three while listing lesser artefacts. **Add them; this is the one place the file should get longer.** |

### The four rules

**No overlap between them.** Verified pairwise: no shared condition regex, and their scopes are disjoint on the files that matter (`vendors.json` / `ratification.json` / generated-region markers / prose in `.org|.typ|.md`). No cuts.

**Every condition can fire — I tested all four against real content:**

| rule | condition | fires? |
|---|---|---|
| `aisec-zero-vs-dash.md:5` | `"score":\s*"0"` | **Yes, 193×.** Scores are strings — `"0"` (193), `"½"` (145), `"✓"` (52), `"✓✓"` (7). Had they been numeric this regex would have been dead; they are not. |
| `aisec-ratification.md:5` | `"ratified":\s*"\d{4}` | **Yes, 2×** (both `"2026-08-06"`; 4 more passes sit at `null`, consistent with "sweep proposes / human promotes"). |
| `aisec-generated-region.md:5-7` | `#\+BEGIN: aisec`, `<<gen:`, `GENERATED by …gen\.mjs` | **All three match markers `gen.mjs` actually emits** — `gen.mjs:9-11` documents the three marker syntaxes, `:29-30` the two banner forms, and `:78/:97/:128/:167/:174/:212/:220` write them. |
| `aisec-prose.md:5,7,8` | `\bstructurally\b`, `is not [a-z ]+\. It is`, `[Nn]ot [a-z]+ — [a-z]+\.` | **Yes** — `structurally` in 10 files, `is not X. It is` 7×. The dash-antithesis has 0 existing hits, which is the *intended* end state, not a dead regex — conditions match text being written. |

**Scopes match the prose — with two verified precision notes:**

- `aisec-zero-vs-dash.md:7-8` scopes only `**/vendors.json`. **This is exactly right, verified:** `"score"` appears 397× in `vendors.json` and **0×** in the other six `data/*.json` files. Not over- or under-scoped.
- `aisec-generated-region.md:9-14` scopes `.org`, `.typ`, `.html`. `gen.mjs:97/:128/:167/:174` targets org regions in `ai_security.org` and `agentic_identity.org` — but **zero `.org` files currently contain `#+BEGIN: aisec`** (verified). The rule is correctly specified; the *repo* state means it can presently only fire on `matrix.html` and `ai_security_reference_architecture.typ`. Not a cut — see Q3.

**Two real defects in `aisec-prose.md`:**

| file:line | category | issue |
|---|---|---|
| `aisec-prose.md:20` vs `:5-8` | **dead-lettered prose** | The bullet bans "the **'X, not Y' antithesis** used as a headline, a refrain, or a closing line" — and **no condition matches the commonest form, the bare comma construction `X, not Y`.** `AGENTS.md` alone contains 12 instances (`:28` "links, not tags"; `:259` "Full journey, not project handoff"; `:307` "missing data substrate, not … weak models"; `:232` "not a competing model"…) and **none of them trip any of the four regexes** — I ran all four against the file: zero hits. The single most-banned construction in the rule is the one with no trigger. Add a condition, e.g. `[a-z]{3,}, not [a-z]{3,}` (accept the false-positive rate — this is a review prompt, not a blocker). |
| `aisec-prose.md:6` | brittle regex | `It's not (about )?[a-z]+, it's` hardcodes the ASCII apostrophe. A model writing "It's not X, it's Y" with the typographic `’` slips through, and this repo uses typographic punctuation and em-dashes heavily (the other conditions already assume `—`). Make the apostrophe a class: `It['’]s not (about )?[a-z]+, it['’]s`. |

### Writing standard — which half belongs where

The split should follow one test: **can a regex see it at write time?**

**Belongs in `aisec-prose.md`** (mechanical, fires at the moment of the offence):
- `AGENTS.md:66` "Write plain declaratives" → already `aisec-prose.md:24`. Duplicate; cut from AGENTS.md.
- `AGENTS.md:66` "Say each point once" → already `output-contracts.md:110`. Duplicate; cut from AGENTS.md.
- `AGENTS.md:66` "Vary sentence shape" → **exists nowhere else. Move it into the rule, do not just delete it.**
- `AGENTS.md:63-65` Voice → duplicated at `aisec-prose.md:24-25` and `output-contracts.md:106`, but **the rule's copy is the thinner one**: it lacks "Never the faceless grand-institutional voice — the audience knows who wrote it", which is the clause that actually catches the failure. **Enrich `aisec-prose.md:24-25` with it, then reduce `AGENTS.md:63-65` to a pointer.**

**Must stay in `AGENTS.md`** (judgement; no regex can see it, and it must apply when the skill is not invoked):
- `:51` BLUF — a document-structure decision made before the first sentence exists.
- `:52-55` Two audiences at once — governs what goes on the first screen.
- `:56-59` Teach, don't assume / the glossing rule — depends on whether a concept has appeared before.
- `:60-62` Sources decide credibility — governs whether a claim ships at all.

**Consequence:** the `## Writing standard` section loses `:48-49`, `:55`, `:66` and shrinks `:63-65` to one line — about 5 lines — while the *enforced* surface gets strictly stronger (one new condition, one fixed regex, two clauses moved into the rule).

---

## Keep despite looking cuttable

Over-cutting is the failure mode here. These all read like cruft and all change behaviour.

1. **`:12-18` — the `.org`/never-Markdown rule, *including* the outward extension.** Reads like a preference stated twice at length. The second paragraph (`:16-18`) is the load-bearing half: it covers the case an agent gets wrong — writing a deliverable *inside a non-org code repo* (the named IAME `companies` Java repo) where every local convention says `.md`. Without that clause the rule looks repo-scoped and will be violated exactly where it matters. Keep both paragraphs.

2. **`:68-71` — "hand them that rule as a hard guardrail and grep-verify afterwards — subagents have repeatedly reintroduced exactly those tells."** Reads like a war story and is duplicated at `SKILL.md:62`. Keep it here anyway: **a rule cannot fire on a subagent's in-context draft**, only on a write. This is the only instruction in the entire setup that says *you*, the parent, must grep the returned prose. The `.md` scope of `aisec-prose` does not save you. Load-bearing and structurally irreplaceable.

3. **`:154-160` — the AI-sceptical buyer and the economic case.** Reads like market colour and is duplicated at `SKILL.md:10` and `playbooks.md §7`. Keep: **the skill is conditionally loaded, this file is not.** It changes the *content* of every recommendation (cost-of-control vs cost-of-incident, plus the enablement argument) and it explicitly forbids a premise an agent will otherwise assume — `:159-160` "Do not assume the value of AI is a shared premise." That last sentence is the whole point and it can lose an argument.

4. **`:197-201` — the externalisation rule.** Reads redundant now that `lint-external.mjs` exists. Keep: the linter finds client identifiers and commercial reasoning, but **it cannot know that "absorbability", "platform-gravity exposure", "the universal-holes thesis as a sales weapon" and "per-vendor scoring relative to their rivals" are the four named categories** that must not travel. This is the highest-cost failure mode in the repo — competitive judgment reaching a partner — and the enumeration is the instruction.

5. **`:229-235` — thesis/practice model management and the pre-GA check.** Reads like project narration. Keep both halves: the three-plane-vs-five-layer relationship is the thing that, left implicit, makes two artefacts drift until *neither can cite the other* (`:232`), and "Silverfort **Fabrix** plus parts of the SailPoint/Zenity agent surface are pre-GA … check availability before the student commits to a capability" is a concrete gate on a decision with a long lead time. Also the only place the file survives cutting `:95-96` — the thesis-derivation rule lives *here*.

6. **`:190-191` — "re-scoped from agentic identity to AI Security".** Reads like exactly the provenance cruft I cut elsewhere. **Keep it**, because the *directory name still says* `agentic_identity_reference_architecture_2026` while the content is AI Security — verified: the directory holds both `reference_architecture.typ` and `ai_security_reference_architecture.typ`. The narration is the only thing reconciling a misleading path with its contents. Provenance that resolves a live ambiguity is not cruft.

7. **`:275-294` — the Bereit brand system.** Reads like a brand book an agent has no use for. Keep: there is no other machine-readable source for it (no brand repo, no `brand.typ` equivalent for Bereit — checked), and this is precisely the specificity that stops an agent inventing a logo or reaching for a gradient. `:276` "The slogan is **context, not part of the logo lockup**" is one clause preventing one concrete, likely, embarrassing error. `:288` gives literal hex values.

8. **`:306-310` — "Leapfrog is a trap".** Reads like an opinion essay. Keep: it **inverts the recommendation an agent would otherwise default to** (skip ahead to autonomous agents) and replaces it with a named mechanism ("Agents fail from a missing data substrate, not from weak models") plus a concrete instantiation (RFQ → structured quote draft as CRM-fill + extraction + drafting). A line that reverses the default answer is the opposite of zero-behaviour.

9. **`:344-347` — family-client traps.** Reads like gossip about Kyrill's uncle. Keep: it changes engagement *design* — run it scoped, priced and measured; negotiate case-study and reference rights **upfront**; and the diagnosis-bias warning ("Kyrill's view is likely shop-floor, not the office bottleneck") is the antidote to the file's own thesis at `:342`. It tells the agent to distrust the wedge it was just handed.

10. **`:369` — "Golden rule: copy an example; never edit `brand.typ`, `report.typ`, or `deck.typ`."** Looks triply redundant with `reports/_template/CLAUDE.md:9-12`, `SKILL.md:34` and `output-contracts.md`. Keep: **`reports/_template/CLAUDE.md` is not auto-loaded by this harness** — verified, the only instruction files are `.omp/AGENTS.md` and `.omp/rules/*`, and `CLAUDE.md` sits in a report directory under a filename OMP does not load. `AGENTS.md:369` is the only always-on copy of a rule that protects a shared engine used by every document.

11. **`:150-152` — client tier with named companies.** "Aldi, Metro, Deutsche Bank as the calibre; ≥€1–2B revenue, ≥5000 staff" reads like padding around "large enterprise". Keep: named calibre plus numeric thresholds is *testable* against a prospect in a way "large enterprise" is not, and "**Not Mittelstand — that is Bereit (below)**" is the disambiguation that keeps two practices with opposite positioning from bleeding into each other inside a single 375-line file. In a file that serves amiconsult *and* Bereit, the separator earns its line.

12. **`:31-33` — the `projects.org` Active/Areas/Archive split.** Sits in a paragraph I am otherwise cutting for being historic, and the phrasing ("is split into") reads like a migration note. It is not: it describes the **current** structure and gives the discriminator ("active projects have clear 'done' criteria, Areas … are ongoing") that decides where a new item goes. Keep, tighten the parenthetical examples if anything.

---

## Open questions

1. **`gtd/notes.org` still exists** — a 3-line tombstone: `#+title: Notes` plus "Content moved to [[…][Reading List]] on 2026-04-04." Delete the file (and then `AGENTS.md:30-31` goes cleanly), or keep the tombstone for link integrity (and then `:30-31` should say so in one clause instead of narrating the merge)? Not derivable from the files.

2. **Should `.claude/workflows/agentic-market-watch.js` move to `.agents/`?** After today's skills move, `.claude/` holds only that file plus `settings.local.json`. It is referenced from **two** places — `AGENTS.md:180` and `SKILL.md:32` — so the move and both edits must land together or one pointer breaks. I have not moved it (read-only remit) and cannot infer whether OMP resolves `.agents/workflows/`.

3. **Has `gen.mjs` ever run against its org targets?** `gen.mjs:97/:128/:167/:174` writes regions into `roam/main/ai_security.org` and `roam/main/agentic_identity.org`, but **no `.org` file in the repo contains `#+BEGIN: aisec`** (verified). Either it has never run, or the regions were stripped by hand. This decides whether `check.mjs`'s hub-vs-matrix agreement invariant — the one `output-contracts.md:134` says was built after an audit found 49 disagreements — is currently checking anything at all. Genuinely cannot tell from the files which it is.

4. **Recreate the prose gate as an OMP agent, or ratify "rule + manual pass" as the gate?** This blocks C2. Four files (`SKILL.md:62`, `output-contracts.md:142`, `kickoff-prompt.md:33`, `kickoff-practice-build.md:18`) route to a nonexistent agent, and `output-contracts.md:142` forbids the fallback ("Self-review does not satisfy this gate"). The correction differs completely depending on the answer — recreate, or rewrite gate 6 in all four files to name `aisec-prose` plus the grep sweep. Needs a decision before anyone edits.

5. **Is `card()` still awaiting treatment?** `AGENTS.md:373` says it is; verified still generic (`brand.typ:119-125`, `grau-7` fill, 12pt inset, 3pt radius). If the default has been silently accepted in practice, the line is a stale TODO and goes; if not, it is a live warning and stays. Only V knows.

6. **Does the global file's "do not default to solutions" gate apply to research runs?** `~/nixos-config/omp/AGENTS.md:32-40` says probe before implementing; `.omp/AGENTS.md:79-83` expects hour-long autonomous sweeps. I read this as **already resolved** — global `:37-40` scopes itself to *design* decisions and explicitly defers to the harness's complete-deliverable contract, so a research run is execution, not design. Flagging it only because it is the one place the two files could be read as pulling opposite ways, and a one-clause note in the org file's Research standard would close it permanently. Not counted as a contradiction.