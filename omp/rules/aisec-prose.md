---
name: aisec-prose
description: Banned constructions that make written deliverables read as machine-generated
condition:
  - "\\bstructurally\\b"
  - "It['’]s not (about )?[a-z]+, it['’]s"
  - "is not [a-z ]+\\. It is"
  - "[Nn]ot [a-z]+ — [a-z]+\\."
  - "(?m)^[-*+\\s]*[A-Z][^.!?\\n]{0,60}, not [^.!?\\n]{1,40}\\.\\s*$"
scope:
  - "tool:edit(**/*.org)"
  - "tool:write(**/*.org)"
  - "tool:edit(**/*.typ)"
  - "tool:write(**/*.typ)"
  - "tool:edit(**/*.md)"
  - "tool:write(**/*.md)"
---
Rewrite this. These constructions mark a deliverable as machine-written and V rejects
them on sight:

- the "X, not Y" antithesis used as a headline, a refrain, or a closing line
- "structurally" as a filler intensifier
- epigram closers — the neat inverted sentence that ends a section

Use plain declaratives and vary sentence shape. First person plural for our work ("we",
"our"); owned first person singular for judgement ("my read"); neutral third person only
for external and analyst facts. Never the faceless grand-institutional voice — the audience
knows who wrote it. State the thing; do not perform it.
