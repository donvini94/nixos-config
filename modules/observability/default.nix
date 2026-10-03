# Prometheus, Grafana and exporters on loopback. Backends stay private; hosts publish
# them through Tailscale Serve.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.localObservability;
  loopback = "127.0.0.1";
  nodeExporterPort = 19100;
  cadvisorPort = 18081;
  gpuExporterPort = 19400;
  scrape = job_name: port: {
    inherit job_name;
    static_configs = [ { targets = [ "${loopback}:${toString port}" ]; } ];
  };
  units = [
    "prometheus.service"
    "grafana.service"
    "prometheus-node-exporter.service"
  ]
  ++ lib.optional cfg.containerMetrics "cadvisor.service"
  ++ lib.optional cfg.gpuMetrics "prometheus-nvidia-gpu-exporter.service";
  # Without autoStart the units keep no boot dependency; observability.target is the switch.
  unitSettings = {
    wantedBy = lib.mkIf (!cfg.autoStart) (lib.mkForce [ ]);
    partOf = [ "observability.target" ];
  };
in
{
  options.services.localObservability = {
    enable = lib.mkEnableOption "Prometheus and Grafana monitoring";

    secretsFile = lib.mkOption {
      type = lib.types.path;
      description = "SOPS file holding `grafana/admin_password` and `grafana/secret_key`.";
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start monitoring at boot. Otherwise use `systemctl start observability.target`.";
    };

    hostLabel = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "Host label attached to all Prometheus series.";
    };

    grafanaPort = lib.mkOption {
      type = lib.types.port;
      default = 13001;
    };

    prometheusPort = lib.mkOption {
      type = lib.types.port;
      default = 19091;
    };

    containerMetrics = lib.mkOption {
      type = lib.types.bool;
      default = config.virtualisation.docker.enable;
      description = "Per-container metrics through cAdvisor.";
    };

    gpuMetrics = lib.mkEnableOption "NVIDIA GPU metrics";

    textfileDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/node-exporter-textfile";
      readOnly = true;
      description = "Directory whose *.prom files node-exporter publishes; scanners write here.";
    };

    scrapeTargets = lib.mkOption {
      type = lib.types.attrsOf lib.types.port;
      default = { };
      description = "Additional loopback scrape jobs keyed by job name.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = lib.genAttrs [ "grafana/admin_password" "grafana/secret_key" ] (_: {
      sopsFile = cfg.secretsFile;
      owner = "grafana";
      mode = "0400";
    });

    systemd.targets.observability = {
      description = "Monitoring stack";
      wants = units;
      wantedBy = lib.optional cfg.autoStart "multi-user.target";
    };

    # Textfile metrics are aggregate counts only; raw scan reports stay root-only.
    systemd.tmpfiles.rules = [ "d ${cfg.textfileDirectory} 0755 root root -" ];

    services.prometheus = {
      enable = true;
      listenAddress = loopback;
      port = cfg.prometheusPort;
      retentionTime = "90d";
      extraFlags = [ "--storage.tsdb.retention.size=20GB" ];
      globalConfig = {
        scrape_interval = "15s";
        evaluation_interval = "15s";
        external_labels.host = cfg.hostLabel;
      };
      ruleFiles = [ ((pkgs.formats.yaml { }).generate "alerts.yml" (import ./alerts.nix)) ];
      scrapeConfigs = [
        (scrape "prometheus" cfg.prometheusPort)
        (scrape "node" nodeExporterPort)
      ]
      ++ lib.optional cfg.containerMetrics (scrape "containers" cadvisorPort)
      ++ lib.optional cfg.gpuMetrics (scrape "nvidia" gpuExporterPort)
      ++ lib.mapAttrsToList scrape cfg.scrapeTargets;
      exporters.node = {
        enable = true;
        listenAddress = loopback;
        port = nodeExporterPort;
        extraFlags = [ "--collector.textfile.directory=${cfg.textfileDirectory}" ];
      };
      exporters.nvidia-gpu = lib.mkIf cfg.gpuMetrics {
        enable = true;
        listenAddress = loopback;
        port = gpuExporterPort;
      };
    };

    services.cadvisor = lib.mkIf cfg.containerMetrics {
      enable = true;
      listenAddress = loopback;
      port = cadvisorPort;
      extraOptions = [
        "--docker_only=true"
        "--store_container_labels=false"
      ];
    };

    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = loopback;
          http_port = cfg.grafanaPort;
        };
        security = {
          admin_user = "admin";
          admin_password = "$__file{${config.sops.secrets."grafana/admin_password".path}}";
          secret_key = "$__file{${config.sops.secrets."grafana/secret_key".path}}";
        };
        users.allow_sign_up = false;
        plugins.preinstall_disabled = true;
        analytics = {
          reporting_enabled = false;
          check_for_updates = false;
          check_for_plugin_updates = false;
        };
      };
      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            uid = "prometheus";
            access = "proxy";
            url = "http://${loopback}:${toString cfg.prometheusPort}";
            isDefault = true;
            editable = false;
          }
        ];
        dashboards.settings.providers = [
          {
            name = "Overview";
            type = "file";
            disableDeletion = true;
            options.path = ./overview.json;
          }
        ];
      };
    };

    systemd.services = {
      prometheus = unitSettings;
      grafana = unitSettings;
      prometheus-node-exporter = unitSettings;
      cadvisor = lib.mkIf cfg.containerMetrics unitSettings;
      prometheus-nvidia-gpu-exporter = lib.mkIf cfg.gpuMetrics unitSettings;
    };
  };
}
