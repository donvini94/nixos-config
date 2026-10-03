# Paperless-ngx for customer staff on its own public subdomain, with Tika and Gotenberg
# for office documents and mail bodies, German date conventions and a nightly export
# that backups pick up.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  stack = config.services.aiStack;
  cfg = stack.features.paperless;
  paperless = config.services.paperless;
in
{
  options.services.aiStack.features.paperless = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = stack.tier == "plus";
      defaultText = lib.literalExpression ''config.services.aiStack.tier == "plus"'';
      description = "Paperless-ngx; part of the plus tier.";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      example = "docs.example.de";
      description = "Public hostname Paperless is served under.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 58080;
    };

    ocrLanguage = lib.mkOption {
      type = lib.types.str;
      default = "deu+eng";
      description = "Tesseract languages, '+'-joined. Drives which language packs get installed.";
    };
  };

  config = lib.mkIf (stack.enable && cfg.enable) {
    sops.secrets."paperless/admin_password" = {
      sopsFile = lib.mkDefault stack.secretsFile;
      mode = "0400";
    };

    services.paperless = {
      enable = true;
      address = "127.0.0.1";
      inherit (cfg) port;
      passwordFile = config.sops.secrets."paperless/admin_password".path;

      # Office documents and .eml message bodies need Tika + Gotenberg. Without
      # them a mail rule can only ever consume PDF attachments.
      configureTika = true;

      settings = {
        PAPERLESS_OCR_LANGUAGE = cfg.ocrLanguage;
        PAPERLESS_URL = "https://${cfg.domain}";
        PAPERLESS_CSRF_TRUSTED_ORIGINS = "https://${cfg.domain}";
        # Loopback allows local administration without nginx. Django still
        # checks the Host header, so this does not widen external exposure.
        PAPERLESS_ALLOWED_HOSTS = "${cfg.domain},127.0.0.1,localhost";

        PAPERLESS_FILENAME_FORMAT = "{{ created_year }}/{{ correspondent }}/{{ created }}_{{ document_type }}_{{ title }}";
        PAPERLESS_FILENAME_FORMAT_REMOVE_NONE = true;

        # German date conventions: 03.04.2026 is 3 April, not 4 March.
        PAPERLESS_DATE_ORDER = "DMY";
        PAPERLESS_FILENAME_DATE_ORDER = "DMY";
        PAPERLESS_NUMBER_OF_SUGGESTED_DATES = 3;

        PAPERLESS_CONSUMER_RECURSIVE = true;
        # Source tags come from workflows, which know the arrival channel; dirs do not.
        PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS = false;

        PAPERLESS_TASK_WORKERS = 2;
        PAPERLESS_OCR_USER_ARGS = {
          deskew = true;
          optimize = 3;
        };
      };

      exporter = {
        enable = true;
        onCalendar = "02:30";
        settings = {
          no-progress-bar = true;
          no-color = true;
          compare-checksums = true;
          delete = true;
          # Per-document manifests keep the incremental off-site sync to what changed.
          split-manifest = true;
        };
      };
    };

    # nixpkgs' tika is 2.9.3, inside the CVE-2025-66516 XXE range, and this parses
    # documents that arrive by email. The module overrides enableOcr/enableGui on
    # whatever package it is given, so this stays a plain package swap.
    services.tika.package = pkgs.callPackage ../packages/tika.nix { };

    systemd.services = {
      # The exporter declares Conflicts= on the paperless units, so at 02:30 systemd
      # stops the task queue. Celery treats SIGTERM as a warm shutdown, but the default
      # 90s stop timeout is far too short for an in-flight OCR of a large PDF: the
      # worker is killed and Paperless records the mail as FAILED, which permanently
      # suppresses a retry (the skip check matches rule+uid+folder and ignores status).
      paperless-task-queue.serviceConfig.TimeoutStopSec = "900";
      paperless-consumer.serviceConfig.TimeoutStopSec = "900";

      # Consumer, web and scheduler share task-queue's PrivateTmp namespace
      # (JoinsNamespaceOf). Bound to it, a task-queue restart cycles them too; otherwise
      # they keep a stale namespace without /tmp/paperless and uploads fail.
      paperless-consumer.unitConfig.PartOf = [ "paperless-task-queue.service" ];
      paperless-scheduler.unitConfig.PartOf = [ "paperless-task-queue.service" ];
      paperless-web.unitConfig.PartOf = [ "paperless-task-queue.service" ];

      # The export holds mail-account passwords, password hashes and TOTP secrets; the
      # upstream module creates the directory world-readable, so close it. Root-run
      # backups are unaffected.
      paperless-export-private = {
        description = "Restrict the Paperless export directory to its owner";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-tmpfiles-setup.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = paperless.user;
          ExecStart = "${pkgs.coreutils}/bin/chmod 0700 ${paperless.exporter.directory}";
        };
      };
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
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

    # The exporter writes a consistent dump to its own directory, snapshotted in place.
    # The Django signing key is not in the export; a restore without it invalidates
    # every session and signed value.
    services.aiStack.backup.jobs.paperless = {
      # The 03:30 schedule has to stay after the 02:30 exporter run.
      after = [ "paperless-exporter.service" ];
      paths = [ paperless.exporter.directory ];
      prepare = ''
        secret_key=${lib.escapeShellArg "${paperless.dataDir}/nixos-paperless-secret-key.env"}
        if [ -r "$secret_key" ]; then
          install -m 0400 "$secret_key" "$stage/nixos-paperless-secret-key.env"
        else
          echo "$secret_key is not readable; refusing a restore-incomplete snapshot" >&2
          exit 1
        fi
      '';
    };
  };
}
