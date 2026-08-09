{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.localSignal;
  signalCli = pkgs.callPackage ../packages/signal-cli-native.nix { };
in
{
  options.services.localSignal = {
    enable = lib.mkEnableOption "private signal-cli bridge for local agents";
    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 18083;
    };
    operators = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.operators != [ ];
        message = "services.localSignal.operators must contain at least one user";
      }
    ];

    users.groups.signal-cli = { };
    users.users = {
      signal-cli = {
        isSystemUser = true;
        group = "signal-cli";
        home = "/var/lib/signal-cli";
      };
      hermes.extraGroups = [ "signal-cli" ];
      wirken.extraGroups = [ "signal-cli" ];
    }
    // lib.genAttrs cfg.operators (_: {
      extraGroups = [ "signal-cli" ];
    });

    systemd.tmpfiles.rules = [
      "d /var/lib/signal-cli 0700 signal-cli signal-cli -"
    ];

    systemd.services.signal-cli = {
      description = "Signal bridge for Hermes and Wirken";
      wantedBy = [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      before = [
        "hermes-agent.service"
        "wirken.service"
      ];
      unitConfig.ConditionPathExists = "/var/lib/signal-cli/signal-cli/data/accounts.json";
      environment = {
        HOME = "/var/lib/signal-cli";
        XDG_DATA_HOME = "/var/lib/signal-cli";
        XDG_RUNTIME_DIR = "/run/signal-cli";
      };
      serviceConfig = {
        User = "signal-cli";
        Group = "signal-cli";
        StateDirectory = "signal-cli";
        StateDirectoryMode = "0700";
        RuntimeDirectory = "signal-cli";
        RuntimeDirectoryMode = "0770";
        ExecStart = lib.escapeShellArgs [
          (lib.getExe signalCli)
          "daemon"
          "--socket"
          "/run/signal-cli/signal-cli.sock"
          "--http"
          "127.0.0.1:${toString cfg.httpPort}"
          "--receive-mode"
          "on-start"
          "--ignore-stories"
        ];
        Restart = "on-failure";
        RestartSec = 5;
        UMask = "0007";
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ "/var/lib/signal-cli" ];
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        RestrictSUIDSGID = true;
        LockPersonality = true;
      };
    };

    environment.systemPackages = [
      signalCli
      pkgs.qrencode
      (pkgs.writeShellScriptBin "signal-link" ''
        set -euo pipefail
        ${config.security.wrapperDir}/sudo ${pkgs.systemd}/bin/systemctl stop signal-cli.service
        coproc LINK_PROCESS {
          ${config.security.wrapperDir}/sudo -u signal-cli \
            ${pkgs.coreutils}/bin/env \
              HOME=/var/lib/signal-cli \
              XDG_DATA_HOME=/var/lib/signal-cli \
              XDG_RUNTIME_DIR=/run/signal-cli \
            ${lib.getExe signalCli} link -n "''${1:-Alucard AI}"
        }
        link_pid=$LINK_PROCESS_PID
        if ! read -r link_uri <&"''${LINK_PROCESS[0]}"; then
          echo "signal-cli did not produce a link URI" >&2
          wait "$link_pid"
          exit 1
        fi
        ${lib.getExe pkgs.qrencode} -t ANSIUTF8 "$link_uri"
        echo "Signal > Settings > Linked devices > +: scan the QR code above."
        ${pkgs.coreutils}/bin/cat <&"''${LINK_PROCESS[0]}" || true
        wait "$link_pid"
        ${config.security.wrapperDir}/sudo ${pkgs.systemd}/bin/systemctl start signal-cli.service
        echo "Signal device linked; configure agent allowlists before accepting messages."
      '')
      (pkgs.writeShellScriptBin "signal-accounts" ''
        exec ${config.security.wrapperDir}/sudo -u signal-cli \
          ${pkgs.coreutils}/bin/env \
            HOME=/var/lib/signal-cli \
            XDG_DATA_HOME=/var/lib/signal-cli \
          ${lib.getExe signalCli} listAccounts
      '')
    ];
  };
}
