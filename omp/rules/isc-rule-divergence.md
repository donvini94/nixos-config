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
Stop. Each of these compiles against the stub JARs and fails in the cloud runtime, where the
only symptom is a provisioning result nobody expected.

**`getOp()` on an account request, or `ObjectOperation` anywhere.** IdentityIQ idiom. ISC
wants `getOperation()` returning `AccountRequest.Operation`, and the stub JAR still exposes
the old shape, so nothing warns you - the rule simply never matches the operation it was
written for.

`AttributeRequest.getOp()` returning `ProvisioningPlan.Operation` is a different, correct
API. Do not "fix" it. This rule deliberately does not fire under `src/test/`, where
asserting on it is normal.

**`context.*` object access.** `getObjectById`, `getObjectByName`, `getObject`, `search` and
`countObjects` are unavailable in the ISC runtime. Use the injected `IdnRuleUtil`. This is a
deploy-time failure, not a test-time one.

Two more that no regex can see, so check them by eye before you finish:

**Did the edit land in the XML?** `src/main/resources/rules/Rule - *.xml` is what deploys.
Editing `src/main/java/<Name>.java` alone leaves the suite green and the deployed rule
unchanged - the tests eval the XML's `<Source>`, not the twin. The triad moves together.

**Is the variable actually injected?** Only what `<Signature><Inputs>` declares arrives.
`identity` is not passed to a BeforeProvisioning rule; it comes from `plan.getIdentity()`.
An uninjected reference is null at runtime and silent everywhere else.
