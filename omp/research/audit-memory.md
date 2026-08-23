# Audit: `~/.claude/memory/` — index accuracy, staleness, duplication, contradiction

**Scope note.** `user_preferences.md`, `user_operating_system.md`, `user_psychological_origins.md`, `user_psychometric_profile.md`, `user_relationships.md`, `feedback_self_calibration.md` and parts of `user_personal_goals.md` / `user_career_strategy.md` were audited **structurally only** — index fit, cross-reference validity, frontmatter, dated metadata, overlap. No personal or psychological content is quoted, summarised or characterised below. Where a staleness finding requires pointing at content, it is named abstractly ("a family life-event", "a numeric target").

---

## Summary

**Store total: 879 lines across 25 files (24 entries + index).**

| file | lines | est. cuttable |
|---|---|---|
| MEMORY.md | 33 | 5 lines outright + 4 lines heavily over-long |
| user_profile.md | 93 | ~10 |
| user_career_strategy.md | 64 | ~10 |
| user_preferences.md | 60 | ~13 |
| user_psychological_origins.md | 59 | ~9 |
| user_operating_system.md | 58 | ~5 |
| project_learning_roadmap.md | 52 | ~13 |
| reference_amiconsult_brand.md | 51 | ~6 |
| user_personal_goals.md | 44 | ~8 |
| reference_emacs_native_comp_libgccjit.md | 39 | 6 (frontmatter only) |
| reference_emacs_reader_mupdf_rebuild.md | 33 | 6 (frontmatter only) |
| project_startup.md | 29 | ~7 |
| reference_aerospace_video_flicker.md | 29 | 5 (frontmatter only) |
| user_psychometric_profile.md | 27 | ~9 |
| user_relationships.md | 27 | ~6 |
| reference_macos_tcc_troubleshooting.md | 27 | 5 (frontmatter only) |
| project_amiconsult_isc.md | 24 | 5 (frontmatter only) |
| project_zed_config.md | 23 | ~7 |
| feedback_verify_against_real_artifact.md | 22 | **22 (whole file)** |
| user_languages.md | 19 | ~13 |
| reference_doom_emacs.md | 17 | 5 (frontmatter only) |
| user_ml_background.md | 16 | ~8 |
| feedback_rust_decision.md | 11 | **11 (whole file)** |
| feedback_self_calibration.md | 11 | **11 (whole file)** |
| feedback_verify_before_asserting.md | 11 | **11 (whole file)** |

**Estimated cuttable: ~205–210 lines (~24% of the store).**

Three structural facts dominate everything below:

1. **Index membership is perfect; index *descriptions* are not.** Diffed mechanically: all 24 linked filenames in `MEMORY.md` exist on disk, and all 24 files on disk are linked. Zero orphans, zero dangling links. Every index defect is a **description-drift** defect, and since `MEMORY.md` is the only always-loaded file, a drifted description is worse than a missing one — it makes the agent skip an entry it needed, or load one on a false premise.
2. **139 of 879 lines (16%) are YAML frontmatter that nothing reads.** Verified: `~/nixos-config/hm-modules/claude.nix` touches `memory/` only as a Syncthing whitelist entry (`claude.nix:39`, `!/memory`); `~/nixos-config/omp/AGENTS.md:140-142` specifies the protocol as "read `MEMORY.md`… it is an index of one-topic files" — filename-based, no field lookup; `grep -rl` across `~/.omp` and `~/.config/omp` for `.claude/memory|MEMORY.md` returns only session transcript `.jsonl` files, no indexer config. See caveat in *Keep despite looking cuttable*.
3. **The entire `## Feedback` section of the index is now dead.** Three of four `feedback_*` entries have been promoted into `RULES.md` verbatim; the fourth is duplicated inside `user_profile.md`. Details in *Promoted feedback* below.

---

## Contradictions

### C1 — Coding cadence: a percentage vs a monthly count
- `user_profile.md:62` — "Day job is ~70% consulting/integration, **~30% code** — needs deliberate practice outside work"
- `user_languages.md:14` — "his day-job coding has dropped to **roughly once a month** — his amiconsult role … is research/pre-sales/strategy, not hands-on implementation"
- `user_ml_background.md:12` — "codes **roughly once a month**"

30% of a working week and once a month differ by more than an order of magnitude, and they drive opposite advice: 30%-code justifies "you get reps at work", once-a-month justifies "the reps must come from outside work". **Winner: once a month** — it is dated 2026-08-19 in two independent entries and is corroborated by the role description; `user_profile.md:62` predates it. Fix `user_profile.md:62` to defer to `user_languages.md`.

### C2 — Is Go a live language?
- `user_profile.md:53` — "Primary languages: Python, Java, **Go**, Rust, Nix, BeanShell (ISC rules)"; corroborated by `user_profile.md:93` listing **gopls** among active LSPs
- `user_languages.md:19` — "LIBRARY (safe to deprioritize): Swift, Kotlin, **Go**, C++, … — user has not indicated active use"

One file lists Go as primary, the other as inactive-and-deprioritisable, and `user_languages.md:3` advertises itself as the file to "use when classifying skills/agents for code repos, recommending stacks, or pruning installs" — i.e. the contradiction is load-bearing on a pruning decision. **`user_languages.md` should own the language list** (it is the purpose-built, more recently maintained entry); `user_profile.md:53` should be cut to a pointer. Go's status is a genuine open question — see *Open questions*.

### C3 — Company-founding date
- `project_startup.md:21` — "**Company founding target: July 1, 2026** — hard date, not aspirational" (section header `project_startup.md:20` stamps this "as of 2026-04-09")
- `user_profile.md:14` — "Long-term goal: build own AI startup (target: **~1 year from now, ~2027**)"

A "hard date, not aspirational" and "~2027" cannot both hold. Compounding it, the hard date is now **~7 weeks in the past** with no entry recording whether it was met — see S1. **Neither wins as written**; both need replacing with the actual current status.

### C4 — Exit is trigger-gated vs already in motion
- `user_career_strategy.md:15` — "**Exit trigger (observable, not date-based):** wife finishes her apprenticeship AND baby enters kita. Both conditions remove the no-relocation constraint and unlock the job switch."
- `user_career_strategy.md:60` — "The '2 years' timeline needs a **trigger**, not a date — otherwise it slips to 4."
- `user_career_strategy.md:30` — "Shift from the relocation-triggered exit above: he is **actively interviewing now** … so the kita/apprenticeship trigger **does NOT gate this move**."

Line 30 explicitly retires the framing at lines 15 and 60, but both survive above and below it in the same file, so an agent reading top-down forms the wrong model and an agent reading the "Implications" tail (line 60) re-derives it. **Winner: line 30** (2026-06-24, latest). Lines 15 and 60 must be rewritten as superseded-history in one clause or cut.

### C5 — Degree title
- `user_profile.md:11` — "Education: **M.Sc. Computer Science, KIT** … focus on ML"
- `user_preferences.md:12` — "ML background (M.Sc. KIT)"
- `user_ml_background.md:10` — "completed a **full Master's degree in Machine Learning** at university"

CS-with-ML-focus and a Master's *in* ML are different claims. This matters because `user_ml_background.md:10` uses the stronger claim to license "do not explain ML fundamentals from scratch" — the instruction is probably still right, but it is resting on an inflated premise, and the inflation will be repeated back to the user in conversation. **Winner: `user_profile.md:11`** (specific institution and programme).

### C6 — Job title, three spellings
- `user_profile.md:63` — "**Lead AI consultant** at amiconsult"
- `user_career_strategy.md:18` — "CV credentials (**Lead AI Consultant**, Head-of-AI track, EIC delegate…)"
- `user_languages.md:14` and `user_ml_background.md:12` — "**Lead AI Security Consultant**"

The "Security" qualifier is exactly the part that carries the argument in the two newer entries (security-side, not implementation-side). Pick one, in `user_profile.md`, and have the rest point at it.

