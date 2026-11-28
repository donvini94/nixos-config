# Upstream compose: Infisical/infisical docker-compose.prod.yml. Tailnet-only; the backend
# has no internet egress (only this host's mailcow), so app connections and secret syncs to
# outside services are unavailable.
{
  config,
  lib,
  pkgs,
  site,
  ...
}:
let
  docker = "${pkgs.docker}/bin/docker --host=unix:///var/run/docker.sock";
  serve = pkgs.writeShellScript "infisical-private-https" ''
    ${lib.getExe config.services.tailscale.package} serve --yes --bg --https=28200 http://127.0.0.1:18200
  '';
  limits = memory: cpus: pids: [
    "--network=infisical"
    "--memory=${memory}"
    "--memory-swap=${memory}"
    "--cpus=${cpus}"
    "--pids-limit=${pids}"
  ];
in
{
  assertions = [
    {
      assertion =
        !(builtins.elem 18200 config.networking.firewall.allowedTCPPorts)
        && !(builtins.elem 28200 config.networking.firewall.allowedTCPPorts);
      message = "Infisical must remain loopback/tailnet-only";
    }
  ];

  sops.secrets =
    lib.genAttrs [ "infisical/database_password" "infisical/encryption_key" "infisical/auth_secret" ]
      (_: {
        sopsFile = ../../secrets/infisical.yaml;
        mode = "0400";
      });
  sops.templates."infisical.env" = {
    mode = "0400";
    content = ''
      DB_CONNECTION_URI=postgres://infisical:${
        config.sops.placeholder."infisical/database_password"
      }@infisical-db:5432/infisical
      ENCRYPTION_KEY=${config.sops.placeholder."infisical/encryption_key"}
      AUTH_SECRET=${config.sops.placeholder."infisical/auth_secret"}
      SMTP_PASSWORD=${config.sops.placeholder."mail/noreply_password"}
    '';
  };
  sops.templates."infisical-db.env" = {
    mode = "0400";
    content = "POSTGRES_PASSWORD=${config.sops.placeholder."infisical/database_password"}\n";
  };

  virtualisation.oci-containers.containers = {
    infisical = {
      image = "infisical/infisical:v0.167.17@sha256:fe28c8eaa2147ffc670db01da5af13b0d8c475a94327928fcbd0cc417b576248";
      dependsOn = [
        "infisical-db"
        "infisical-redis"
      ];
      environmentFiles = [ config.sops.templates."infisical.env".path ];
      environment = {
        NODE_ENV = "production";
        SITE_URL = "https://${site.server}.${site.tailnet}:28200";
        REDIS_URL = "redis://infisical-redis:6379";
        TELEMETRY_ENABLED = "false";
        SMTP_HOST = "mail.${site.domains.secondary}";
        SMTP_PORT = "587";
        SMTP_USERNAME = "noreply@${site.domains.secondary}";
        SMTP_FROM_ADDRESS = "noreply@${site.domains.secondary}";
      };
      ports = [ "127.0.0.1:18200:8080" ];
      # NAT-less ingress network: the published port works, the container gets no egress.
      extraOptions = limits "2g" "1.5" "256" ++ [ "--network=infisical-ingress" ];
      log-driver = "journald";
    };
    infisical-db = {
      image = "postgres:16.15@sha256:1beaa3084eee2676f20a9cd9928f0bf2c5bf674f8e49f81017912183d377c61c";
      environment = {
        POSTGRES_USER = "infisical";
        POSTGRES_DB = "infisical";
      };
      environmentFiles = [ config.sops.templates."infisical-db.env".path ];
      volumes = [ "infisical-db:/var/lib/postgresql/data" ];
      extraOptions = limits "1g" "1" "128";
      log-driver = "journald";
    };
    infisical-redis = {
      image = "redis:7.4.12-alpine@sha256:338fbfc036dc5517ac0b04d6de21521085935336e565f223406180e9d84166e2";
      volumes = [ "infisical-redis:/data" ];
      extraOptions = limits "256m" "0.5" "64";
      log-driver = "journald";
    };
  };

  systemd.services = {
    infisical-network = {
      description = "Isolated Infisical Docker network";
      before = map (name: "docker-${name}.service") [
        "infisical"
        "infisical-db"
        "infisical-redis"
      ];
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${docker} network inspect infisical >/dev/null 2>&1 || ${docker} network create --internal infisical
        ${docker} network inspect infisical-ingress >/dev/null 2>&1 \
          || ${docker} network create -o com.docker.network.bridge.enable_ip_masquerade=false infisical-ingress
      '';
    };
    docker-infisical-db = {
      requires = [ "infisical-network.service" ];
      after = [ "infisical-network.service" ];
    };
    docker-infisical-redis = {
      requires = [ "infisical-network.service" ];
      after = [ "infisical-network.service" ];
    };
    # Migrations run at backend start and fail if Postgres is still initialising.
    docker-infisical.preStart = lib.mkAfter ''
      for i in $(seq 1 120); do
        if ${docker} exec infisical-db pg_isready -U infisical -d infisical; then exit 0; fi
        sleep 2
      done
      exit 1
    '';
    tailscale-private-services = {
      serviceConfig.ExecStartPost = [ serve ];
      restartTriggers = [ serve ];
    };
  };

  # Redis holds only queues and caches. The env file carries ENCRYPTION_KEY, without
  # which the dump is unreadable.
  services.aiStack.backup.jobs.infisical = {
    runtimeInputs = [ pkgs.docker ];
    requires = [ "docker-infisical-db.service" ];
    prepare = ''
      export DOCKER_HOST=unix:///var/run/docker.sock
      docker exec infisical-db pg_dump -U infisical -d infisical --format=custom --no-owner > "$stage/infisical.dump"
      test -s "$stage/infisical.dump"
      docker exec -i infisical-db pg_restore --list < "$stage/infisical.dump" >/dev/null
      install -m 0600 ${config.sops.templates."infisical.env".path} "$stage/infisical.env"
    '';
  };
}
