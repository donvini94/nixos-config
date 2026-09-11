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
  stateDirectory = "/var/lib/n8n-container";
  dockerNetwork = "n8n-local";
  dockerBridge = "n8n-local0";
  dockerSubnet = "172.30.0.0/24";
  dockerGateway = "172.30.0.1";

  # Mirrors API_SERVER_PORT in lib/hermes-agent.nix: the proxy must target the port
  # Hermes listens on.
  hermesApiPort = 8642;

  hermesRouteProbe = ''
    hermes_status="$(${pkgs.docker}/bin/docker exec n8n node -e \
      'fetch("http://host.docker.internal:${toString hermesApiPort}/v1/models").then(r => process.stdout.write(String(r.status))).catch(() => process.exit(2))')"
    if [ "$hermes_status" != 401 ]; then
      echo "n8n-to-Hermes private route returned HTTP $hermes_status, expected authenticated rejection 401" >&2
      exit 1
    fi
  '';

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

    # Pinned by digest, readable version in front: n8n and its task runners speak a
    # versioned protocol and share one SQLite schema, so they must move together in a
    # reviewed commit. Renovate proposes digest bumps.
    #
    # docker.io, not the docker.n8n.io the upstream compose file advertises: that host
    # is a pull-through proxy whose 401 hands you back to auth.docker.io, so every
    # anonymous request is billed to the proxy's own egress IP and shares one rate-limit
    # bucket that sits at `x-ratelimit-remaining: 0`. That 429s the `manifests/<tag>`
    # fetch, leaving the digest unreadable to Renovate and cold `docker pull` broken.
    # Same repository either way: Hub returns byte-identical digests for both names.
    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/n8nio/n8n:2.39.4@sha256:5fa13ec66b5703f3ae0189eb979940baec35add43fa828e2313b1fe5190e7d25";
      description = "Digest-pinned official n8n OCI image.";
    };

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };

    encryptionKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "File containing the n8n credential-encryption key.";
    };

    runnerAuthTokenFile = lib.mkOption {
      type = lib.types.path;
      description = "File containing the task-runner authentication token.";
    };

    runnerEnvironmentFile = lib.mkOption {
      type = lib.types.path;
      description = "Root-only environment file containing the runner authentication token.";
    };

    # Workflows are host-specific: importing the whole tree on both hosts would install
    # workflows whose dependencies do not exist there (the delegate/inbox pair needs
    # Hermes as the shared team agent; the smoke test asserts Dracula's local model).
    workflowDirectory = lib.mkOption {
      type = lib.types.path;
      description = "Directory of reviewed workflow JSON installed by `n8n-workflows import`.";
    };

    orgOwner = lib.mkOption {
      type = lib.types.str;
      description = "User owning the shared Org tree; its `users` group gets write access.";
    };

    orgDirectory = lib.mkOption {
      type = lib.types.path;
      description = "Shared Org tree exposed read-write at /org.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.encryptionKeyFile != null;
        message = "services.localN8n.encryptionKeyFile must be configured";
      }
    ];

    virtualisation.oci-containers = {
      backend = "docker";
      containers = {
        n8n = {
          image = cfg.image;
          autoStart = false;
          pull = "missing";
          ports = [ "${cfg.bindAddress}:${toString port}:5678" ];
          networks = [ dockerNetwork ];
          volumes = [
            "${stateDirectory}:/home/node/.n8n"
            "${cfg.encryptionKeyFile}:/run/secrets/n8n_encryption_key:ro"
            "${cfg.runnerAuthTokenFile}:/run/secrets/n8n_runner_auth_token:ro"
            "${cfg.orgDirectory}:/org"
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
            N8N_RUNNERS_BROKER_LISTEN_ADDRESS = "0.0.0.0";
            N8N_RUNNERS_BROKER_PORT = "5679";
            N8N_RUNNERS_TASK_TIMEOUT = "300";

            N8N_BLOCK_ENV_ACCESS_IN_NODE = "true";
            N8N_RESTRICT_FILE_ACCESS_TO = "/org";
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
          # Tag must match `services.localN8n.image`; see the pinning note there.
          image = "docker.io/n8nio/runners:2.39.4@sha256:6af63a7b0c0cde47993f66e46307528be44f36135d9c7a0fb7cfa38798a85a2f";
          autoStart = false;
          pull = "missing";
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

    networking.firewall.interfaces.${dockerBridge}.allowedTCPPorts = [
      8080
      hermesApiPort
    ];

    systemd.tmpfiles.rules = [
      "d ${stateDirectory} 0750 1000 1000 -"
      "d ${cfg.orgDirectory} 2770 ${cfg.orgOwner} users -"
    ];

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

    # Hermes itself only listens on host loopback. This socket gives n8n a
    # route to that authenticated API without publishing it on a host NIC.
    systemd.sockets.n8n-hermes-api = {
      description = "Container-only socket for the Hermes agent API";
      wantedBy = [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      after = [ "n8n-docker-network.service" ];
      requires = [ "n8n-docker-network.service" ];
      unitConfig.DefaultDependencies = false;
      listenStreams = [ "${dockerGateway}:${toString hermesApiPort}" ];
    };

    systemd.services.n8n-hermes-api = {
      description = "Proxy n8n container traffic to the Hermes agent API";
      partOf = [ "ai-stack.target" ];
      after = [ "hermes-agent.service" ];
      requires = [ "hermes-agent.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd 127.0.0.1:${toString hermesApiPort}";
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
      after = [ "n8n-docker-network.service" ];
      requires = [ "n8n-docker-network.service" ];
      serviceConfig = {
        TimeoutStartSec = lib.mkForce "600s";
        TimeoutStopSec = lib.mkForce "40s";
        SuccessExitStatus = [ 143 ];
        ExecStartPost = pkgs.writeShellScript "wait-for-container-n8n" ''
          healthy_samples=0
          for attempt in $(${pkgs.coreutils}/bin/seq 1 600); do
            container_running="$(${pkgs.docker}/bin/docker inspect --format '{{.State.Running}}' n8n 2>/dev/null || true)"
            # Docker can spend substantial time pulling before it creates the container
            # object; an absent object is not a failed container, and the main docker-run
            # process stays authoritative.
            if [ "$container_running" = false ]; then
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
                ${pkgs.docker}/bin/docker exec n8n sh -c \
                  'probe=/org/.n8n-write-probe; : > "$probe"; rm "$probe"'
                ${hermesRouteProbe}
                exit 0
              fi
            else
              healthy_samples=0
            fi
            ${pkgs.coreutils}/bin/sleep 1
          done
          echo "n8n did not become healthy within 600 seconds" >&2
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
      (pkgs.writeShellScriptBin "n8n-workflows" ''
        export PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.docker
            pkgs.findutils
            pkgs.gnugrep
            pkgs.jq
          ]
        }:"$PATH"
        # The n8n container belongs to the system daemon; an operator's rootless
        # DOCKER_HOST (Alucard has one) would make this tool report it as missing.
        export DOCKER_HOST=unix:///run/docker.sock
        export N8N_WORKFLOW_DIR=${cfg.workflowDirectory}
        exec ${pkgs.bash}/bin/bash ${../n8n/bin/n8n-workflows} "$@"
      '')
    ];
  };
}
