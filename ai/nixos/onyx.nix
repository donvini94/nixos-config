# Onyx (enterprise search and chat over the customer's sources) as upstream's Docker
# Compose deployment, pinned: the compose file comes from a fixed release, every image
# is pinned by digest here, and Nix renders the environment from options and sops.
# Upgrades follow upstream's release notes; bump the deployment and images together.
# The code interpreter is not run: upstream gives it the host's Docker socket as root.
# Files live in PostgreSQL rather than MinIO, whose images are no longer public.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  stack = config.services.aiStack;
  cfg = stack.features.onyx;
  deployment = pkgs.callPackage ../packages/onyx-deployment.nix { };
  images = {
    api_server = "docker.io/onyxdotapp/onyx-backend:v4.8.4@sha256:df7dbe02631587c9383ccdb07faa39a69f572e58eeb895f0df6ded9778b0aafd";
    background = images.api_server;
    web_server = "docker.io/onyxdotapp/onyx-web-server:v4.8.4@sha256:9a5049f57dae444fa0c7bacbea60174598af8d6e624579ff45a0bbd26975a030";
    inference_model_server = "docker.io/onyxdotapp/onyx-model-server:v4.8.4@sha256:2acf61ff814007071be9c941f09855df377c9ba411bfd356b11c92c479b47850";
    indexing_model_server = images.inference_model_server;
    relational_db = "docker.io/library/postgres:15.2-alpine@sha256:d9c304353c031b21e9a7e33dc4781e272a9fa802a2ab9703fe4199d72ba1422c";
    opensearch = "docker.io/opensearchproject/opensearch:3.6.0@sha256:b5dd1512af2a99748c942cfbbd7f32162623336b210667d0fc6333c6321f171d";
    nginx = "docker.io/library/nginx:1.25.5-alpine@sha256:516475cc129da42866742567714ddc681e5eed7b9ee0b9e9c015e464b4221a00";
    cache = "docker.io/library/redis:7.4-alpine@sha256:858f009f9709ce576febc734aa78b8f6d624b82571f9ddb6bda4377c833b3499";
  };
  onyxImages = [
    images.api_server
    images.web_server
    images.inference_model_server
  ];
  override = pkgs.writeText "onyx-override.yml" (
    "services:\n"
    + lib.concatStrings (
      lib.mapAttrsToList (service: image: "  ${service}:\n    image: ${image}\n") (
        removeAttrs images [ "nginx" ]
      )
    )
    + lib.concatStringsSep "\n" [
      "  nginx:"
      "    image: ${images.nginx}"
      "    ports: !override"
      "      - \"127.0.0.1:${toString cfg.port}:80\""
      "  code-interpreter:"
      "    profiles: [ \"disabled\" ]"
      ""
    ]
  );
  directory = "/var/lib/onyx";
  compose = "${lib.getExe pkgs.docker-compose} --project-name onyx --file ${directory}/docker_compose/docker-compose.yml --file ${override}";
  secret = name: config.sops.placeholder."onyx/${name}";
