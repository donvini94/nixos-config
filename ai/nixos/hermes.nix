# Upstream's published Hermes image, with its data directory as the only state. The
# dashboard, gateway and API server run in that one container; Nix pins the image and
# supplies secrets, mounts and loopback bindings. Settings, MCP servers and installed
# tools belong to the application and live in the data directory.
{
  config,
  lib,
  ...
}:

let
  cfg = config.services.hermesAgent;
  apiPort = 8642;
  dashboardPort = 9119;
in
{
  options.services.hermesAgent = {
    enable = lib.mkEnableOption "the Hermes agent container";

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/nousresearch/hermes-agent:v2026.9.24@sha256:fca358f12efd65bfaaca05884166f15c0e2788375ca30d77061ac1ebc96452b7";
      description = "Digest-pinned upstream Hermes image.";
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/hermes-agent";
      description = "Host directory mounted as the container's HERMES_HOME (/opt/data).";
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 10000;
      description = "Owner of the state directory; the image remaps its hermes user to it.";
    };

    gid = lib.mkOption {
      type = lib.types.int;
      default = 10000;
    };

    sharedMount = lib.mkOption {
      type = lib.types.nullOr (import ./shared-mount.nix lib);
      default = null;
      description = "Host directory shared read-write with the agent, which may also write there.";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Root-only env files supplying credentials; values saved in the UI override them.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.hermes.gid = cfg.gid;
    users.users.hermes = {
      isSystemUser = true;
      uid = cfg.uid;
      group = "hermes";
      home = cfg.stateDirectory;
    };

    systemd.tmpfiles.rules = [ "d ${cfg.stateDirectory} 0750 hermes hermes -" ];

    virtualisation.oci-containers.containers.hermes-agent = {
      image = cfg.image;
      autoStart = false;
      pull = "missing";
      cmd = [
        "gateway"
        "run"
      ];
      volumes = [
        "${cfg.stateDirectory}:/opt/data"
      ]
      ++ lib.optional (
        cfg.sharedMount != null
      ) "${cfg.sharedMount.hostPath}:${cfg.sharedMount.mountPoint}:rw";
      environmentFiles = cfg.environmentFiles;
      environment = {
        HERMES_UID = toString cfg.uid;
        HERMES_GID = toString cfg.gid;
        HERMES_DASHBOARD = "1";
        HERMES_DASHBOARD_HOST = "127.0.0.1";
        HERMES_DASHBOARD_PORT = toString dashboardPort;
        HERMES_DASHBOARD_TUI = "1";
        API_SERVER_ENABLED = "true";
        API_SERVER_HOST = "127.0.0.1";
        API_SERVER_PORT = toString apiPort;
        HERMES_WRITE_SAFE_ROOT = lib.concatStringsSep ":" (
          [ "/opt/data" ] ++ lib.optional (cfg.sharedMount != null) cfg.sharedMount.mountPoint
        );
      };
      # Host networking: n8n reaches the API on loopback and the dashboard is published
      # by Tailscale Serve. Both bind 127.0.0.1.
      extraOptions = [
        "--network=host"
        "--pids-limit=512"
        "--memory=8g"
      ];
    };

    systemd.services.docker-hermes-agent = {
      wantedBy = lib.mkForce [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      restartTriggers = cfg.environmentFiles;
    };
  };
}