### C7 — Headcount, inside one file
- `user_profile.md:30` — "currently has **3 students + 1 associate consultant** working under him"
- `user_profile.md:64` — "Currently has **4 students** reporting to him"

Same file, 34 lines apart. Line 30 is the more specific claim.

### C8 — Tool path, inside one file
- `reference_amiconsult_brand.md:34` — "Geometry extractor: `scratchpad/dump_slide.py`"
- `reference_amiconsult_brand.md:43` — "`tools/dump_slide.py` (geometry extractor)"

Verified on disk: `~/Downloads/amiconsult-typst/scratchpad/dump_slide.py` **does not exist**; `tools/dump_slide.py` **does**. Line 34's path is stale; line 43 wins.

### C9 — A success criterion that licenses under-delivery (memory vs global config)
- `user_preferences.md:29` — success criterion: "he **relies less on the agent for solutions**"
- `~/nixos-config/omp/AGENTS.md:24-26` — "Inside the overlap, the harness sets the mechanism and this file sets the content. 'Challenge my understanding' **never becomes a reason to block, ask permission, or ship less than a complete deliverable**; the challenge travels alongside the finished work."

Read as a target-state observation, `user_preferences.md:29` is harmless but does nothing (see Z1). Read as an instruction — which is how anything in the memory store gets read — it is a standing reason to withhold a solution, which `AGENTS.md:24-26` explicitly forbids. This is the one place where memory can actively degrade delivery. **Winner: `AGENTS.md:24-26`.** The whole block `user_preferences.md:27-31` should go; the Precedence block already resolves the domain split and needs no restatement in memory.

### C10 — Seniority bar vs seniority target
- `user_preferences.md:8-9` — "Not yet senior/staff level — explicitly aspires to become exceptional / Wants to be held to the senior/staff bar even though he's not there yet"
- `user_profile.md:52` — "actively working to reduce dependency to build confidence and independence, **not to reach staff-engineer level**"; `user_profile.md:28`, `user_profile.md:50` — "wants technical fluency … **not technical mastery**"; `user_personal_goals.md:35` — "**NOT pursuing:** Staff Engineer title, deep IC path, CTO role"

Not a strict contradiction — `user_preferences.md:9` is a *review standard*, `user_profile.md:52` is a *career destination* — but the words "staff level" appear on both sides with opposite polarity, and an agent resolving them by recency or proximity will get one of them backwards. Fix by disambiguating in place: review bar vs career target. Note also that `user_preferences.md:9-10` is a near-restatement of `AGENTS.md:3-9` ("senior/staff-level engineer", "maximize my long-term growth… not… speed or convenience", "Assume I can handle critique") — the always-loaded file wins; only `user_preferences.md:8`'s factual half ("not yet at that level") is additive.

---

## Index drift (`MEMORY.md`)

Membership is exact (24/24 both directions). These are description defects, all in the only always-loaded file.

| line | index says | file actually says | verdict |
|---|---|---|---|
| `MEMORY.md:7` | "fitness (**550kg total**), Japanese (**N3/N2**)" | `user_personal_goals.md:8` — the 550kg figure is explicitly retired as unrealistic; `user_personal_goals.md:14` and `:28` — the N2 target is explicitly cut; `user_personal_goals.md:29` — specific powerlifting numbers cut | **Confirmed drift.** The index advertises two targets the entry deleted, and the entry's own frontmatter (`user_personal_goals.md:3`) already says "revised". Worst-case failure: the agent cites a retired number back to the user from the index without opening the file. |
| `MEMORY.md:7` | "**Non-tech goals**" | `user_personal_goals.md:31-37` is a "Career Path" section — mid-term title, long-term CEO role, public-profile ramp | Description excludes a section that is 7 of the file's 44 lines and overlaps `user_career_strategy.md`. See D3. |
| `MEMORY.md:9` | "**Volentum CEO as current exit broker**" | `user_career_strategy.md:42` dates the Volentum signal "as of 2026-05"; `user_career_strategy.md:28-32` (2026-06-24) records two **live, named interview processes** reached by other routes, and `:36` records an open decision frame with named blockers | **Drift.** The index foregrounds the superseded broker and omits the live processes — the single most decision-relevant thing in the entry. |
| `MEMORY.md:9` | "building Bereit on the side **using employer publicity**" | `user_career_strategy.md:52` — "**Key clarification:** he is NOT advertising the side business on the employer platform… The personal brand is his; the employer brand is the employer's. This is the legally and strategically clean version." | **Drift, and in the risky direction.** The index compresses to exactly the claim the entry was written to deny. An agent that loads only the index will reason about a legal exposure the user has explicitly structured away. Highest-priority index fix. |
| `MEMORY.md:10` | 41 words duplicating almost the whole of `user_ml_background.md`, including the four MLE domains verbatim from `user_ml_background.md:14` | — | Redundancy inside the always-loaded file. An index line is a pointer, not a copy. Same fault, milder, at `MEMORY.md:12` (33 words, reproduces the five strength themes and the caveat from `user_psychometric_profile.md:19,21,27`) and `MEMORY.md:13`. |
| `MEMORY.md:18` | "ARENA, nanoGPT, paper reading group, Rust, startup prep timeline" | `project_learning_roadmap.md:22-29` is an 8-line "AI at Amiconsult (Active Work Projects)" section — named live work projects — and `:31-34` is "Startup Technical Decisions". Neither is mentioned | Description omits the most operationally useful half of the entry, so the agent won't open it when the topic is current work. |

---

## Frontmatter vs filename

`name:` mismatches its filename in **20 of 24 entries** (only `user_ml_background.md`, `user_psychometric_profile.md`, `reference_emacs_native_comp_libgccjit.md`, `reference_emacs_reader_mupdf_rebuild.md` agree):

| file | `name:` value (line 2) |
|---|---|
| `feedback_rust_decision.md:2` | `rust-decision-settled` |
| `feedback_self_calibration.md:2` | `self-calibration-pattern` |
| `feedback_verify_against_real_artifact.md:2` | `feedback-verify-against-real-artifact` |
| `feedback_verify_before_asserting.md:2` | `verify-before-asserting` |
| `project_amiconsult_isc.md:2` | `amiconsult-isc-rules` |
| `project_learning_roadmap.md:2` | `learning-roadmap` |
| `project_startup.md:2` | `startup-hewitech` |
| `project_zed_config.md:2` | `zed-config` |
| `reference_aerospace_video_flicker.md:2` | `AeroSpace video-player workspace flicker` |
| `reference_amiconsult_brand.md:2` | `reference-amiconsult-brand` |
| `reference_doom_emacs.md:2` | `doom-emacs-config` |
| `reference_macos_tcc_troubleshooting.md:2` | `macOS TCC permission troubleshooting` |
| `user_career_strategy.md:2` | `user-career-strategy` |
| `user_languages.md:2` | `User Programming Languages` |
| `user_operating_system.md:2` | `user-operating-system` |
| `user_personal_goals.md:2` | `personal-goals` |
| `user_preferences.md:2` | `user-preferences` |
| `user_profile.md:2` | `user-profile` |
| `user_psychological_origins.md:2` | `user-psychological-origins` |
| `user_relationships.md:2` | `key-relationships` |

**Does it matter for retrieval? No — and that is the finding.** Retrieval is 100% filename-based: `AGENTS.md:141-142` instructs reading `MEMORY.md` and opening entries from it, and `MEMORY.md` addresses every entry by markdown link to its filename. No consumer of `name:` exists in `~/nixos-config` or `~/.omp` (evidence in Summary point 2). So the mismatches are harmless *and* the field is inert.

The mismatch set is nonetheless diagnostic: three separate naming conventions coexist (kebab-case slug, filename-echo, free-text title at `reference_aerospace_video_flicker.md:2` / `reference_macos_tcc_troubleshooting.md:2` / `user_languages.md:2`), which is what you'd expect from a field no tool validates. Two frontmatter *shapes* also coexist — top-level `type:` in 16 files vs nested `metadata:\n  type:` in 8 (e.g. `user_career_strategy.md:4-6`, `user_ml_background.md:4-7`, `reference_amiconsult_brand.md:4-5`) — further evidence nothing parses it.

