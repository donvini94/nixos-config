{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.localWirken;
  stateDirectoryName = lib.removePrefix "/var/lib/" cfg.stateDirectory;
  dataDirectory = "${cfg.stateDirectory}/.wirken";
  auditAnchorDirectory = "/var/lib/wirken-audit-anchor";
  auditAnchor = "${auditAnchorDirectory}/audit-signing.pub";
  json = pkgs.formats.json { };

  providerConfig = json.generate "wirken-provider.json" {
    provider = "custom";
    inherit (cfg) model;
    base_url = cfg.ingressUrl;
  };

  sandboxConfig = json.generate "wirken-sandbox.json" {
    mode = "exec-only";
    network = false;
  };

  # The v1.13 release's age-file fallback deliberately reads its passphrase
  # from a TTY. Feed the systemd credential over a private pseudo-terminal;
  # the secret never appears in the store, argv, environment, or journal.
  vaultPty = pkgs.writeText "wirken-vault-pty.exp" ''
    log_user 0
    set timeout 30
    set mode [lindex $argv 0]
    set command [lrange $argv 1 end]
    set credential_dir $env(CREDENTIALS_DIRECTORY)
    set handle [open [file join $credential_dir vault-passphrase] r]
    set passphrase [string trimright [read $handle] "\r\n"]
    close $handle

    spawn -noecho {*}$command
    expect {
      -re {Vault passphrase.*:} {
        send -- "$passphrase\r"
        if {$mode eq "gateway"} {
          expect {
            -re {WebChat:} {
              log_user 1
              set timeout -1
              expect eof
            }
            timeout {
              puts stderr "Wirken did not finish gateway initialization"
              exit 1
            }
            eof {
              puts stderr "Wirken exited during gateway initialization"
            }
          }
        } else {
          set timeout -1
          expect eof
        }
        catch wait result
        exit [lindex $result 3]
      }
      timeout {
        puts stderr "timed out waiting for Wirken's vault prompt"
        exit 1
      }
      eof {
        catch wait result
        exit [lindex $result 3]
      }
    }
  '';

  initialize = pkgs.writeShellScript "initialize-wirken" ''
    set -euo pipefail
    data=${lib.escapeShellArg dataDirectory}
    token="$CREDENTIALS_DIRECTORY/ingress-token"
    marker="$data/.ingress-token.sha256"

    ${pkgs.coreutils}/bin/install -d -m 0700 "$data" "$data/workspace"
    ${pkgs.coreutils}/bin/install -m 0600 ${providerConfig} "$data/provider.json"
    ${pkgs.coreutils}/bin/install -m 0600 ${sandboxConfig} "$data/sandbox.json"

    ${pkgs.expect}/bin/expect ${vaultPty} quiet \
      ${cfg.package}/bin/wirken credentials list
    echo "Wirken encrypted vault check: ok"

    token_hash="$(${pkgs.coreutils}/bin/sha256sum "$token" | ${pkgs.coreutils}/bin/cut -d ' ' -f 1)"
    current_hash="$(${pkgs.coreutils}/bin/cat "$marker" 2>/dev/null || true)"
    if [ "$token_hash" != "$current_hash" ]; then
      ${pkgs.expect}/bin/expect ${vaultPty} quiet \
        ${cfg.package}/bin/wirken credentials add custom-api-key \
        --channel inference --value-file "$token"
      echo "Wirken ingress credential bootstrap: ok"
      ${pkgs.coreutils}/bin/printf '%s\n' "$token_hash" > "$marker"
      ${pkgs.coreutils}/bin/chmod 0600 "$marker"
    fi
  '';

  prepareSandboxImage = pkgs.writeShellScript "prepare-wirken-sandbox-image" ''
    set -euo pipefail
    source_image=${lib.escapeShellArg cfg.sandboxImage}
    upstream_tag=debian:bookworm-slim

    ${pkgs.docker}/bin/docker pull "$source_image"
    ${pkgs.docker}/bin/docker tag "$source_image" "$upstream_tag"

    source_id="$(${pkgs.docker}/bin/docker image inspect --format '{{.Id}}' "$source_image")"
    tagged_id="$(${pkgs.docker}/bin/docker image inspect --format '{{.Id}}' "$upstream_tag")"
    if [ "$source_id" != "$tagged_id" ]; then
      echo "Wirken sandbox tag did not resolve to the pulled image" >&2
      exit 1
    fi
  '';

  pinAuditAnchor = pkgs.writeShellScript "pin-wirken-audit-anchor" ''
    set -euo pipefail
    source=${lib.escapeShellArg "${dataDirectory}/audit/audit-signing.pub"}
    anchor=${lib.escapeShellArg auditAnchor}

    for _ in $(${pkgs.coreutils}/bin/seq 1 100); do
      [ -s "$source" ] && break
      ${pkgs.coreutils}/bin/sleep 0.1
    done
    if [ ! -s "$source" ]; then
      echo "Wirken did not create an audit signing public key" >&2
      exit 1
    fi

    if [ -e "$anchor" ]; then
      if ! ${pkgs.diffutils}/bin/cmp --silent "$source" "$anchor"; then
        echo "Wirken audit signing key changed; review and rotate the operator anchor explicitly" >&2
        exit 1
      fi
    else
      ${pkgs.coreutils}/bin/install -o root -g root -m 0444 "$source" "$anchor"
    fi
  '';

  serviceHardening = {
    NoNewPrivileges = true;
    CapabilityBoundingSet = "";
    AmbientCapabilities = "";
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectHostname = true;
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    RemoveIPC = true;
    KeyringMode = "private";
    ProtectProc = "invisible";
    ProcSubset = "pid";
    SystemCallArchitectures = "native";
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
    ];
    IPAddressDeny = "any";
    IPAddressAllow = "localhost";
    TasksMax = 512;
    MemoryMax = "8G";
  };
