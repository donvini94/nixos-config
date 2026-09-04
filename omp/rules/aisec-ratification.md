---
name: aisec-ratification
description: Only a human promotes a score — ratified dates are written by ratify.mjs, never by hand
condition:
  - "\"ratified\":\\s*\"\\d{4}"
scope:
  - "tool:edit(**/ratification.json)"
  - "tool:write(**/ratification.json)"
---
You are writing a ratified date. Stop unless a human in this conversation told you to.

- A score is a **proposal** until a person promotes it. That is the rule the whole
  programme runs on: the sweep proposes, a human promotes.
- `ratified` is written by `node reports/ai_security_matrix/ratify.mjs --promote=<pass> --by=<name>`,
  which runs the invariants first and records who decided. Hand-editing the field
  forges the one signature in the store that is not yours to give.
- Adding a pass is yours; it takes `"ratified": null`. Promoting it is not.

What you may do instead: `ratify.mjs --queue` prints the batch as org, and you put it
to V with the specific decision named.