**Recommendation: delete frontmatter wholesale (139 lines, 16% of the store), not repair it.** `type:` is already triple-encoded — in the filename prefix, in the `MEMORY.md` section heading, and in the field. `description:` is a second copy of the `MEMORY.md` index line. `node_type: memory` (`user_career_strategy.md:5`, `user_psychological_origins.md:5`, `user_psychometric_profile.md:5`) is a tautology inside the memory directory.

---

## Cuts

### MEMORY.md (33 lines)
| file:line | category | text (truncated) | why it goes |
|---|---|---|---|
| `MEMORY.md:29-33` | redundancy | `## Feedback` + 4 entry lines | All four entries are superseded — see *Promoted feedback*. Removing them removes the section heading too: 5 lines off the always-loaded file. |
| `MEMORY.md:10` | redundancy | "Full ML Master's (strong theory); day-job coding down to ~monthly… (CV defect detection, recsys, predictive maintenance, forecasting) for Bereit delivery" | Reproduces `user_ml_background.md:14`. Compress to a pointer; halve the tokens. |
| `MEMORY.md:12` | redundancy | "CliftonStrengths 2014 (Competition/Command/…) + DISC 2017 high-D… trust the convergence, not any single score" | Reproduces `user_psychometric_profile.md:19,21,27`. Compress to a pointer. |
| `MEMORY.md:13` | redundancy | "…Open question: which parts of the inherited code are chosen vs auto-running" | Reproduces `user_psychological_origins.md:51,57`. Compress to a pointer. |
| `MEMORY.md:6` | zero-behaviour | "**Load-bearing** for advising him on hard problems." | Every entry in the index is load-bearing for something; the claim cannot lose an argument and does not change which entry gets opened. Same phrase is also already inside the entry at `user_operating_system.md:3`. |
| `MEMORY.md:7`, `:9` | stale / drift | see index-drift table | Rewrite, not delete. |

### user_profile.md (93 lines)
| file:line | category | text (truncated) | why it goes |
|---|---|---|---|
| `user_profile.md:1-5` | dead metadata | frontmatter | No consumer. |
| `user_profile.md:29` | redundancy | "Self-perception gap: compares himself to [named comparators]… Needs to calibrate against real-world founders, not content creators." | Near-verbatim duplicate of `feedback_self_calibration.md:7,11`, same named comparators. This copy **survives**; the feedback file goes. |
| `user_profile.md:32` (2nd half) | redundancy | "turned an underperformer into a rising talent over 2.5 years… Wants his people to surpass him." | Duplicates `user_relationships.md:23`, which has the name and the date anchor. `user_relationships.md` owns people. |
| `user_profile.md:53` | contradiction (C2) | "Primary languages: Python, Java, Go, Rust, Nix, BeanShell" | Conflicts with `user_languages.md:8,19`. Replace with a pointer. |
| `user_profile.md:62` | contradiction (C3→C1) | "Day job is ~70% consulting/integration, ~30% code" | Superseded by `user_languages.md:14`. |
| `user_profile.md:64` | contradiction (C7) | "Currently has 4 students reporting to him" | Conflicts with `user_profile.md:30` 34 lines earlier. |
| `user_profile.md:14` | contradiction (C3) | "target: ~1 year from now, ~2027" | Conflicts with `project_startup.md:21`; both need the real status. |
| `user_profile.md:85` (2nd half) | historic cruft | "Migrated off Claude Code 2026-08-21; **RTK was retired with it** — OMP's native read/grep/glob already return token-optimized output, so the shell-rewriting proxy was redundant." | The rationale is a changelog entry. The instruction buried in it is one clause and is load-bearing (see *Keep*): compress to "Harness is OMP. RTK is not hooked into any agent — do not reintroduce it; OMP's native read/grep/glob already return token-optimized output." The `rtk` binary is indeed still installed (`/opt/homebrew/bin/rtk`), so the trailing sentence is factually correct and is the reason the do-not-reintroduce clause must survive. |
| `user_profile.md:23-47` | duplication | "Founder Identity & Career Path" + "Startup Plan" (25 lines) | Overlaps `project_startup.md`, `user_career_strategy.md`, `user_personal_goals.md:31-37`. See D3 for the ownership split. |

### user_languages.md (19 lines) — the most stale entry in the store
| file:line | category | text (truncated) | why it goes |
|---|---|---|---|
| `user_languages.md:1-7` | dead metadata | frontmatter incl. `originSessionId` (`:5`) and `modified:` (`:6`) | No consumer; a session UUID instructs nothing. |
| `user_languages.md:10` | **stale factual claim** | "Telemetry signal (from `~/.claude/cost-tracker.log`)" | **Verified: `~/.claude/cost-tracker.log` does not exist.** The evidence base for the whole section is gone — consistent with `user_profile.md:85` (harness migrated off Claude Code 2026-08-21). |
| `user_languages.md:11-13` | zero-behaviour + stale | "`/python` (136), `/pytest` (30)… Java and Rust: stated by user 2026-05-24 (not yet visible in current telemetry window…)" | Raw counts from a deleted log. The *conclusion* at `:8` is the instruction; the tallies change no decision, and "current telemetry window" refers to a window that no longer exists. |
| `user_languages.md:17` | **stale factual claim** | "DAILY skill candidates per language: `python-patterns/testing/review`, `java-reviewer` + `springboot-*` + `jpa-patterns`, `rust-patterns/…`, no first-party Nix skill exists" | **Verified: none of these skills exist.** `~/.claude/skills/` does not exist; `~/.omp/skills/` does not exist; no `*python-patterns*`, `*java-reviewer*`, `*rust-patterns*` anywhere under either. Entirely dead. |
| `user_languages.md:18` | **stale factual claim** | "Do NOT auto-prune Java, Rust, or Nix-adjacent tooling from `~/.claude/skills/` even if `~/org` shows no code" | **Verified: `~/.claude/skills/` does not exist.** The guardrail guards a deleted directory. The *reasoning* is still valid and worth one clause — "absence of a language in `~/org` is not evidence of disuse; other repos exist" — but the path and the pruning action are dead. |
| `user_languages.md:14` (parenthetical) | redundancy | "…(classical MLE: CV defect detection, recsys, predictive maintenance, forecasting)" | Verbatim duplicate of `user_ml_background.md:14`, which owns ML skill state. Keep the coding-frequency claim here; drop the MLE-domain list. |

After these cuts `user_languages.md` is ~5 lines: the language list, the frequency caveat, the not-in-`~/org` reasoning. That is the whole load-bearing content.

### user_ml_background.md (16 lines)
| file:line | category | text (truncated) | why it goes |
|---|---|---|---|
| `user_ml_background.md:1-8` | dead metadata | frontmatter incl. `originSessionId: session-2026-08-19-mle-platform-question` (`:6`), `modified:` (`:7`) | No consumer. The session id is a provenance stamp with no reader. |
| `user_ml_background.md:10` | stale / contradiction (C5) | "(stated 2026-08-19)" and "full Master's degree in Machine Learning" | The date-stamp is bare provenance; the degree claim conflicts with `user_profile.md:11`. |
| `user_ml_background.md:12` | redundancy | "codes roughly once a month ([[user_languages]])" | Duplicates `user_languages.md:14`; the cross-reference makes the duplication unnecessary. |

