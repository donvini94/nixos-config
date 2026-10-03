# Public edge of a host: CrowdSec bans abusive sources at the firewall from sshd and nginx
# logs; ModSecurity with CRS filters requests in nginx. Hosts add their own acquisitions,
# collections and whitelists through services.crowdsec.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.aiStack.edge;
  coreruleset = pkgs.callPackage ../packages/coreruleset.nix { };
  modsecurityBase = pkgs.runCommand "modsecurity.conf" { } ''
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
  # Hub content only: .index.json, the database, credentials and mmdb archives are
  # rewritten by CrowdSec itself and would report a change on every run.
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
      # Not quiet: this log is the only record of which detection items moved.
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
  options.services.aiStack.edge.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.services.aiStack.enable;
    defaultText = lib.literalExpression "config.services.aiStack.enable";
    description = "CrowdSec with its firewall bouncer and ModSecurity/CRS in nginx.";
  };

  config = lib.mkIf cfg.enable {
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
      ];
      settings = {
        lapi.credentialsFile = "/var/lib/crowdsec/state/local_api_credentials.yaml";
        general.api.server = {
          enable = true;
          listen_uri = "127.0.0.1:18082";
          # No security events off-host without an explicit CAPI enrollment decision.
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
        ];
        parsers.s02Enrich = [
          {
            name = "ai-stack/private-network-whitelist";
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

    # Upstream enables DynamicUser without declaring the state directory, which makes
    # /var/lib/private/crowdsec inaccessible during setup and hub updates.
    systemd.services.crowdsec.serviceConfig = {
      StateDirectory = "crowdsec";
      StateDirectoryMode = "0750";
    };

    # localConfig is published through systemd-tmpfiles rather than the unit, so
    # switch-to-configuration never restarts the engine: a new whitelist lands on disk
    # but stays unloaded. Tie the unit to the ruleset it enforces.
    systemd.services.crowdsec.restartTriggers = [
      (builtins.toJSON config.services.crowdsec.localConfig)
    ];
    # Each entry is published as its own `L+` link named after its store hash, and a `L+`
    # rule that disappears never deletes its file. `systemd-tmpfiles --create --remove`
    # runs every `r` before any `L+`, so ordering after it prunes the stale ones.
    systemd.services.crowdsec.after = [ "systemd-tmpfiles-resetup.service" ];

    # autoUpdateService is broken upstream: ExecStart is only `cscli hub update`, which
    # refreshes the catalogue and upgrades nothing, and ExecStartPost reloads as the
    # unit's DynamicUser, which is denied — crowdsec.service clears ExecReload anyway.
    # Restart only when the upgrade moved something: the file datasource resumes at the
    # end of the access log instead of replaying it, and a restart discards every
    # in-flight bucket. `try-restart` because ExecReload is empty, `+` because a unit's
    # User= does not apply to those lines.
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
    # Preserve file modes while enforcing ownership; remove links to immutable hub entries.
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

    # Upstream requires the registration unit but does not order the bouncer after it,
    # so the first activation races the key file.
    systemd.services.crowdsec-firewall-bouncer.after = [
      "crowdsec-firewall-bouncer-register.service"
      "docker.service"
    ];
    systemd.services.crowdsec-firewall-bouncer.wants = [ "docker.service" ];

    # Registration stops when CrowdSec still knows a bouncer whose local key was lost.
    # Re-register that one bouncer so rebuilding the machine is self-healing.
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

    # CRS does request-level virtual patching; the bouncer handles layers 3/4.
    services.nginx = {
      enable = true;
      additionalModules = lib.mkAfter [ pkgs.nginxModules.modsecurity ];
      appendHttpConfig = ''
        limit_req_zone $binary_remote_addr zone=public_per_ip:10m rate=30r/s;
        limit_conn_zone $binary_remote_addr zone=public_connections:10m;
        modsecurity on;
        modsecurity_rules_file ${modsecurityRules};

        # CrowdSec HTTP scenarios bucket on `source_ip + '/' + target_fqdn`, and
        # crowdsecurity/nginx-logs fills target_fqdn only from a leading vhost field that
        # stock `combined` lacks: without it every service collapses into one bucket per
        # client IP and ordinary browsing self-bans. $host needs no sanitising — nginx
        # answers an invalid Host with 400 and falls back to server_name, and the grok
        # search is unanchored.
        log_format crowdsec_vhost
          '$host $remote_addr - $remote_user [$time_local] '
          '"$request" $status $body_bytes_sent '
          '"$http_referer" "$http_user_agent"';
        access_log /var/log/nginx/access.log crowdsec_vhost;
      '';
    };

    # The firewall-bouncer module invokes upstream cscli, which expects this path;
    # CrowdSec itself reads the same generated config from the store.
    environment.etc."crowdsec/config.yaml".source =
      (pkgs.formats.yaml { }).generate "crowdsec.yaml"
        config.services.crowdsec.settings.general;
  };
}
