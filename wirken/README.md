# Wirken on dracula

Wirken is the governed browser/chat agent path in the local AI stack. Open its upstream
WebChat at <http://127.0.0.1:18790> after `ai-stack-start`.

## Lifecycle and health

Wirken is part of `ai-stack.target`, so the existing lifecycle is authoritative:

```console
ai-stack-start
ai-stack-health
ai-stack-stop
```

The relevant units are `wirken-init.service`, `wirken-sandbox-image.service`,
`wirken.service`, `wirken-audit-anchor.service`, and `wirken-audit-verify.timer`.
`ai-stack-stop` is also the emergency stop; it does not depend on the Wirken UI or agent.

## State and secrets

- Gateway state and workspace: `/var/lib/wirken/.wirken`
- Operator-pinned audit key: `/var/lib/wirken-audit-anchor/audit-signing.pub`
- Declarative provider: `custom/qwen3.6-27b-local` through `http://127.0.0.1:8080/v1`
- Exec sandbox: upstream `exec-only`, no network, digest-pinned Debian image
- Bootstrap secrets: `secrets/dracula-ai.yaml`, delivered with systemd credentials
- Application credentials: Wirken's encrypted vault, added only when a real connector is
  introduced

The local bearer token lets the inference logger attribute a client that cannot set
`X-AI-Caller`; it is not an authentication boundary.

## Audit

Run an anchored verification or inspect recent events with:

```console
wirken-audit-verify
wirken-audit-log --limit 50
```

The verifier deliberately hides Wirken's co-resident public-key copy and reads the
root-owned anchor instead. A key mismatch fails activation and requires an explicit,
reviewed anchor rotation.

## Security boundary

Wirken governs tools, approvals, credentials, and audit events for agents running inside
Wirken. It does not transparently intercept independent Hermes, n8n, OMP, or OpenCode
processes. Those paths remain bypass-capable until migrated to an upstream-supported
Wirken integration.

The `wirken` service account belongs to the Docker group so it can create upstream's
ephemeral exec sandbox. Docker access is root-equivalent for the gateway process, although
the agent's exec container never receives the Docker socket. The human operator is also
already in the Docker group; do not describe this workstation as a boundary against a
determined same-UID process.

## Upgrade procedure

Use a published GitHub release with its binary, `checksums.sha256`, and
`checksums.sha256.sig`. Verify the manifest against the release key pinned in the audited
source commit, verify the binary against that signed manifest, then update
`packages/wirken.nix`. Do not advance to an unsigned tag-only commit merely because its
version number is newer.
