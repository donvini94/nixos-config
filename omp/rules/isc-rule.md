---
name: isc-rule
description: SailPoint ISC rule development - which artifact deploys, injected variables per rule type, the API boundary, and the two gates that actually run
globs:
  - "**/rule-development-kit/**/*.java"
  - "**/rule-development-kit/**/*.xml"
  - "**/20-Rule-Development/**/*.java"
  - "**/rules/Rule*.xml"
---
# SailPoint ISC rules

Java-shaped, not a Java project. Read this before editing anything here, because the file
that compiles is not the file that deploys.

## The XML is the artifact

Three files carry one rule and they move together:

```
src/main/resources/rules/Rule - <Type> - <Name>.xml   <- deploys. BeanShell in <Source><![CDATA[...]]>
src/main/java/<Name>.java                             <- compile check only. Never deployed.
src/test/java/sailpoint/<Name>Test.java               <- extracts the XML's <Source> and evals it
```

The test reads the XML through `RuleXmlUtils.readRuleSourceFromFilePath()` and runs it in a
real `bsh.Interpreter` against Mockito doubles. So the suite proves the **shipped**
BeanShell, and a change made only in the `.java` twin passes every test while changing
nothing that deploys. Edit the XML first, mirror it into the `.java`, then the test.

The `.java` twin exists so the compiler and `javap` can check types against the SailPoint
stub JARs in `lib/`. It carries declarations - a `Logger`, a `plan`, an `IdnRuleUtil` - that
are stubs for the injected variables and are deleted when the logic is copied into
`<Source>`. Do not add a constructor, a `main`, or dependency wiring to make it "proper
Java". It is a type harness.

## Injected variables are per rule type

The `<Signature><Inputs>` block declares what the platform passes in. Reference anything
outside it and you get null at runtime, not a compile error.

| Rule type | Injected |
|---|---|
| BeforeProvisioning | `plan`, `log` - **not** `identity` |
| AttributeGenerator | `identity`, `log` |
| IdentityAttribute | `identity`, `log` |
| BuildMap | `record`, `columns`, `log` |
| ManagerCorrelation | `link`, `managerAttributeValue`, `log` |

BeforeProvisioning is the one that bites: reach the identity through `plan.getIdentity()`
and null-check it, because a plan without one is a real state and the rule should throw
`GeneralException` naming the identity rather than dereference it.

## ISC is not IdentityIQ

The stub JARs expose the IIQ surface, so IIQ idioms compile and then misbehave. Two
families:

- `getOperation()` returning `AccountRequest.Operation`, never `getOp()` / `ObjectOperation`.
- `context.getObjectById()`, `getObjectByName()`, `getObject()`, `search()`, `countObjects()`
  are gone in the cloud runtime. The `IdnRuleUtil` helper (`idn`) is the replacement.

When the published docs disagree with the stub JAR, the JAR wins - decompile it with
`javap -p` and follow the signature you find.

## Two gates, and the invocation matters

```sh
# unit tests - Java 17 and Maven come from devbox; a newer system JDK breaks byte-buddy
devbox run -- bash -c 'cd rule-development-kit && mvn test'
devbox run -- bash -c 'cd rule-development-kit && mvn test -Dtest=<Name>Test'

# ISC linter - the shipped ./sp-rv wrapper is not executable, so call the jar
java -jar sailpoint-saas-rule-validator-*/sailpoint-saas-rule-validator.jar \
  -f rule-development-kit/src/main/resources/rules/
```

The validator takes only `--file` / `-f`, accepts a directory and recurses, and rejects
`--help`. It enforces that the `name` attribute inside the XML matches the filename minus
the `Rule - <Type> - ` prefix. Both gates run before a rule is considered done; green tests
alone say nothing about whether the XML is deployable.

## Asserting on a BeanShell rule

BeanShell has no typed return, so tests verify through mock interaction rather than a
returned value - `verify(accountRequest).setNativeIdentity(expected)`. Thrown exceptions
arrive wrapped: catch `bsh.TargetError` and unwrap with `getTarget()` before asserting the
type and message.

Cover the operation filter explicitly. A rule that reacts to Create must be shown ignoring
Modify and Disable, because over-triggering on the wrong operation is silent in test and
destructive in production.

## Client specifics live with the client

Target OU tables, application names, attribute mappings and DN layouts are per engagement
and stay in the client repo - `SKILL.md` beside the kit carries them, and it is not
discoverable from here by design. This file holds only the platform mechanics, because it
is versioned in a public repository.