### user_preferences.md (60 lines)
| file:line | category | text (truncated) | why it goes |
|---|---|---|---|
| `user_preferences.md:1-5` | dead metadata | frontmatter | No consumer. |
| `user_preferences.md:23-25` | historic cruft, self-refuting | "Relocated from `~/nixos-config/omp/AGENTS.md` on 2026-08-22 — it describes the **target state rather than instructing behaviour**, so it **changed no agent decision and was dead weight** in the system prompt." | The note argues that the text below it is inert, then keeps it. Both cannot be right. Either the block instructs (and the note is wrong) or it doesn't (and both should go). The provenance is also unnecessary: moving text out of a git-tracked file is already recorded in git. |
| `user_preferences.md:27-31` | zero-behaviour + contradiction (C9) | "He is being served well when: his reasoning gets sharper… he **relies less on the agent for solutions**…" | By its own relocation note's reasoning, target-state description that changes no decision. Worse: read as instruction, `:29` licenses withholding a deliverable, which `AGENTS.md:24-26` forbids. Both reasons point the same way. |
| `user_preferences.md:9-10` | redundancy | "Wants to be held to the senior/staff bar… The goal is accelerated growth, not comfort" | Restates `AGENTS.md:3-9`, which is always loaded. Only `:8`'s factual half (not yet at that level) is additive. |
| `user_preferences.md:14-19` | over-long anecdote with an instruction inside | "Git internals are a known gap (2026-08-22, his own framing)… he asked why merging a branch had not cleared its stashes… and the explanation landed immediately…" | 6 lines to carry two instructions: *git internals are a gap, explain the mechanism not just the conclusion* and *show the evidence beside the verdict*. The worked example is the anecdote. Compress to 2 lines. Note the second instruction is already covered by `RULES.md:7-9`. |

### user_personal_goals.md (44 lines)
| file:line | category | text (truncated) | why it goes |
|---|---|---|---|
| `user_personal_goals.md:1-5` | dead metadata | frontmatter | No consumer. |
| `user_personal_goals.md:26-29` | redundancy | "## Cut from goals" + 3 items | Two of the three restate retirements already stated at point of use (`:8` and `:14`). Keep the inline notes — they are where an agent reading a section actually looks — and fold the one item that appears *only* here (`:27`) up into the relevant section. Saves 3 lines and removes a second place to keep in sync. |
| `user_personal_goals.md:31-37` | duplication | "## Career Path (clarified 2026-04-09)" | Career content in the non-tech-goals file; overlaps `user_career_strategy.md` and `user_profile.md:23-34`. See D3. |
| `user_personal_goals.md:38` | redundancy | "**Note:** Vision 2028 was written before [life event]. All timelines subject to reassessment." | Third copy of the same caveat: also at `project_learning_roadmap.md:43` and `:47`. This copy **survives** (goals is where timelines live); the two roadmap copies go. |
| `user_personal_goals.md:40-44` | vague directive | "Every amiconsult engagement = future case study. Document what worked. / Every process built = company operating system v0.1" | Aphorisms, not instructions — no agent decision turns on them. `:41` (coding fluency closes with reps) is real and duplicated at `user_languages.md:14`; `:42-43` are the only actionable lines (document engagements, keep mentee relationships warm) and can survive as two. |

### project_learning_roadmap.md (52 lines)
| file:line | category | text (truncated) | why it goes |
|---|---|---|---|
| `project_learning_roadmap.md:1-5` | dead metadata | frontmatter | No consumer. |
| `project_learning_roadmap.md:46` | **stale factual claim** | "[a family life-event] due ~April 2026. This has been the primary constraint for ~9 months" | `user_relationships.md:27` records that event as having occurred, ~4 months before today's date. The roadmap still frames it as forthcoming. Directly misinforms any conversation about current bandwidth. |
| `project_learning_roadmap.md:50` | **stale factual claim** | "Life context has changed significantly. [Event] arriving imminently." | Same defect, and "imminently" is now 4 months wrong. |
| `project_learning_roadmap.md:47` | redundancy + stale | "All goals and timelines (Vision 2028, startup launch, learning cadence) need to be **reassessed post-baby**" | The reassessment has already happened for goals — `user_personal_goals.md:3` says "revised", `:7` "Fitness (revised)", `:8`/`:14` record the revisions. A pending-action note for a completed action. |
| `project_learning_roadmap.md:43` | redundancy | "Startup timeline may shift — Vision 2028 was written pre-pregnancy" | Third copy; `user_personal_goals.md:38` survives. |
| `project_learning_roadmap.md:36-38` | redundancy | "## Paper (published)" + title + description | Duplicates `user_profile.md:12`, which owns credentials. |
| `project_learning_roadmap.md:11` | redundancy | "Paper reading group with Jan (regular cadence…)" | Duplicates `user_relationships.md:15`; `MEMORY.md:8` also names it. `user_relationships.md` owns people. |
| `project_learning_roadmap.md:19` | redundancy | "Needs more hands-on coding outside work — day job doesn't give enough reps" | Third statement of the cadence problem after `user_languages.md:14` and `user_profile.md:62`. |
| `project_learning_roadmap.md:32-33` | duplication | Two-language architecture + rationale (type safety, compiler-as-reviewer, long context gaps, AI-assisted Rust effective) | Near-verbatim duplicate of `feedback_rust_decision.md:9`. This copy **survives** — it is the rationale in its natural home; the feedback file goes (already promoted to `RULES.md:11`). |
| `project_learning_roadmap.md:13` | stale | "**2025** AI Engineer Reading List organized by section" | A 2025-vintage reading list described as current in an "active learning plan", with no items marked done. |
| `project_learning_roadmap.md:10` | historic narration | "Has Karpathy's Zero to Hero NN series queued (**started 2023, not finished**)" | The instruction is "queued"; the 3-year-old start date adds nothing an agent can act on. |

### project_startup.md (29 lines)
| file:line | category | text (truncated) | why it goes |
|---|---|---|---|
| `project_startup.md:1-5` | dead metadata | frontmatter | No consumer. |
| `project_startup.md:20-21` | **stale factual claim** (S1) | "## Current State (as of 2026-04-09) / Company founding target: **July 1, 2026** — hard date, not aspirational" | The hard date passed ~7 weeks ago; no entry in the store records whether the company was founded. A "Current State" header 4.5 months old asserting a past date as future is the single most misleading line in the projects section. |
| `project_startup.md:23` | stale | "Baby is the primary constraint" | Same family-life-event staleness as the roadmap; the constraint's shape has changed and no entry records how. |
| `project_startup.md:24` | stale | "CI/CD project at amiconsult is the **last** free work for them" | Dated 2026-04-09; nothing records whether that project closed. "Last" is a claim with an expiry date. |
| `project_startup.md:27` | zero-behaviour | "**Why:** This is not a hypothetical startup… The starting position is stronger than most funded startups." | Advocacy, not instruction. Nothing could contradict it and no agent decision turns on it. The one operative clause ("real but unhurried") is already at `:29`. |

### user_career_strategy.md (64 lines)
| file:line | category | text (truncated) | why it goes |
|---|---|---|---|
| `user_career_strategy.md:4-8` | dead metadata | `metadata:`, `node_type: memory`, `originSessionId`, `modified:` | No consumer; `node_type: memory` is tautological inside the memory dir. |
| `user_career_strategy.md:15` | contradiction (C4) | "Exit trigger (observable, not date-based)…" | Explicitly retired by `:30`. |
| `user_career_strategy.md:60` | contradiction (C4) | "The '2 years' timeline needs a trigger, not a date" | Same; it is the last thing an agent reads, so it overwrites the correction at `:30`. |
| `user_career_strategy.md:38-42` | ageing evidence | "## Network signal (as of 2026-05)" — weekly inbound volume, a named offer figure, a named CEO as expected broker | 3 months stale and partly superseded by `:28-36`. The transferable finding at `:41` (in-person depth outperforms feed volume) is the only line that survives ageing; the volume claim and broker expectation should be marked historical or cut. |
| `user_career_strategy.md:18` | contradiction (C6) | "Lead AI Consultant" | Title drift. |
| `user_career_strategy.md:48` | speculative narration | "Worth tracking as **either** an alliance opportunity **or** a subtle peer-positioning dynamic… **first time** these two profiles are visible together" | Names both possible readings and commits to neither, so no advice changes. Tied to a Nov 2026 event; if kept, it should be a one-line watch-item, not 4 lines of scenario. |
| `user_career_strategy.md:64` | broken convention | "Related: [[user_languages]]" | Wiki-link to a language list from a career-strategy entry — non-obvious relevance, and the `[[…]]` form is used nowhere in `MEMORY.md` (which uses markdown links). See R3. |

