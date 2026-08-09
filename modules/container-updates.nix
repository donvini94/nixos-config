{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.containerUpdates;
in
{
  options.services.containerUpdates = {
    enable = lib.mkEnableOption "automatic updates for Docker-managed application units";

    units = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Systemd units to restart when active so they pull and recreate rolling containers.";
    };

    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 04:00:00";
      description = "Calendar expression for automatic container updates.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.units != [ ];
        message = "services.containerUpdates.units must contain at least one systemd unit";
      }
    ];

    systemd.services.container-update = {
      description = "Update active Docker application stacks";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      serviceConfig.Type = "oneshot";
      script = ''
        set -euo pipefail
        for unit in ${lib.escapeShellArgs cfg.units}; do
          echo "Updating $unit"
          ${pkgs.systemd}/bin/systemctl try-restart --wait "$unit"
        done
      '';
    };

    systemd.timers.container-update = {
      description = "Daily rolling-container update";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.onCalendar;
        # Avoid starting container recreation inside a NixOS switch merely because
        # the machine was off at the scheduled time.
        Persistent = false;
        RandomizedDelaySec = "30m";
        Unit = "container-update.service";
      };
    };

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "containers-update" ''
        exec ${pkgs.sudo}/bin/sudo ${pkgs.systemd}/bin/systemctl start --wait container-update.service
      '')
    ];
  };
}
