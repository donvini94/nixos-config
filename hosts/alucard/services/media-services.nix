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
    text = ''
      set -euo pipefail

      network_config=/home/jellyfin/config/network.xml
      test -f "$network_config"

      current_addresses="$(xml sel -t -v 'count(/NetworkConfiguration/LocalNetworkAddresses/string[text() = "127.0.0.1"])' "$network_config")"
      current_ipv6="$(xml sel -t -v '/NetworkConfiguration/EnableIPv6' "$network_config")"
      if [ "$current_addresses" != 1 ] || [ "$current_ipv6" != false ]; then
        xml ed -P -L \
          -d '/NetworkConfiguration/LocalNetworkAddresses/*' \
          -s '/NetworkConfiguration/LocalNetworkAddresses' -t elem -n string -v 127.0.0.1 \
          -u '/NetworkConfiguration/EnableIPv6' -v false \
          "$network_config"
        chown jellyfin:jellyfin "$network_config"
      fi

      sso_config=/home/jellyfin/plugins/configurations/SSO-Auth.xml
      if [ -f "$sso_config" ]; then
        provider="/PluginConfiguration/OidConfigs/item[key/string = 'keycloak']/value/PluginConfiguration"
        provider_count="$(xml sel -t -v "count($provider)" "$sso_config")"
        if [ "$provider_count" = 1 ]; then
          setting_count="$(xml sel -t -v "count($provider/DisablePushedAuthorization)" "$sso_config")"
          if [ "$setting_count" = 0 ]; then
            xml ed -P -L \
              -s "$provider" -t elem -n DisablePushedAuthorization -v true \
              "$sso_config"
            chown jellyfin:jellyfin "$sso_config"
          elif [ "$setting_count" = 1 ] \
            && [ "$(xml sel -t -v "$provider/DisablePushedAuthorization" "$sso_config")" != true ]; then
            xml ed -P -L \
              -u "$provider/DisablePushedAuthorization" -v true \
              "$sso_config"
            chown jellyfin:jellyfin "$sso_config"
          elif [ "$setting_count" != 1 ]; then
            echo "expected at most one DisablePushedAuthorization setting for the keycloak provider" >&2
            exit 1
          fi
        elif [ "$provider_count" != 0 ]; then
          echo "expected at most one keycloak OIDC provider" >&2
          exit 1
        fi
      fi
    '';
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

  # Jellyfin SSO-Auth 4.x follows the provider's advertised PAR endpoint by
  # default, but Keycloak rejects this confidential client's pushed request.
  # Disable PAR through the plugin's supported setting before Jellyfin starts;
  # the ordinary authorization-code flow remains protected by state and PKCE.
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
