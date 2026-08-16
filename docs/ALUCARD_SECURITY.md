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
  The authenticated Jellyfin playback endpoint family `POST /Sessions/Playing*` is the sole
  location-level WAF exception: CRS 4.25.1 falsely blocks Swiftfin's payload before
  Jellyfin can authorize it; Jellyfin itself retains authorization for those endpoints.
- AI and media-administration backends bind to loopback. Jellyfin and Mailcow web backends
  also bind to `127.0.0.1`: they remain available to friends and family through their public
  nginx HTTPS hosts, while raw backend ports cannot bypass nginx. Mail protocols remain direct.
  Hermes' dashboard and authenticated automation API bind to `127.0.0.1`; only the dashboard is
  mapped through Tailscale Serve.
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
| Wirken | `https://alucard.tailf117a1.ts.net:28790` |
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

If a legitimate source is unable to reach every public service while an independent network
still can, inspect the exact decision and its triggering requests before changing policy:

```console
crowdsec-admin decisions list -i CLIENT_IPV4 --color no
crowdsec-admin alerts inspect ALERT_ID --details --color no
```

Delete only a confirmed false-positive decision, then restart the bouncer to apply it
immediately. Do not disable CrowdSec, flush firewall rules, or persistently whitelist a
residential address without finding the triggering request pattern:

```console
crowdsec-admin decisions delete -i CLIENT_IPV4
systemctl restart crowdsec-firewall-bouncer.service
```

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
| P0 | Bind Jellyfin 8096 and Mailcow web ports 880/4433 to loopback; retain public nginx access and the host ACME certificate | Enforced and checked locally on 2026-08-15 |
| P0 | Back up and update Mailcow from 2025-07 to current stable | Complete; operator confirmed web login and mailbox retrieval on 2026-08-15 |
| P1 | Install CrowdSec engine and firewall remediation | Complete; real nginx decision verified in the live ipset behind both host and Docker chains |
| P1 | Add tested nginx AppSec/WAF integration | Active; normal Jellyfin request returned 302 and a traversal/shell probe returned 403 on 2026-08-09 |
| P1 | Add per-service rate and connection limits | Active at the nginx edge; configuration and normal application path verified |
| P1 | Apply consistent security headers and bounded request sizes | Active; upload-heavy Registry/Filebrowser/WebDAV bypass WAF and retain explicit size policy |
| P1 | Retire dead DNS/vhosts and remove unused firewall ports | Dead root/Git/docs/Coder backends return 404; unused TCP 53/873/11335/11445 removed |
| P2 | Define Keycloak/2FA policy for every public application | Deferred for one identity-platform design and rollout with Keycloak, Teleport, and OpenBao; not a standalone hardening change. |
| P2 | Harden native services and containers | Keycloak loopback bind and systemd sandbox prepared; remaining application policy review pending |
| P2 | Add vulnerability scanning and security alerts | 41-image post-Mailcow scan and Prometheus/Grafana export verified; cAdvisor upgraded; fixed findings and upstream-owned residuals are triaged below |
| P3 | Add GeoIP restrictions to selected web services | Pending explicit country policy; never global mail blocking |

The future identity-platform work combines Keycloak policy, Teleport access, and
OpenBao secret-management boundaries in one reviewed deployment. It must define
the authentication authority, 2FA requirements, service enrollment, secret
migration, break-glass access, and rollback together; adding any component in
isolation would create conflicting trust boundaries.

### Paperless off-site recovery verification

`paperless-offsite-backup.service` creates the repository parent only after the
Hetzner CIFS automount is active, then snapshots Paperless' exporter output and
its Django signing key. `paperless-offsite-restore-verify.service` restores the
latest snapshot into a temporary directory beneath `/var/lib/paperless`, verifies
both paths, and removes that directory without touching live Paperless data or the
repository. Run it on demand after changing the backup configuration:

```bash
sudo env TERM=dumb SYSTEMD_PAGER=cat \
  systemctl start paperless-offsite-restore-verify.service
sudo env TERM=dumb SYSTEMD_PAGER=cat \
  systemctl show paperless-offsite-restore-verify.service \
  -p Result -p ExecMainStatus --no-pager
```

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

