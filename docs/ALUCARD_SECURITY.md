# Alucard security and exposure guide

Alucard has two deliberately separate access planes:

- Public services enter through nginx on ports 80 and 443, or through an explicitly required
  mail, synchronization, or game protocol.
- Administration, AI interfaces, metrics, and media automation use Tailscale. SSH forwarding
  remains the break-glass fallback.

Tailscale Funnel is prohibited. It would turn a private tailnet service into a public service.

## Current controls

- The NixOS firewall is enabled.
- SSH uses keys only; password login, keyboard-interactive login, and root login are disabled.
- Fail2ban currently protects SSH.
- nginx terminates ACME TLS and runs with NixOS systemd hardening.
- nginx applies OWASP CRS 4.25.1 LTS through ModSecurity, per-address request and
  connection limits, bounded request bodies, and consistent low-risk headers.
- AI and media-administration backends bind to loopback. Hermes' dashboard and authenticated
  automation API bind to `127.0.0.1`; only the dashboard is mapped through Tailscale Serve.
  n8n reaches the API through a socket restricted to its private Docker bridge.
- Nix assertions reject globally opened AI and web-backend ports.
- SOPS keeps encrypted source secrets out of the Nix store and renders runtime values beneath
  `/run/secrets`.
- Grafana, Prometheus, node-exporter, and cAdvisor provide machine and container metrics.
- CrowdSec is configured for local log analysis and firewall remediation in both the host
  `INPUT` and Docker `DOCKER-USER` chains. Its agent and authenticated firewall bouncer were
  recovered and verified active on 2026-08-09. Community event sharing is disabled unless
  an operator deliberately enrolls the machine later.

## Private Tailscale access

Tailscale is installed declaratively on Dracula and Alucard. It does not advertise routes,
act as an exit node, mark `tailscale0` trusted in the NixOS firewall, open a public firewall
port, or enable Taildrop. The explicit Tailscale Serve mappings below are the supported and
documented entry points.

Tailscale's default Linux netfilter mode independently accepts traffic arriving on
`tailscale0`; it runs before the NixOS firewall. Consequently, any application that binds a
wildcard address can also be reachable directly from an authorized tailnet peer even when it
is not a Serve mapping. The 2026-08-09 check found Jellyfin's raw port 8096 in this category.
This is private, not internet exposure, but it can bypass nginx/WAF. Loopback binding remains
the backend boundary, and restrictive Tailscale grants are mandatory before inviting the
cofounder or any customer identity.
The HTTP applications remain bound to `127.0.0.1`. Traffic between devices is encrypted by
Tailscale's WireGuard tunnel.

Alucard uses `systemd-resolved` plus explicit Cloudflare and Quad9 fallback resolvers. This
prevents Tailscale's MagicDNS takeover from losing all public upstream DNS after activation.
Raw-IP connectivity with hostname `SERVFAIL` is a resolver fault, not evidence that CrowdSec
or the NixOS firewall blocked outbound traffic.

Enroll each machine once:

```console
sudo tailscale up
```

Open the login URL printed by that command. After Alucard is enrolled, apply its declarative
Serve mappings:

```console
sudo systemctl restart tailscale-private-services.service
tailscale serve status
```

The stable MagicDNS name is `alucard.tailf117a1.ts.net`; the short name `alucard` also works
when MagicDNS search domains are enabled. The `100.x` address can change and should not be
bookmarked.

### AI and observability

| Component | Tailnet URL |
| --- | --- |
| n8n | `http://alucard.tailf117a1.ts.net:25678` |
| Requesty-backed API | `http://alucard.tailf117a1.ts.net:28080/v1` |
| Hermes | `https://alucard.tailf117a1.ts.net:29119` |
| Langfuse | `http://alucard.tailf117a1.ts.net:23000` |
| Grafana | `http://alucard.tailf117a1.ts.net:23001` |
| Wirken | `http://alucard.tailf117a1.ts.net:28790` |
| Prometheus | `http://alucard.tailf117a1.ts.net:29091` |

### Media administration

