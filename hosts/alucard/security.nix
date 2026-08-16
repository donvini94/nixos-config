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
in
{
  # UPSTREAM DEFECT, verified live on 2026-08-16: nixpkgs builds pcre2 with
  # `--enable-jit-sealloc`, whose mmap-backed JIT allocator is documented as
  # NOT fork-safe. nginx compiles the CRS ruleset in the master and forks
  # workers, so every worker exit runs msc_rules_cleanup -> pcre2_code_free ->
  # sljit_free_exec against JIT code the parent also owns, and the worker dies
  # with SIGSEGV (backtrace captured in journal, core dumped). That kills
  # in-flight connections on every reload, including ACME renewals.
  #
  # libmodsecurity already falls back to PCRE2_NO_JIT when JIT compilation is
  # unavailable, so refusing the two eager jit_compile calls is behaviour the
  # library supports. No nixpkgs revision avoids this: 3.0.16 + pcre2 10.47 is
  # what both nixos-unstable and master ship. Remove once nixpkgs drops
  # --enable-jit-sealloc or libmodsecurity stops eagerly JIT-compiling.
  nixpkgs.overlays = [
    (_final: prev: {
      libmodsecurity = prev.libmodsecurity.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace src/utils/regex.cc src/operators/verify_cc.cc \
            --replace-fail \
              "m_pcje = pcre2_jit_compile(m_pc, PCRE2_JIT_COMPLETE);" \
              "m_pcje = PCRE2_ERROR_JIT_BADOPTION;"
        '';
      });
    })
  ];

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
  systemd.services.crowdsec-update-hub.serviceConfig = {
    StateDirectory = "crowdsec";
    StateDirectoryMode = "0750";
  };
  # Normalize nested state left behind by the module's earlier DynamicUser
  # migration. Preserve existing file modes while repairing owner/group.
  systemd.tmpfiles.rules = [
    "Z /var/lib/private/crowdsec - crowdsec crowdsec - -"
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
