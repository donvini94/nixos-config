# docker-compose rather than services.prometheus/services.grafana on purpose: the stack
# shares one docker network with Hermes and n8n, tracks upstream Hermes releases directly,
# and ships as a unit to customer deployments. Porting it to native NixOS modules would
# cost all three.
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
  # Only real, writable mounts. /nix and /nix/store are bind mounts of / and would
  # alert three times for one full disk.
  watchedMounts = ''mountpoint=~"/|/home|/boot|/mnt/.*"'';
  ratioFree = ''node_filesystem_avail_bytes{${watchedMounts}} / node_filesystem_size_bytes{${watchedMounts}}'';
  alertRules = (pkgs.formats.yaml { }).generate "prometheus-alerts.yml" {
    groups = [
      {
        name = "storage";
        rules = [
          {
            alert = "FilesystemFillingUp";
            expr = "${ratioFree} < 0.10";
            for = "30m";
            labels.severity = "warning";
            annotations.summary = "{{ $labels.mountpoint }} is below 10% free ({{ $value | humanizePercentage }})";
          }
          {
            alert = "FilesystemAlmostFull";
            expr = "${ratioFree} < 0.03";
            for = "10m";
            labels.severity = "critical";
            annotations.summary = "{{ $labels.mountpoint }} is below 3% free ({{ $value | humanizePercentage }}); backups to it will start failing";
          }
        ];
      }
      {
        name = "security-scans";
        rules = [
          {
            # A scan that cannot read an image reports nothing for it, which looks
            # identical to a clean image on the dashboard. This is the alert that was
            # missing when ten rootless images failed for a night unnoticed.
            alert = "ContainerScanIncomplete";
            expr = "security_container_scan_failures > 0";
            for = "15m";
            labels.severity = "warning";
            annotations.summary = "{{ $value }} running image(s) could not be scanned; the vulnerability counts are incomplete";
          }
          {
            # Daily timer with up to 2h of jitter, so a legitimate gap never exceeds
            # ~26h. 36h means two runs were missed or the unit is failing outright.
            alert = "ContainerScanStale";
            expr = "time() - security_container_scan_timestamp_seconds > 36 * 3600";
            for = "30m";
            labels.severity = "warning";
            annotations.summary = "No container scan completed for {{ $value | humanizeDuration }}";
          }
          {
            # Weekly timer. Both staleness rules compare a published value rather than
            # using absent(), so they stay quiet until a scanner has run at least once.
            alert = "HostScanStale";
            expr = "time() - security_host_scan_timestamp_seconds > 9 * 24 * 3600";
            for = "30m";
            labels.severity = "warning";
            annotations.summary = "No host closure scan completed for {{ $value | humanizeDuration }}";
          }
        ];
      }
    ];
  };
  prometheusConfig = (pkgs.formats.yaml { }).generate "prometheus.yml" {
    global = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
      external_labels.host = cfg.hostLabel;
    };
    rule_files = [ "/etc/prometheus/alerts.yml" ];
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
  prepare = pkgs.writeShellApplication {
    name = "observability-prepare";
    runtimeInputs = [ pkgs.coreutils ];
    runtimeEnv = {
      OBSERVABILITY_STATE_DIR = stateDirectory;
      OBSERVABILITY_ASSETS = "${../observability}";
      OBSERVABILITY_PROMETHEUS_CONFIG = "${prometheusConfig}";
      OBSERVABILITY_PROMETHEUS_ALERTS = "${alertRules}";
    };
    text = builtins.readFile ../scripts/observability-prepare.sh;
  };
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
      # Official node-exporter runs unprivileged. This directory contains only
      # deliberately exported aggregate metrics; raw reports remain root-only.
      "d ${stateDirectory}/textfile 0755 root root -"
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
      # The compose mounts are bind mounts of files in the state dir, so a changed
      # prometheus.yml or alerts.yml is invisible to a running container. The restart
      # goes through `docker compose down`, which recreates it.
      restartTriggers = [
        prometheusConfig
        alertRules
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
        ExecStartPre = [ (lib.getExe prepare) ];
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
