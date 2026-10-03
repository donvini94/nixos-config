---
name: debt-ledger
description: Audit technical debt, distinguish concrete defects from acceptable trade-offs, and prioritize fixes.
argument-hint: "paths to audit (default: the whole source tree)"
---

Read the source and existing constraints. Look for problems that affect correctness,
security, performance or maintenance, not code that merely differs from your taste.

Check growing data structures, repeated scans, shared mutable state, unchecked input,
swallowed errors, unbounded retries, and assumptions about upstream APIs or identity.
Verify whether each suspected failure can actually occur with the current inputs.

Report the location, failure condition, evidence and smallest reasonable fix.
Separate current defects from future risks. State uncertainty rather than inventing
an upgrade plan for a problem that has not been demonstrated.

Do not add audit labels, tracking comments, report files or speculative abstractions.
Explain a non-obvious constraint in ordinary language only when it helps someone
maintain the code. Respect the project's authorization rules before making changes.

If nothing actionable is found, say so. Do not pad the audit with style complaints.
