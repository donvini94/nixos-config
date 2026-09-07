{
  config,
  lib,
  pkgs,
  ...
}:
let
  jellyfinRuntimePolicy = pkgs.writeShellApplication {
    name = "jellyfin-runtime-policy";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.xmlstarlet
    ];
    runtimeEnv = {
      JELLYFIN_DATA_DIR = config.services.jellyfin.dataDir;
      JELLYFIN_USER = config.services.jellyfin.user;
      JELLYFIN_GROUP = config.services.jellyfin.group;
    };
    text = builtins.readFile ../../../scripts/jellyfin-runtime-policy.sh;
  };
in
{
  assertions = [
    {
      assertion =
        lib.intersectLists [
          "docker"
          "wheel"
        ] config.users.users.jellyfin.extraGroups == [ ]
        && config.users.users.jellyfin.openssh.authorizedKeys.keys == [ ];
      message = "The public Jellyfin service account must not have host administrator access";
    }
  ];

  services = {
    jellyfin = {
      enable = true;
      openFirewall = false;
      dataDir = "/home/jellyfin/";
    };

    navidrome = {
      enable = true;
      openFirewall = false;
      settings.MusicFolder = "/mnt/music";
    };

    calibre-web = {
      enable = true;
      listen.ip = "127.0.0.1";
      listen.port = 8083;
      openFirewall = false;
      dataDir = "calibre-web";
      options = {
        enableBookUploading = true;
        enableBookConversion = true;
      };
    };
  };

  # Jellyfin SSO-Auth 4.x follows the provider's advertised PAR endpoint, but
  # Keycloak rejects this confidential client's pushed request, so PAR is
  # disabled here before Jellyfin starts; the code flow keeps state and PKCE.
  systemd.services.jellyfin-runtime-policy = {
    description = "Enforce Jellyfin network and SSO policy";
    before = [ "jellyfin.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe jellyfinRuntimePolicy;
    };
  };

  systemd.services.jellyfin = {
    requires = [ "jellyfin-runtime-policy.service" ];
    after = [ "jellyfin-runtime-policy.service" ];
    # A group-policy change is a security boundary, so the running process
    # must drop its old supplementary groups during the same activation.
    restartTriggers = [ (builtins.toJSON config.users.users.jellyfin.extraGroups) ];
  };
}
