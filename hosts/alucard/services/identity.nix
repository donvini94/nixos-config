{
  config,
  lib,
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

  # Keycloak realm export (manual activation only)
  systemd.services.keycloakExportRealms =
    let
      p = config.systemd.services.keycloak;
    in
    lib.mkIf config.services.keycloak.enable {
      after = p.after;
      before = [ "keycloak.service" ];
      wantedBy = [ ];
      environment = lib.mkForce p.environment;
      serviceConfig =
        let
          origin = p.serviceConfig;
        in
        {
          Type = "oneshot";
          RemainAfterExit = true;
          User = origin.User;
          Group = origin.Group;
          LoadCredential = origin.LoadCredential;
          DynamicUser = origin.DynamicUser;
          RuntimeDirectory = origin.RuntimeDirectory;
          RuntimeDirectoryMode = origin.RuntimeDirectoryMode;
          AmbientCapabilities = origin.AmbientCapabilities;
          StateDirectory = "keycloak";
          StateDirectoryMode = "0750";
        };
      script = ''
        EDIR="/var/lib/keycloak"
        EDIRT="$EDIR/$(date '+%Y-%m-%d_%H-%M-%S')"
        mkdir -p $EDIRT
        kc.sh export --dir=$EDIRT
        echo "Keycloak export completed successfully to: $EDIRT"
      '';
    };

  # Startup-critical state that a host loss would otherwise destroy. The
  # Paperless job lives in modules/paperless.nix because its snapshot depends on
  # that module's exporter directory and signing key.
  services.offsiteBackup.jobs.keycloak = {
    # pg_dump, not a file copy: Keycloak's cluster is live during the window,
    # and the realm export alone omits users, sessions and credentials.
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
    verifyPaths = [ "${"/var/lib/offsite-backup/keycloak/keycloak.dump"}" ];
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
