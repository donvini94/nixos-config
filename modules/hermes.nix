{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.localHermes;
  hermesHome = "${cfg.stateDirectory}/.hermes";
  composeDirectory = "${cfg.stateDirectory}/compose";
  initialConfig = pkgs.writeText "hermes-config.json" (builtins.toJSON {
    database.journal_mode = "wal";
    providers."stack-ingress" = {
      api = cfg.ingressUrl;
      default_model = cfg.model;
      transport = "chat_completions";
      discover_models = true;
      extra_headers.X-AI-Caller = "hermes";
      models."${cfg.model}".context_length = cfg.contextLength;
    };
    model = {
      default = cfg.model;
      provider = "custom:stack-ingress";
      base_url = cfg.ingressUrl;
      context_length = cfg.contextLength;
      default_headers.X-AI-Caller = "hermes";
    };
    terminal = {
      backend = "local";
      cwd = "/workspace";
      home_mode = "profile";
      timeout = 300;
    };
    platform_toolsets.cli = [
      "terminal"
      "file"
      "skills"
      "todo"
      "memory"
      "session_search"
      "cronjob"
    ];
    agent.disabled_toolsets = [
      "web"
      "browser"
      "vision"
      "image_gen"
      "tts"
    ];
    approvals = {
      mode = "manual";
      timeout = 300;
      cron_mode = "deny";
      mcp_reload_confirm = true;
      destructive_slash_confirm = true;
      deny = [
        "git push*"
        "*curl*|*sh*"
        "*wget*|*sh*"
      ];
    };
    onboarding.profile_build = "off";
    dashboard.show_token_analytics = true;
  });
  prepare = pkgs.writeShellScript "hermes-container-prepare" ''
    set -euo pipefail
    ${pkgs.coreutils}/bin/install -d -m 2770 -o hermes -g hermes \
      ${cfg.stateDirectory} ${hermesHome} ${cfg.workspace}
    ${pkgs.coreutils}/bin/install -d -m 2770 \
      -o ${builtins.head cfg.operators} -g users ${cfg.orgDirectory}
    # Both containers use host-aligned numeric UIDs. ACLs grant Hermes access
    # without making the Org tree world-writable and are inherited by new files.
    ${pkgs.acl}/bin/setfacl -R -m \
      u:hermes:rwX,d:u:hermes:rwx ${cfg.orgDirectory}
    ${pkgs.coreutils}/bin/install -d -m 0750 -o root -g root ${composeDirectory}
    ${pkgs.coreutils}/bin/chown hermes:hermes ${hermesHome} ${cfg.workspace}
    ${pkgs.coreutils}/bin/chmod 2770 ${hermesHome} ${cfg.workspace}
    ${pkgs.coreutils}/bin/rm -f ${hermesHome}/.managed

    if [ ! -s ${hermesHome}/config.yaml ]; then
      ${pkgs.coreutils}/bin/install -o hermes -g hermes -m 0640 \
        ${initialConfig} ${hermesHome}/config.yaml
    fi
    ${pkgs.coreutils}/bin/install -o hermes -g hermes -m 0640 \
      ${../hermes/workspace/AGENTS.md} ${cfg.workspace}/AGENTS.md
    ${pkgs.coreutils}/bin/install -o hermes -g hermes -m 0640 \
      ${../hermes/workspace/SOUL.md} ${cfg.workspace}/SOUL.md
    ${pkgs.coreutils}/bin/install -m 0644 ${../hermes/docker-compose.yml} \
      ${composeDirectory}/docker-compose.yml
    HERMES_UID="$(${pkgs.coreutils}/bin/id -u hermes)"
    HERMES_GID="$(${pkgs.coreutils}/bin/id -g hermes)"
    ${pkgs.coreutils}/bin/printf 'HERMES_UID=%s\nHERMES_GID=%s\n' \
      "$HERMES_UID" "$HERMES_GID" > ${composeDirectory}/.env
    ${pkgs.coreutils}/bin/chmod 0600 ${composeDirectory}/.env

    if [ ! -d ${cfg.workspace}/.git ]; then
      ${pkgs.util-linux}/bin/runuser -u hermes -- \
        ${pkgs.git}/bin/git -C ${cfg.workspace} init --initial-branch=main
      ${pkgs.util-linux}/bin/runuser -u hermes -- \
        ${pkgs.git}/bin/git -C ${cfg.workspace} config user.name "Hermes Agent"
      ${pkgs.util-linux}/bin/runuser -u hermes -- \
        ${pkgs.git}/bin/git -C ${cfg.workspace} config user.email "hermes@localhost"
      ${pkgs.util-linux}/bin/runuser -u hermes -- \
        ${pkgs.git}/bin/git -C ${cfg.workspace} add --all
      ${pkgs.util-linux}/bin/runuser -u hermes -- \
        ${pkgs.git}/bin/git -C ${cfg.workspace} commit --allow-empty \
          --message "chore: initialize Hermes sandbox"
    fi
  '';
  verifyApi = pkgs.writeShellScript "hermes-container-verify-api" ''
    set -euo pipefail
    auth_config="$RUNTIME_DIRECTORY/api-auth.conf"
    trap '${pkgs.coreutils}/bin/rm -f "$auth_config"' EXIT
    umask 077
    ${pkgs.coreutils}/bin/printf 'header = "Authorization: Bearer %s"\n' \
      "$API_SERVER_KEY" > "$auth_config"
    for _ in $(${pkgs.coreutils}/bin/seq 1 120); do
      if ${pkgs.curl}/bin/curl --config "$auth_config" --fail --silent \
        --max-time 2 http://127.0.0.1:${toString cfg.apiServer.port}/v1/models \
        >/dev/null; then
        ${pkgs.docker}/bin/docker exec \
          --user "$(${pkgs.coreutils}/bin/id -u hermes):$(${pkgs.coreutils}/bin/id -g hermes)" \
          hermes-agent sh -c \
          'probe=/org/.hermes-write-probe; : > "$probe"; rm "$probe"'
        exit 0
      fi
      ${pkgs.coreutils}/bin/sleep 1
    done
    echo "Hermes API did not become ready within 120 seconds" >&2
    exit 1
  '';
  dockerHermes = pkgs.writeShellApplication {
    name = "hermes-admin";
    runtimeInputs = [ pkgs.docker ];
    text = ''
      tty=()
      if [ -t 0 ] && [ -t 1 ]; then tty=(-t); fi
      exec docker exec -i "''${tty[@]}" --workdir /workspace hermes-agent hermes "$@"
    '';
  };
  dockerHermesTui = pkgs.writeShellApplication {
    name = "hermes-tui";
    runtimeInputs = [ pkgs.docker ];
    text = ''
      exec docker exec -it --workdir /workspace hermes-agent hermes --tui "$@"
    '';
  };
in
{
  options.services.localHermes = {
    enable = lib.mkEnableOption "official containerized Hermes Agent";
    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/nousresearch/hermes-agent:latest";
      description = "Official rolling Hermes image; the deployed digest is retained by Docker for rollback.";
    };
    model = lib.mkOption {
      type = lib.types.str;
      default = "qwen3.6-27b-local";
    };
    contextLength = lib.mkOption {
      type = lib.types.ints.positive;
      default = 65536;
    };
    ingressUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8080/v1";
    };
    proxyUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/hermes";
    };
    workspace = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.stateDirectory}/workspace";
    };
    orgDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/ai-org";
      description = "Shared Org tree exposed read-write at /org.";
    };
    apiServer = {
      enable = lib.mkEnableOption "the authenticated Hermes agent API for private automation";
      bindAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8642;
      };
    };
    dashboard = {
      enable = lib.mkEnableOption "Hermes dashboard in the gateway container" // {
        default = true;
      };
      bindAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 9119;
      };
      environmentFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
      };
    };
    operators = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.contextLength >= 64000;
        message = "services.localHermes.contextLength must be at least 64,000";
      }
      {
        assertion = cfg.dashboard.bindAddress == "127.0.0.1";
        message = "Hermes must remain loopback-only; use Tailscale Serve";
      }
      {
        assertion = cfg.operators != [ ];
        message = "services.localHermes.operators must not be empty";
      }
      {
        assertion = lib.hasPrefix "/" cfg.orgDirectory;
        message = "services.localHermes.orgDirectory must be an absolute path";
      }
      {
        assertion = !cfg.apiServer.enable || cfg.apiServer.bindAddress == "127.0.0.1";
        message = "Hermes automation API must remain loopback-only; n8n uses its private bridge proxy";
      }
      {
        assertion = !cfg.apiServer.enable || cfg.dashboard.environmentFile != null;
        message = "Hermes API requires an EnvironmentFile containing API_SERVER_KEY";
      }
    ];

    virtualisation.docker.enable = true;
    users.groups.hermes = { };
    users.users =
      lib.genAttrs cfg.operators (_: {
        extraGroups = [ "hermes" ];
      })
      // {
        hermes = {
          isSystemUser = true;
          group = "hermes";
          home = cfg.stateDirectory;
        };
      };

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDirectory} 2770 hermes hermes - -"
      "d ${hermesHome} 2770 hermes hermes - -"
      "d ${cfg.workspace} 2770 hermes hermes - -"
      "d ${cfg.orgDirectory} 2770 ${builtins.head cfg.operators} users - -"
      "d ${composeDirectory} 0750 root root - -"
    ];

    systemd.services.hermes-agent = {
      description = "Official Hermes Agent container";
      wantedBy = [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      after = [
        "docker.service"
        "local-llama-logger.service"
      ]
      ++ lib.optional (cfg.proxyUrl != null) "tinyproxy.service";
      requires = [
        "docker.service"
        "local-llama-logger.service"
      ];
      wants = lib.optional (cfg.proxyUrl != null) "tinyproxy.service";
      environment = {
        HERMES_IMAGE = cfg.image;
        HERMES_STATE = hermesHome;
        HERMES_WORKSPACE = cfg.workspace;
        HERMES_ORG = cfg.orgDirectory;
        HERMES_DASHBOARD_ENABLED = if cfg.dashboard.enable then "1" else "0";
        HERMES_DASHBOARD_HOST = cfg.dashboard.bindAddress;
        HERMES_DASHBOARD_PORT = toString cfg.dashboard.port;
        HERMES_API_SERVER_ENABLED = if cfg.apiServer.enable then "true" else "false";
        HERMES_API_SERVER_HOST = cfg.apiServer.bindAddress;
        HERMES_API_SERVER_PORT = toString cfg.apiServer.port;
        HERMES_PROXY_URL = if cfg.proxyUrl == null then "" else cfg.proxyUrl;
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = composeDirectory;
        TimeoutStartSec = "30min";
        TimeoutStopSec = "5min";
        ExecStartPre = [ prepare ];
        ExecStart = "${pkgs.docker}/bin/docker compose up -d --pull always --remove-orphans --wait";
        ExecStop = "${pkgs.docker}/bin/docker compose down";
      }
      // lib.optionalAttrs cfg.apiServer.enable {
        RuntimeDirectory = "hermes-agent-verify";
        RuntimeDirectoryMode = "0700";
        ExecStartPost = verifyApi;
      }
      // lib.optionalAttrs (cfg.dashboard.environmentFile != null) {
        EnvironmentFile = cfg.dashboard.environmentFile;
      };
    };

    services.containerUpdates.units = [ "hermes-agent.service" ];
    environment.systemPackages = [
      dockerHermes
      dockerHermesTui
    ];
  };
}
