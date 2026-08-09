{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.localN8n;
  n8nUrl = "http://${cfg.bindAddress}:${toString cfg.port}";
  orgWriterGroup = "n8n-org-writers";
  stateDirectory = "/var/lib/n8n-container";
  nativeStateDirectory = "/var/lib/private/n8n/.n8n";
  dockerNetwork = "n8n-local";
  dockerBridge = "n8n-local0";
  dockerSubnet = "172.30.0.0/24";
  dockerGateway = "172.30.0.1";

  containerHardening = [
    "--read-only"
    "--security-opt=no-new-privileges:true"
    "--cap-drop=ALL"
    "--pids-limit=512"
  ];
in
{
  options.services.localN8n = {
    enable = lib.mkEnableOption "local n8n workflow service";

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.n8n.io/n8nio/n8n:latest";
      description = "Rolling official n8n OCI image.";
    };

    runnerImage = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/n8nio/runners:latest";
      description = "Rolling official n8n task-runner OCI image.";
    };

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5678;
    };

    encryptionKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "File containing the n8n credential-encryption key.";
    };

    runnerAuthTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "File containing the task-runner authentication token.";
    };

    runnerEnvironmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Root-only environment file containing the runner authentication token.";
    };

    operators = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users allowed to access n8n-created org inbox entries.";
    };

    orgInbox = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/n8n/org-inbox";
      description = "Restricted output directory exposed to file-writing workflow nodes.";
    };

    executionRetentionHours = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2160;
      description = "Hours of completed n8n execution history to retain.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.encryptionKeyFile != null;
        message = "services.localN8n.encryptionKeyFile must be configured";
      }
      {
        assertion = cfg.runnerAuthTokenFile != null;
        message = "services.localN8n.runnerAuthTokenFile must be configured";
      }
      {
        assertion = cfg.runnerEnvironmentFile != null;
        message = "services.localN8n.runnerEnvironmentFile must be configured";
      }
      {
        assertion = lib.hasPrefix "/" cfg.orgInbox;
        message = "services.localN8n.orgInbox must be an absolute path";
      }
      {
        assertion = cfg.operators != [ ];
        message = "services.localN8n.operators must contain at least one user";
      }
    ];

    virtualisation.oci-containers = {
      backend = "docker";
      containers = {
        n8n = {
          image = cfg.image;
          autoStart = false;
          pull = "always";
          ports = [ "${cfg.bindAddress}:${toString cfg.port}:5678" ];
          networks = [ dockerNetwork ];
          volumes = [
            "${stateDirectory}:/home/node/.n8n"
            "${cfg.encryptionKeyFile}:/run/secrets/n8n_encryption_key:ro"
            "${cfg.runnerAuthTokenFile}:/run/secrets/n8n_runner_auth_token:ro"
            "${cfg.orgInbox}:/org-inbox"
          ];
          environment = {
            N8N_LISTEN_ADDRESS = "0.0.0.0";
            N8N_HOST = cfg.bindAddress;
            N8N_PORT = "5678";
            N8N_PROTOCOL = "http";
            N8N_EDITOR_BASE_URL = n8nUrl;
            N8N_SECURE_COOKIE = "false";

            N8N_ENCRYPTION_KEY_FILE = "/run/secrets/n8n_encryption_key";
            N8N_RUNNERS_AUTH_TOKEN_FILE = "/run/secrets/n8n_runner_auth_token";

            DB_TYPE = "sqlite";
            DB_SQLITE_POOL_SIZE = "4";
            DB_SQLITE_VACUUM_ON_STARTUP = "false";

            EXECUTIONS_MODE = "regular";
            EXECUTIONS_TIMEOUT = "1800";
            EXECUTIONS_TIMEOUT_MAX = "3600";
            N8N_AI_TIMEOUT_MAX = "1800000";
            N8N_CONCURRENCY_PRODUCTION_LIMIT = "2";
            EXECUTIONS_DATA_SAVE_ON_ERROR = "all";
            EXECUTIONS_DATA_SAVE_ON_SUCCESS = "all";
            EXECUTIONS_DATA_SAVE_ON_PROGRESS = "false";
            EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS = "true";
            EXECUTIONS_DATA_PRUNE = "true";
            EXECUTIONS_DATA_MAX_AGE = toString cfg.executionRetentionHours;
            EXECUTIONS_DATA_PRUNE_MAX_COUNT = "50000";
            N8N_DEFAULT_BINARY_DATA_MODE = "filesystem";

            N8N_METRICS = "true";
            N8N_METRICS_INCLUDE_DEFAULT_METRICS = "true";
            N8N_METRICS_INCLUDE_WORKFLOW_ID_LABEL = "true";
            N8N_METRICS_INCLUDE_WORKFLOW_NAME_LABEL = "true";
            N8N_METRICS_INCLUDE_NODE_TYPE_LABEL = "true";
            N8N_METRICS_INCLUDE_WORKFLOW_EXECUTION_DURATION = "true";
            N8N_METRICS_INCLUDE_WORKFLOW_STATISTICS = "true";
            N8N_METRICS_INCLUDE_EXECUTION_DATA_METRICS = "true";
            N8N_METRICS_INCLUDE_DB_POOL_METRICS = "true";

            N8N_RUNNERS_MODE = "external";
            N8N_RUNNERS_BROKER_LISTEN_ADDRESS = "0.0.0.0";
            N8N_RUNNERS_BROKER_PORT = "5679";
            N8N_RUNNERS_TASK_TIMEOUT = "300";

            N8N_BLOCK_ENV_ACCESS_IN_NODE = "true";
            N8N_RESTRICT_FILE_ACCESS_TO = "/org-inbox";
            N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS = "true";
            N8N_GIT_NODE_DISABLE_BARE_REPOS = "true";
            N8N_UNVERIFIED_PACKAGES_ENABLED = "false";
            N8N_COMPRESSION_NODE_MAX_DECOMPRESSED_SIZE_BYTES = "268435456";
            N8N_COMPRESSION_NODE_MAX_ZIP_ENTRIES = "1000";
            N8N_DIAGNOSTICS_ENABLED = "false";
            N8N_VERSION_NOTIFICATIONS_ENABLED = "false";
            N8N_PERSONALIZATION_ENABLED = "false";
            N8N_HIRING_BANNER_ENABLED = "false";
            N8N_TEMPLATES_ENABLED = "false";
            N8N_LOG_LEVEL = "info";
            N8N_LOG_OUTPUT = "console";
          };
          extraOptions = containerHardening ++ [
            "--tmpfs=/tmp:rw,nosuid,size=512m"
            "--tmpfs=/home/node/.cache:rw,nosuid,size=128m"
            "--add-host=host.docker.internal:${dockerGateway}"
          ];
        };

        n8n-runners = {
          image = cfg.runnerImage;
          autoStart = false;
          pull = "always";
          dependsOn = [ "n8n" ];
          networks = [ dockerNetwork ];
          environmentFiles = [ cfg.runnerEnvironmentFile ];
          environment = {
            N8N_RUNNERS_TASK_BROKER_URI = "http://n8n:5679";
            N8N_RUNNERS_AUTO_SHUTDOWN_TIMEOUT = "15";
            N8N_RUNNERS_TASK_TIMEOUT = "300";
          };
          extraOptions = containerHardening ++ [
            "--tmpfs=/tmp:rw,nosuid,size=512m"
          ];
        };
      };
    };

    users.groups.${orgWriterGroup} = { };
    users.users = lib.genAttrs cfg.operators (_: {
      extraGroups = [ orgWriterGroup ];
    });

    networking.firewall.interfaces.${dockerBridge}.allowedTCPPorts = [ 8080 ];

    systemd.tmpfiles.rules = [
      "d ${stateDirectory} 0750 1000 1000 -"
      "d ${cfg.orgInbox} 2770 ${builtins.head cfg.operators} ${orgWriterGroup} -"
    ];

    systemd.services.n8n-state-migrate = {
      description = "Migrate native n8n state to the official container layout";
      before = [ "docker-n8n.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -euo pipefail
        ${pkgs.coreutils}/bin/install -d -m 0750 -o 1000 -g 1000 ${stateDirectory}
        if [ ! -e ${stateDirectory}/database.sqlite ] \
          && [ -e ${nativeStateDirectory}/database.sqlite ]; then
          ${pkgs.coreutils}/bin/cp -a ${nativeStateDirectory}/. ${stateDirectory}/
          ${pkgs.coreutils}/bin/chown -R 1000:1000 ${stateDirectory}
          ${pkgs.coreutils}/bin/touch ${stateDirectory}/.migrated-from-native
        fi
        ${pkgs.coreutils}/bin/chmod 0750 ${stateDirectory}
      '';
    };

    systemd.services.n8n-docker-network = {
      description = "Private Docker network for n8n and its task runners";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      before = [
        "docker-n8n.service"
        "docker-n8n-runners.service"
        "n8n-ai-ingress.socket"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -euo pipefail
        if ! ${pkgs.docker}/bin/docker network inspect ${dockerNetwork} >/dev/null 2>&1; then
          ${pkgs.docker}/bin/docker network create \
            --driver bridge \
            --subnet ${dockerSubnet} \
            --gateway ${dockerGateway} \
            --opt com.docker.network.bridge.name=${dockerBridge} \
            ${dockerNetwork} >/dev/null
        fi
        subnet="$(${pkgs.docker}/bin/docker network inspect ${dockerNetwork} \
          --format '{{(index .IPAM.Config 0).Subnet}}')"
        gateway="$(${pkgs.docker}/bin/docker network inspect ${dockerNetwork} \
          --format '{{(index .IPAM.Config 0).Gateway}}')"
        bridge="$(${pkgs.docker}/bin/docker network inspect ${dockerNetwork} \
          --format '{{index .Options "com.docker.network.bridge.name"}}')"
        if [ "$subnet" != ${dockerSubnet} ] || [ "$gateway" != ${dockerGateway} ] || [ "$bridge" != ${dockerBridge} ]; then
          echo "Docker network ${dockerNetwork} has $subnet/$gateway on $bridge; expected ${dockerSubnet}/${dockerGateway} on ${dockerBridge}" >&2
          exit 1
        fi
      '';
    };

    systemd.sockets.n8n-ai-ingress = {
      description = "Container-only socket for the local AI ingress";
      wantedBy = [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      after = [ "n8n-docker-network.service" ];
      requires = [ "n8n-docker-network.service" ];
      # The Docker bridge is created by a service that starts after basic.target.
      # A socket's default Before=sockets.target ordering would otherwise make
      # activation cyclic: basic -> sockets -> this socket -> bridge -> basic.
      unitConfig.DefaultDependencies = false;
      listenStreams = [ "${dockerGateway}:8080" ];
    };

    systemd.services.n8n-ai-ingress = {
      description = "Proxy n8n container traffic to the loopback AI ingress";
      partOf = [ "ai-stack.target" ];
      after = [ "local-llama-logger.service" ];
      requires = [ "local-llama-logger.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd 127.0.0.1:8080";
        DynamicUser = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
      };
    };

    systemd.services.docker-n8n = {
      wantedBy = lib.mkForce [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      after = [
        "n8n-state-migrate.service"
        "n8n-docker-network.service"
      ];
      requires = [
        "n8n-state-migrate.service"
        "n8n-docker-network.service"
      ];
      serviceConfig = {
        TimeoutStartSec = lib.mkForce "180s";
        TimeoutStopSec = lib.mkForce "40s";
        SuccessExitStatus = [ 143 ];
        ExecStartPost = pkgs.writeShellScript "wait-for-container-n8n" ''
          healthy_samples=0
          for attempt in $(${pkgs.coreutils}/bin/seq 1 180); do
            container_running="$(${pkgs.docker}/bin/docker inspect --format '{{.State.Running}}' n8n 2>/dev/null || true)"
            if [ "$container_running" = false ] || { [ -z "$container_running" ] && [ "$attempt" -gt 5 ]; }; then
              echo "n8n container exited before becoming healthy" >&2
              exit 1
            fi
            if ${pkgs.curl}/bin/curl --fail --silent --max-time 1 ${n8nUrl}/healthz/readiness >/dev/null; then
              healthy_samples=$((healthy_samples + 1))
              if [ "$healthy_samples" -ge 3 ]; then
                journal_mode="$(${pkgs.sqlite}/bin/sqlite3 ${stateDirectory}/database.sqlite \
                  'PRAGMA journal_mode;')"
                if [ "$journal_mode" != wal ]; then
                  echo "n8n SQLite journal mode is '$journal_mode', expected 'wal'" >&2
                  exit 1
                fi
                exit 0
              fi
            else
              healthy_samples=0
            fi
            ${pkgs.coreutils}/bin/sleep 1
          done
          echo "n8n did not become healthy within 180 seconds" >&2
          exit 1
        '';
      };
    };

    systemd.services.docker-n8n-runners = {
      wantedBy = lib.mkForce [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      after = [
        "n8n-docker-network.service"
      ];
      requires = [
        "n8n-docker-network.service"
      ];
      serviceConfig = {
        TimeoutStopSec = lib.mkForce "10s";
        SuccessExitStatus = [ 143 ];
      };
    };

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "n8n-workflows-import" ''
        export PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.docker
            pkgs.findutils
            pkgs.gnugrep
            pkgs.jq
          ]
        }:"$PATH"
        export N8N_WORKFLOW_DIR=${../n8n/workflows}
        exec ${pkgs.bash}/bin/bash ${../n8n/bin/n8n-workflows-import} "$@"
      '')
      (pkgs.writeShellScriptBin "n8n-workflows-export" ''
        export PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.docker
            pkgs.findutils
            pkgs.gnugrep
            pkgs.jq
          ]
        }:"$PATH"
        exec ${pkgs.bash}/bin/bash ${../n8n/bin/n8n-workflows-export} "$@"
      '')
    ];
  };
}
