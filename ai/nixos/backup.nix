# restic backups of the stack's state, one repository per job under `repository`.
# Anything a service writes concurrently is staged as a consistent copy first; every job
# verifies 5% of its data weekly and publishes its last success for alerting.
{
  config,
  lib,
  pkgs,
  utils,
  ...
}:

let
  cfg = config.services.aiStack.backup;
  stage = name: "/var/lib/offsite-backup/${name}";
  exporters = config.services.observability.exporters;
  repository = name: "${cfg.repository}/${name}";
  passwordFile =
    job:
    if job.passwordFile != null then
      job.passwordFile
    else
      config.sops.secrets."backup/restic_password".path;
  sftp = lib.hasPrefix "sftp:" cfg.repository;
  # Storage Box sub-accounts accept SSH on port 23 and only a restricted SFTP shell.
  sftpCommand = lib.concatStringsSep " " [
    (lib.getExe pkgs.openssh)
    "-p 23"
    "-i ${config.sops.secrets."backup/ssh_key".path}"
    "-o StrictHostKeyChecking=accept-new"
    "-o UserKnownHostsFile=/var/lib/offsite-backup/known_hosts"
    (lib.head (lib.splitString ":" (lib.removePrefix "sftp:" cfg.repository)))
    "-s sftp"
  ];
  publishSuccess =
    name:
    pkgs.writeShellScript "restic-${name}-success" ''
      out=${exporters.textfileDirectory}/restic-${name}.prom
      printf 'restic_backup_last_success_timestamp_seconds{backup="%s"} %s\n' ${name} "$(${pkgs.coreutils}/bin/date +%s)" > "$out.tmp"
      ${pkgs.coreutils}/bin/mv "$out.tmp" "$out"
    '';

  jobType = lib.types.submodule {
    options = {
      prepare = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Shell that writes a consistent copy into $stage before the snapshot.";
      };
      paths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Paths snapshotted in place, besides the staging directory.";
      };
      runtimeInputs = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
      };
      after = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      requires = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Repository password, when this job's repository predates the shared one.";
      };
    };
  };

  backupService = name: job: {
    repository = repository name;
    passwordFile = passwordFile job;
    initialize = true;
    # The restic module splices these into ExecStart unquoted.
    extraOptions = lib.optional sftp "sftp.command='${sftpCommand}'";
    paths = [ (stage name) ] ++ job.paths;
    extraBackupArgs = [
      "--tag"
      name
    ];
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
    backupPrepareCommand = ''
      set -eu
      export PATH=${lib.makeBinPath ([ pkgs.coreutils ] ++ job.runtimeInputs)}:$PATH
      stage=${stage name}
      rm -rf -- "$stage"
      install -d -m 0700 "$stage"
      ${job.prepare}
    '';
    timerConfig = {
      OnCalendar = "03:30";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };

  units = name: job: {
    "restic-backups-${name}" = {
      inherit (job) after requires;
      unitConfig.RequiresMountsFor = cfg.requiresMountsFor;
      serviceConfig = {
        Nice = 10;
        IOSchedulingClass = "idle";
        TimeoutStartSec = "2h";
        ExecStartPost = lib.mkIf exporters.enable [ (publishSuccess name) ];
      };
    };
    "restic-check-${name}" = {
      description = "Verify restic repository ${name}";
      after = [ "restic-backups-${name}.service" ];
      unitConfig.RequiresMountsFor = cfg.requiresMountsFor;
      serviceConfig = {
        Type = "oneshot";
        Nice = 10;
        IOSchedulingClass = "idle";
        ExecStart = utils.escapeSystemdExecArgs (
          [ "${pkgs.restic}/bin/restic" ]
          ++ lib.optionals sftp [
            "-o"
            "sftp.command=${sftpCommand}"
          ]
          ++ [
            "check"
            "--read-data-subset=5%"
          ]
        );
      };
      environment = {
        RESTIC_REPOSITORY = repository name;
        RESTIC_PASSWORD_FILE = passwordFile job;
      };
    };
  };
in
{
  options.services.aiStack.backup = {
    repository = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "sftp:u123456-sub1@u123456.your-storagebox.de:restic";
      description = ''
        Base of the restic repositories; each job uses `<repository>/<job>`. An `sftp:`
        base authenticates with `backup/ssh_key`. Null disables backups.
      '';
    };

    requiresMountsFor = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Mounts a local repository lives on.";
    };

    jobs = lib.mkOption {
      type = lib.types.attrsOf jobType;
      default = { };
      description = "Backup jobs keyed by name; the stack adds its own.";
    };
  };

  config = lib.mkIf (cfg.repository != null) {
    sops.secrets = {
      # A host whose password lives elsewhere overrides sopsFile.
      "backup/restic_password" = {
        sopsFile = lib.mkDefault config.services.aiStack.secretsFile;
        mode = "0400";
      };
      "backup/ssh_key" = lib.mkIf sftp {
        sopsFile = config.services.aiStack.secretsFile;
        mode = "0400";
      };
    };
    systemd.tmpfiles.rules = [ "d /var/lib/offsite-backup 0700 root root -" ];

    services.restic.backups = lib.mapAttrs backupService cfg.jobs;
    systemd.services = lib.mkMerge (lib.mapAttrsToList units cfg.jobs);
    systemd.timers = lib.mapAttrs' (
      name: _:
      lib.nameValuePair "restic-check-${name}" {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "Sun 05:00";
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
      }
    ) cfg.jobs;
  };
}
