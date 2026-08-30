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
  Two location-level WAF exceptions exist, both on the Jellyfin host. The authenticated
  playback endpoint family `POST /Sessions/Playing*` is exempt because CRS 4.25.1 falsely
  blocks Swiftfin's payload before Jellyfin can authorize it, and Jellyfin itself retains
  authorization for those endpoints. `GET /web/config.json` is exempt because CRS ships
  `config.json` in both `restricted-files.data` and `lfi-os-files.data`, so 930120/930130
  score the web client's own bootstrap file at CRITICAL and 949110 answers 403 — the public
  UI could not start at all while `/web/index.html` and the API answered 200.
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
  `INPUT` and Docker `DOCKER-USER` chains. Its agent and authenticated firewall bouncer are
  active. Community event sharing is disabled unless
  an operator deliberately enrolls the machine later.

## Private Tailscale access

Tailscale is installed declaratively on Dracula and Alucard. It does not advertise routes,
act as an exit node, mark `tailscale0` trusted in the NixOS firewall, open a public firewall
port, or enable Taildrop. The explicit Tailscale Serve mappings below are the supported and
documented entry points.

Tailscale's default Linux netfilter mode independently accepts traffic arriving on
`tailscale0`; it runs before the NixOS firewall. Consequently, any application that binds a
wildcard address can also be reachable directly from an authorized tailnet peer even when it
is not a Serve mapping. Such a listener is private exposure rather than internet exposure, but
it can bypass nginx and the WAF. Loopback binding remains
the backend boundary, and restrictive Tailscale grants are mandatory before inviting the
cofounder or any customer identity.
The HTTP applications remain bound to `127.0.0.1`. Traffic between devices is encrypted by
Tailscale's WireGuard tunnel.

Alucard uses `systemd-resolved` plus explicit Cloudflare and Quad9 fallback resolvers. This
prevents Tailscale's MagicDNS takeover from losing all public upstream DNS after activation.
Raw-IP connectivity with hostname `SERVFAIL` is a resolver fault, not evidence that CrowdSec
or the NixOS firewall blocked outbound traffic.

If raw IP connectivity works but names return `SERVFAIL`, temporarily run
`sudo tailscale set --accept-dns=false`, switch the current configuration, then re-enable it
and verify that both `github.com` and another tailnet host resolve.

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

The remediation path is checked without changing firewall state by selecting an active IPv4
decision from `crowdsec-admin decisions list`, then running:

```console
sudo iptables -C INPUT -j CROWDSEC_CHAIN
sudo iptables -C DOCKER-USER -j CROWDSEC_CHAIN
sudo ipset test crowdsec-blacklists-0 ADDRESS
```

### Reaching the admin interfaces while a client IP is banned

A firewall-bouncer decision drops the source address for every protocol, so the browser used to
lift the ban loses the admin UIs at the same moment ICMP stops answering. SSH is unaffected when
it runs over the tailnet, because `alucard/private-network-whitelist` exempts `100.64.0.0/10`, so
the recovery path is a SOCKS proxy through that session rather than a DNS override:

```console
ssh -D 1080 -N alucard
```

Point the browser at SOCKS5 `127.0.0.1:1080` with remote DNS enabled. Requests then originate
from Alucard itself, the `Host` header and public certificate stay intact, and Keycloak's
`hostname-strict` check still passes. Pinning the public hostnames to a tailnet address in
`networking.hosts` also works but hardcodes an address that is only stable while the node keeps
its Tailscale identity, and it silently hides real public-edge outages, so prefer the proxy.

Whitelisting the residential address is the wrong reflex: it is a Vodafone dynamic address that
moves, and every trigger so far has been the operator's own browsing rather than the network it
came from. Two of them were genuinely application-specific and are whitelisted by request
pattern in `hosts/alucard/security.nix`: Next.js `?_rsc=` prefetch bursts from the Onyx admin UI
(`crowdsecurity/http-crawl-non_statics`) and Jellyfin client session 403s from Swiftfin
(`LePresidente/http-generic-403-bf`). The third had no application-specific pattern to whitelist
at all.

### Crawl buckets are per virtual host

`crowdsecurity/http-crawl-non_statics` groups by
`evt.Meta.source_ip + '/' + evt.Parsed.target_fqdn` and trips on 40 distinct non-static paths.
`crowdsecurity/nginx-logs` fills `target_fqdn` only from an optional leading vhost field in the
access log, and stock `combined` has none, so until 2026-08-17 the entire reverse proxy shared
one 40-path budget per client address. Demonstrating four services in one sitting was therefore
enough to earn a 4h ban with no single service behaving unusually: on 2026-08-16 at 20:22:48
CEST a Jellyfin-then-Paperless walkthrough produced 74 distinct paths in 57.8s and banned
92.208.223.20.

