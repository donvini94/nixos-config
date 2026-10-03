# A single n8n container on the host network, backed by the host's PostgreSQL: it must
# reach Hermes and the database on loopback, and nothing but Tailscale Serve exposes it. Code nodes run in a second
# container (n8n's external task runner) that reaches the broker on loopback.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.localN8n;
  port = 5678;
  n8nUrl = "http://${cfg.bindAddress}:${toString port}";
  executionRetentionHours = 2160;
  inherit (cfg) stateDirectory;
in
{
  options.services.localN8n = {
    enable = lib.mkEnableOption "local n8n workflow service";

    # Update n8n and the runners together; their versions must match.
    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/n8nio/n8n:2.41.6@sha256:87e0bab2c93192e8dd885ff7b0697c22a1bd97489568a8c67cc140fd7dbb342d";
      description = "Digest-pinned official n8n OCI image.";
    };

    runnersImage = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/n8nio/runners:2.41.6@sha256:443eaee69319997627e2129ed8d512c4f4ea2418a744393cf26e843237399299";
      description = "Digest-pinned official task-runner image; must match `image`.";
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/n8n-container";
      description = "Persistent n8n state, also used by backups.";
    };

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };

    encryptionKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "File containing the n8n credential-encryption key.";
    };

    databasePasswordFile = lib.mkOption {
      type = lib.types.path;
      description = "File containing the password of the `n8n` PostgreSQL role.";
    };

    runnerAuthTokenFile = lib.mkOption {
      type = lib.types.path;
      description = "File containing the task-runner authentication token.";
    };

    runnerEnvironmentFile = lib.mkOption {
      type = lib.types.path;
      description = "Root-only environment file defining N8N_RUNNERS_AUTH_TOKEN.";
    };

    sharedMount = lib.mkOption {
      type = lib.types.nullOr (import ./shared-mount.nix lib);
      default = null;
      description = "Host directory shared read-write with n8n; also the only place file nodes may touch.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers = {
      backend = "docker";
      containers.n8n = {
        image = cfg.image;
        autoStart = false;
        pull = "missing";
        volumes = [
          "${stateDirectory}:/home/node/.n8n"
          "${cfg.encryptionKeyFile}:/run/secrets/n8n_encryption_key:ro"
          "${cfg.runnerAuthTokenFile}:/run/secrets/n8n_runner_auth_token:ro"
          "${cfg.databasePasswordFile}:/run/secrets/n8n_db_password:ro"
        ]
        ++ lib.optional (
          cfg.sharedMount != null
        ) "${cfg.sharedMount.hostPath}:${cfg.sharedMount.mountPoint}";
        environment = {
          N8N_LISTEN_ADDRESS = cfg.bindAddress;
          N8N_HOST = cfg.bindAddress;
          N8N_PORT = toString port;
          N8N_PROTOCOL = "http";
          N8N_EDITOR_BASE_URL = n8nUrl;
          N8N_SECURE_COOKIE = "false";

          N8N_ENCRYPTION_KEY_FILE = "/run/secrets/n8n_encryption_key";
          N8N_RUNNERS_AUTH_TOKEN_FILE = "/run/secrets/n8n_runner_auth_token";
          DB_TYPE = "postgresdb";
          DB_POSTGRESDB_HOST = "127.0.0.1";
          DB_POSTGRESDB_PORT = "5432";
          DB_POSTGRESDB_DATABASE = "n8n";
          DB_POSTGRESDB_USER = "n8n";
          DB_POSTGRESDB_PASSWORD_FILE = "/run/secrets/n8n_db_password";

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
          EXECUTIONS_DATA_MAX_AGE = toString executionRetentionHours;
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
          N8N_RUNNERS_BROKER_LISTEN_ADDRESS = cfg.bindAddress;
          N8N_RUNNERS_BROKER_PORT = "5679";
          N8N_RUNNERS_TASK_TIMEOUT = "300";

          N8N_BLOCK_ENV_ACCESS_IN_NODE = "true";
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
        }
        // lib.optionalAttrs (cfg.sharedMount != null) {
          N8N_RESTRICT_FILE_ACCESS_TO = cfg.sharedMount.mountPoint;
        };
        extraOptions = [
          "--network=host"
          "--read-only"
          "--security-opt=no-new-privileges:true"
          "--cap-drop=ALL"
          "--pids-limit=512"
          "--tmpfs=/tmp:rw,nosuid,size=512m"
          "--tmpfs=/home/node/.cache:rw,nosuid,size=128m"
        ];
      };

      containers.n8n-runners = {
        image = cfg.runnersImage;
        autoStart = false;
        pull = "missing";
        dependsOn = [ "n8n" ];
        environmentFiles = [ cfg.runnerEnvironmentFile ];
        environment = {
          N8N_RUNNERS_TASK_BROKER_URI = "http://${cfg.bindAddress}:5679";
          N8N_RUNNERS_AUTO_SHUTDOWN_TIMEOUT = "15";
          N8N_RUNNERS_TASK_TIMEOUT = "300";
        };
        extraOptions = [
          "--network=host"
          "--read-only"
          "--security-opt=no-new-privileges:true"
          "--cap-drop=ALL"
          "--pids-limit=512"
          "--tmpfs=/tmp:rw,nosuid,size=512m"
        ];
      };
    };

    systemd.tmpfiles.rules = [
      "d ${stateDirectory} 0750 1000 1000 -"
    ];

    systemd.services.docker-n8n-runners = {
      wantedBy = lib.mkForce [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      serviceConfig = {
        TimeoutStopSec = lib.mkForce "10s";
        SuccessExitStatus = [ 143 ];
      };
    };

    warnings = lib.optional (lib.versionOlder config.services.postgresql.package.version "17") "n8n supports PostgreSQL 17 and newer; this host runs ${config.services.postgresql.package.version}.";

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "n8n" ];
      ensureUsers = [
        {
          name = "n8n";
          ensureDBOwnership = true;
        }
      ];
    };

    # ensureUsers creates the role without a password; n8n authenticates over loopback.
    systemd.services.n8n-database-password = {
      description = "Set the n8n PostgreSQL role's password";
      # postgresql-setup creates the role from ensureUsers.
      after = [ "postgresql-setup.service" ];
      requires = [ "postgresql-setup.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [
        config.services.postgresql.package
        pkgs.util-linux
      ];
      script = ''
        password=$(< ${lib.escapeShellArg cfg.databasePasswordFile})
        # Interpolated into SQL, so only characters that need no quoting are accepted.
        if [[ ! $password =~ ^[A-Za-z0-9]{24,}$ ]]; then
          echo "n8n/db_password must be at least 24 letters or digits" >&2
          exit 1
        fi
        echo "ALTER ROLE n8n WITH LOGIN PASSWORD '$password';" \
          | runuser -u postgres -- psql --quiet --set=ON_ERROR_STOP=1 >/dev/null
      '';
    };

    systemd.services.docker-n8n = {
      after = [ "n8n-database-password.service" ];
      requires = [ "n8n-database-password.service" ];
      wantedBy = lib.mkForce [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      serviceConfig = {
        TimeoutStartSec = lib.mkForce "600s";
        TimeoutStopSec = lib.mkForce "40s";
        SuccessExitStatus = [ 143 ];
        ExecStartPost = pkgs.writeShellScript "wait-for-container-n8n" ''
          for _ in $(${pkgs.coreutils}/bin/seq 1 600); do
            if ${pkgs.curl}/bin/curl --fail --silent --max-time 1 ${n8nUrl}/healthz/readiness >/dev/null; then
              exit 0
            fi
            ${pkgs.coreutils}/bin/sleep 1
          done
          echo "n8n did not become healthy within 600 seconds" >&2
          exit 1
        '';
      };
    };
  };
}