### user_psychometric_profile.md (27 lines) — structural only
| file:line | category | text (truncated) | why it goes |
|---|---|---|---|
| `user_psychometric_profile.md:4-7` | dead metadata | `metadata:`, `node_type`, `originSessionId` | No consumer. |
| `user_psychometric_profile.md:27` | **broken cross-reference** | "…wants instruments treated as hypotheses — see **[[user_languages]]**…" | Wrong target: the ML/research-background fact lives in `user_ml_background.md` and `user_profile.md:11`, not in a programming-language list. An agent following this reference gets nothing. |
| `user_psychometric_profile.md:27` (tail) | redundancy + zero-behaviour | "…and `~/.omp/agent/AGENTS.md` (\"assume I want to be challenged\"), **which this profile independently explains**." | Quotes an always-loaded file back at itself (`AGENTS.md:7`), then adds a claim of explanatory convergence that changes no behaviour. The caveat's operative half (trust cross-instrument convergence, not single scores) is at the start of `:27` and should survive alone. |

### user_psychological_origins.md (59 lines) — structural only
| file:line | category | text (truncated) | why it goes |
|---|---|---|---|
| `user_psychological_origins.md:4-7` | dead metadata | `metadata:`, `node_type`, `originSessionId` | No consumer. |
| `user_psychological_origins.md:18`, `:30`, `:39`, `:47` | formatting filler | `---` rules between sections | Four horizontal rules in a 59-line file that already uses `##` headings. Pure tokens; used in no other entry. |
| `user_psychological_origins.md:57` | zero-behaviour | "The answer to which-parts-are-chosen is only available through future behavior under that pressure — not through introspection now." | Epistemological hedge on the preceding paragraph. Cannot be acted on and cannot lose an argument; the actionable watch-items are at `:55`. |
| `user_psychological_origins.md:41-45` | duplication | "## Mythic Self-Narrative" section | Same topic domain as `user_operating_system.md:7-15` ("Foundational mythology"), and `:45` explicitly cross-references the other entry's subject. Two entries own one topic. See D2. |

### user_operating_system.md (58 lines) — structural only
| file:line | category | text (truncated) | why it goes |
|---|---|---|---|
| `user_operating_system.md:1-5` | dead metadata | frontmatter incl. "load-bearing for understanding how he approaches any problem" (`:3`) | No consumer; and the load-bearing claim is a third copy of the same assertion (`MEMORY.md:6`, `:3`, `:32`). |
| `user_operating_system.md:15` | zero-behaviour | "This is not a self-image he reached for. This is core architecture." | Rhetorical reinforcement of `:9`, which already says the same with evidence. |
| `user_operating_system.md:28` | zero-behaviour | "Almost everything formidable about him is downstream of this OS." | Summary flourish on the list preceding it. |
| `user_operating_system.md:42-48` | duplication | "## Pattern: organizing self around single targets" | Overlaps `user_psychological_origins.md:32-38`. See D2. The watch-item at `:48` is the operative line and should survive wherever the topic lands. |

### user_relationships.md (27 lines) — structural only
| file:line | category | text (truncated) | why it goes |
|---|---|---|---|
| `user_relationships.md:1-5` | dead metadata | frontmatter (`name: key-relationships`) | No consumer. |
| `user_relationships.md:23` (tail) | zero-behaviour | "Proof of Vincenzo's ability to develop people long-term." | Editorial conclusion on the facts already stated in the same bullet. |
| `user_relationships.md:27` (tail) | duplication | interpretive paragraph ending "See [[user_operating_system]]" | Interpretation of a relationship rather than the relationship itself; the cross-reference points at the entry that owns interpretation. `user_relationships.md` should hold the who-and-role facts; `user_operating_system.md` the interpretation. |

### project_zed_config.md (23 lines)
| file:line | category | text (truncated) | why it goes |
|---|---|---|---|
| `project_zed_config.md:1-5` | dead metadata | frontmatter | No consumer. |
| `project_zed_config.md:22` | redundancy | "No jk escape in insert mode" | `RULES.md:10` — "Never bind `jk` to escape in vim insert mode" — is a standing rule in force every session. **`RULES.md` wins**; this line adds nothing an agent doesn't already have. |
| `project_zed_config.md:11` | ageing header | "**Current state (2026-03-19):**" | 5 months old and labelled "current". The keymap facts below are probably still true (`~/.config/zed` exists), but the label overstates freshness. Restate as a dated snapshot or re-verify. |
| `project_zed_config.md:16` | redundancy | "Modus Vivendi/Operandi themes, Iosevka Nerd Font" | Duplicates `user_profile.md:78-79`, which owns editor/appearance preferences. |
| `project_zed_config.md:15` | redundancy | "Python: ty (type checking) + ruff (linting + formatting), explicit formatter config" | Third copy: `user_profile.md:91` and `reference_doom_emacs.md:13`. |
| `project_zed_config.md:19` | historic narration | "AI bindings under SPC l (Zed-native, **not gptel port — no muscle memory to preserve**)" | The decision is "AI bindings under SPC l"; the rejected-alternative rationale is a design-review artifact. Compare `user_profile.md:84`, which states the same rationale. |

### reference_amiconsult_brand.md (51 lines)
| file:line | category | text (truncated) | why it goes |
|---|---|---|---|
| `reference_amiconsult_brand.md:4-5` | dead metadata | `metadata:` / `type:` | No consumer. |
| `reference_amiconsult_brand.md:30` | ageing status header | "STATUS (2026-06-21): **building** a reusable rich Typst component library" | Contradicted 5 lines later by "**COMPLETE**: 15 verified components" (`:35-38`), which is confirmed on disk (`components.typ`, `demo.typ`, `demo.pdf`, `README.md`, `verification/comparisons/`, `assets/_gen/` all exist). The work finished; the header still says in-progress. |
| `reference_amiconsult_brand.md:32-33` | historic narration | "FROM the 197 real slides (**NOT the empty layouts — that was the first attempt's failure**)" | Retains a failed-attempt narration whose lesson is also in `feedback_verify_against_real_artifact.md:12-17` and in `RULES.md:7-9`. Keep the positive instruction (build from the real slides), drop the failure recount — but see *Keep* for why one clause of it must survive. |
| `reference_amiconsult_brand.md:33-34` | **dead reference** | "Page→slide map for `real_deck_197.pdf` (195 pp, slides 17 & 152 hidden)" | **Verified: `real_deck_197.pdf` does not exist** in `~/Downloads/amiconsult-typst/` (only `demo.pdf` is present). The mapping is still valid *data* if the deck is re-obtained; the finding is that the source artifact is gone and the entry does not say so. |
| `reference_amiconsult_brand.md:34` | contradiction (C8) | "Geometry extractor: `scratchpad/dump_slide.py`" | Verified dead; `:43` has the live path. |
| `reference_amiconsult_brand.md:49` | redundancy | "See [[feedback_verify_against_real_artifact]]." | Dangling once that file is removed — and its content is already inlined at `:31-33`. |
| `reference_amiconsult_brand.md:51` | spurious cross-reference | "Related: [[project_amiconsult_isc]]." | `project_amiconsult_isc.md` is SailPoint BeanShell rule development — no relationship to brand assets or Typst beyond the employer's name. Following it wastes a read. |

