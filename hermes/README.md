# Hermes Agent on Dracula and Alucard

Phase 4 uses the official rolling `nousresearch/hermes-agent:latest` container. The image's
s6 supervisor owns the gateway and dashboard; this repository supplies persistent mounts,
the private inference route, authentication, and Compose lifecycle.

After activation:

- Dracula dashboard and browser chat: <http://127.0.0.1:9119/sessions>
- Alucard tailnet dashboard and browser chat:
  <https://alucard.tailf117a1.ts.net:29119/sessions>
- State and session history: `/var/lib/hermes/.hermes`
- Agent workspace: `/var/lib/hermes/workspace`
- Shared Org tree: host `/home/vincenzo/org`, container `/org`
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

This executes the CLI inside the same container and shared session database as the browser UI.
The operator must belong to the host's Docker group.
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

Hermes runs from the official `nousresearch/hermes-agent:latest` image. Gateway and dashboard
share one container and its upstream s6 supervisor, while `/var/lib/hermes/.hermes` is mounted
at the official persistent `/opt/data` boundary. The container receives no Docker socket;
only its isolated workspace and the explicitly shared Org tree are mounted from the host.
The dashboard binds to host loopback;
Alucard reaches it through authenticated Tailscale Serve. Telegram uses the domain-filtered
proxy at `127.0.0.1:18084`.

## n8n and Org integration

Hermes and n8n can collaborate without either container gaining general host access:

- Both mount `/home/vincenzo/org` read-write as `/org`. Host ACLs grant the isolated Hermes
  UID access, while n8n keeps file nodes restricted to `/org`.
- Hermes may call reviewed production webhooks at
  `http://127.0.0.1:5678/webhook/<path>`. No n8n administration token is given to Hermes.
- n8n may call Hermes' OpenAI-compatible API at
  `http://host.docker.internal:8642/v1`. A systemd socket proxies only n8n's private Docker
  bridge to Hermes' loopback listener; port `8642` is not exposed on the LAN, tailnet, or
  public firewall.
- The Hermes API requires the SOPS-managed `hermes/api_server_key`. Store it in an n8n
  Header Auth credential as `Authorization: Bearer <key>`; never put it in workflow JSON.

No workflows are installed automatically. Their webhook paths, allowed actions, and payload
schemas remain reviewable workflow artifacts. Notion, Linear, and other systems should be
added through their maintained n8n nodes or reviewed MCP servers, with separate credentials.

## Telegram quick setup

The official image includes Hermes' messaging dependencies. In the dashboard, open
**Channels → Telegram → Create with QR**, scan the code in Telegram, confirm bot creation,
and retain the numeric owner ID offered by the workflow. The upstream dashboard stores the
bot token and strict numeric allowlist in `/var/lib/hermes/.hermes/.env`; rebuilds preserve
that runtime-owned file. The dashboard owns runtime channel settings and `config.yaml` after
the initial seed; Nix does not replace them. BotFather manual token entry remains the fallback.

The dashboard's **Restart gateway** action is handled by the image's s6 supervisor. Do not
install a second host or user gateway.

After setup, verify an allowed DM, `/model`, an inference record attributed to `hermes`, and
that an unlisted Telegram account receives no agent response. Keep group joining disabled
until a specific group ID and sender policy are reviewed.

The official image includes the personal-account WhatsApp bridge. It remains deferred for
customer use: evaluate WhatsApp Business Cloud when a real business number and Meta app exist.

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

No MCP server is enabled initially. Use maintained n8n nodes or reviewed MCP servers when a
real external system is introduced instead of building a custom adapter.
