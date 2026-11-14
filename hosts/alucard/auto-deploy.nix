{
  config,
  pkgs,
  ...
}:
let
  # Public repository: root needs no credentials; private inputs use the deploy keys from ai.nix.
  autoDeploy = pkgs.writeShellApplication {
    name = "alucard-auto-deploy";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.gawk
      pkgs.nix
      pkgs.nixos-rebuild
      pkgs.systemd
      config.virtualisation.docker.package
    ];
    runtimeEnv = {
      FLAKE = "github:donvini94/nixos-config/master#alucard";
      CHAT_ID = "935728023";
      TOKEN_FILE = config.sops.secrets."alertmanager/telegram_bot_token".path;
    };
    text = builtins.readFile ./scripts/auto-deploy.sh;
  };
in
{
  systemd.services.auto-deploy = {
    description = "Deploy the latest nixos-config with health check and rollback";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${autoDeploy}/bin/alucard-auto-deploy";
      TimeoutStartSec = "1h";
      Slice = "maintenance.slice";
    };
  };

  # After the 04:05 backups, before the Sunday 05:00 restic checks.
  systemd.timers.auto-deploy = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 04:30:00 Europe/Berlin";
      # Persistent would deploy during the day after downtime.
      Persistent = false;
    };
  };
}
