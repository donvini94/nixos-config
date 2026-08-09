# Wirken on dracula

Wirken is an experimental browser/chat agent path in the local AI stack. Open its upstream
WebChat at <http://127.0.0.1:18790> after `ai-stack-start`.

Do not use it for effectful work. Release v1.13.0 has a confirmed session-ID mismatch in
its WebChat approval gate: effectful tool calls fail closed because the approval request
cannot reach the browser. The newer tag-only v1.16 source has the same defect. This trial
remains installed for audit inspection while a maintained replacement is selected.

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

Use the upstream CLI through the state- and vault-aware operator launcher:

```console
wirken-admin doctor
wirken-admin channel list
wirken-admin permissions pending
wirken-admin approvers list
```

`wirken-admin` asks for sudo, runs as the isolated `wirken` account, and obtains the vault
passphrase through a systemd credential and private pseudo-terminal. The passphrase does not
enter argv, the environment, shell history, or the journal. Commands that mutate upstream
state still require an intentional operator invocation; Nix does not replace Wirken's vault,
adapter registry, permission database, or audit model.

## Usable governed path for the observation week

Use upstream's interactive `ask` command for real governed tasks:

```console
wirken-admin ask --message "Create a concise implementation plan for this task: ..."
```

Unlike the affected WebChat path, `ask` attaches Wirken's stdin approval gate when run from a
terminal. Tier 2/3 tool requests display an interactive approval prompt, execute only after the
operator's decision, and enter the signed audit chain. It is deliberately one task per command,
not a full-screen chat client. Use Hermes Telegram/Desktop for conversational work and Wirken
`ask` for approval/audit exercises until a safe persistent channel is configured.

## State and secrets

- Gateway state and workspace: `/var/lib/wirken/.wirken`
- Operator-pinned audit key: `/var/lib/wirken-audit-anchor/audit-signing.pub`
- Declarative provider: `custom/qwen3.6-27b-local` through `http://127.0.0.1:8080/v1`
- Exec sandbox: upstream `exec-only`, no network, rolling official Debian image
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

The verifier receives the root-owned anchor explicitly. Wirken v1.13 incorrectly warns
that any supplied key equal to its local public key is co-resident, even when the supplied
file is outside the gateway data directory; the warning is an upstream provenance-detection
limitation. A real key mismatch still fails and requires an explicit, reviewed rotation.

## Security boundary

Wirken is intended to govern tools, approvals, credentials, and audit events for agents
running inside Wirken, but the confirmed WebChat defect means this deployment has not met
that claim through WebChat. The interactive `wirken-admin ask` path does have its upstream
stdin approval gate and is the supported effectful test path. Wirken does not transparently
intercept independent Hermes, n8n, OMP, or OpenCode processes.

The `wirken` service account belongs to the Docker group so it can create upstream's
ephemeral exec sandbox. Docker access is root-equivalent for the gateway process, although
the agent's exec container never receives the Docker socket. The human operator is also
already in the Docker group; do not describe this workstation as a boundary against a
determined same-UID process.

## Messaging channel status

No Wirken messaging channel is configured. Telegram was considered after the Signal account
requirement proved impractical, but Wirken 1.13's released security model does not authorize
by platform sender identity: identities are audited, while approvals are scoped to agent and
action. Its Telegram adapter also responds to all private messages. A discoverable Telegram
bot would therefore widen access beyond the operator and is not enabled.

Hermes will own the first Telegram bot because its maintained adapter has explicit numeric
user and chat allowlists. Wirken stays on its private WebChat and `wirken-admin` surfaces until
upstream provides sender authorization or a separately reviewed channel is deployed. Do not
reuse one bot or conversation across both agents.

## Upgrade procedure

Use a published GitHub release with its binary, `checksums.sha256`, and
`checksums.sha256.sig`. Verify the manifest against the release key pinned in the audited
source commit, verify the binary against that signed manifest, then update
`packages/wirken.nix`. Do not advance to an unsigned tag-only commit merely because its
version number is newer.
