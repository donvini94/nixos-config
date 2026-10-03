---
name: isc-rule-divergence
description: SailPoint ISC patterns that pass tests and fail after deploy - IIQ-only API, uninjected variable, edited twin instead of artifact
condition:
  - "^(?!\\s*(?://|\\*|/\\*))[^\\n]*(\\.getOp\\(\\)|\\bObjectOperation\\b)"
  - "^(?!\\s*(?://|\\*|/\\*))[^\\n]*context\\.(getObjectById|getObjectByName|getObject|search|countObjects)\\("
scope:
  - "tool:edit(**/rule-development-kit/src/main/**)"
  - "tool:write(**/rule-development-kit/src/main/**)"
  - "tool:edit(**/20-Rule-Development/**/src/main/**)"
  - "tool:write(**/20-Rule-Development/**/src/main/**)"
  - "tool:edit(**/rules/Rule*.xml)"
  - "tool:write(**/rules/Rule*.xml)"
---
Review the matched API against the actual ISC rule contract. Stub compilation is not proof
of runtime support.

- Account requests use `getOperation()`; attribute requests may correctly use `getOp()`.
  Check the receiver type before replacing a call.
- IdentityIQ `context.*` object access is not an ISC cloud API. Use supported ISC helpers.
- Confirm the edit reaches the deployed XML source and tests execute that source.
- Confirm referenced variables are inputs for this rule type; local harness declarations
  do not make them available in production.

The full requirements live in `isc-rule.md`; paths and commands belong to the project.
