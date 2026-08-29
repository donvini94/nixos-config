{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.offsiteBackup;

  # Each job stages its state into a private directory first, then restic reads
  # only that directory. Staging is what makes the snapshot consistent: a live
  # SQLite file or a running Postgres cluster copied byte-wise is not a backup,
  # it is a coin flip.
  stageRoot = "/var/lib/offsite-backup";

  jobStage = name: "${stageRoot}/${name}";
  jobRepository = name: "${cfg.repositoryBase}/${name}";

  backupScript =
    name: job:
    pkgs.writeShellApplication {
      name = "offsite-backup-${name}";
      runtimeInputs = [
        pkgs.restic
        pkgs.coreutils
      ]
      ++ job.runtimeInputs;
      text = ''
        RESTIC_PASSWORD_FILE="$CREDENTIALS_DIRECTORY/restic-password"
        export RESTIC_PASSWORD_FILE
        export RESTIC_REPOSITORY=${lib.escapeShellArg (jobRepository name)}

        stage=${lib.escapeShellArg (jobStage name)}
        mkdir -p "$stage"
        chmod 0700 "$stage"

        parent=$(dirname "$RESTIC_REPOSITORY")
        mkdir -p "$parent"

        if ! restic cat config >/dev/null 2>&1; then
          echo "initialising restic repository at $RESTIC_REPOSITORY"
          restic init
        fi

        ${job.prepare}

        restic backup --tag ${lib.escapeShellArg name} \
          --host ${lib.escapeShellArg config.networking.hostName} \
          "$stage" ${lib.escapeShellArgs job.paths}

        restic forget --tag ${lib.escapeShellArg name} --prune \
          --keep-daily ${toString cfg.retention.daily} \
          --keep-weekly ${toString cfg.retention.weekly} \
          --keep-monthly ${toString cfg.retention.monthly}
      '';
    };

  # A backup nobody has restored is a hypothesis. Each job names the paths that
  # must reappear, and the verify unit fails loudly when they do not.
  verifyScript =
    name: job:
    pkgs.writeShellApplication {
      name = "offsite-restore-verify-${name}";
      runtimeInputs = [
        pkgs.restic
        pkgs.coreutils
      ];
      text = ''
        RESTIC_PASSWORD_FILE="$CREDENTIALS_DIRECTORY/restic-password"
        export RESTIC_PASSWORD_FILE
        export RESTIC_REPOSITORY=${lib.escapeShellArg (jobRepository name)}

        target=$(mktemp -d --tmpdir=${lib.escapeShellArg stageRoot} .restore-verify.XXXXXXXX)
        cleanup() {
          rm -rf "$target"
        }
        trap cleanup EXIT

        restic restore latest --target "$target"
        ${lib.concatMapStringsSep "\n" (p: ''
          restored="$target"${lib.escapeShellArg p}
          if [ -d "$restored" ]; then
            if [ -z "$(ls -A "$restored")" ]; then
              echo "restored directory is empty: ${p}" >&2
              exit 1
            fi
          elif [ ! -s "$restored" ]; then
            echo "restored file is missing or empty: ${p}" >&2
            exit 1
          fi
        '') job.verifyPaths}
        echo "restore verified: ${name}"
      '';
    };

  jobModule =
    { name, ... }:
    {
      options = {
        prepare = lib.mkOption {
          type = lib.types.lines;
          description = ''
            Shell fragment that writes this job's state into "$stage". Runs as
            root inside the backup unit, before restic reads the directory.
          '';
        };

        runtimeInputs = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = "Extra packages available to `prepare`.";
        };

        paths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Live paths to snapshot in place alongside the staging directory. Use
            this only for data another unit already wrote out consistently;
            anything the service mutates concurrently belongs in `prepare`.
          '';
        };

        passwordSecret = lib.mkOption {
          type = lib.types.str;
          default = cfg.passwordSecret;
          defaultText = lib.literalExpression "config.services.offsiteBackup.passwordSecret";
          description = ''
            sops key encrypting this job's repository. Overriding it keeps an
            existing repository readable; changing it orphans every snapshot.
          '';
        };

        verifyPaths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Absolute paths, as they appear inside a restore, that must exist and
            be non-empty. Empty list means the job is not restore-verified,
            which the module refuses.
          '';
        };

        after = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra units this job must run after.";
        };

        requires = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Units that must be running for this job to be meaningful.";
        };

        onCalendar = lib.mkOption {
          type = lib.types.str;
          default = cfg.onCalendar;
          defaultText = lib.literalExpression "config.services.offsiteBackup.onCalendar";
          description = "Schedule for this job.";
        };
      };

      config = {
        _module.args.jobName = name;
      };
    };
