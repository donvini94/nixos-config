# Client demo: Hewitech management cockpit (Sage 100 dashboard on synthetic data) at
# demo.istbereit.de; the nginx vhost lives in services/reverse-proxy.nix. Code runs from a
# checkout of ~/code/hewitech-dashboard; its scripts/deploy.sh updates the checkout and the
# path unit restarts the service. Rebuild only when the Python dependencies change.
{
  pkgs,
  username,
  ...
}:
let
  port = 8097;
  stateDir = "/var/lib/hewitech-demo";
  src = "${stateDir}/src";
  python = pkgs.python3.withPackages (ps: [
    ps.flask
    ps.sqlalchemy
    ps.gunicorn
  ]);
in
{
  users.users.hewitech-demo = {
    isSystemUser = true;
    group = "hewitech-demo";
    home = stateDir;
  };
  users.groups.hewitech-demo = { };

  # The operator owns the checkout; the service only reads it and writes to data/.
  systemd.tmpfiles.rules = [
    "d ${stateDir} 0755 hewitech-demo hewitech-demo -"
    "d ${src} 0755 ${username} users -"
    "d ${stateDir}/data 0750 hewitech-demo hewitech-demo -"
  ];

  systemd.services.hewitech-demo = {
    description = "Hewitech cockpit demo (synthetic data)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    unitConfig.ConditionPathExists = "${src}/hewidash/__init__.py";
    environment = {
      HEWIDASH_DEMO_DB = "${stateDir}/data/demo.sqlite";
      TZ = "Europe/Berlin";
      PYTHONDONTWRITEBYTECODE = "1";
    };
    serviceConfig = {
      User = "hewitech-demo";
      Group = "hewitech-demo";
      WorkingDirectory = src;
      ExecStart = "${python}/bin/gunicorn --bind 127.0.0.1:${toString port} --workers 1 --threads 8 --no-control-socket --access-logfile - 'hewidash:create_app()'";
      Restart = "on-failure";
      RestartSec = 5;
      ReadWritePaths = [ "${stateDir}/data" ];
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
  };

  systemd.paths.hewitech-demo-deploy = {
    wantedBy = [ "paths.target" ];
    pathConfig.PathChanged = "${src}/.deployed";
  };
  systemd.services.hewitech-demo-deploy = {
    description = "Restart the Hewitech cockpit demo after a code deploy";
    serviceConfig.Type = "oneshot";
    script = "${pkgs.systemd}/bin/systemctl restart hewitech-demo.service";
  };
}