in
{
  options.services.localWirken = {
    enable = lib.mkEnableOption "governed local Wirken agent gateway";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../packages/wirken.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ../packages/wirken.nix { }";
      description = "Pinned upstream Wirken package.";
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "qwen3.6-27b-local";
    };

    ingressUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8080/v1";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 18790;
      description = "Loopback-only upstream WebChat port.";
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/wirken";
    };

    vaultPassphraseFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Root-only file containing the passphrase for Wirken's encrypted vault.";
    };

    ingressCredentialFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Root-only bearer token bootstrapped into Wirken's custom-api-key vault slot.";
    };

    sandboxImage = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/library/debian:latest";
      description = "Rolling official Debian image retagged for Wirken's upstream exec sandbox.";
    };

    operators = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Local operators of the Wirken gateway.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.vaultPassphraseFile != null;
        message = "services.localWirken.vaultPassphraseFile must be configured";
      }
      {
        assertion = cfg.ingressCredentialFile != null;
        message = "services.localWirken.ingressCredentialFile must be configured";
      }
      {
        assertion = cfg.operators != [ ];
        message = "services.localWirken.operators must contain at least one user";
      }
      {
        assertion = lib.hasPrefix "/var/lib/" cfg.stateDirectory;
        message = "services.localWirken.stateDirectory must be below /var/lib";
      }
      {
        assertion = config.virtualisation.docker.enable;
        message = "services.localWirken requires virtualisation.docker.enable for its fail-closed exec sandbox";
      }
      {
        assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
        message = "the Wirken release package is currently x86_64-linux only";
      }
    ];

    users = {
      groups.wirken = { };
      users = {
        wirken = {
          isSystemUser = true;
          group = "wirken";
          extraGroups = [ "docker" ];
          home = cfg.stateDirectory;
        };
      }
      // lib.genAttrs cfg.operators (_: {
        extraGroups = [ "wirken" ];
      });
    };

    systemd.services.wirken-sandbox-image = {
      description = "Prepare Wirken's rolling exec sandbox image";
      wantedBy = [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      before = [ "wirken.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = prepareSandboxImage;
        PrivateTmp = true;
      };
    };

    systemd.services.wirken-init = {
      description = "Initialize declarative Wirken configuration and encrypted vault";
      wantedBy = [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      before = [ "wirken.service" ];
      environment.HOME = cfg.stateDirectory;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "wirken";
        Group = "wirken";
        StateDirectory = stateDirectoryName;
        StateDirectoryMode = "0700";
        LoadCredential = [
          "vault-passphrase:${cfg.vaultPassphraseFile}"
          "ingress-token:${cfg.ingressCredentialFile}"
        ];
        ExecStart = initialize;
        PrivateNetwork = true;
        NoNewPrivileges = true;
        CapabilityBoundingSet = "";
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.stateDirectory ];
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        UMask = "0077";
      };
    };

    systemd.services.wirken = {
      description = "Wirken governed local agent gateway";
      wantedBy = [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      after = [
        "local-llama-logger.service"
        "wirken-init.service"
        "wirken-sandbox-image.service"
      ];
      requires = [
        "local-llama-logger.service"
        "wirken-init.service"
        "wirken-sandbox-image.service"
      ];
      environment = {
        HOME = cfg.stateDirectory;
        RUST_LOG = "info";
      };
      serviceConfig = serviceHardening // {
        Type = "simple";
        User = "wirken";
        Group = "wirken";
        SupplementaryGroups = [ "docker" ];
        StateDirectory = stateDirectoryName;
        StateDirectoryMode = "0700";
        WorkingDirectory = dataDirectory;
        LoadCredential = "vault-passphrase:${cfg.vaultPassphraseFile}";
        ExecStart = lib.escapeShellArgs [
          "${pkgs.expect}/bin/expect"
          vaultPty
          "gateway"
          "${cfg.package}/bin/wirken"
          "run"
          "--port"
          (toString cfg.port)
        ];
        Restart = "on-failure";
        RestartSec = 3;
        UMask = "0077";
        ReadWritePaths = [ cfg.stateDirectory ];
      };
    };

    systemd.services.wirken-audit-anchor = {
      description = "Pin Wirken's audit signing key outside the gateway data directory";
      wantedBy = [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      after = [ "wirken.service" ];
      requires = [ "wirken.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        StateDirectory = "wirken-audit-anchor";
        StateDirectoryMode = "0755";
        ExecStart = pinAuditAnchor;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadOnlyPaths = [ cfg.stateDirectory ];
        ReadWritePaths = [ auditAnchorDirectory ];
        PrivateTmp = true;
        PrivateDevices = true;
      };
    };

    systemd.services.wirken-audit-verify = {
      description = "Verify Wirken audit chains against the operator-pinned key";
      after = [ "wirken-audit-anchor.service" ];
      unitConfig.ConditionPathExists = [ auditAnchor ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.escapeShellArgs [
          "${cfg.package}/bin/wirken"
          "audit"
          "verify"
          "--require-signed"
          "--anchor"
          auditAnchor
        ];
        User = "root";
        Environment = "HOME=${cfg.stateDirectory}";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadOnlyPaths = [
          cfg.stateDirectory
          auditAnchorDirectory
        ];
        PrivateTmp = true;
        PrivateDevices = true;
      };
    };

    systemd.timers.wirken-audit-verify = {
      description = "Periodically verify Wirken's signed audit chain";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "15min";
        OnUnitActiveSec = "6h";
        Unit = "wirken-audit-verify.service";
      };
    };

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "wirken-audit-verify" ''
        exec ${config.security.wrapperDir}/sudo ${pkgs.coreutils}/bin/env \
          HOME=${lib.escapeShellArg cfg.stateDirectory} \
          ${cfg.package}/bin/wirken audit verify --require-signed \
          --anchor ${lib.escapeShellArg auditAnchor} "$@"
      '')
      (pkgs.writeShellScriptBin "wirken-audit-log" ''
        exec ${config.security.wrapperDir}/sudo ${pkgs.coreutils}/bin/env \
          HOME=${lib.escapeShellArg cfg.stateDirectory} \
          ${cfg.package}/bin/wirken audit log "$@"
      '')
    ];
  };
}