The post-Mailcow scan on 2026-08-15 inspected 41 resident image references and exported
84 critical, 1,357 high, and zero failed-image counts. These totals include duplicate packages
across related images; `--ignore-unfixed` means every reported finding has a published fixed
version. Root-only JSON reports remain the authoritative package/CVE inventory.

On 2026-08-16, cAdvisor moved from the obsolete GCR `latest` image (v0.55.1) to the
upstream-supported, digest-pinned `ghcr.io/google/cadvisor:v0.60.5`. Its live `/metrics`
endpoint and runtime version were verified. A direct fresh scan of that exact digest reduced
cAdvisor from four critical and 55 high findings to zero critical and eight high findings.

### Temporary vulnerability risk register

These entries are temporary, evidence-based risk acceptances—not evidence that the findings are
unexploitable. They are reviewed on the earlier of the stated date or an upstream image release.
The remaining high findings are **not** blanket-accepted: their package/CVE detail remains in the
root-only reports and each image is exported as a Prometheus time series.

| Component | Fixed findings currently resident | Exposure and compensating controls | Revisit |
| --- | --- | --- | --- |
| cAdvisor v0.60.5 | High: `CVE-2026-33818`, `CVE-2026-39821`, `CVE-2026-56853`, `CVE-2026-56858`, `CVE-2026-56859`, `CVE-2026-56860`, `CVE-2026-56862` (`stdlib` v1.25.12, fixed v1.25.13); `GHSA-hrxh-6v49-42gf` (`grpc` v1.81.1, fixed v1.82.1) | Privileged host inspector, but bound only to `127.0.0.1:18081`; Prometheus reaches it locally. Replacing it with the unsupported GCR image is prohibited. | Next cAdvisor release or 2026-08-30 |
| Mailcow 2026-07a | Critical: `CVE-2026-31789` (OpenSSL), `CVE-2026-3593` (BIND), `CVE-2026-33845`/`CVE-2026-42010` (GnuTLS), `CVE-2026-44170`/`CVE-2026-44172`/`CVE-2026-49261` (MariaDB) across its current components | Public mail protocols and web UI are necessary. Nix firewall policy, nginx TLS/WAF, service authentication, and upstream-only `update.sh` constrain exposure; independent image replacement is unsupported. | Next Mailcow stable release or 2026-08-23 |
| Seerr v3.4.1 | Critical: `CVE-2026-33937` (`handlebars` 4.7.8, fixed 4.7.9); `CVE-2026-59873` (`tar` 6.2.1–7.5.13, fixed 7.5.19) | Public request UI through nginx. TLS, ModSecurity, application authentication, and loopback-only container binding remain required. The installed version is the current upstream release. | Next Seerr release or 2026-08-23 |
| Komga 1.26.3 | Critical: `CVE-2023-24538`, `CVE-2023-24540`, `CVE-2024-24790`, `CVE-2025-68121` (`stdlib` v1.17.8) | Public comics UI through nginx; application authentication and TLS remain required. Docker Hub `latest` resolves to the same official 1.26.3 digest, so retagging cannot remediate it. | Next Komga release or 2026-08-23 |
| Private services | Kapowarr: `CVE-2026-33845`, `CVE-2026-42010`, `CVE-2026-31789`, `CVE-2025-68121`; Hermes: `CVE-2026-59873`; internal Redis/Postgres/MariaDB/Ofelia findings are recorded per package in the scan reports | These services are limited to loopback or private Docker networks; Hermes and AI interfaces are not public. Keep Docker-published ports closed and retain their existing service authentication. | Upstream release or 2026-08-30 |
| Host packages | The 2026-08-05 Nixpkgs lock is retained. A 2026-08-13 update builds Alucard but fails Dracula because upstream `ananicy-cpp` 1.2.0 does not build with the newer C++ toolchain. No local package patch is permitted. | `ananicy-cpp` is an existing desktop process-priority daemon, not a security control. The operator chose to retain it rather than change desktop scheduling behavior. | A Nixpkgs update that builds out of the box, or 2026-08-30 |