| Component | Tailnet URL |
| --- | --- |
| Kapowarr | `http://alucard.tailf117a1.ts.net:15656` |
| Sonarr | `http://alucard.tailf117a1.ts.net:18989` |
| Radarr | `http://alucard.tailf117a1.ts.net:17878` |
| Prowlarr | `http://alucard.tailf117a1.ts.net:19696` |
| Bazarr | `http://alucard.tailf117a1.ts.net:16767` |
| qBittorrent | `http://alucard.tailf117a1.ts.net:18080` |
| SABnzbd | `http://alucard.tailf117a1.ts.net:19090` |

The existing `ssh -N ai-admin` and `ssh -N media-admin` profiles remain available if Tailscale
is unavailable. Do not expose these ports through nginx, Tailscale Funnel, Docker wildcard
bindings, or the global firewall.

Before adding more tailnet members, create a Tailscale operator group, tag Alucard as a server,
and use grants to allow only that group to these ports. Record the final policy and its owner
here after applying and testing it.

## CrowdSec operations

Use `crowdsec-admin` for interactive CrowdSec administration:

```console
crowdsec-admin metrics
crowdsec-admin decisions list
crowdsec-admin alerts list
```

This launcher runs the official `cscli` in CrowdSec's systemd-managed state namespace and asks
for sudo authentication. Calling the NixOS-provided `cscli` wrapper directly does not work with
the firewall-bouncer module's DynamicUser state-directory layout.

The remediation path was verified live on 2026-08-09 using a real nginx-derived decision: the
address appeared in `crowdsec-blacklists-0`, and both `INPUT` and `DOCKER-USER` jumped to
`CROWDSEC_CHAIN`. Recheck it without changing firewall state by selecting an active IPv4 decision
from `crowdsec-admin decisions list`, then running:

```console
sudo iptables -C INPUT -j CROWDSEC_CHAIN
sudo iptables -C DOCKER-USER -j CROWDSEC_CHAIN
sudo ipset test crowdsec-blacklists-0 ADDRESS
```

## Public-service inventory

nginx currently defines public HTTPS virtual hosts for Keycloak, GitLab, Docker Registry,
Jellyfin, chat, Navidrome, Paperless, file management, budgeting, Calibre, Mailcow, Coder,
Komga, Seerr, WebDAV, and static sites. Some configured backends are currently absent and
return HTTP 502; unused virtual hosts must be retired instead of remaining as dead public
entry points.

Mail protocols, SSH, Syncthing, and selected game ports do not pass through nginx. They need
their own explicit firewall justification and protocol-specific protection.

## Hardening work register

| Priority | Work | State |
| --- | --- | --- |
| P0 | Keep AI and administration private | Enforced; tailnet endpoints verified from Dracula |
| P0 | Remove direct public Jellyfin ports 8096/8920 | Enforced; both ports externally verified closed/filtered |
| P0 | Bind Mailcow web ports 880/4433 to loopback | Pending controlled Mailcow maintenance |
| P0 | Back up and update Mailcow from 2025-07 to current stable | Pending; local modifications must be reconciled |
| P1 | Install CrowdSec engine and firewall remediation | Complete; real nginx decision verified in the live ipset behind both host and Docker chains |
| P1 | Add tested nginx AppSec/WAF integration | Active; normal Jellyfin request returned 302 and a traversal/shell probe returned 403 on 2026-08-09 |
| P1 | Add per-service rate and connection limits | Active at the nginx edge; configuration and normal application path verified |
| P1 | Apply consistent security headers and bounded request sizes | Active; upload-heavy Registry/Filebrowser/WebDAV bypass WAF and retain explicit size policy |
| P1 | Retire dead DNS/vhosts and remove unused firewall ports | Dead root/Git/docs/Coder backends return 404; unused TCP 53/873/11335/11445 removed |
| P2 | Define Keycloak/2FA policy for every public application | Pending identity review |
| P2 | Harden native services and containers | Keycloak loopback bind and systemd sandbox prepared; remaining application policy review pending |
| P2 | Add vulnerability scanning and security alerts | Trivy daily scan and Grafana/Prometheus export verified; per-image remediation and external notification routing pending |
| P2 | Implement and test application-aware backups/restores | Pending; required before customer use |
| P3 | Add GeoIP restrictions to selected web services | Pending explicit country policy; never global mail blocking |