in
{
  options.services.offsiteBackup = {
    enable = lib.mkEnableOption "encrypted off-site restic backups of declared state";

    repositoryBase = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/hetzner/restic";
      description = "Parent path or URL under which each job gets its own repository.";
    };

    passwordSecret = lib.mkOption {
      type = lib.types.str;
      default = "backup/restic_password";
      description = "sops key holding the restic repository password.";
    };

    requiresMountsFor = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "/mnt/hetzner";
      description = "Mount that must be present before any job runs.";
    };

    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "03:30";
      description = "Default schedule for jobs that do not override it.";
    };

    verifyOnCalendar = lib.mkOption {
      type = lib.types.str;
      default = "Sun *-*-* 05:00:00";
      description = ''
        Schedule for the restore drills. Restoring is the only evidence a
        repository is usable, so this runs on its own cadence rather than being
        folded into the backup unit.
      '';
    };

    retention = {
      daily = lib.mkOption {
        type = lib.types.ints.positive;
        default = 7;
      };
      weekly = lib.mkOption {
        type = lib.types.ints.positive;
        default = 4;
      };
      monthly = lib.mkOption {
        type = lib.types.ints.positive;
        default = 6;
      };
    };

    jobs = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule jobModule);
      default = { };
      description = "Named state stores to back up off-site.";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.jobs != { }) {
    assertions = lib.mapAttrsToList (name: job: {
      assertion = job.verifyPaths != [ ];
      message = "services.offsiteBackup.jobs.${name} must declare verifyPaths; an unverified backup is not a backup";
    }) cfg.jobs;

    sops.secrets = lib.listToAttrs (
      map (secret: {
        name = secret;
        value = {
          owner = "root";
          mode = "0400";
        };
      }) (lib.unique (lib.mapAttrsToList (_: job: job.passwordSecret) cfg.jobs))
    );

    systemd.tmpfiles.rules = [
      "d ${stageRoot} 0700 root root -"
    ]
    ++ lib.mapAttrsToList (name: _: "d ${jobStage name} 0700 root root -") cfg.jobs;

    systemd.services = lib.concatMapAttrs (name: job: {
      "offsite-backup-${name}" = {
        description = "Push ${name} state off-site with restic";
        after = [ "network-online.target" ] ++ job.after;
        wants = [ "network-online.target" ];
        requires = job.requires;
        unitConfig = lib.mkIf (cfg.requiresMountsFor != null) {
          RequiresMountsFor = cfg.requiresMountsFor;
        };
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          LoadCredential = [
            "restic-password:${config.sops.secrets.${job.passwordSecret}.path}"
          ];
          ExecStart = lib.getExe (backupScript name job);
          # The CIFS target is an automount; give it room to come up.
          TimeoutStartSec = "2h";
          Nice = 10;
          IOSchedulingClass = "idle";
        };
      };

      "offsite-restore-verify-${name}" = {
        description = "Verify the ${name} off-site backup restores";
        after = [ "offsite-backup-${name}.service" ];
        conflicts = [ "offsite-backup-${name}.service" ];
        unitConfig = lib.mkIf (cfg.requiresMountsFor != null) {
          RequiresMountsFor = cfg.requiresMountsFor;
        };
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          LoadCredential = [
            "restic-password:${config.sops.secrets.${job.passwordSecret}.path}"
          ];
          ExecStart = lib.getExe (verifyScript name job);
          TimeoutStartSec = "2h";
          Nice = 10;
          IOSchedulingClass = "idle";
        };
      };
    }) cfg.jobs;

    # Persistent timers with no stamp file fire once shortly after activation,
    # so a freshly provisioned host takes its first snapshot without an operator.
    systemd.timers = lib.concatMapAttrs (name: job: {
      "offsite-backup-${name}" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = job.onCalendar;
          Persistent = true;
          RandomizedDelaySec = "15m";
        };
      };

      "offsite-restore-verify-${name}" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.verifyOnCalendar;
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
      };
    }) cfg.jobs;

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "offsite-backup-status" ''
        for job in ${lib.escapeShellArgs (lib.attrNames cfg.jobs)}; do
          printf '== %s ==\n' "$job"
          ${pkgs.systemd}/bin/systemctl list-timers --all --no-pager \
            "offsite-backup-$job.timer" "offsite-restore-verify-$job.timer" || true
          ${pkgs.systemd}/bin/systemctl --no-pager --property=Result --property=ExecMainStatus \
            show "offsite-backup-$job.service" "offsite-restore-verify-$job.service" || true
        done
      '')
    ];
  };
}
