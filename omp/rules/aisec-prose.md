---
name: aisec-prose
description: Banned prose constructions in AI-security research deliverables; also read for AISec sessions
globs:
  - "**/reports/ai_security_matrix/**"
  - "**/reports/ai_agent_security_whitepaper_2026/**"
  - "**/reports/ai_security_partner_review_2026/**"
  - "**/reports/agentic_identity_reference_architecture_2026/**"
  - "**/reports/agentic_identity_market_comparison_2026/**"
  - "**/roam/main/ai_security*.org"
  - "**/roam/main/agentic_identity.org"
condition:
  - "\\bstructurally\\b"
  - "It['’]s not (about )?[a-z]+, it['’]s"
  - "is not [a-z ]+\\. It is"
  - "[Nn]ot [a-z]+ — [a-z]+\\."
  - "(?m)^[-*+\\s]*[A-Z][^.!?\\n]{0,60}, not [^.!?\\n]{1,40}\\.\\s*$"
scope:
  - "tool:edit"
  - "tool:write"
---
Apply these prose constraints to AI-security research deliverables and AISec sessions.
Native TTSR path gates enforce them on the named research sources; the
`aisec-session` rulebook entry supplies the same context when the session topic is
AISec. Do not apply them to unrelated Org or Markdown work.

Rewrite this. These constructions make a written deliverable read as machine-generated:

- the "X, not Y" antithesis used as a headline, a refrain, or a closing line
- "structurally" as a filler intensifier
- epigram closers — the neat inverted sentence that ends a section

Use plain declaratives and vary sentence shape. First person plural for our work ("we",
"our"); owned first person singular for judgement ("my read"); neutral third person only
for external and analyst facts. Never the faceless grand-institutional voice — the audience
knows who wrote it. State the thing; do not perform it.