### Frontmatter-only cuts (bodies are clean, keep as-is)
| file:line | lines | note |
|---|---|---|
| `project_amiconsult_isc.md:1-5` | 5 | Body is exemplary: dense, verified paths, hard-won API deltas. |
| `reference_doom_emacs.md:1-5` | 5 | Body is a clean fact sheet. |
| `reference_macos_tcc_troubleshooting.md:1-5` | 5 | Body is a complete, reproducible fix with diagnosis commands. |
| `reference_aerospace_video_flicker.md:1-5` | 5 | Body is high-value: root cause, rejected hypothesis, verified paths. |
| `reference_emacs_native_comp_libgccjit.md:1-6` | 6 | Verified: `~/nixos-config/doom/native-comp-driver-fix.el` exists. |
| `reference_emacs_reader_mupdf_rebuild.md:1-6` | 6 | Body is a clean rebuild procedure. |

---

## Promoted feedback

`AGENTS.md:153-155`: "A correction that recurs is a config bug, not a memory entry: when the same mistake needs correcting twice, promote it to a standing rule in `~/nixos-config/omp/RULES.md` instead of only filing another `feedback_*` note." Checked all four against `RULES.md`:

| entry | promoted? | evidence | status |
|---|---|---|---|
| `feedback_verify_before_asserting.md` (11 lines) | **Yes, fully** | `RULES.md:7-9` — "Verify before asserting. Read the real artifact… before stating anything about its content." Covers `feedback_verify_before_asserting.md:7` and `:11` exactly. `:9` is the originating incident (a misidentified paper) — anecdote. | **Delete.** Nothing survives that `RULES.md:7-9` doesn't already carry every session. |
| `feedback_rust_decision.md` (11 lines) | **Yes, fully** | `RULES.md:11` — "Rust for non-ML code is a settled decision. Do not reopen it." Covers `:7` and `:11`. The rationale at `:9` is duplicated in `project_learning_roadmap.md:32-33`. | **Delete.** Directive is in `RULES.md`; rationale is in the roadmap. |
| `feedback_verify_against_real_artifact.md` (22 lines) | **Yes** | `RULES.md:9` — "**Never verify against a proxy** and never against your own earlier summary." That is `:8-10` and the operative half of `:18-21`. The remaining unique content is the scaffold-detection tell at `:20-21` ("if a template/layout looks empty, that's a signal it's a scaffold") — and that is already recorded where it applies, at `reference_amiconsult_brand.md:31-33`. `:12-17` is the incident recount. | **Delete.** Largest single cut in the store. |
| `feedback_self_calibration.md` (11 lines) | **No** | No corresponding line in `RULES.md` (all 12 lines read; nothing on reference-group calibration). But the content is duplicated near-verbatim at `user_profile.md:29`, same named comparators. | **Not yet promoted.** Per `AGENTS.md:153-155` this is the one that *should* become a standing rule (one line in `RULES.md`), after which the note is deletable and `user_profile.md:29` remains as the supporting evidence. Do not delete the note before promoting it. |

**Net effect: all four `feedback_*` files (55 lines) can go, plus `MEMORY.md:29-33` (5 lines including the section heading) — but only after `feedback_self_calibration.md`'s directive lands in `RULES.md`.** This is the cleanest structural win available: it removes a whole category from the always-loaded index and eliminates the store's only category whose entire purpose has been superseded by a better mechanism.

---

## Contradiction with the global config

Checked all of memory against `AGENTS.md:12-26` (Precedence) and `AGENTS.md:30-69` (Interaction Rules 1-4).

**One real conflict: C9** — `user_preferences.md:29` ("he relies less on the agent for solutions") against `AGENTS.md:24-26` ("never becomes a reason to block, ask permission, or ship less than a complete deliverable"). Detailed above. `AGENTS.md` wins; the block goes.

**One redundancy: C10 / `user_preferences.md:9-10`** restates `AGENTS.md:3-9`.

**Two apparent conflicts that are correctly resolved by the Precedence block and must NOT be edited:**

1. `user_preferences.md:49` — "Comfortable with long analytical responses *if substantive*. Pads register as fluff. Match his density." This reads as conflicting with the harness's brevity contract. It does not: `AGENTS.md:22-24` assigns register and "what to optimize for" to the user's file, and mechanics to the harness. This is content, not mechanism. Load-bearing — keep.
2. `user_preferences.md:45-52` and `user_operating_system.md:32-40` prescribe *how* to challenge and *when a problem resists effort*. `AGENTS.md:32-40` (Rule 1) prescribes *that* one challenges, scoped to design. Complementary: `AGENTS.md` sets the trigger, memory supplies the technique. No conflict.

**Nothing in memory contradicts Interaction Rule 4 (`AGENTS.md:53-69`, converge-on-target-then-go).** No memory entry instructs an extra confirmation round, and none instructs skipping the front gate.

**One process contradiction between the two config files, noted for completeness because memory depends on it:** `AGENTS.md:154` directs standing rules to `~/nixos-config/omp/RULES.md`, while `MEMORY.md:5` and `user_psychometric_profile.md:27` spell the same file family as `~/.omp/agent/AGENTS.md`. **Both resolve** — verified `~/.omp/agent/AGENTS.md` and `~/.omp/agent/RULES.md` are symlinks to `/Users/vincenzopace/nixos-config/omp/{AGENTS,RULES}.md`. But two spellings for one file invite an agent to edit the generated path. Standardise memory on the `nixos-config` spelling, matching `user_preferences.md:23` and `AGENTS.md:154`.

---

## Duplication between entries — proposed ownership

**D1 — Coding cadence / language inventory / ML skill state** (currently spread across 5 files: `user_profile.md:52,53,62,93`, `user_languages.md:8,14,19`, `user_ml_background.md:12,14`, `project_learning_roadmap.md:19`, `user_personal_goals.md:41`).
- `user_languages.md` **owns** the language list and the coding-cadence fact.
- `user_ml_background.md` **owns** ML theory-vs-practice state and the target MLE domains.
- `user_profile.md` keeps a one-line pointer to each; delete `:53` and `:62`.
- `project_learning_roadmap.md:19` and `user_personal_goals.md:41` delete.

**D2 — Formative-pattern interpretation** (`user_operating_system.md` vs `user_psychological_origins.md`). The two entries overlap on the same subject at `user_operating_system.md:7-15` / `user_psychological_origins.md:41-45`, and on behavioural pattern description at `user_operating_system.md:42-48` / `user_psychological_origins.md:32-38`. `MEMORY.md:6` and `:13` describe them as if cleanly separated; they are not. Proposed split, purely structural: **`user_operating_system.md` owns the operative advisory model** — the type-1/type-2 distinction at `:34-40` and the watch-items at `:48`, `:52`, `:56`, which are the lines that actually change advice. **`user_psychological_origins.md` owns origin and the open question** at `:49-55`. Move the narrative-identity material into one of them, not both.

**D3 — Career and startup** (currently 4 files). `user_profile.md:23-47`, `user_personal_goals.md:31-37`, `user_career_strategy.md`, `project_startup.md` all carry career-trajectory and company content, and `MEMORY.md:4`, `:7`, `:9`, `:19` all advertise overlapping slices of it. Proposed split:
- `user_career_strategy.md` **owns** employment trajectory, exit strategy, live opportunities, employer-relationship risk.
- `project_startup.md` **owns** the company: entity, client, founding status, division of labour.
- `user_profile.md` **owns** stable identity — education, background, role-fit, tooling. Cut `:35-47` (Startup Plan) to a pointer at `project_startup.md`; `user_profile.md:39-41` (founder-pair division of labour) duplicates `user_relationships.md:9-12`, which owns people.
- `user_personal_goals.md` **owns** non-work goals only; `:31-37` moves to `user_career_strategy.md`, which also fixes the `MEMORY.md:7` description mismatch.

**D4 — Python tooling** stated three times: `user_profile.md:91`, `reference_doom_emacs.md:13`, `project_zed_config.md:15`. The two editor entries are legitimately editor-specific config (different priorities and formatter integration); `user_profile.md:91` is the redundant general copy — but it is the one an agent reads when it needs the answer without caring which editor. Keep `user_profile.md:91`; keep `reference_doom_emacs.md:13` (records LSP priority values, additive); cut `project_zed_config.md:15`.