`security.nix` now emits `$host` as the first access-log field through the `crowdsec_vhost`
format, so every service gets its own bucket. Reproduced against CrowdSec's own engine: 60
distinct paths split 20/20/20 across three hostnames raise one `http-crawl-non_statics` ban
without the field and none with it.

Two consequences are worth remembering. Paperless cannot fill this bucket on its own — every URL
its frontend builds ends in `/` and `evt.Parsed.file_name` is only the final path segment, so its
entire API fan-out counts as a single distinct value. And an alert now names the service it came
from, which is worth reading before adding another whitelist.

### Retracting a local whitelist

`services.crowdsec.localConfig` publishes each entry as its own `systemd-tmpfiles` `L+` link
named after its store hash, and a rule that disappears never deletes the file it created. Before
2026-08-17 a whitelist could therefore be added declaratively but never withdrawn: the engine
kept loading it from `/etc/crowdsec` after it was gone from Nix. `security.nix` now removes the
generated names with `r` globs, which `systemd-tmpfiles --create --remove` executes before it
recreates the declared links, and orders the agent after `systemd-tmpfiles-resetup.service` so
a switch cannot start it against the previous ruleset.

### Nightly hub upgrades

`autoUpdateService` was doing nothing useful and failing while it did so. Upstream's unit runs
only `cscli hub update`, which refreshes the catalogue and upgrades no item, and then reloads
the agent from an `ExecStartPost` that runs as the unit's own `DynamicUser` — denied, and
pointless anyway because `crowdsec.service` clears `ExecReload`. It had failed every night since
at least 2026-08-14.

`security.nix` replaces the command with `cscli hub update`, `cscli hub upgrade`, and a
conditional `systemctl try-restart crowdsec.service` from a `+`-prefixed line, which is how a
`User=`-confined unit reaches root. The restart is conditional on a content fingerprint of the
installed hub items and data files because the file datasource resumes at the end of the access
log instead of replaying it, so every restart is a short blind window and also discards every
in-flight leaky bucket. Exercised in both directions on 2026-08-17: a run that re-downloaded all
19 data files byte-identically left the engine alone, and a forced content change restarted it.

Detection content therefore now moves on its own, which is also how a scenario can start
false-positiving without anything in this repository changing. `cscli hub upgrade` output is
deliberately not silenced, so that is the record to check first:

```console
journalctl -u crowdsec-update-hub --since '-2 days' -o cat
```

Local whitelists are unaffected by an upgrade — they are local items, not hub ones.

### Identifying a ban without sudo

The agent's journal is readable by the operator account and records every decision, which is
enough to name the scenario and the address before unlocking `cscli`:

```console
journalctl -u crowdsec --since today -o cat | grep 'ban on Ip'
```

The nginx access log stays root-only, so the triggering requests themselves still need
`crowdsec-admin alerts inspect ALERT_ID --details`.

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
| P0 | Bind Jellyfin 8096 and Mailcow web ports 880/4433 to loopback; retain public nginx access and the host ACME certificate | Enforced and checked locally |
| P0 | Back up and update Mailcow from 2025-07 to current stable | Complete; operator confirmed web login and mailbox retrieval |
| P1 | Install CrowdSec engine and firewall remediation | Complete; real nginx decision verified in the live ipset behind both host and Docker chains |
| P1 | Add tested nginx AppSec/WAF integration | Active; a normal Jellyfin request returns 302 and a traversal/shell probe returns 403 |
| P1 | Add per-service rate and connection limits | Active at the nginx edge; configuration and normal application path verified |
| P1 | Apply consistent security headers and bounded request sizes | Active; upload-heavy Registry/Filebrowser/WebDAV bypass WAF and retain explicit size policy |
| P1 | Retire dead DNS/vhosts and remove unused firewall ports | Dead root/Git/docs/Coder backends return 404; unused TCP 53/873/11335/11445 removed |
| P1 | Make `autoUpdateService` actually reach the engine | Complete; `crowdsec-update-hub.service` had failed every night since at least 2026-08-14 and now upgrades hub items and restarts the engine only when their content changed. Both branches exercised on 2026-08-17: an upgrade that re-downloaded all 19 data files byte-identically left the running engine alone, and a forced content change restarted it through the `+`-prefixed line. |
| P2 | Define Keycloak/2FA policy for every public application | Open. Keycloak is the application identity provider; scope this to Keycloak alone. |
| P2 | Harden native services and containers | Keycloak loopback bind and systemd sandbox prepared; remaining application policy review pending |
| P2 | Add vulnerability scanning and security alerts | Complete; both Docker engines enumerated by immutable image ID (51 images, 0 failures) and a partial scan now fails the unit. Findings triaged below. |
| P3 | Add GeoIP restrictions to selected web services | Pending explicit country policy; never global mail blocking |