in
{
  options.services.aiStack.features.onyx = {
    enable = lib.mkEnableOption "Onyx; an add-on in every tier";

    domain = lib.mkOption {
      type = lib.types.str;
      example = "search.example.de";
      description = "Public hostname Onyx is served under.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 1447;
      description = "Loopback port of Onyx's own nginx.";
    };
  };

  config = lib.mkIf (stack.enable && cfg.enable) {
    assertions = [
      {
        assertion = lib.all (lib.hasInfix ":v${deployment.version}@") onyxImages;
        message = "Onyx images must match onyx-deployment ${deployment.version}; bump them together";
      }
    ];

    virtualisation.docker.enable = true;

    sops.secrets =
      lib.genAttrs
        [
          "onyx/user_auth_secret"
          "onyx/encryption_key"
          "onyx/postgres_password"
          "onyx/opensearch_password"
        ]
        (_: {
          sopsFile = lib.mkDefault stack.secretsFile;
          mode = "0400";
        });

    # Read by the containers through upstream's `env_file: .env`, and by compose for
    # interpolation. Compose expands `$` in values, so secrets must not contain one.
    sops.templates."onyx.env" = {
      content = ''
        AUTH_TYPE=basic
        WEB_DOMAIN=https://${cfg.domain}
        USER_AUTH_SECRET=${secret "user_auth_secret"}
        ENCRYPTION_KEY_SECRET=${secret "encryption_key"}
        ENABLE_PAID_ENTERPRISE_EDITION_FEATURES=false
        DISABLE_TELEMETRY=true
        POSTGRES_USER=postgres
        POSTGRES_PASSWORD=${secret "postgres_password"}
        OPENSEARCH_ADMIN_PASSWORD=${secret "opensearch_password"}
        COMPOSE_PROFILES=
        FILE_STORE_BACKEND=postgres
        POSTGRES_HOST=relational_db
        REDIS_HOST=cache
        MODEL_SERVER_HOST=inference_model_server
        INDEXING_MODEL_SERVER_HOST=indexing_model_server
        INTERNAL_URL=http://api_server:8080
        LOG_LEVEL=info
      '';
      mode = "0400";
      restartUnits = [ "onyx.service" ];
    };

    systemd.services.onyx = {
      description = "Onyx (Docker Compose)";
      after = [
        "docker.service"
        "network-online.target"
      ];
      requires = [ "docker.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [
        deployment
        override
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        StateDirectory = "onyx";
        StateDirectoryMode = "0700";
        TimeoutStartSec = "30min";
        # Upstream's compose reads `.env` and the nginx templates relative to itself.
        ExecStartPre = pkgs.writeShellScript "onyx-prepare" ''
          set -eu
          rm -rf ${directory}/docker_compose ${directory}/data
          cp -r --no-preserve=mode ${deployment}/docker_compose ${deployment}/data ${directory}/
          ln -s ${config.sops.templates."onyx.env".path} ${directory}/docker_compose/.env
        '';
        ExecStart = "${compose} up --detach --wait --remove-orphans";
        # Post, not Stop: a failed start must not leave containers bound to the directory
        # the next start replaces.
        ExecStopPost = "${compose} down";
      };
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    # Next.js router prefetch (?_rsc=) trips crowdsecurity/http-crawl-non_statics.
    # Statuses are constrained so a scanner cannot append ?_rsc= to hide 404/403
    # probing. Both field names are matched because the parser file name carries a
    # store hash, so this node may run before http-logs (query in .request) or after
    # it (.http_args).
    services.crowdsec.localConfig.parsers.s02Enrich = [
      {
        name = "ai-stack/onyx-rsc-prefetch-whitelist";
        description = "Next.js router prefetch is not an aggressive crawl";
        whitelist = {
          reason = "Next.js RSC prefetch (?_rsc=) from the Onyx UI";
          expression = [
            "evt.Meta.target_fqdn == '${cfg.domain}' && (evt.Parsed.request contains '_rsc=' || evt.Parsed.http_args contains '_rsc=') && evt.Meta.http_status in ['200', '204', '304']"
          ];
        };
      }
    ];

    services.nginx = {
      enable = true;
      virtualHosts.${cfg.domain} = {
        enableACME = true;
        forceSSL = true;
        extraConfig = ''
          client_max_body_size 100m;
          add_header X-Content-Type-Options "nosniff" always;
          add_header Referrer-Policy "strict-origin-when-cross-origin" always;
          add_header Strict-Transport-Security "max-age=31536000" always;
          add_header Permissions-Policy "camera=(), geolocation=(), microphone=()" always;
        ''
        + lib.optionalString stack.edge.enable ''
          limit_req zone=public_per_ip burst=120 nodelay;
          limit_conn public_connections 50;
        '';
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.port}";
          proxyWebsockets = true;
        };
      };
    };

    # The search index rebuilds from the sources; the database holds users, settings,
    # connector state and, with the PostgreSQL file store, uploaded files.
    services.aiStack.backup.jobs.onyx = {
      runtimeInputs = [ config.virtualisation.docker.package ];
      after = [ "onyx.service" ];
      prepare = ''
        docker exec onyx-relational_db-1 pg_dumpall --username=postgres > "$stage/onyx.sql"
        test -s "$stage/onyx.sql"
      '';
    };
  };
}