---

## Reference integrity

Every filesystem path in the store was resolved.

**Dead (3):**
| reference | at | status |
|---|---|---|
| `~/.claude/skills/` | `user_languages.md:18` (and the skill names at `:17`) | **Does not exist.** No `~/.omp/skills/` either; none of `python-patterns`, `java-reviewer`, `springboot-*`, `jpa-patterns`, `rust-patterns/*` found anywhere. Consistent with `user_profile.md:85`. |
| `~/.claude/cost-tracker.log` | `user_languages.md:10` | **Does not exist.** Invalidates the telemetry section `:11-13`. |
| `real_deck_197.pdf` | `reference_amiconsult_brand.md:33` | **Does not exist** in `~/Downloads/amiconsult-typst/`. |
| `scratchpad/dump_slide.py` | `reference_amiconsult_brand.md:34` | **Does not exist**; superseded by `tools/dump_slide.py` at `:43`. |

**Live (verified, 17):** `~/.omp/agent/AGENTS.md` and `~/.omp/agent/RULES.md` (`MEMORY.md:5`, `user_psychometric_profile.md:27` — symlinks into `nixos-config`); `~/nixos-config/omp/AGENTS.md` (`user_preferences.md:23`); `~/nixos-config/hm-modules/claude.nix` (referenced from `AGENTS.md:146`; the Syncthing-whitelist claim is confirmed at `claude.nix:6-7,39`); `~/org/.omp/AGENTS.md` (`user_languages.md:14`, `user_ml_background.md:14`, `user_psychometric_profile.md:23`, `user_psychological_origins.md:59` — exists, and contains a Bereit section: 8 matches); `~/org/.omp/rules/`; `~/amiconsult/vac/20-Rule-Development/rule-development-kit` (`project_amiconsult_isc.md:9`); `~/nixos-config/doom/native-comp-driver-fix.el` (`reference_emacs_native_comp_libgccjit.md:33`); `~/.config/doom/` and `config.org` (`reference_doom_emacs.md:7`); `~/.config/aerospace/aerospace.toml` (`reference_aerospace_video_flicker.md:23`); `~/Library/Application Support/Jellyfin Media Player/mpv.conf` (same line); `~/Library/Fonts/gothamssm_*.otf` (`reference_amiconsult_brand.md:10` — 10 files present, matching the claim); `~/Downloads/amiconsult-typst/` plus `components.typ`, `colors.typ`, `demo.typ`, `demo.pdf`, `README.md`, `tools/dump_slide.py`, `assets/_gen/`, `verification/comparisons/` (`reference_amiconsult_brand.md:30,36,40-43`); `~/.config/zed` (implied by `project_zed_config.md`); `/opt/homebrew/bin/rtk` (`user_profile.md:85` — the "still installed" claim is correct).

**R3 — cross-reference convention is inconsistent and partly unresolvable.** `MEMORY.md` addresses entries by markdown link to filename; entry bodies use org/roam-style `[[wiki-links]]` at `user_languages.md:14`, `user_ml_background.md:12`, `user_psychometric_profile.md:23,27`, `user_psychological_origins.md:59`, `user_career_strategy.md:64`, `user_relationships.md:27`, `user_operating_system.md` (via `:46` subject matter), `reference_aerospace_video_flicker.md:25`, `reference_emacs_reader_mupdf_rebuild.md:33`, `reference_amiconsult_brand.md:49,51`, `feedback_verify_against_real_artifact.md:22`. Nothing resolves `[[…]]` — they are guessable (`[[user_languages]]` → `user_languages.md`) but require the agent to infer the mapping, and two of them are simply wrong targets (`user_psychometric_profile.md:27`, `reference_amiconsult_brand.md:51`). Standardise on the `MEMORY.md` markdown-link form so cross-references are machine-followable, and repair the two bad targets while doing it.

**R4 — the `~/.claude/agents/` premise does not hold.** `~/.claude/agents/` does not exist, but grepping the whole store for `claude/agents` returns **zero hits** — no entry references it. Nothing to fix.

---

## Stale factual claims — consolidated

| id | file:line | claim | verified state |
|---|---|---|---|
| S1 | `project_startup.md:20-21` | "Current State (as of 2026-04-09) / founding target July 1, 2026 — hard date" | Date passed ~7 weeks ago; no entry records the outcome. |
| S2 | `project_learning_roadmap.md:46`, `:50` | a family life-event framed as forthcoming/imminent | `user_relationships.md:27` records it as past, ~4 months ago. |
| S3 | `project_learning_roadmap.md:47` | goals "need to be reassessed" | Reassessment already done — `user_personal_goals.md:3,7,8,14`. |
| S4 | `user_languages.md:10-13` | telemetry from `~/.claude/cost-tracker.log` | Log does not exist. |
| S5 | `user_languages.md:17-18` | skills under `~/.claude/skills/` | Neither the directory nor any named skill exists. |
| S6 | `user_personal_goals.md` index line (`MEMORY.md:7`) | two retired targets advertised as current | Retired at `user_personal_goals.md:8,14,28,29`. |
| S7 | `reference_amiconsult_brand.md:30` | "STATUS: building" | Contradicted by `:35` "COMPLETE" and confirmed complete on disk. |
| S8 | `reference_amiconsult_brand.md:33-34` | `real_deck_197.pdf`, `scratchpad/dump_slide.py` | Both absent. |
| S9 | `project_zed_config.md:11` | "Current state (2026-03-19)" | 5 months old; label overstates freshness (contents likely still valid). |
| S10 | `user_career_strategy.md:38-42` | "Network signal (as of 2026-05)", named CEO "expected to broker the next role" | Partly superseded by `:28-36` (2026-06-24). |
| S11 | `project_learning_roadmap.md:13` | "2025 AI Engineer Reading List" as active | A year old with nothing marked complete. |

---

## Keep despite looking cuttable

Over-cutting is the failure mode here. Each of these reads like cruft and is not.

1. **`reference_macos_tcc_troubleshooting.md:27`** — "Confirmed working on: macOS Tahoe (Darwin 25.3.0), 2026-03-20". Looks like a bare date stamp. It is a **scope stamp**: it tells the agent which OS generation the `tccutil` recipe was proven against. The machine is now Darwin 25.5.0, so the delta is exactly the information needed to decide whether to re-verify. **Keep. Same for `reference_aerospace_video_flicker.md:29`** ("AeroSpace 0.20.3-Beta, mpv 0.41.0, JMP 1.12.0, 2026-07-01") — version-pinned fixes for fast-moving beta software are worthless without the versions.

2. **`reference_aerospace_video_flicker.md:17`** — the long passage establishing that Jellyfin Media Player's keep-awake is *passive* and "**must be left alone**", with the verification method (`nm -u` on the binary). This reads as debugging narration. It is a **negative instruction that prevents a regression**: it stops a future session "fixing" the wrong component and breaking screen-on-during-playback. The `nm -u` technique at `:25` is a reusable diagnostic. **Keep both.** Likewise `:23`'s "...but that was NOT the fix" — a rejected hypothesis, explicitly labelled, is what stops the next session repeating it.

