---
name: debt-ledger
description: Find the deliberate shortcuts and silent ceilings in a codebase, mark them in a fixed format, and triage each into fix-now, mark-and-defer, or accept. Use when auditing technical debt, harvesting deferred CEILING markers, or before a change that may have crossed a limit somebody wrote down.
argument-hint: "paths to audit (default: the whole source tree)"
---

Debt is not "code I dislike". Debt is a limit the code has, that the code does not say it has. The ledger exists so "later" does not become "never", and so a limit that has already been crossed gets found before a user finds it.

## The marker format

```
CEILING: <the limit>. Breaks when <the trigger>. Upgrade: <the way out>.
```

Three fields, all required:

- **limit** — what this code cannot do. Concrete: "one company code per department", "loads the full export into memory", "O(n²) over cost centres".
- **trigger** — the observable condition that makes it a bug. A marker without a trigger is a `TODO` wearing a better hat; nobody can ever check it.
- **upgrade** — the path out, at the level of "stream it" or "key by (company, id)". Not a design doc.

Written as a normal comment in the language's syntax, directly above the code it bounds.

## Two passes

**Harvest.** Grep for `CEILING:` and collect every marker. For each, evaluate the trigger against the code and data as they are *now*, not as they were when it was written. Zero markers is the expected result on a codebase that has not used the convention yet — report it in one line and go straight to the audit.

**Audit.** Markers only cover the debt somebody noticed. Read the source for ceilings nobody wrote down:

- Nested scans, repeated lookups, or full loads over data that grows with the input.
- A process-wide lock, a single-threaded chokepoint, module-level mutable state.
- Naive heuristics on real-world data: splitting on a delimiter that can occur inside the value, matching on a display name where an identifier exists, first-match-wins on a key that is not unique, case-folding used as identity.
- Assumptions about upstream shape the upstream never promised: exactly one parent, a field that is always populated, an ID that is globally unique rather than unique per tenant.
- Unbounded growth: a cache with no eviction, a retry with no ceiling, a table only ever appended to.
- Swallowed errors, and error paths that assume a payload shape.
- Time, locale, encoding: naive datetimes, implicit local timezone, byte-length used as character length.

A limit already explained in a docstring or comment is not thereby handled. Prose that names the limit *and* the condition that breaks it is doing the marker's job — accept it, do not re-file it. Prose that only explains why the code is the way it is leaves the trigger uncheckable, which is the thing a marker fixes: **mark**.

## Triage

Every item gets exactly one disposition:

- **already triggered** — the condition in the marker is met today. This is not debt, it is an open bug. List these first, separately, and stop calling them debt.
- **fix now** — the fix is smaller than the marker explaining it. Do that instead.
- **mark** — the shortcut is right for now. Add the `CEILING:` comment. This is the only edit this skill makes. When reporting rather than editing, draft the full three fields anyway; a location without the limit, trigger and upgrade is not reviewable.
- **accept** — bounded forever by a real invariant. Write the invariant in a comment and take it off the ledger permanently. An accepted ceiling that keeps reappearing in every audit is ledger noise.

An item you cannot place in one of these four has not been understood yet. Read more; do not file it as "monitor".

## Output

One table for already-triggered items, one for the rest: location, limit, trigger, disposition. Order by blast radius, not by age.

Do not create a `DEBT.md`, a tracking issue, or a report file unless asked — the markers live next to the code, which is the only place they cannot rot out of sync with it.

If a pass finds nothing, say so. A short honest ledger beats a long one padded with style complaints; the audit categories above are limits, not preferences.
