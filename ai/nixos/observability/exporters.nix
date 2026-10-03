# Customer-side monitoring: exporters only. Data stays on the host until a central
# Prometheus scrapes it, and only from the interface named in `scrapeInterface`.
{ config, lib, ... }:

let
  cfg = config.services.observability.exporters;
  ports = import ./ports.nix;
in
{
  options.services.observability.exporters = {
    enable = lib.mkEnableOption "node and container exporters";

    scrapeInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "tailscale0";
      description = ''
        Interface a central Prometheus scrapes through. Null keeps the exporters on
        loopback, for a host that scrapes itself.
      '';
    };

    containerMetrics = lib.mkOption {
      type = lib.types.bool;
      default = config.virtualisation.docker.enable;
      description = "Per-container metrics through cAdvisor.";
    };

    textfileDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/node-exporter-textfile";
      readOnly = true;
      description = "Directory whose *.prom files node-exporter publishes; scanners write here.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Not loopback, but only the scrape interface is opened below.
    services.prometheus.exporters.node = {
      enable = true;
      listenAddress = if cfg.scrapeInterface == null then "127.0.0.1" else "0.0.0.0";
      port = ports.node;
      extraFlags = [ "--collector.textfile.directory=${cfg.textfileDirectory}" ];
    };

    services.cadvisor = lib.mkIf cfg.containerMetrics {
      enable = true;
      listenAddress = if cfg.scrapeInterface == null then "127.0.0.1" else "0.0.0.0";
      port = ports.cadvisor;
      extraOptions = [
        "--docker_only=true"
        "--store_container_labels=false"
      ];
    };

    networking.firewall.interfaces = lib.mkIf (cfg.scrapeInterface != null) {
      ${cfg.scrapeInterface}.allowedTCPPorts = [
        ports.node
      ]
      ++ lib.optional cfg.containerMetrics ports.cadvisor;
    };

    # Textfile metrics are aggregate counts only; raw scan reports stay root-only.
    systemd.tmpfiles.rules = [ "d ${cfg.textfileDirectory} 0755 root root -" ];
  };
}