3. **`reference_emacs_native_comp_libgccjit.md:32`** — "must be re-added on a fresh Mac. No-op on Linux." Reads like an aside about a past machine setup. It is a **portability condition** on the fix — the difference between a shell-level and a config-level remedy, which is the whole point of the entry (and of `MEMORY.md:25`'s "shell-level, not Doom"). **Keep.**

4. **`reference_doom_emacs.md:11` and `:15`** — `claude-code-ide` in the custom-package list and bound to `SPC C`, which looks stale given `user_profile.md:85` records migrating off Claude Code on 2026-08-21. **Verified against the real config: `claude-code-ide` appears 3× in `~/.config/doom/config.org` and 2× in `packages.el`.** The memory is accurate about the config as it exists. If the migration should have retired it, the **config** is the stale artifact, not the memory entry — and silently deleting the memory line would hide that. **Keep; raise as a config question instead.**

5. **`user_profile.md:85`, the RTK clause** — "The `rtk` binary is still installed but no longer hooked into any agent." This is the most cruft-looking line in the store: a dated migration note about a retired tool. **Verified: `/opt/homebrew/bin/rtk` is still on PATH.** That is precisely why the line must survive in compressed form — an agent that finds `rtk` installed will otherwise conclude it is meant to be used. The *rationale* ("OMP's native read/grep/glob already return token-optimized output") is also load-bearing: it is the reason not to re-add it. Cut the migration date and the word "redundant"; keep the do-not-reintroduce instruction and its one-clause reason.

6. **`user_relationships.md:23`, "(as of April 2026)"** — attached to a mentoring duration. A bare-looking date, but the duration figure is **only computable relative to it**; strip the date and the number silently ages into a falsehood. **Keep.** This is the model for how a date earns its place: it anchors a quantity that changes with time.

7. **`user_relationships.md:27`, "(confirmed living/present as of June 2026)"** — awkward, oddly clinical provenance. It is currently **the only guard** in the store against the stale framing at `project_learning_roadmap.md:46,50`, and it is doing real work today. **Keep until S2 is fixed**; once the roadmap is corrected, the parenthetical becomes optional — but it is cheap insurance against a re-import of the older framing, so keeping it costs 8 words.

8. **`MEMORY.md:5`, "Interaction rules themselves live in ~/.omp/agent/AGENTS.md."** Looks redundant — `AGENTS.md` is always loaded, so telling the agent where the rules it already read live seems to instruct nothing. It is a **negative boundary**: it stops a future session writing interaction rules into `user_preferences.md`, which is the exact drift that produced `user_preferences.md:23-31`. **Keep** — but change the path spelling to `~/nixos-config/omp/AGENTS.md` per the R-section finding.

9. **`project_learning_roadmap.md:48`** — "Do NOT pressure about learning pace or flag sporadic cadence as a problem — it's a conscious trade-off." Sits inside a section that is otherwise stale (S2/S3) and could easily be deleted with it. It is an explicit **behavioural prohibition** — the highest-value shape a memory line can take — and it is not stated anywhere else in the store or in `RULES.md`. **Keep verbatim; rescue it before cutting the surrounding section.** Same treatment for `project_learning_roadmap.md:41-42` and `:52` (the active-thread scoping: agentic AI and agent security, don't push broad ML fundamentals unprompted) — that is a live routing instruction, not narration.

10. **`user_personal_goals.md:8` and `:14`** — the retirement notes ("previous 550kg total… was unrealistic", "N2 cut from targets"). These *are* dated-narration-shaped and mention numbers that no longer apply. They are **load-bearing provenance**: they are what stops a future session restoring targets that were deliberately abandoned — exactly the distinction the assignment asks for. **Keep these; cut the duplicate ledger at `:26-29` instead.** Also `user_personal_goals.md:38` ("Do not treat as hard commitments") — keep; it is the surviving copy of a caveat that exists three times.

11. **`project_amiconsult_isc.md:11`** — "Uses devbox (Java 17 + Maven) — **system Java 25 is incompatible with Mockito/byte-buddy**". Reads like an environment note that will age out. It is the **reason** the devbox constraint at `:12` is non-negotiable; without it, an agent will try `mvn` directly and hit an opaque byte-buddy failure. **Keep.** `:22` ("When docs fail, decompile the stub JAR (`javap -p`)") and `:24` ("Multiple days of debugging") are similar — the latter is the weakest line in the file, but it justifies the entry's existence against a future cull.

12. **`user_operating_system.md:34-40`** — the two-kinds-of-problem distinction and the instruction to name the second kind explicitly. Structurally this is a long prose passage in a psychological entry and would be an obvious target for compression. It is the **only lines in the store that change what advice gets given** on a recurring class of problem, and `MEMORY.md:6` is right to flag the entry for it. **Keep the mechanism intact**; compress only the surrounding rhetoric (`:15`, `:28`).

13. **`user_preferences.md:41-52` and `:54-60`** — "empirically observed" engagement style. Long, and much of it reads as characterisation rather than instruction. Structurally, though, these are **calibration instructions with observable triggers** (what to do when X happens), which is the shape that survives the "can this line lose an argument?" test — each one could be contradicted by opposite behaviour. `:49` in particular is the register instruction that `AGENTS.md:22-24` explicitly delegates to this file. **Keep the section; cut only `:27-31`, which is the target-state block.**

14. **All four `feedback_*` files until `feedback_self_calibration.md` is promoted.** Three are safely deletable now, but deleting all four in one pass drops the self-calibration correction on the floor, because `RULES.md` has no equivalent line. **Sequence matters: promote first, then delete.**

15. **The `description:` field, if frontmatter is cut wholesale.** It is a duplicate of the `MEMORY.md` index line *today*, which is what makes it cuttable — but it is also the only in-file self-description, and several of the index-drift findings above (`MEMORY.md:7` vs `user_personal_goals.md:3`) were detectable **because** the two copies disagreed. If frontmatter goes, the index becomes the single point of failure for entry descriptions with no second copy to diff against. That is the right trade — one canonical description beats two that drift — but it should be a conscious choice, not a side effect.

---

## Open questions

Not derivable from the files or the filesystem:

1. **Was the company founded?** `project_startup.md:21` asserts a hard date now ~7 weeks past; nothing in the store records the outcome. This blocks resolving C3 and S1, and it gates whether `project_startup.md` is a plan or an operating record.
2. **Is Go live or not?** `user_profile.md:53` and the `gopls` entry at `:93` say yes; `user_languages.md:19` says no. Cannot be settled from disk (the telemetry source at `user_languages.md:10` is gone). Needed to resolve C2 and to make `user_languages.md:3`'s stated pruning purpose usable.
3. **What is the current job title** — with or without "Security"? (C6.) The two spellings carry different implications for what kind of work the day job involves, which is the premise of `user_ml_background.md:12`.
4. **Where do skills live now**, if anywhere? `user_languages.md:17-18` is dead (S5) and there is no successor directory in `~/.claude`, `~/.omp`, or `~/.config/omp`. Whether to rewrite the guidance or delete it depends on whether a skills mechanism still exists.
5. **Status of the two named interview processes** at `user_career_strategy.md:31-32`, and of the open blockers at `:36`. Dated 2026-06-24, two months stale, and they are the entry's most decision-relevant content — the `MEMORY.md:9` rewrite depends on knowing whether they are live, closed, or abandoned.
6. **Master's degree — CS-with-ML-focus or ML?** (C5.) `user_profile.md:11` is more specific and probably right, but the weaker premise is what `user_ml_background.md:10` uses to justify its instruction, so it is worth stating once, correctly.
7. **Does any harness component read the memory frontmatter?** Nothing in `~/nixos-config` or `~/.omp` config does (evidence in Summary point 2), and the documented protocol at `AGENTS.md:140-142` is filename-based. But the harness is a compiled binary and I cannot rule out an internal indexer. Confirm before cutting all 139 lines; if a memory-search feature exists, `description:` may be its input, and `name:` mismatching the filename in 20 of 24 files would then become a real retrieval defect rather than a cosmetic one.
8. **Should `feedback_self_calibration.md`'s directive become a `RULES.md` line, or is it already handled by `user_profile.md:29`?** Per `AGENTS.md:153-155` a recurring correction belongs in `RULES.md`, but whether this one has recurred twice is a fact only the user has.
9. **Is `reference_amiconsult_brand.md` finished work or paused work?** `:35` says COMPLETE and the artifacts exist, but `:30` says building and the source deck (`real_deck_197.pdf`) is gone. If the project is done, the entry should be trimmed to the durable brand facts (`:10-28`) plus the pipeline gotchas (`:45-49`) and the in-progress narration dropped.