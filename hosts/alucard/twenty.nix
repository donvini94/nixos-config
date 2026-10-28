# Upstream compose: twentyhq/twenty twenty/v2.52.0, packages/twenty-docker/docker-compose.yml.
{
  config,
  lib,
  pkgs,
  site,
  ...
}:
let
  image = "twentycrm/twenty:v2.52.0@sha256:20b1010a975c42954d9f90698564795daf106da964bc95028836b09a8f424839";
  docker = "${pkgs.docker}/bin/docker --host=unix:///var/run/docker.sock";
  storage = "/app/packages/twenty-server/.local-storage";
  serve = pkgs.writeShellScript "twenty-private-https" ''
    ${lib.getExe config.services.tailscale.package} serve --yes --bg --https=23000 http://127.0.0.1:13000
  '';
  common = {
    inherit image;
    environmentFiles = [ config.sops.templates."twenty.env".path ];
    environment = {
      NODE_PORT = "3000";
      SERVER_URL = "https://${site.server}.${site.tailnet}:23000";
      REDIS_URL = "redis://twenty-redis:6379";
      STORAGE_TYPE = "local";
      IS_WORKSPACE_CREATION_LIMITED_TO_SERVER_ADMINS = "true";
      TELEMETRY_ENABLED = "false";
      IS_EMAIL_VERIFICATION_REQUIRED = "false";
      MESSAGING_PROVIDER_GMAIL_ENABLED = "false";
      MESSAGING_PROVIDER_MICROSOFT_ENABLED = "false";
      CALENDAR_PROVIDER_GOOGLE_ENABLED = "false";
      CALENDAR_PROVIDER_MICROSOFT_ENABLED = "false";
    };
    volumes = [ "twenty-files:${storage}" ];
    extraOptions = [
      "--network=twenty"
      "--memory=2g"
      "--memory-swap=2g"
      "--cpus=1.5"
      "--pids-limit=256"
    ];
    log-driver = "journald";
  };
in
{
  assertions = [
    {
      assertion =
        !(builtins.elem 13000 config.networking.firewall.allowedTCPPorts)
        && !(builtins.elem 23000 config.networking.firewall.allowedTCPPorts);
      message = "Twenty must remain loopback/tailnet-only";
    }
  ];

  sops.secrets =
    lib.genAttrs [ "twenty/database_password" "twenty/app_secret" "twenty/encryption_key" ]
      (_: {
        sopsFile = ../../secrets/twenty.yaml;
        mode = "0400";
      });
  sops.templates."twenty.env" = {
    mode = "0400";
    content = ''
      PG_DATABASE_URL=postgres://twenty:${
        config.sops.placeholder."twenty/database_password"
      }@twenty-db:5432/twenty
      APP_SECRET=${config.sops.placeholder."twenty/app_secret"}
      ENCRYPTION_KEY=${config.sops.placeholder."twenty/encryption_key"}
    '';
  };
  sops.templates."twenty-db.env" = {
    mode = "0400";
    content = "POSTGRES_PASSWORD=${config.sops.placeholder."twenty/database_password"}\n";
  };

  virtualisation.oci-containers.containers = {
    twenty-server = common // {
      dependsOn = [
        "twenty-db"
        "twenty-redis"
      ];
      ports = [ "127.0.0.1:13000:3000" ];
      # Docker publishes no ports for internal-only containers; the ingress network has NAT off, so no egress.
      extraOptions = common.extraOptions ++ [
        "--network=twenty-ingress"
        "--health-cmd=curl --fail http://localhost:3000/healthz"
        "--health-interval=15s"
        "--health-timeout=5s"
        "--health-retries=20"
        "--health-start-period=120s"
      ];
    };
    twenty-worker = common // {
      dependsOn = [ "twenty-server" ];
      cmd = [
        "yarn"
        "worker:prod"
      ];
      environment = common.environment // {
        DISABLE_DB_MIGRATIONS = "true";
        DISABLE_CRON_JOBS_REGISTRATION = "true";
      };
    };
    twenty-db = {
      image = "postgres:16.15@sha256:1beaa3084eee2676f20a9cd9928f0bf2c5bf674f8e49f81017912183d377c61c";
      environment = {
        POSTGRES_USER = "twenty";
        POSTGRES_DB = "twenty";
      };
      environmentFiles = [ config.sops.templates."twenty-db.env".path ];
      volumes = [ "twenty-db:/var/lib/postgresql/data" ];
      extraOptions = [
        "--network=twenty"
        "--memory=1g"
        "--memory-swap=1g"
        "--cpus=1"
        "--pids-limit=128"
        "--health-cmd=pg_isready -U twenty -d twenty"
        "--health-interval=5s"
        "--health-retries=20"
      ];
      log-driver = "journald";
    };
    twenty-redis = {
      image = "redis:7.4.12-alpine@sha256:338fbfc036dc5517ac0b04d6de21521085935336e565f223406180e9d84166e2";
      cmd = [
        "redis-server"
        "--maxmemory-policy"
        "noeviction"
        "--appendonly"
        "yes"
      ];
      volumes = [ "twenty-redis:/data" ];
      extraOptions = [
        "--network=twenty"
        "--memory=256m"
        "--memory-swap=256m"
        "--cpus=0.5"
        "--pids-limit=64"
        "--health-cmd=redis-cli ping"
        "--health-interval=5s"
        "--health-retries=20"
      ];
      log-driver = "journald";
    };
  };

  systemd.services = {
    twenty-network = {
      description = "Isolated Twenty Docker network";
      before = map (name: "docker-twenty-${name}.service") [
        "db"
        "redis"
        "server"
        "worker"
      ];
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${docker} network inspect twenty >/dev/null 2>&1 || ${docker} network create --internal twenty
        ${docker} network inspect twenty-ingress >/dev/null 2>&1 \
          || ${docker} network create -o com.docker.network.bridge.enable_ip_masquerade=false twenty-ingress
      '';
    };
    docker-twenty-db = {
      requires = [ "twenty-network.service" ];
      after = [ "twenty-network.service" ];
    };
    docker-twenty-redis = {
      requires = [ "twenty-network.service" ];
      after = [ "twenty-network.service" ];
    };
    docker-twenty-server.preStart = lib.mkAfter ''
      for i in $(seq 1 120); do
        if ${docker} exec twenty-db pg_isready -U twenty -d twenty && ${docker} exec twenty-redis redis-cli ping; then exit 0; fi
        sleep 2
      done
      exit 1
    '';
    docker-twenty-worker.preStart = lib.mkAfter ''
      for i in $(seq 1 180); do
        if ${docker} exec twenty-server curl --fail --silent http://localhost:3000/healthz >/dev/null; then exit 0; fi
        sleep 2
      done
      exit 1
    '';
    tailscale-private-services = {
      serviceConfig.ExecStartPost = [ serve ];
      restartTriggers = [ serve ];
    };
  };

  services.aiStack.backup.jobs.twenty = {
    runtimeInputs = [ pkgs.docker ];
    after = [
      "docker-twenty-server.service"
      "docker-twenty-worker.service"
    ];
    requires = [ "docker-twenty-db.service" ];
    prepare = "${pkgs.bash}/bin/bash ${./scripts/twenty-backup.sh} \"$stage\" ${
      config.sops.templates."twenty.env".path
    }";
  };
  # Exercise the new job and its verification shortly after initial activation, too.
  systemd.timers.restic-backups-twenty.timerConfig.OnActiveSec = "2min";
  systemd.timers.restic-check-twenty.timerConfig.OnActiveSec = "5min";
}
