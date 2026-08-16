# Hermes operator dashboard.
#
# WHY THIS EXISTS: the dashboard is a second process, not part of `hermes
# gateway run`. The official nousresearch image supervises it as an s6 longrun
# (docker/s6-rc.d/dashboard) gated on $HERMES_DASHBOARD; the upstream NixOS
# module's OCI mode uses a plain base image with no s6, so nothing starts it.
# Everything else about the deployment is upstream's.
#
# DELETE THIS when services.hermes-agent supervises the dashboard itself. The
# check is one command: with this unit masked, confirm container-mode Hermes
# listens on $HERMES_DASHBOARD_PORT by itself.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.hermesDashboard;
  hermesCfg = config.services.hermes-agent;

  # Both fixed by the upstream module (nix/nixosModules.nix: containerName,
  # containerDataDir). stateDir is mounted at /data inside the container, so
  # the host path is not valid here.
  containerName = "hermes-agent";
  containerDataDir = "/data";

  runDashboard = pkgs.writeShellScript "hermes-dashboard-run" ''
    set -euo pipefail
    # Resolve the identity at runtime: the hermes uid/gid are allocated by
    # NixOS, and `docker exec` would otherwise default to the container's root
    # and leave root-owned files in the shared HERMES_HOME.
    uid="$(${pkgs.coreutils}/bin/id -u ${hermesCfg.user})"
    gid="$(${pkgs.coreutils}/bin/id -g ${hermesCfg.user})"
    exec ${pkgs.docker}/bin/docker exec --user "$uid:$gid" ${containerName} \
      ${containerDataDir}/current-package/bin/hermes dashboard \
      --host 127.0.0.1 --port ${toString cfg.port} --no-open --skip-build
  '';
in
{
  options.services.hermesDashboard = {
    enable = lib.mkEnableOption "the Hermes dashboard inside the agent container";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9119;
      description = "Loopback port for the dashboard web UI.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = hermesCfg.enable && hermesCfg.container.enable;
        message = "services.hermesDashboard requires the upstream Hermes container mode";
      }
    ];

    systemd.services.hermes-dashboard = {
      description = "Hermes operator dashboard";
      wantedBy = [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      # BindsTo, not Requires: the dashboard lives inside the agent's container,
      # so it must die with it instead of retrying against a dead exec target.
      bindsTo = [ "hermes-agent.service" ];
      after = [ "hermes-agent.service" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = runDashboard;
        Restart = "always";
        RestartSec = 5;
      };
    };
  };
}
