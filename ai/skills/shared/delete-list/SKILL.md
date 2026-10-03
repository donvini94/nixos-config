---
name: delete-list
description: Review a diff for code that has not earned its place and hand back a delete-list — each finding with a named replacement and the lines it saves. Use when reviewing your own or an agent's changes for over-engineering, speculative abstraction, reimplemented stdlib, or unrequested scope.
argument-hint: "what to review (default: working tree vs HEAD)"
---

The deliverable is a delete-list, not an essay. Every added line must justify its own existence; the ones that cannot are named, located, and priced.

## Scope

No argument: `git diff HEAD` plus untracked files. An argument naming a branch or ref: diff against `git merge-base <ref> HEAD`. An argument naming paths: restrict to those. Judge added lines; removed lines are already gone.

Source, configuration, and tests are in scope. Prose is not — documentation, comments-as-writing, and commit messages are a separate review with separate criteria, and none of the eight categories below map onto them.

If the diff cannot be obtained, stop and say so. A review written from the file's current contents instead of its change is not a delete-list, and reading like one makes it worse than nothing.

## Read before judging

A delete-list produced from the diff alone is guesswork. Before claiming anything is redundant:

- Read the module the change lands in, not just the hunk. The helper it should have reused is usually one file away.
- Scale the reading to the blast radius. A commit touching one module: read that module and its immediate callers. A commit touching most of a service: read the project's own docs first for what the change was *for*, then the hunks — otherwise you will price coherent restructuring as bloat.
- Read the dependency manifest (`pyproject.toml`, `Cargo.toml`, `package.json`). "Reimplements an installed dependency" needs the dependency named.
- Trace one real call path end to end. An abstraction with one caller today may have three tomorrow in code you have not read.

## What goes on the list

1. **Speculative generality** — an interface, trait, base class, or protocol with one implementation; a strategy/registry/factory for one case; a config knob nothing sets; a parameter every caller passes the same value for.
2. **Reimplementation** — the stdlib, the platform, or an installed dependency already does it. Name the exact call.
3. **Duplication** — this codebase already has the helper. Name its path.
4. **Unrequested scope** — retries, caching, batching, metrics, telemetry, rate limiting, migration paths added because they felt responsible. Nobody asked. Not robustness, scope creep.
5. **Defensive noise** — `try`/`except` that re-raises unchanged; type checks on internally-typed arguments; `None` guards where `None` cannot arrive; validation repeated behind a boundary that already validated.
6. **Ceremony** — a wrapper with one call site, pass-through kwargs, a class holding one function, a struct that wants to be a tuple, comments restating the line below them, docstrings on private one-liners.
7. **Dead on arrival** — unused exports, `__all__` padding, compatibility shims for consumers that do not exist, optional parameters nobody passes.
8. **Test padding** — assertions on plumbing, defaults, field copies, forwarding, mock echoes, source text, "does not throw", "list is non-empty". A test earns its place only where a plausible bug fails it.

## Never on the list

Validation at a trust boundary. Error handling that prevents data loss. Security controls. Accessibility. Anything explicitly requested, however baroque. A test that defends an observable contract, a boundary, or a real error path.

Cutting these is not laziness, it is damage. If a finding brushes against one, drop it.

## Each finding

| field | requirement |
|---|---|
| location | `path:line` |
| category | one of the eight above |
| replacement | the exact stdlib call, existing helper, native feature, or "nothing — delete it" |
| saved | lines removed |

A finding without a named replacement is an opinion. Cut it from the list before showing it.

Order by lines saved. Each row must be independently applicable — no finding may depend on another being taken first.

## Verdict

Close with one short paragraph: what the change was actually for, and whether the diff is the shortest honest version of it.

**An empty list is a real result.** Say "nothing to cut" and stop. Manufacturing three findings to look thorough is exactly the padding this skill exists to remove, and it costs more than it saves — style nits dressed as findings train the reader to ignore the list.

Report only. Do not edit, restyle, or rename anything; apply the list only when asked.
