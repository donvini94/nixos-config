# Hermes Agent on Dracula and Alucard

Phase 4 uses the official Nous Research Hermes Agent Nix flake, pinned in `flake.lock`.
The upstream NixOS module owns the gateway and persistent profile; this repository adds
the inference route and host isolation policy.

After activation:

- Dracula dashboard and browser chat: <http://127.0.0.1:9119/sessions>
- Alucard tailnet dashboard and browser chat:
  <https://alucard.tailf117a1.ts.net:29119/sessions>
- State and session history: `/var/lib/hermes/.hermes`
- Agent workspace: `/var/lib/hermes/workspace`
- Inference: each host's permanent logger at `127.0.0.1:8080`, attributed as `hermes`

## Browser quick start

1. Open **Sessions** with one of the links above.
2. Create a session and send a concrete task. For a safe first demo, ask Hermes to create a
   short Markdown research plan in its workspace and then summarize what it wrote.
3. Keep the session open while the agent works. If a terminal action matches Hermes' danger
   rules, approve or reject it in the browser.
4. Use **Files** to inspect workspace output and **Analytics** to inspect Hermes' local token
   estimate. Use Grafana for authoritative aggregate request/token/cost metrics.

Alucard uses the hosted Requesty model configured for the business demo; Dracula uses the local
model registry. The UI itself is otherwise the same. Hermes has no general browser or web-search
tool in this deployment, so demonstrate file, terminal, planning, memory, and session workflows
instead of promising live internet research.

For the full terminal interface, run `hermes-tui` on Dracula. On Alucard, attach over SSH:

```console
ssh -t Bereitserver hermes-tui
```

This runs the same pinned Hermes package and shared session database as the browser UI. It asks
for operator sudo authentication because the session belongs to the isolated `hermes` account.
The official desktop app can connect to a remote Hermes backend as well, but that path remains
disabled until Alucard has a proper dashboard authentication provider; tailnet reachability alone
is not a substitute for application authentication.

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
