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
The official Hermes Desktop package is installed on Dracula. In its **Settings → Gateway → Remote
gateway** page, use `https://alucard.tailf117a1.ts.net:29119`, sign in as `demo`, and retrieve the
password from SOPS only long enough to put it in the company password manager. Cofounders and
customers can install the official macOS, Windows, or Linux build and use the same remote URL.
Alucard uses Hermes' official authentication gate in addition to Tailscale; clients never receive
the Requesty credential.

The full MagicDNS name is required for the HTTPS certificate and Hermes host validation; the
shortened `https://alucard:29119` URL is not supported. An operator retrieves the current password
without committing plaintext:

```console
cd ~/nixos-config
sops --decrypt secrets/alucard-ai.yaml | yq -r '.hermes.dashboard_password'
```

The gateway and dashboard run as the unprivileged `hermes` system user. Their systemd
sandbox hides `/home`, makes the host filesystem read-only, allows writes only below
`/var/lib/hermes`, drops every capability, and limits network access to loopback. The
agent does not receive Docker access. Browser-chat child processes inherit the same
service boundary. On Alucard, a hardened Tinyproxy listener at `127.0.0.1:18084` permits
only `api.telegram.org` and the upstream Hermes Telegram onboarding service; direct agent
Internet access remains denied.

## Telegram quick setup

Alucard uses Hermes' official `messaging` package variant. In the dashboard, open
**Channels → Telegram → Create with QR**, scan the code in Telegram, confirm bot creation,
and retain the numeric owner ID offered by the workflow. The upstream dashboard stores the
bot token and strict numeric allowlist in `/var/lib/hermes/.hermes/.env`; rebuilds preserve
that runtime-owned file. The dashboard is deliberately allowed to manage runtime channel
settings even though the gateway remains Nix-managed. Nix-defined settings still win when a
rebuild merges them into `config.yaml`. BotFather manual token entry remains the fallback.

The dashboard's **Restart gateway** action performs a clean gateway shutdown. The NixOS
system service supervises that lifecycle with `Restart=always` and reclaims ownership with
Hermes' supported `gateway run --replace` mode if the dashboard briefly spawns a standalone
replacement. Do not enable a second Hermes user service or user lingering.

After setup, verify an allowed DM, `/model`, an inference record attributed to `hermes`, and
that an unlisted Telegram account receives no agent response. Keep group joining disabled
until a specific group ID and sender policy are reviewed.

The dashboard's personal-account WhatsApp QR option is not supported in this Nix deployment.
Upstream's Nix package omits its mutable Node bridge, and upstream documents the official
WhatsApp Business Cloud API—not that QR bridge—as the production path. Use Telegram for the
observation week; evaluate WhatsApp Cloud only when a real business number and Meta app exist.

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
