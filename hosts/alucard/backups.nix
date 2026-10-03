# Alucard's backups: the stack's jobs (n8n, Hermes) plus this host's applications, in
# per-job restic repositories on the Hetzner share. Repository paths and passwords are
# unchanged from earlier job runners, so existing snapshots stay readable.
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
    repository = "/mnt/hetzner/restic";
    requiresMountsFor = [ "/mnt/hetzner" ];
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

      # Paperless: the exporter writes a consistent dump to its own directory, snapshotted in
      # place. The Django signing key is not in the export; a restore without it invalidates
      # every session and signed value.
      paperless = {
        # Predates the shared key; repointing it would orphan the existing snapshots.
        passwordFile = config.sops.secrets."paperless/restic_password".path;
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
      };
    };
  };
}