### Identity platform: not adopted

OpenBao and Teleport were deployed and verified on 2026-08-29, then removed the
same day. The decision was explicit: for a two-person MVP they were two more
systems to operate for benefits the setup does not yet consume.

- **OpenBao** would have added dynamic secrets, leases, revocation and read
  auditing. None of those are in use; the existing secrets are static
  deploy-time configuration, which SOPS already handles well. Holding static
  strings in OpenBao would have meant SOPS plus a manual unseal after every
  reboot, since a single node has no KMS or second instance to auto-unseal
  against.
- **Teleport** would have added per-person identity, short-lived certificates
  and session recording. Its concrete target here was the shared `nix` account;
  that problem is now tracked directly in `docs/OPERATOR-ACTIONS.org` and has a
  fix that needs no new software.

Reopen only if a real requirement appears: dynamic per-client database
credentials, an audit trail a customer asks for, or shell access for someone
outside the two founders. Do not reintroduce either as general hardening.

### Off-site recovery verification

`services.offsiteBackup` (`modules/offsite-backup.nix`) gives every declared
state store its own restic repository under `/mnt/hetzner/restic/<job>`, a
`offsite-backup-<job>.service` that stages a consistent copy before snapshotting,
and a `offsite-restore-verify-<job>.service` that restores the latest snapshot
into a scratch directory and fails unless the declared paths come back non-empty.
The module refuses a job that declares no `verifyPaths`: an unverified backup is
not a backup.

Current jobs:

| job | staged by | why staging |
| --- | --- | --- |
| `keycloak` | `pg_dump --format=custom` | the cluster is live during the window, and a realm export omits users and credentials |
| `n8n` | `sqlite3 .backup` | copying `database.sqlite` under WAL captures a torn page; rows stay encrypted because `n8n/encryption_key` lives only in SOPS |
| `paperless` | exporter output snapshotted in place, Django signing key staged | a restore without the signing key invalidates every session and signed value |

Backups run daily, restore drills weekly. Check both:

```bash
offsite-backup-status
```

Run one on demand after changing the backup configuration:

```bash
sudo env TERM=dumb SYSTEMD_PAGER=cat \
  systemctl start offsite-restore-verify-keycloak.service
sudo env TERM=dumb SYSTEMD_PAGER=cat \
  systemctl show offsite-restore-verify-keycloak.service \
  -p Result -p ExecMainStatus --no-pager
```

Run an on-demand scan with `containers-scan`. The digest-pinned Trivy container inspects an
archive exported from every distinct image resident in the root Docker daemon and in the
`vincenzo` rootless daemon. Enumeration uses each container's *immutable image ID*, not the
reference from `docker ps`: a digest-pinned pull never creates the plain tag locally, so three
startup-stack images (n8n, its task runners, and the Hermes `ubuntu` base) were previously
unresolvable and reported as failures. This avoids registry drift and does not expose a Docker
socket to the scanner. Full JSON reports stay root-only under
`/var/lib/container-vulnerability-scan/reports`; aggregate critical/high/failure counts and
scan age appear in the **AI and machine overview** Grafana dashboard. A finding is inventory,
not proof of exploitability: review the package, reachable surface, and upstream fix before
changing production images.

**A partial scan fails the unit.** Any image that cannot be exported or inspected, and an
unreachable rootless daemon, increment a failure counter; metrics are published first so the
dashboard still shows what was learned, then the unit exits non-zero. A silently skipped
engine reads on a dashboard exactly like a clean result, which is how the rootless daemon went
unscanned: `ProtectHome=true` masks `/run/user` so thoroughly that neither it nor a deeper
path can be bound back in. The unit now uses `ProtectHome=tmpfs` plus a `BindPaths=` entry for
the rootless runtime directory, which requires that user's uid to be *declared* rather than
allocated — there is an assertion for it.

The most recent full scan inspected 51 resident image references across both engines
(41 rootful, 10 rootless) with zero failures. Those totals include duplicate packages across
related images; `--ignore-unfixed` means every reported finding has a published fixed version.
Root-only JSON reports remain the authoritative package/CVE inventory. cAdvisor runs the
upstream-supported, digest-pinned `ghcr.io/google/cadvisor:v0.60.5`; the obsolete GCR `latest`
image is prohibited.

### Temporary vulnerability risk register

These entries are temporary, evidence-based risk acceptances—not evidence that the findings are
unexploitable. They are reviewed on the earlier of the stated date or an upstream image release.
The remaining high findings are **not** blanket-accepted: their package/CVE detail remains in the
root-only reports and each image is exported as a Prometheus time series.

