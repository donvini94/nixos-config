# Hermes Agent on Dracula

Phase 4 uses the official Nous Research Hermes Agent Nix flake, pinned in `flake.lock`.
The upstream NixOS module owns the gateway and persistent profile; this repository adds
the local inference route and the host isolation policy.

After activation:

- Dashboard and browser chat: <http://127.0.0.1:9119>
- State and session history: `/var/lib/hermes/.hermes`
- Agent workspace: `/var/lib/hermes/workspace`
- Inference: the permanent logger at `127.0.0.1:8080`, attributed as `hermes`

The gateway and dashboard run as the unprivileged `hermes` system user. Their systemd
sandbox hides `/home`, makes the host filesystem read-only, allows writes only below
`/var/lib/hermes`, drops every capability, and limits network access to loopback. The
agent does not receive Docker access. Browser-chat child processes inherit the same
service boundary.

`approvals.mode = "manual"` is a dangerous-command gate, not approval of every action.
Hermes prompts for terminal commands that match its risk patterns. Routine reads,
`write_file`/`patch` below `HERMES_WRITE_SAFE_ROOT`, and ordinary Git commits can proceed
without a prompt. The write-safe-root restriction and systemd confinement are the actual
host boundary; use the session transcript and ingress log as the audit record.

The workspace is initialized as a Git repository on first start. Inspect it with:

```bash
sudo -u hermes git -C /var/lib/hermes/workspace status
sudo -u hermes git -C /var/lib/hermes/workspace log --oneline --decorate
```

Hermes' dashboard token analytics are enabled for operational insight, but upstream calls
them a local lower-bound estimate: auxiliary calls, retries, fallbacks, and cache writes
can be absent. The ingress JSONL remains the authoritative complete request/token record.

No MCP server is enabled initially because there is no external integration in scope.
Hermes' upstream MCP client is packaged and the NixOS module exposes declarative
`services.hermes-agent.mcpServers`; add established MCP servers there when a real tool is
introduced instead of building a custom adapter.
