{
  config,
  lib,
  pkgs,
  ...
}:

let
  tailscale = lib.getExe config.services.tailscale.package;
  privateTcpServices = {
    # AI stack. These match Dracula's ai-admin forwarding ports.
    "23000" = 13000; # Langfuse
    "23001" = 13001; # Grafana
    "25678" = 5678; # n8n
    "28080" = 8080; # Requesty-backed OpenAI API
    "28790" = 18790; # Wirken
    "29091" = 19091; # Prometheus
    # Media administration. These match the media-admin SSH forwards.
    "15656" = 15656; # Kapowarr
    "16767" = 16767; # Bazarr
    "17878" = 17878; # Radarr
    "18080" = 18080; # qBittorrent
    "18989" = 18989; # Sonarr
    "19090" = 19090; # SABnzbd
    "19696" = 19696; # Prowlarr
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
    # HTTPS avoids browser HTTPS-only upgrades breaking Hermes' WebSockets.
    ${tailscale} serve --yes --bg --https=29119 http://127.0.0.1:9119
  '';
in
{
  services.tailscale = {
    enable = true;
    disableTaildrop = true;
    openFirewall = false;
    useRoutingFeatures = "none";
  };

  # Backends stay on loopback, and no tailnet interface is globally trusted.
  # Hermes additionally gets a tailnet-valid HTTPS endpoint because its chat
  # and event streams use browser WebSockets.
  systemd.services.tailscale-private-services = {
    description = "Publish explicit Alucard administration ports inside the tailnet";
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecCondition = tailscaleReady;
      ExecStart = configurePrivateServices;
    };
  };
}
