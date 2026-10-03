# Restic repositories on the Hetzner share, one per application. Repository paths, passwords
# and staging directories are unchanged from the previous job runner, so existing snapshots
# stay readable. Anything a service writes concurrently is staged as a consistent copy first.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  repositoryBase = "/mnt/hetzner/restic";
  stage = name: "/var/lib/offsite-backup/${name}";

  job =
    name:
    {
      prepare,
      paths ? [ ],
      passwordSecret ? "backup/restic_password",
      after ? [ ],
      requires ? [ ],
      runtimeInputs ? [ ],
    }:
    {
      services.restic.backups.${name} = {
        repository = "${repositoryBase}/${name}";
        passwordFile = config.sops.secrets.${passwordSecret}.path;
        initialize = true;
        paths = [ (stage name) ] ++ paths;
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
          export PATH=${lib.makeBinPath ([ pkgs.coreutils ] ++ runtimeInputs)}:$PATH
          stage=${stage name}
          rm -rf -- "$stage"
          install -d -m 0700 "$stage"
          ${prepare}
        '';
        timerConfig = {
          OnCalendar = "03:30";
          Persistent = true;
          RandomizedDelaySec = "15m";
        };
      };
      systemd.services."restic-backups-${name}" = {
        inherit after requires;
        unitConfig.RequiresMountsFor = "/mnt/hetzner";
        serviceConfig = {
          Nice = 10;
          IOSchedulingClass = "idle";
          TimeoutStartSec = "2h";
        };
      };
      systemd.services."restic-check-${name}" = {
        description = "Verify restic repository ${name}";
        after = [ "restic-backups-${name}.service" ];
        unitConfig.RequiresMountsFor = "/mnt/hetzner";
        serviceConfig = {
          Type = "oneshot";
          Nice = 10;
          IOSchedulingClass = "idle";
          ExecStart = "${pkgs.restic}/bin/restic check --read-data-subset=5%";
        };
        environment = {
          RESTIC_REPOSITORY = "${repositoryBase}/${name}";
          RESTIC_PASSWORD_FILE = config.sops.secrets.${passwordSecret}.path;
        };
      };
      systemd.timers."restic-check-${name}" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "Sun 05:00";
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
      };
      sops.secrets.${passwordSecret} = {
        owner = "root";
        mode = "0400";
      };
    };
in
lib.mkMerge [
  # Keycloak: a database dump; realm exports do not preserve all database state.
  (job "keycloak" {
    runtimeInputs = [
      config.services.postgresql.package
      pkgs.util-linux
    ];
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
    prepare = ''
      runuser -u postgres -- pg_dump --format=custom --no-owner keycloak > "$stage/keycloak.dump"
      test -s "$stage/keycloak.dump"
    '';
  })

  # n8n: `.backup` copies a database the container is still writing to. Rows stay
  # encrypted; the encryption key lives only in SOPS.
  (job "n8n" {
    runtimeInputs = [ pkgs.sqlite ];
    after = [ "docker-n8n.service" ];
    prepare = ''
      sqlite3 ${lib.escapeShellArg "${config.services.localN8n.stateDirectory}/database.sqlite"} \
        ".backup '$stage/database.sqlite'"
      test -s "$stage/database.sqlite"
    '';
  })

  # Hermes: SQLite databases are copied consistently; the rest of the data directory is
  # snapshotted in place minus caches that rebuild themselves.
  (job "hermes" {
    runtimeInputs = [ pkgs.sqlite ];
    prepare = ''
      src=${lib.escapeShellArg config.services.hermesAgent.stateDirectory}
      find "$src" -name '*.db' -not -path '*/skills/*' -print0 | while IFS= read -r -d "" db; do
        rel=''${db#"$src"/}
        install -d -m 0700 "$stage/$(dirname "$rel")"
        sqlite3 "$db" ".backup '$stage/$rel'"
      done
      tar -C "$src" --exclude='*.db' --exclude='*.db-wal' --exclude='*.db-shm' --exclude=./cache \
        --exclude=./image_cache --exclude=./audio_cache --exclude=./models_dev_cache.json -cf - . \
        | tar -C "$stage" -xf -
    '';
  })

  # Jellyfin: consistent database copies plus config and authored playlists; the rest
  # is rebuilt by a library scan.
  (job "jellyfin" {
    runtimeInputs = [ pkgs.sqlite ];
    prepare = ''
      install -d -m 0700 "$stage/data" "$stage/config"
      data=${lib.escapeShellArg "${config.services.jellyfin.dataDir}/data"}
      found=0
      for db in "$data"/*.db; do
        [ -e "$db" ] || continue
        sqlite3 "$db" ".backup '$stage/data/$(basename "$db")'"
        test -s "$stage/data/$(basename "$db")"
        found=1
      done
      if [ "$found" -eq 0 ]; then
        echo "no Jellyfin database found under $data; refusing an empty snapshot" >&2
        exit 1
      fi
      cp -a ${lib.escapeShellArg "${config.services.jellyfin.configDir}/."} "$stage/config/"
      if [ -d "$data/playlists" ]; then
        cp -a "$data/playlists" "$stage/data/playlists"
      fi
    '';
  })

  # Paperless: the exporter writes a consistent dump to its own directory, snapshotted in
  # place. The Django signing key is not in the export; a restore without it invalidates
  # every session and signed value.
  (job "paperless" {
    # Predates the shared key; repointing it would orphan the existing snapshots.
    passwordSecret = "paperless/restic_password";
    # The 03:30 schedule has to stay after the 02:30 exporter run.
    after = [ "paperless-exporter.service" ];
    paths = [ config.services.paperless.exporter.directory ];
    prepare = ''
      secret_key=${lib.escapeShellArg "${config.services.paperless.dataDir}/nixos-paperless-secret-key.env"}
      if [ -r "$secret_key" ]; then
        install -m 0400 "$secret_key" "$stage/nixos-paperless-secret-key.env"
      else
        echo "$secret_key is not readable; refusing a restore-incomplete snapshot" >&2
        exit 1
      fi
    '';
  })
]
