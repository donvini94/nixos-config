{
  config,
  lib,
  pkgs,
  ...
}:

let
  tailscale = lib.getExe config.services.tailscale.package;
  tailnetHost = "alucard.tailf117a1.ts.net";
  # Tailnet listen port -> loopback target. The AI entries match dracula's
  # ai-admin SSH forwards, the media ones media-admin's.
  privateTcpServices = {
    langfuse = { listen = 23000; target = 13000; };
    grafana = { listen = 23001; target = 13001; };
    n8n = { listen = 25678; target = 5678; };
    openai-ingress = { listen = 28080; target = 8080; };
    prometheus = { listen = 29091; target = 19091; };
    kapowarr = { listen = 15656; target = 15656; };
    bazarr = { listen = 16767; target = 16767; };
    radarr = { listen = 17878; target = 17878; };
    qbittorrent = { listen = 18080; target = 18080; };
    sonarr = { listen = 18989; target = 18989; };
    sabnzbd = { listen = 19090; target = 19090; };
    prowlarr = { listen = 19696; target = 19696; };
    # Plain TCP rather than `serve --https`: the atuin client is not a browser,
    # has no origin check to satisfy, and WireGuard already encrypts the hop.
    atuin = { listen = 28888; target = 8888; };
  };
  tailscaleReady = pkgs.writeShellScript "tailscale-private-services-ready" ''
    set -euo pipefail
    state="$(${tailscale} status --json --peers=false | ${lib.getExe pkgs.jq} -r .BackendState)"
    test "$state" = Running
  '';
  configurePrivateServices = pkgs.writeShellScript "tailscale-private-services" ''
    set -euo pipefail
    ${tailscale} serve reset
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        _: service:
        "${tailscale} serve --yes --bg --tcp=${toString service.listen} tcp://127.0.0.1:${toString service.target}"
      ) privateTcpServices
    )}
    # Hermes only accepts its bound loopback Host and Origin, so nginx validates
    # the exact tailnet origin and rewrites them before proxying.
    ${tailscale} serve --yes --bg --https=29119 http://127.0.0.1:19119
  '';
in
{
  services.tailscale = {
    enable = true;
    disableTaildrop = true;
    openFirewall = false;
    useRoutingFeatures = "none";
  };

  services.nginx = {
    appendHttpConfig = lib.mkAfter ''
      map $http_origin $hermes_tailnet_origin {
        default invalid;
        "" "";
        "https://${tailnetHost}:29119" "http://127.0.0.1:9119";
      }
    '';
    virtualHosts = {
      hermes-tailnet-proxy = {
        serverName = tailnetHost;
        listen = [
          {
            addr = "127.0.0.1";
            port = 19119;
          }
        ];
        extraConfig = "modsecurity off;";
        locations."/" = {
          proxyPass = "http://127.0.0.1:9119";
          proxyWebsockets = true;
          recommendedProxySettings = false;
          extraConfig = ''
            if ($hermes_tailnet_origin = invalid) { return 403; }
            proxy_set_header Host 127.0.0.1:9119;
            proxy_set_header Origin $hermes_tailnet_origin;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Host $http_host;
            proxy_set_header X-Forwarded-Proto https;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
          '';
        };
      };
    };
  };

  # Backends stay on loopback and no tailnet interface is globally trusted;
  # Hermes also gets a tailnet-valid HTTPS endpoint for its browser WebSockets.
  systemd.services.tailscale-private-services = {
    description = "Publish explicit Alucard administration ports inside the tailnet";
    after = [
      "nginx.service"
      "tailscaled.service"
    ];
    wants = [
      "nginx.service"
      "tailscaled.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecCondition = tailscaleReady;
      ExecStart = configurePrivateServices;
    };
  };
}