Last refreshed **2026-08-29** from a full scan of all 51 resident images across both Docker
engines (97 critical, 1977 high, 0 scan failures). "Verified identical" below means the newest
upstream digest was pulled and scanned that day and produced the same counts, so bumping the
pin would be churn rather than remediation.

| Component | Fixed findings currently resident | Exposure and compensating controls | Revisit |
| --- | --- | --- | --- |
| cAdvisor v0.60.5 | High only (10). No fixable criticals as of the 2026-08-29 scan. | Privileged host inspector bound to `127.0.0.1:18081`; Prometheus reaches it locally. Replacing it with the unsupported GCR image is prohibited. | Next cAdvisor release or 2026-09-30 |
| Mailcow (9 images) | Critical, per image: `dovecot` 17, `watchdog` 11, `sogo` 9, `clamd` 4, `postfix-tlspol` 4, `dockerapi` 3, `olefy` 3, `phpfpm` 3, `netfilter` 2. Packages are MariaDB client, OpenSSL, BIND and Go `stdlib` in the base layers. | **The largest remaining exposure on the host, and it is publicly reachable** (IMAP, POP3, submission, webmail). Nix firewall policy, nginx TLS/WAF and service authentication constrain it; independent image replacement is unsupported. | **Overdue.** Run `mailcow update.sh` — tracked in `OPERATOR-ACTIONS.org` |
| Seerr | Critical: `CVE-2026-33937` (`handlebars`), `CVE-2026-59873` (`tar`, ×3) | Public request UI through nginx with TLS, ModSecurity and application authentication. Verified 2026-08-29: the newest upstream digest carries an identical finding set, so bumping the pin remediates nothing. | Next Seerr release that actually changes the count |
| Komga | Critical: 4 × Go `stdlib` (`CVE-2023-24538`, `CVE-2023-24540`, `CVE-2024-24790`, `CVE-2025-68121`) | Public comics UI through nginx; application authentication and TLS required. Komga is JVM — these come from a bundled Go helper, not the request path. Verified 2026-08-29: newest digest is identical. | Next Komga release that actually changes the count |
| Kapowarr | Critical: 5 | Private: loopback-published, reachable only over the tailnet. Verified 2026-08-29: newest digest is identical. | Next release that changes the count |
| Onyx (unmanaged) | Critical: `redis:7.4-alpine` 6, `minio` 4, `nginx:1.25.5-alpine` 3, `postgres:15.2-alpine` 1. High: `opensearch:3.6.0` 238. | Deployed from `~/.config/onyx/deployment`, outside this repository. Public chat UI through nginx; loopback-bound since 2026-08-29. These versions are pinned by Onyx upstream, so remediation means an Onyx upgrade with database migrations. | Operator decision — `OPERATOR-ACTIONS.org` |
| Actual Budget (unmanaged) | Critical: 1 (`tar`, `CVE-2026-59873`) | Was 9 critical / 75 high including an application-level CVE in `@actual-app/sync-server`; updated 2026-08-29 after a data backup and verified on the running image. Public budget UI, loopback-bound. | Next upstream image |

### Runtime privilege review

The rootful containers were reviewed individually. cAdvisor is privileged because the
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

The expected result is HTTP 302 for the first request and HTTP 403 for the probe. The
audit-log entry and Keycloak's local listener still require a host-side check because neither
is exposed to the tailnet:

```bash
ss -ltn '( sport = :38080 )'
systemd-analyze security keycloak.service
```

Historically, repeated nginx reloads and clean stops segfaulted in libmodsecurity's PCRE2
10.47 JIT allocator: nixpkgs built `pcre2` with `--enable-jit-sealloc`, which is not
fork-safe, so `msc_rules_cleanup` reached `sljit_free_exec` and every nginx worker died with
SIGSEGV on exit. Alucard carried a reviewed source mutation refusing the two eager JIT
compile calls.

**Resolved upstream on 2026-08-29.** nixpkgs `9fbb54b` no longer passes
`--enable-jit-sealloc` (`pcre2.configureFlags` is now `--enable-pcre2-16 --enable-pcre2-32
--enable-jit=auto`), which is exactly the removal condition the exception named. The mutation
and its entry in `scripts/check-no-package-patches.sh` are gone, and the repository now
carries **zero** package mutations. Verified on stock `libmodsecurity-3.0.16` with a restart
and two reloads: no coredumps, benign traffic 200, a CRS SQLi probe still 403.

`scripts/check-no-package-patches.sh` runs in CI and as a `nix flake check` check with an
empty exception list, so any new mutation fails the build. If a future exception is
unavoidable, it must carry an `# UPSTREAM DEFECT` comment naming the live failure and the
condition for removing it. Verify WAF behaviour after nginx changes with consecutive reloads,
a clean restart, and an HTTPS health check; a new coredump or failed unit is a release blocker.

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
