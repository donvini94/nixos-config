# Client demo: Hewitech management cockpit (Sage 100 dashboard on synthetic data) at
# demo.istbereit.de; the nginx vhost lives in services/reverse-proxy.nix. Two instances run
# side by side from checkouts of ~/code/hewitech-dashboard: version 1 (branch master) at /
# and version 2 (branch v2, DATEV and machine-data vision) at /v2/. Each branch's
# scripts/deploy.sh updates its checkout and the path unit restarts that instance.
# Rebuild only when the Python dependencies change.
{
  lib,
  pkgs,
  username,
  ...
}:
let
  stateDir = "/var/lib/hewitech-demo";
  python = pkgs.python3.withPackages (ps: [
    ps.flask
    ps.sqlalchemy
    ps.gunicorn
  ]);
  instances = {
    hewitech-demo = {
      label = "version 1";
      port = 8097;
      src = "${stateDir}/src";
      data = "${stateDir}/data";
      environment = { };
    };
    # gunicorn strips SCRIPT_NAME from the path, so Flask builds /v2/ links itself.
    hewitech-demo-v2 = {
      label = "version 2";
      port = 8099;
      src = "${stateDir}/v2";
      data = "${stateDir}/data-v2";
      environment.SCRIPT_NAME = "/v2";
    };
  };
in
{
  users.users.hewitech-demo = {
    isSystemUser = true;
    group = "hewitech-demo";
    home = stateDir;
  };
  users.groups.hewitech-demo = { };

  # The operator owns the checkouts; the services only read them and write to their data dir.
  systemd.tmpfiles.rules = [
    "d ${stateDir} 0755 hewitech-demo hewitech-demo -"
  ]
  ++ lib.concatMap (i: [
    "d ${i.src} 0755 ${username} users -"
    "d ${i.data} 0750 hewitech-demo hewitech-demo -"
  ]) (lib.attrValues instances);

  systemd.services =
    lib.mapAttrs (name: i: {
      description = "Hewitech cockpit demo, ${i.label} (synthetic data)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      unitConfig.ConditionPathExists = "${i.src}/hewidash/__init__.py";
      environment = {
        HEWIDASH_DEMO_DB = "${i.data}/demo.sqlite";
        TZ = "Europe/Berlin";
        PYTHONDONTWRITEBYTECODE = "1";
      }
      // i.environment;
      serviceConfig = {
        User = "hewitech-demo";
        Group = "hewitech-demo";
        WorkingDirectory = i.src;
        ExecStart = "${python}/bin/gunicorn --bind 127.0.0.1:${toString i.port} --workers 1 --threads 8 --no-control-socket --access-logfile - 'hewidash:create_app()'";
        Restart = "on-failure";
        RestartSec = 5;
        ReadWritePaths = [ i.data ];
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        LockPersonality = true;
        SystemCallArchitectures = "native";
        CapabilityBoundingSet = "";
        UMask = "0027";
      };
    }) instances
    // lib.mapAttrs' (
      name: _:
      lib.nameValuePair "${name}-deploy" {
        description = "Restart ${name} after a code deploy";
        serviceConfig.Type = "oneshot";
        script = "${pkgs.systemd}/bin/systemctl restart ${name}.service";
      }
    ) instances;

  systemd.paths = lib.mapAttrs' (
    name: i:
    lib.nameValuePair "${name}-deploy" {
      wantedBy = [ "paths.target" ];
      pathConfig.PathChanged = "${i.src}/.deployed";
    }
  ) instances;
}
