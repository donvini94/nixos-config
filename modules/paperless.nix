{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.paperlessStack;
  paperless = config.services.paperless;

  taxonomyFile = ../paperless/taxonomy.yaml;
  provisionSource = pkgs.writeText "paperless-provision.py" (
    builtins.readFile ../paperless/provision.py
  );
  python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);

  privateSecret = config.sops.secrets."paperless-private".path;
  adminPasswordSecret = config.sops.secrets."paperless/password".path;

  # Operator CLI. Same code path as the systemd unit, so a --dry-run here is a
  # faithful preview of what the next rebuild will do.
  provisionCli = pkgs.writeShellApplication {
    name = "paperless-provision";
    runtimeInputs = [ python ];
    text = ''
      exec ${python}/bin/python3 ${provisionSource} \
        --base-url ${lib.escapeShellArg cfg.baseUrl} \
        --taxonomy ${taxonomyFile} \
        --private ${lib.escapeShellArg privateSecret} \
        --password-file ${lib.escapeShellArg adminPasswordSecret} \
        "$@"
    '';
  };

  # Backs up the exporter's output plus the one piece of state the exporter
  # cannot capture: the runtime-generated Django secret key.
  offsiteScript = pkgs.writeShellApplication {
    name = "paperless-offsite-backup";
    runtimeInputs = [
      pkgs.restic
      pkgs.coreutils
    ];
    text = ''
      repo=${lib.escapeShellArg cfg.offsite.repository}
      RESTIC_PASSWORD_FILE="$CREDENTIALS_DIRECTORY/restic-password"
      export RESTIC_PASSWORD_FILE
      export RESTIC_REPOSITORY="$repo"

      # Preflight. The Hetzner box is a CIFS mount with uid/gid remapping, and
      # an unwritable destination otherwise fails deep inside restic with a
      # much less obvious error.
      parent=$(dirname "$repo")
      if [ ! -d "$parent" ]; then
        echo "offsite parent directory $parent does not exist (is the CIFS mount up?)" >&2
        exit 1
      fi
      if [ ! -w "$parent" ]; then
        echo "offsite parent directory $parent is not writable by $(id -un)" >&2
        exit 1
      fi

      if ! restic cat config >/dev/null 2>&1; then
        echo "initialising restic repository at $repo"
        restic init
      fi

      # The secret key is not part of document_exporter's output, so a restore
      # without it invalidates every session and signed value.
      secretKey=${lib.escapeShellArg "${paperless.dataDir}/nixos-paperless-secret-key.env"}
      extra=()
      if [ -r "$secretKey" ]; then
        extra+=("$secretKey")
      else
        echo "warning: $secretKey not readable, not included in the snapshot" >&2
      fi

      restic backup --tag paperless --host ${lib.escapeShellArg config.networking.hostName} \
        ${lib.escapeShellArg paperless.exporter.directory} "''${extra[@]}"

      restic forget --tag paperless --prune \
        --keep-daily ${toString cfg.offsite.keepDaily} \
        --keep-weekly ${toString cfg.offsite.keepWeekly} \
        --keep-monthly ${toString cfg.offsite.keepMonthly}
    '';
  };
