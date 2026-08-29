{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Nixpkgs still carries CRS 3.3.4, which predates the July 2026 security
  # fixes. Pin the current v4 LTS rules independently of the nginx module.
  coreruleset = pkgs.fetchFromGitHub {
    owner = "coreruleset";
    repo = "coreruleset";
    rev = "v4.25.1";
    hash = "sha256-dSzy1rJgPxc7qAivevR+a8BpGRi0CjrG0q+U3kXr48Q=";
  };
  modsecurityBase = pkgs.runCommand "modsecurity-alucard.conf" { } ''
    cp ${pkgs.libmodsecurity}/share/modsecurity/modsecurity.conf-recommended "$out"
    substituteInPlace "$out" \
      --replace-fail "SecRuleEngine DetectionOnly" "SecRuleEngine On" \
      --replace-fail "SecRequestBodyLimit 13107200" "SecRequestBodyLimit 67108864" \
      --replace-fail "SecResponseBodyAccess On" "SecResponseBodyAccess Off" \
      --replace-fail "SecAuditLog /var/log/modsec_audit.log" "SecAuditLog /var/log/nginx/modsec_audit.log" \
      --replace-fail "SecUnicodeMapFile unicode.mapping 20127" \
        "SecUnicodeMapFile ${pkgs.libmodsecurity}/share/modsecurity/unicode.mapping 20127"
  '';
  modsecurityRules = pkgs.writeText "modsecurity-rules.conf" ''
    Include ${modsecurityBase}
    Include ${coreruleset}/crs-setup.conf.example
    Include ${coreruleset}/plugins/*-config.conf
    Include ${coreruleset}/plugins/*-before.conf
    Include ${coreruleset}/rules/*.conf
    Include ${coreruleset}/plugins/*-after.conf
  '';
  crowdsecAdmin = pkgs.writeShellApplication {
    name = "crowdsec-admin";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      if (( EUID != 0 )); then
        exec ${config.security.wrapperDir}/sudo "$0" "$@"
      fi

      exec systemd-run --quiet --wait --pipe --collect \
        --property=User=${lib.escapeShellArg config.services.crowdsec.user} \
        --property=Group=${lib.escapeShellArg config.services.crowdsec.group} \
        --property=DynamicUser=yes \
        --property=StateDirectory=crowdsec \
        --property=NoNewPrivileges=yes \
        --property=PrivateTmp=yes \
        --property=PrivateUsers=yes \
        --property=ProtectHome=yes \
        --property=ProtectSystem=strict \
        --property=UMask=0077 \
        ${lib.getExe' config.services.crowdsec.package "cscli"} \
        -c=/etc/crowdsec/config.yaml "$@"
    '';
  };
  crowdsecPaths = config.services.crowdsec.settings.general.config_paths;
  hubChangedMarker = "/run/crowdsec-update-hub/hub-changed";
  # Content of every installed hub item and detection data file. `.index.json`
  # is excluded because `hub update` rewrites the catalogue daily whether or
  # not an item changed, and the database, its WAL sidecars, the LAPI
  # credentials, and the GeoLite archives are excluded because CrowdSec writes
  # those itself: including any of them would report a change on every run and
  # turn the conditional restart below into an unconditional one.
  hubFingerprint = pkgs.writeShellApplication {
    name = "crowdsec-hub-fingerprint";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
    ];
    text = ''
      {
        find ${lib.escapeShellArg crowdsecPaths.hub_dir} \
          -type f ! -name .index.json -print0
        find ${lib.escapeShellArg crowdsecPaths.data_dir} -maxdepth 1 \
          -type f ! -name 'crowdsec.db*' ! -name '*.mmdb' \
          ! -name '*_credentials.yaml' -print0
      } | sort -z | xargs -0 -r sha256sum | sha256sum | cut -d ' ' -f 1
    '';
  };
  hubUpgrade = pkgs.writeShellApplication {
    name = "crowdsec-hub-upgrade";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      cscli() {
        ${lib.getExe' config.services.crowdsec.package "cscli"} \
          -c=/etc/crowdsec/config.yaml "$@"
      }

      rm -f ${lib.escapeShellArg hubChangedMarker}
      before="$(${lib.getExe hubFingerprint})"
      cscli --error hub update
      # Deliberately not quiet: this is the only record of which detection
      # items moved, and a new false positive is triaged against it.
      cscli hub upgrade
      after="$(${lib.getExe hubFingerprint})"

      if [ "$before" = "$after" ]; then
        echo "hub content unchanged ($before); leaving the running engine alone"
      else
        echo "hub content changed ($before -> $after); restarting the engine"
        : > ${lib.escapeShellArg hubChangedMarker}
      fi
    '';
  };
  hubReload = pkgs.writeShellApplication {
    name = "crowdsec-hub-reload";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      if [ -e ${lib.escapeShellArg hubChangedMarker} ]; then
        systemctl try-restart crowdsec.service
      fi
    '';
  };
in
{
  environment.systemPackages = [
    crowdsecAdmin
    pkgs.ipset
  ];

  services.crowdsec = {
    enable = true;
    autoUpdateService = true;
    openFirewall = false;
    hub.collections = [
      "crowdsecurity/linux"
      "crowdsecurity/nginx"
      "LePresidente/jellyfin"
    ];
    settings = {
      lapi.credentialsFile = "/var/lib/crowdsec/state/local_api_credentials.yaml";
      general.api.server = {
        enable = true;
        # Port 8080 belongs permanently to the AI ingress.
        listen_uri = "127.0.0.1:18082";
        # Do not send security events off-host unless CAPI enrollment is an
        # explicit operator decision.
        online_client = {
          sharing = false;
          pull = {
            community = false;
            blocklists = false;
          };
        };
      };
    };
    localConfig = {
      acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
          labels.type = "syslog";
        }
        {
          source = "file";
          filenames = [ "/var/log/nginx/access.log" ];
          labels.type = "nginx";
        }
        {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=jellyfin.service" ];
          labels.type = "jellyfin";
        }
      ];
      parsers.s02Enrich = [
        {
          name = "alucard/private-network-whitelist";
          description = "Never ban loopback, LAN, container, or tailnet source ranges";
          whitelist = {
            reason = "private administration network";
            cidr = [
              "127.0.0.0/8"
              "10.0.0.0/8"
              "100.64.0.0/10"
              "172.16.0.0/12"
              "192.168.0.0/16"
              "::1/128"
              "fd7a:115c:a1e0::/48"
            ];
          };
        }
        # Verified false positive, alert 1625 on 2026-08-16: the Onyx admin UI
        # is a Next.js app whose router prefetches every route the pointer
        # touches, so opening the admin panel emitted 55 distinct `?_rsc=`
        # GETs in 9 seconds and tripped crowdsecurity/http-crawl-non_statics
        # (capacity 40, distinct on file_name). Statuses are constrained so a
        # scanner cannot append `?_rsc=` to hide 404/403 probing.
        #
        # The query string is matched through both field names on purpose. The
        # NixOS module links local parsers as
        # `s02-enrich/<store-hash>-parsers-s02-enrich.yaml`, and CrowdSec
        # orders a stage by file name, so whether this node runs before or
        # after `crowdsecurity/http-logs` changes with every store hash. Before
        # that node `evt.Parsed.request` still carries `?args`; after it the
        # query lives in `evt.Parsed.http_args`. `evt.Meta.http_status` comes
        # from s01 and is stable either way.
        {
          name = "alucard/nextjs-rsc-prefetch-whitelist";
          description = "Next.js router prefetch is not an aggressive crawl";
          whitelist = {
            reason = "Next.js RSC prefetch (?_rsc=) from the Onyx admin UI";
            expression = [
              "(evt.Parsed.request contains '_rsc=' || evt.Parsed.http_args contains '_rsc=') && evt.Meta.http_status in ['200', '204', '304']"
            ];
          };
        }
        # Verified false positive, alert 1339 on 2026-08-15: Swiftfin on iOS
        # POSTs session progress to /Sessions/Playing and gets 403 once the
        # Jellyfin session is stale, ten times in 46 seconds, which reads as
        # credential stuffing to LePresidente/http-generic-403-bf. Scoped to
        # the session-reporting endpoints so 403s anywhere else still count.
        {
          name = "alucard/jellyfin-session-403-whitelist";
          description = "Stale Jellyfin client sessions are not a 403 brute force";
          whitelist = {
            reason = "Jellyfin client session reporting returns 403 when the session expired";
            expression = [
              "evt.Meta.http_verb == 'POST' && evt.Meta.http_status == '403' && evt.Parsed.request startsWith '/Sessions/'"
            ];
          };
        }
      ];
    };
  };

  # The module registers and stores its bouncer key outside the Nix store.
  services.crowdsec-firewall-bouncer = {
    enable = true;
    settings = {
      mode = "iptables";
      iptables_chains = [
        "INPUT"
        "DOCKER-USER"
      ];
    };
  };

  # The upstream NixOS module enables DynamicUser but does not declare its
  # persistent state directory.  On a hardened systemd setup that makes the
  # /var/lib/crowdsec -> /var/lib/private/crowdsec link inaccessible during
  # setup and hub updates.
  systemd.services.crowdsec.serviceConfig = {
    StateDirectory = "crowdsec";
    StateDirectoryMode = "0750";
  };

  # The module publishes localConfig parsers, whitelists, and scenarios into
  # /etc/crowdsec through systemd-tmpfiles links rather than the unit
  # definition, so switch-to-configuration sees no reason to restart the
  # engine: a whitelist added here lands on disk but stays unloaded until the
  # next reboot. Verified on 2026-08-16, when two new whitelists were absent
  # from `cs_node_hits_total` after two successive switches while the engine
  # still reported the uptime it had since boot. Tie the unit to the local
  # ruleset so changing it reloads the engine that enforces it.
  systemd.services.crowdsec.restartTriggers = [
    (builtins.toJSON config.services.crowdsec.localConfig)
  ];
  # The same tmpfiles indirection makes a whitelist unretractable: each entry
  # is published as its own `L+` link named after its store hash, and a `L+`
  # rule that disappears never deletes the file it created. Verified on
  # 2026-08-17 with a probe whitelist that outlived its own deletion and kept
  # accumulating `cs_node_hits_total`. `systemd-tmpfiles --create --remove`
  # performs every `r` before any `L+` in one invocation, so globbing the
  # generated names makes the published ruleset equal what this file declares
  # instead of the union of everything it has ever declared.
  systemd.services.crowdsec.after = [ "systemd-tmpfiles-resetup.service" ];

  # `autoUpdateService` is broken twice over upstream, and had failed every
  # night since at least 2026-08-14. Its `ExecStart` is only `cscli hub
  # update`, which refreshes the catalogue and upgrades nothing, so detection
  # content never advanced. Its `ExecStartPost` then ran `systemctl reload
  # crowdsec.service` as the unit's own DynamicUser, which is denied — and
  # `crowdsec.service` clears `ExecReload`, so that reload could not have
  # worked even as root.
  #
  # Refresh the catalogue, upgrade the installed items, and restart the engine
  # only when the upgrade actually moved something. Conditional matters: the
  # file datasource resumes at the end of the access log rather than replaying
  # it, so every restart is a short blind window, and it also discards every
  # in-flight leaky bucket. `try-restart` because `ExecReload` is empty, and a
  # `+` line because a unit's `User=` does not apply to those. The local
  # whitelists are unaffected by an upgrade: they are local items, not hub
  # ones.
  systemd.services.crowdsec-update-hub.serviceConfig = {
    StateDirectory = "crowdsec";
    StateDirectoryMode = "0750";
    RuntimeDirectory = "crowdsec-update-hub";
    ExecStart = lib.mkForce [
      (lib.getExe hubUpgrade)
      "+${lib.getExe hubReload}"
    ];
    ExecStartPost = lib.mkForce [ ];
  };
  # Normalize nested state left behind by the module's earlier DynamicUser
  # migration. Preserve existing file modes while repairing owner/group.
  systemd.tmpfiles.rules = [
    "Z /var/lib/private/crowdsec - crowdsec crowdsec - -"
    "r /etc/crowdsec/parsers/s00-raw/*-parsers-s00-raw.yaml"
    "r /etc/crowdsec/parsers/s01-parse/*-parsers-s01-parse.yaml"
    "r /etc/crowdsec/parsers/s02-enrich/*-parsers-s02-enrich.yaml"
    "r /etc/crowdsec/postoverflows/s01-whitelist/*-postoverflows-s01-whitelist.yaml"
    "r /etc/crowdsec/scenarios/*-scenario.yaml"
    "r /etc/crowdsec/contexts/*-context.yaml"
    "r /etc/crowdsec/notifications/*-notification.yaml"
  ];

  # The upstream module requires the registration unit but does not order the
  # bouncer after it. Without this edge the first activation races the key file.
  systemd.services.crowdsec-firewall-bouncer.after = [
    "crowdsec-firewall-bouncer-register.service"
    "docker.service"
  ];
  systemd.services.crowdsec-firewall-bouncer.wants = [ "docker.service" ];

  # NixOS' registration unit stops when CrowdSec still knows a bouncer whose
  # local key was lost. Re-register that one exact bouncer with upstream cscli
  # so rebuilding the machine is self-healing rather than a manual procedure.
  systemd.services.crowdsec-firewall-bouncer-register.script = lib.mkForce ''
    cscli=${lib.getExe' config.services.crowdsec.package "cscli"}
    key=/var/lib/crowdsec-firewall-bouncer-register/api-key.cred
    registered() {
      "$cscli" bouncers list --output json |
        ${lib.getExe pkgs.jq} -e -- 'any(.[]; .name == "crowdsec-firewall-bouncer")' >/dev/null
    }

    if registered && [ ! -s "$key" ]; then
      "$cscli" bouncers delete crowdsec-firewall-bouncer
    fi
    if ! registered; then
      rm -f "$key"
      if ! "$cscli" bouncers add --output raw -- crowdsec-firewall-bouncer >"$key"; then
        rm -f "$key"
        exit 1
      fi
    fi
  '';

  users.users.crowdsec.extraGroups = lib.mkAfter [ "nginx" ];

  # OWASP Core Rule Set provides request-level virtual patching while the
  # firewall bouncer handles host and Docker traffic at layers 3/4.
  services.nginx = {
    additionalModules = lib.mkAfter [ pkgs.nginxModules.modsecurity ];
    appendHttpConfig = ''
      limit_req_zone $binary_remote_addr zone=public_per_ip:10m rate=30r/s;
      limit_conn_zone $binary_remote_addr zone=public_connections:10m;
      modsecurity on;
      modsecurity_rules_file ${modsecurityRules};

      # Every CrowdSec HTTP scenario groups by `source_ip + '/' +
      # target_fqdn`, and `crowdsecurity/nginx-logs` can only fill
      # `target_fqdn` from an optional leading vhost field in the access log:
      # `(%{IPORHOST:target_fqdn}(:%{INT:port})? )?`. Stock `combined` has no
      # such field, so the whole reverse proxy collapses into one bucket per
      # client IP and a session that touches several of our own services sums
      # into a single 40-distinct-path `http-crawl-non_statics` overflow.
      # Verified on 2026-08-16: 74 distinct paths in 57.8s while demoing
      # Jellyfin and Paperless back to back, 4h ban on the operator's address.
      #
      # `$host` needs no sanitising. nginx answers a syntactically invalid
      # Host header with 400 and falls back to the matched `server_name`, so
      # the field can never contain a space or a quote, and the grok search is
      # unanchored: a value that is not IPORHOST-shaped (a bracketed IPv6
      # literal, an empty default) leaves `target_fqdn` empty and parses the
      # rest of the line exactly as it does today.
      log_format crowdsec_vhost
        '$host $remote_addr - $remote_user [$time_local] '
        '"$request" $status $body_bytes_sent '
        '"$http_referer" "$http_user_agent"';
      access_log /var/log/nginx/access.log crowdsec_vhost;
    '';
  };

  # The firewall-bouncer module invokes upstream cscli, which expects this
  # conventional path. CrowdSec itself uses the identical generated config
  # directly from the Nix store.
  environment.etc."crowdsec/config.yaml".source =
    (pkgs.formats.yaml { }).generate "crowdsec.yaml"
      config.services.crowdsec.settings.general;

  services.localObservability.extraScrapeTargets.crowdsec = 6060;
}
