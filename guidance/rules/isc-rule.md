---
name: isc-rule
description: SailPoint ISC guardrails for deployed artifacts, injected inputs and runtime API compatibility
globs:
  - "**/rule-development-kit/**/*.java"
  - "**/rule-development-kit/**/*.xml"
  - "**/20-Rule-Development/**/*.java"
  - "**/rules/Rule*.xml"
---
# SailPoint ISC rules

## Verify what ships

- Identify the deployed artifact before editing. In kits that deploy XML with BeanShell
  inside `<Source>`, a Java compile-check twin is not the deployed code.
- Keep any compile-check twin consistent with the XML. Tests must execute the shipped
  source, not merely a reimplementation that can drift from it.
- Run both the project's behavior tests and the applicable rule validator. Compilation
  against stub JARs alone does not establish cloud-runtime compatibility.

## Verify the runtime contract

- Check inputs against the rule type's documented signature; do not assume variables are
  injected because a local harness declares them. Handle absent values explicitly.
- A BeforeProvisioning rule does not receive `identity` as a separate input; retrieve it
  through the plan when needed and handle a missing identity.
- Do not assume IdentityIQ APIs exist in ISC. Use the documented ISC helpers. If stubs and
  documentation disagree, establish the deployed runtime's supported API before proceeding.
- Distinguish account and attribute operations: account requests use `getOperation()`;
  an attribute request's `getOp()` is a different API and must not be replaced blindly.
- Test operation filters and non-matching cases. Provisioning logic must not silently act
  on Modify or Disable when it is intended only for Create.
- When testing BeanShell failures, inspect the underlying exception rather than treating
  an interpreter wrapper as the rule's error contract.

## Keep project details local

Kit paths, build commands, toolchains, validator quirks, application names, mappings and
client-specific policy belong in the engagement's repository. Read its instructions first.