Signal's loopback HTTP bridge is intentionally not included in Tailscale Serve. Its Unix socket
is group-scoped, and its linked-device state is mode 0700. Sender allowlists remain mandatory:
Signal transport encryption authenticates the sender but does not make the message safe agent
input.

Run an on-demand scan with `containers-scan`. The official rolling Trivy container inspects
an archive exported from every distinct image currently resident in the root Docker daemon and
the `vincenzo` rootless daemon when present. This avoids registry drift and does not expose a
Docker socket to the scanner. Full JSON reports stay root-only under
`/var/lib/container-vulnerability-scan/reports`; aggregate critical/high/failure counts and
scan age appear in the **AI and machine overview** Grafana dashboard. A finding is inventory,
not proof of exploitability: review the package, reachable surface, and upstream fix before
changing production images.

The first live scan on 2026-08-09 inspected 40 image references and exported 175 critical,
2,265 high, and one failed-image count. These totals include duplicate packages across related
images, but all requested findings have published fixes because the scan uses `--ignore-unfixed`.
Per-image triage and remediation are required before calling Alucard production-ready.

The WAF uses the current OWASP CRS v4 LTS rather than Nixpkgs' older CRS 3.3.4,
which predates July 2026 security fixes. Response-body inspection is disabled to
avoid reflected denial-of-service behavior. After switching, verify both normal
application traffic and a known malicious request before calling the WAF shipped:

```bash
curl -I https://stream.dumusstbereitsein.de
curl -i 'https://stream.dumusstbereitsein.de/?probe=/etc/passwd&shell=/bin/sh'
sudo tail -50 /var/log/nginx/modsec_audit.log
```

This acceptance passed on 2026-08-09: the first request returned its normal HTTP 302 and the
probe returned HTTP 403. The audit-log entry and Keycloak's local listener still require a
host-side check because neither is exposed to the tailnet:

```bash
ss -ltn '( sport = :38080 )'
systemd-analyze security keycloak.service
```

Repeated nginx reloads and clean stops segfaulted in libmodsecurity's PCRE2 10.47 JIT allocator.
Both live coredumps identified the JIT compile/free stacks. Alucard therefore disables the two
eager JIT calls only in libmodsecurity; its maintained interpreter fallback remains active while
nginx retains standard reload semantics and the full service sandbox. Verify this compatibility
policy after changes with three consecutive `systemctl reload nginx` calls, a clean restart, and
an HTTPS health check; a new coredump or failed unit is a release blocker.

## Mailcow maintenance boundary

Mailcow lives in `/opt/mailcow-dockerized` outside the NixOS repository. Its own supported
`update.sh` must manage application upgrades because Mailcow updates include configuration and
database migrations. Do not add it to the generic container pull timer.

Before updating:

1. Produce and verify a Mailcow backup.
2. Preserve a patch of every locally modified tracked file.
3. Classify each local change as obsolete, still required, or secret material that belongs in
   `mailcow.conf`/supported override files.
4. Bind `HTTP_BIND` and `HTTPS_BIND` to `127.0.0.1` as documented by Mailcow.
5. Run the official update checker, review release notes across skipped releases, then use the
   supported updater during a maintenance window.
6. Verify SMTP submission, inbound and outbound delivery, IMAP, SOGo, TLS, DNS records,
   backups, and the nginx frontend before closing the window.

References:

- [Tailscale Serve](https://tailscale.com/docs/features/tailscale-serve)
- [Tailscale grants](https://tailscale.com/kb/1337/policy-syntax)
- [CrowdSec nginx and AppSec](https://docs.crowdsec.net/u/bouncers/nginx/)
- [CrowdSec firewall bouncer](https://docs.crowdsec.net/u/bouncers/firewall/)
- [Mailcow reverse proxy](https://docs.mailcow.email/post_installation/reverse-proxy/r_p/)
- [Mailcow updates](https://docs.mailcow.email/maintenance/update/)