### Runtime privilege review

All 41 rootful containers were reviewed on 2026-08-16. cAdvisor is privileged because the
upstream collector requires host namespaces and `/dev/kmsg`; it remains loopback-only. Mailcow's
official `netfilter` container is privileged, and its `ofelia` scheduler and `dockerapi` have the
Docker socket; those are root-equivalent boundaries confined to the supported Mailcow stack.
Gluetun has only `CAP_NET_ADMIN`, required for its VPN kill switch. No other resident container
has extra capabilities or the Docker socket.

Every reviewed rootful container currently has a writable root filesystem. This is not silently
"hardened" with a blanket `read_only` flag: it would break stateful upstream images and obscure
their required writable paths. New or upgraded compose services must instead document and test a
per-container read-only-root plan before it is enabled.

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

Mailcow lives in `/opt/mailcow-dockerized` outside the NixOS repository. Its supported
`update.sh` manages its application, image, configuration, and database migrations. Do not add
it to the generic container pull timer. The NixOS `mailcow-tls` unit deliberately has a narrower
role: after host ACME renewal it replaces only Mailcow's `cert.pem`/`key.pem` and restarts
Postfix, Dovecot, and Mailcow nginx. It does not run application upgrades.

The Alucard profile installs `jq`, which the current official `update.sh` requires before it
will begin a migration.

Perform the following on Alucard in a scheduled maintenance window; do not run
`update.sh --force`, `--ours`, or `--nightly` for this production installation.

1. Record the current Mailcow commit, status, active image IDs, bindings, and `mailcow.conf`
   settings **without copying secret values**. Save an external, access-controlled copy of
   `mailcow.conf` and a patch for every modified tracked file.
2. Back up and verify Mailcow's database and state before stopping anything. Use the upstream
   helper in place:

   ```console
   cd /opt/mailcow-dockerized
   MAILCOW_BACKUP_LOCATION=/approved/backup/path \
     ./helper-scripts/backup_and_restore.sh backup all
   ```

   Verify the completed backup is readable from the intended recovery location; retain its
   output and the pre-update commit outside this Git repository.
3. Read the release notes for every skipped stable release, then run `./update.sh --check`.
   Reconcile reported local modifications: upstream code wins for obsolete copies; required
   local behavior belongs in `mailcow.conf` or documented upstream override points.
4. Keep Mailcow's web listener private behind host nginx by setting supported `mailcow.conf`
   bindings (`HTTP_BIND=127.0.0.1`, `HTTPS_BIND=127.0.0.1`) and its configured ports. Set
   `SKIP_LETS_ENCRYPT=y`: host nginx owns HTTP-01 and the `mailcow-tls` unit supplies the
   renewed certificate to IMAP/SMTP services. Apply `mailcow.conf` changes with
   `docker compose up -d`.
5. Run the supported stable updater interactively: `./update.sh --stable`. Review every prompt
   and merge conflict; do not accept a configuration change merely to finish the update.
6. Check `docker compose ps`, Mailcow logs, host `systemctl --failed`, nginx frontend, SMTP
   submission, inbound and outbound delivery, IMAP, SOGo, TLS chain/hostname, DKIM/SPF/DMARC,
   queues, and a backup restore drill before closing the window.

Rollback uses the pre-update commit and the upstream sequence: `docker compose down`, check out
the recorded commit, `docker compose pull`, then `docker compose up -d`. Restore the verified
backup only when application/database recovery requires it; rolling back code alone does not
reverse every data migration.

References:

- [Tailscale Serve](https://tailscale.com/docs/features/tailscale-serve)
- [Tailscale grants](https://tailscale.com/kb/1337/policy-syntax)
- [CrowdSec nginx and AppSec](https://docs.crowdsec.net/u/bouncers/nginx/)
- [CrowdSec firewall bouncer](https://docs.crowdsec.net/u/bouncers/firewall/)
- [Mailcow reverse proxy](https://docs.mailcow.email/post_installation/reverse-proxy/r_p/)
- [Mailcow updates](https://docs.mailcow.email/maintenance/update/)
