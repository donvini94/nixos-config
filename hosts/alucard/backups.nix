# Alucard's backups: the stack's jobs (n8n, Hermes) plus this host's applications, in
# per-job restic repositories on the Storage Box, reached over SFTP. Repositories and
# passwords are unchanged from earlier job runners, so existing snapshots stay readable.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  sops.secrets = {
    # Both predate the stack's secrets file.
    "backup/restic_password".sopsFile = config.sops.defaultSopsFile;
    "paperless/restic_password".mode = "0400";
  };

  services.aiStack.backup = {
    # Sub-account whose home is the share's restic/ folder, where the repositories were
    # created through the SMB mount.
    repository = "sftp:u487137-sub6@u487137.your-storagebox.de:";
    jobs = {
      # Keycloak: a database dump; realm exports do not preserve all database state.
      keycloak = {
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
      };

      # Jellyfin: consistent database copies plus config and authored playlists; the rest
      # is rebuilt by a library scan.
      jellyfin = {
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
      };

      # Predates the shared key; repointing it would orphan the existing snapshots.
      paperless.passwordFile = config.sops.secrets."paperless/restic_password".path;
    };
  };
}
