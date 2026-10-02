{
  config,
  pkgs,
  ...
}:
{
  services = {
    postgresql.enable = true;

    keycloak = {
      enable = true;
      database = {
        createLocally = true;
        username = "keycloak";
        passwordFile = config.sops.secrets."keycloak/password".path;
      };
      settings = {
        hostname = "auth.dumusstbereitsein.de";
        http-port = 38080;
        http-host = "127.0.0.1";
        http-enabled = true;
        proxy-headers = "xforwarded";
        hostname-strict-https = false;
        hostname-strict = true;
      };
    };
  };

  services.offsiteBackup.jobs.keycloak = {
    # Use a consistent database dump; realm exports do not preserve all database state.
    runtimeInputs = [
      config.services.postgresql.package
      pkgs.util-linux
    ];
    requires = [ "postgresql.service" ];
    after = [ "postgresql.service" ];
    prepare = ''
      install -d -m 0700 "$stage"
      runuser -u postgres -- pg_dump --format=custom --no-owner keycloak \
        > "$stage/keycloak.dump"
      test -s "$stage/keycloak.dump"
    '';
    verifyPaths = [ "/var/lib/offsite-backup/keycloak/keycloak.dump" ];
  };

  systemd.services.keycloak.serviceConfig = {
    CapabilityBoundingSet = "";
    PrivateDevices = true;
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
    LockPersonality = true;
    ProtectProc = "invisible";
    ProcSubset = "pid";
  };
}
