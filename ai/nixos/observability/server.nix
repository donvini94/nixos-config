# Central monitoring: Prometheus, Grafana and alerting for the fleet. Backends stay on
# loopback; the host publishes them through Tailscale Serve.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.observability.server;
  exporters = config.services.observability.exporters;
  ports = import ./ports.nix;
  loopback = "127.0.0.1";
  alertmanagerPort = 19093;
  scrape = job_name: targets: {
    inherit job_name;
    static_configs = targets;
  };
  target = host: address: {
    targets = [ address ];
    labels = { inherit host; };
  };
  # Every host's exporters, this one's included when it runs them.
  nodeTargets =
    lib.optional exporters.enable (target cfg.hostLabel "${loopback}:${toString ports.node}")
    ++ lib.mapAttrsToList (name: host: target name "${host.address}:${toString ports.node}") cfg.hosts;
  containerTargets =
    lib.optional (exporters.enable && exporters.containerMetrics) (
      target cfg.hostLabel "${loopback}:${toString ports.cadvisor}"
    )
    ++ lib.mapAttrsToList (name: host: target name "${host.address}:${toString ports.cadvisor}") (
      lib.filterAttrs (_: host: host.containerMetrics) cfg.hosts
    );
in
{
  options.services.observability.server = {
    enable = lib.mkEnableOption "central Prometheus, Grafana and alerting";

    secretsFile = lib.mkOption {
      type = lib.types.path;
      description = "SOPS file holding `grafana/admin_password` and `grafana/secret_key`.";
    };

    hostLabel = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "Host label for this machine's own series.";
    };

    hosts = lib.mkOption {
      default = { };
      description = "Other hosts whose exporters are scraped over the tailnet, keyed by host label.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            address = lib.mkOption {
              type = lib.types.str;
              description = "Tailnet name or address of the host.";
            };
            containerMetrics = lib.mkOption {
              type = lib.types.bool;
              default = true;
            };
          };
        }
      );
    };

    localTargets = lib.mkOption {
      type = lib.types.attrsOf lib.types.port;
      default = { };
      description = "Loopback scrape jobs for services on this host, keyed by job name.";
    };

    grafanaPort = lib.mkOption {
      type = lib.types.port;
      default = 13001;
    };

    prometheusPort = lib.mkOption {
      type = lib.types.port;
      default = 19091;
    };

    alerting.telegram = lib.mkOption {
      default = null;
      description = "Telegram delivery for alerts; null leaves alerts visible in Prometheus only.";
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            botTokenFile = lib.mkOption {
              type = lib.types.str;
              description = "File holding the bot token.";
            };
            chatId = lib.mkOption {
              type = lib.types.int;
              description = "Chat that receives alerts.";
            };
          };
        }
      );
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = lib.genAttrs [ "grafana/admin_password" "grafana/secret_key" ] (_: {
      sopsFile = cfg.secretsFile;
      owner = "grafana";
      mode = "0400";
    });

    services.prometheus = {
      enable = true;
      listenAddress = loopback;
      port = cfg.prometheusPort;
      retentionTime = "90d";
      extraFlags = [ "--storage.tsdb.retention.size=20GB" ];
      globalConfig = {
        scrape_interval = "15s";
        evaluation_interval = "15s";
      };
      ruleFiles = [ ((pkgs.formats.yaml { }).generate "alerts.yml" (import ./alerts.nix)) ];
      scrapeConfigs = [
        (scrape "prometheus" [ (target cfg.hostLabel "${loopback}:${toString cfg.prometheusPort}") ])
      ]
      ++ lib.optional (nodeTargets != [ ]) (scrape "node" nodeTargets)
      ++ lib.optional (containerTargets != [ ]) (scrape "containers" containerTargets)
      ++ lib.mapAttrsToList (
        job: port: scrape job [ (target cfg.hostLabel "${loopback}:${toString port}") ]
      ) cfg.localTargets;
      alertmanagers = lib.optional (cfg.alerting.telegram != null) {
        static_configs = [ { targets = [ "${loopback}:${toString alertmanagerPort}" ]; } ];
      };
      alertmanager = lib.mkIf (cfg.alerting.telegram != null) {
        enable = true;
        listenAddress = loopback;
        port = alertmanagerPort;
        configuration = {
          route.receiver = "telegram";
          receivers = [
            {
              name = "telegram";
              telegram_configs = [
                {
                  bot_token_file = cfg.alerting.telegram.botTokenFile;
                  chat_id = cfg.alerting.telegram.chatId;
                  send_resolved = true;
                }
              ];
            }
          ];
        };
      };
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
  };
}
