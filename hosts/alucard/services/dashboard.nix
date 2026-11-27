# Read-only gateway from the Homarr dashboard (media-stack's `dashboard` network) to
# backends that listen on loopback only. Custom widgets query it server-side.
{ config, ... }:
let
  network = "172.31.250.0/24";
  port = 8480;
  readOnly = target: {
    proxyPass = target;
    extraConfig = "limit_except GET { deny all; }";
  };
in
{
  networking.firewall.interfaces.br-dashboard.allowedTCPPorts = [ port ];

  # Bound to all addresses because the bridge only exists once the media stack is up;
  # the firewall opens the port on br-dashboard alone, and nginx admits only its subnet.
  services.nginx.virtualHosts.dashboard-gateway = {
    listen = [
      {
        addr = "0.0.0.0";
        inherit port;
      }
    ];
    extraConfig = ''
      modsecurity off;
      allow ${network};
      deny all;
    '';
    locations = {
      "= /prometheus/api/v1/query" =
        readOnly "http://127.0.0.1:${toString config.services.observability.server.prometheusPort}/api/v1/query";
      # Twenty enforces its own API key on every request.
      "/twenty/rest/" = readOnly "http://127.0.0.1:13000/rest/";
      "/" = {
        return = "404";
      };
    };
  };
}
