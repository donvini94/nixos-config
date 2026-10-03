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
