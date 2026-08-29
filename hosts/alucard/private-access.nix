{
  config,
  lib,
  pkgs,
  ...
}:

let
  tailscale = lib.getExe config.services.tailscale.package;
  tailnetHost = "alucard.tailf117a1.ts.net";
  privateTcpServices = {
    # AI stack. These match Dracula's ai-admin forwarding ports.
    "23000" = 13000; # Langfuse
    "23001" = 13001; # Grafana
    "25678" = 5678; # n8n
    "28080" = 8080; # Requesty-backed OpenAI API
    "29091" = 19091; # Prometheus
    # Media administration. These match the media-admin SSH forwards.
    "15656" = 15656; # Kapowarr
    "16767" = 16767; # Bazarr
    "17878" = 17878; # Radarr
    "18080" = 18080; # qBittorrent
    "18989" = 18989; # Sonarr
    "19090" = 19090; # SABnzbd
    "19696" = 19696; # Prowlarr
    # Secrets platform. Administration only; workloads reach it on loopback.
    "28200" = 8200; # OpenBao
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
        listenPort: targetPort:
        "${tailscale} serve --yes --bg --tcp=${listenPort} tcp://127.0.0.1:${toString targetPort}"
      ) privateTcpServices
    )}
    # This upstream UI intentionally accepts only its bound loopback Host and
    # Origin. nginx validates the exact tailnet origin before translating it;
    # Tailscale remains the only listener exposed outside loopback.
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

  # Backends stay on loopback, and no tailnet interface is globally trusted.
  # Hermes additionally gets a tailnet-valid HTTPS endpoint because its chat
  # and event streams use browser WebSockets.
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