in
{
  options.services.paperlessStack = {
    enable = lib.mkEnableOption "the opinionated Paperless-ngx configuration for this fleet";

    domain = lib.mkOption {
      type = lib.types.str;
      example = "paperless.example.com";
      description = "Public hostname Paperless is served under.";
    };

    address = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 58080;
    };

    baseUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://${cfg.address}:${toString cfg.port}";
      defaultText = lib.literalExpression ''"http://''${address}:''${port}"'';
      description = ''
        Where the provisioner talks to Paperless. Deliberately loopback rather
        than the public vhost: the public one runs ModSecurity CRS, which
        false-positives on the regex-bearing JSON bodies a taxonomy push sends.
      '';
    };

    ocrLanguage = lib.mkOption {
      type = lib.types.str;
      default = "deu+eng";
      description = "Tesseract languages, '+'-joined. Drives which language packs get installed.";
    };

    provision = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Reconcile the taxonomy on every rebuild. Upsert-only: objects created
          by hand in the web UI are reported but never deleted.
        '';
      };
    };

    offsite = {
      enable = lib.mkEnableOption "encrypted off-site restic backup of the document export";

      repository = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/hetzner/restic/paperless";
        description = "restic repository path or URL.";
      };

      passwordSecret = lib.mkOption {
        type = lib.types.str;
        default = "paperless/restic_password";
        description = "sops key holding the restic repository password.";
      };

      onCalendar = lib.mkOption {
        type = lib.types.str;
        default = "03:30";
        description = "When to push off-site. Must be after the exporter has finished.";
      };

      keepDaily = lib.mkOption {
        type = lib.types.int;
        default = 7;
      };
      keepWeekly = lib.mkOption {
        type = lib.types.int;
        default = 5;
      };
      keepMonthly = lib.mkOption {
        type = lib.types.int;
        default = 12;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.paperless = {
      enable = true;
      inherit (cfg) address port;
      consumptionDirIsPublic = true;
      passwordFile = adminPasswordSecret;

      # Office documents and .eml message bodies need Tika + Gotenberg. Without
      # them a mail rule can only ever consume PDF attachments.
      configureTika = true;

      # Carries PAPERLESS_IGNORE_DATES. Those values are birthdates, so they
      # cannot live in `settings` above — that ends up world-readable in the
      # Nix store and in this public repo.
      environmentFile = config.sops.templates."paperless.env".path;

      settings = {
        PAPERLESS_OCR_LANGUAGE = cfg.ocrLanguage;
        PAPERLESS_URL = "https://${cfg.domain}";
        PAPERLESS_CSRF_TRUSTED_ORIGINS = "https://${cfg.domain}";
        # Loopback is here so the provisioner can bypass nginx. Django still
        # checks the Host header, so this does not widen external exposure.
        PAPERLESS_ALLOWED_HOSTS = "${cfg.domain},127.0.0.1,localhost";

        PAPERLESS_FILENAME_FORMAT =
          "{{ created_year }}/{{ correspondent }}/{{ created }}_{{ document_type }}_{{ title }}";
        PAPERLESS_FILENAME_FORMAT_REMOVE_NONE = true;

        # German date conventions: 03.04.2026 is 3 April, not 4 March.
        PAPERLESS_DATE_ORDER = "DMY";
        PAPERLESS_FILENAME_DATE_ORDER = "DMY";
        PAPERLESS_NUMBER_OF_SUGGESTED_DATES = 3;

        PAPERLESS_CONSUMER_RECURSIVE = true;
        # Source tags come from workflows, which know whether a document
        # arrived by mail, WebDAV, or upload. Directory names do not.
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
          # Per-document manifests instead of one giant JSON, so an
          # incremental off-site sync only moves what actually changed.
          split-manifest = true;
        };
      };
    };

    sops.secrets = {
      "paperless-private" = {
        sopsFile = ../secrets/paperless.yaml;
        format = "yaml";
        # An empty key yields the whole decrypted document rather than one leaf.
        key = "";
        owner = paperless.user;
        mode = "0400";
        restartUnits = lib.optional cfg.provision.enable "paperless-provision.service";
      };
      # Paperless' date parser takes the first plausible date in a document, so
      # "geboren am 14.07.1994" wins over the actual letter date. This affected
      # 20 of the first 210 documents.
      "paperless/ignore_dates" = {
        sopsFile = ../secrets/paperless.yaml;
        key = "ignore_dates";
        owner = paperless.user;
        mode = "0400";
      };
    }
    // lib.optionalAttrs cfg.offsite.enable {
      # Deliberately NOT in secrets/paperless.yaml: that file is read whole by
      # the provisioner running as the `paperless` user, and the service user
      # has no business holding the backup encryption key.
      ${cfg.offsite.passwordSecret} = {
        owner = "root";
        mode = "0400";
      };
    };

    # The exporter declares Conflicts= on the paperless units, so at 02:30
    # systemd stops the task queue. Celery treats SIGTERM as a warm shutdown,
    # but the default 90s stop timeout is far too short for an in-flight OCR of
    # a large PDF -- the worker gets killed and Paperless records the mail as
    # FAILED, which permanently suppresses a retry (the skip check matches on
    # rule+uid+folder and ignores status). Give it room to drain instead.
    systemd.services.paperless-task-queue.serviceConfig.TimeoutStopSec = "900";
    systemd.services.paperless-consumer.serviceConfig.TimeoutStopSec = "900";

    sops.templates."paperless.env" = {
      content = ''
        PAPERLESS_IGNORE_DATES=${config.sops.placeholder."paperless/ignore_dates"}
      '';
      owner = paperless.user;
      mode = "0400";
      restartUnits = [
        "paperless-web.service"
        "paperless-consumer.service"
        "paperless-scheduler.service"
        "paperless-task-queue.service"
      ];
    };

    environment.systemPackages = [ provisionCli ];

    systemd.services.paperless-provision = lib.mkIf cfg.provision.enable {
      description = "Reconcile Paperless taxonomy from declarative config";
      wantedBy = [ "multi-user.target" ];
      after = [
        "paperless-web.service"
        "sops-install-secrets.service"
      ];
      requires = [ "paperless-web.service" ];
      # A rebuild starts every paperless unit in one transaction, so ordering
      # only guarantees launch order, not readiness. The script polls for up to
      # three minutes; the unit timeout has to outlast that, and a genuinely
      # slow start (migrations after a version bump) gets a few retries rather
      # than needing a manual rerun.
      startLimitBurst = 4;
      startLimitIntervalSec = 900;
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "600";
        Restart = "on-failure";
        RestartSec = "45";
        User = paperless.user;
        Group = config.users.users.${paperless.user}.group;
        LoadCredential = [ "admin-password:${adminPasswordSecret}" ];
        # paperless-web being "started" is not the same as it serving, so the
        # script polls /api/ rather than trusting unit ordering.
        ExecStart = ''
          ${python}/bin/python3 ${provisionSource} \
            --base-url ${lib.escapeShellArg cfg.baseUrl} \
            --taxonomy ${taxonomyFile} \
            --private ${lib.escapeShellArg privateSecret} \
            --wait
        '';
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
      };
    };

    systemd.services.paperless-offsite-backup = lib.mkIf cfg.offsite.enable {
      description = "Push the Paperless export off-site with restic";
      after = [ "paperless-exporter.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        LoadCredential = [
          "restic-password:${config.sops.secrets.${cfg.offsite.passwordSecret}.path}"
        ];
        ExecStart = lib.getExe offsiteScript;
        # The CIFS mount is an automount; give it room to come up.
        TimeoutStartSec = "2h";
      };
    };

    systemd.timers.paperless-offsite-backup = lib.mkIf cfg.offsite.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.offsite.onCalendar;
        Persistent = true;
        RandomizedDelaySec = "15m";
      };
    };
  };
}
