# Alucard's own administration ports on the tailnet, published by the ai-stack's
# Tailscale Serve unit alongside n8n, Hermes, Grafana and Prometheus. The media ports
# match dracula's media-admin SSH forwards.
{ site, username, ... }:
{
  # The operator may run Tailscale without root: the staging run and customer installs
  # pre-sign their join keys with this node's Tailnet Lock key.
  services.tailscale.extraSetFlags = [ "--operator=${username}" ];

  services.aiStack.tailnet = {
    domain = site.tailnet;
    tcp = {
      kapowarr = {
        listen = 15656;
        target = 15656;
      };
      bazarr = {
        listen = 16767;
        target = 16767;
      };
      radarr = {
        listen = 17878;
        target = 17878;
      };
      qbittorrent = {
        listen = 18080;
        target = 18080;
      };
      sonarr = {
        listen = 18989;
        target = 18989;
      };
      sabnzbd = {
        listen = 19090;
        target = 19090;
      };
      prowlarr = {
        listen = 19696;
        target = 19696;
      };
      # Plain TCP rather than `serve --https`: the atuin client is not a browser,
      # has no origin check to satisfy, and WireGuard already encrypts the hop.
      atuin = {
        listen = 28888;
        target = 8888;
      };
    };
  };
}
