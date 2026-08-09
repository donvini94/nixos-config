{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.localObservability;
  stateDirectory = "/var/lib/observability-stack";
  scrape = job_name: port: {
    inherit job_name;
    static_configs = [ { targets = [ "127.0.0.1:${toString port}" ]; } ];
  };
  prometheusConfig = (pkgs.formats.yaml { }).generate "prometheus.yml" {
    global = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
      external_labels.host = cfg.hostLabel;
    };
    scrape_configs = [
      (scrape "prometheus" cfg.prometheusPort)
      (scrape "node" cfg.nodeExporterPort)
      (scrape "containers" cfg.cadvisorPort)
    ]
    ++ lib.optional cfg.gpuMetrics (scrape "nvidia" cfg.dcgmExporterPort)
    ++ lib.optional (cfg.inferencePort != null) (scrape "ai-ingress" cfg.inferencePort)
    ++ lib.optional (cfg.n8nPort != null) (scrape "n8n" cfg.n8nPort)
    ++ lib.mapAttrsToList scrape cfg.extraScrapeTargets;
  };
  prepare = pkgs.writeShellScript "observability-prepare" ''
    set -euo pipefail
    ${pkgs.coreutils}/bin/install -d -m 0750 ${stateDirectory}/textfile
    ${pkgs.coreutils}/bin/cp -R ${../observability}/. ${stateDirectory}/
    ${pkgs.coreutils}/bin/cp ${prometheusConfig} ${stateDirectory}/prometheus.yml
  '';
in
{
  options.services.localObservability = {
    enable = lib.mkEnableOption "local Langfuse, Grafana, and Prometheus observability stack";

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Root-only environment file containing observability service secrets.";
    };

    hostLabel = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "Host label attached to all Prometheus series.";
    };

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };

    langfusePort = lib.mkOption {
      type = lib.types.port;
      default = 13000;
    };

    grafanaPort = lib.mkOption {
      type = lib.types.port;
      default = 13001;
    };

    prometheusPort = lib.mkOption {
      type = lib.types.port;
      default = 19091;
    };

    minioPort = lib.mkOption {
      type = lib.types.port;
      default = 19000;
    };

    nodeExporterPort = lib.mkOption {
      type = lib.types.port;
      default = 19100;
    };

    cadvisorPort = lib.mkOption {
      type = lib.types.port;
      default = 18081;
    };

    dcgmExporterPort = lib.mkOption {
      type = lib.types.port;
      default = 19400;
    };

    gpuMetrics = lib.mkEnableOption "NVIDIA GPU metrics via DCGM exporter";

    inferencePort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      description = "Optional loopback OpenAI ingress metrics port.";
    };

    n8nPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      description = "Optional loopback n8n Prometheus metrics port.";
    };

    extraScrapeTargets = lib.mkOption {
      type = lib.types.attrsOf lib.types.port;
      default = { };
      description = "Additional loopback Prometheus scrape jobs keyed by job name.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.environmentFile != null;
        message = "services.localObservability.environmentFile must be configured";
      }
    ];

    virtualisation.docker.enable = true;

    systemd.tmpfiles.rules = [
      "d ${stateDirectory} 0750 root root -"
      "d ${stateDirectory}/textfile 0750 root root -"
    ];

    systemd.services.observability-stack = {
      description = "Langfuse and machine/container observability stack";
      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      path = [
        pkgs.docker
        pkgs.docker-compose
      ];
      environment = {
        OBSERVABILITY_BIND_ADDRESS = cfg.bindAddress;
        LANGFUSE_PORT = toString cfg.langfusePort;
        GRAFANA_PORT = toString cfg.grafanaPort;
        PROMETHEUS_PORT = toString cfg.prometheusPort;
        MINIO_PORT = toString cfg.minioPort;
        NODE_EXPORTER_PORT = toString cfg.nodeExporterPort;
        CADVISOR_PORT = toString cfg.cadvisorPort;
        DCGM_EXPORTER_PORT = toString cfg.dcgmExporterPort;
        COMPOSE_PROFILES = lib.optionalString cfg.gpuMetrics "gpu";
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "30min";
        TimeoutStopSec = "10min";
        WorkingDirectory = stateDirectory;
        EnvironmentFile = cfg.environmentFile;
        ExecStartPre = [ prepare ];
        ExecStart = "${pkgs.docker}/bin/docker compose up -d --pull always --remove-orphans --wait";
        ExecStop = "${pkgs.docker}/bin/docker compose down";
      };
    };

    services.containerUpdates.units = [ "observability-stack.service" ];

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "observability-status" ''
        ${pkgs.systemd}/bin/systemctl --no-pager status observability-stack.service
        ${config.security.wrapperDir}/sudo ${pkgs.docker}/bin/docker compose \
          --env-file ${cfg.environmentFile} \
          --project-directory ${stateDirectory} ps
      '')
    ];
  };
}
