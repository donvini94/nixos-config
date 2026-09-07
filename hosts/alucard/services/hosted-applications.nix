{
  config,
  lib,
  pkgs,
  ...
}:
{
  services = {
    # Paperless itself lives in modules/paperless.nix: taxonomy, mail rules,
    # provisioning and backup travel with it.
    paperlessStack = {
      enable = true;
      domain = "paperless.dumusstbereitsein.de";
      port = 58080;
    };

    # mailcow's own ACME cannot work behind this nginx, so hand it our cert.
    mailcowTls = {
      enable = true;
      domain = "mail.istbereit.de";
    };

    dockerRegistry = {
      enable = true;
      openFirewall = false;
    };

    # Reachable only through `tailscale serve --tcp=28888`
    # (hosts/alucard/private-access.nix), so authentication is Tailscale's
    # before it is atuin's.
    # openRegistration is how a machine enrols (`atuin register` on the client);
    # set it to false once the last one is enrolled — logins and sync are
    # unaffected by the flip.
    atuin = {
      enable = true;
      openRegistration = true;
    };
  };

  services.offsiteBackup.jobs.n8n = {
    # `.backup` takes a consistent copy of a database the container is still
    # writing to; copying database.sqlite under WAL would capture a torn page.
    # The rows stay encrypted — n8n/encryption_key lives only in SOPS.
    runtimeInputs = [ pkgs.sqlite ];
    after = [ "docker-n8n.service" ];
    prepare = ''
      install -d -m 0700 "$stage"
      sqlite3 /var/lib/n8n-container/database.sqlite \
        ".backup '$stage/database.sqlite'"
      test -s "$stage/database.sqlite"
    '';
    verifyPaths = [ "/var/lib/offsite-backup/n8n/database.sqlite" ];
  };

  # The exporter already writes a consistent dump to its own directory, so the job
  # snapshots that in place. The Django signing key is not part of the exporter's
  # output and a restore without it invalidates every session and signed value.
  services.offsiteBackup.jobs.paperless = {
    # This key predates the shared backup key and must stay distinct: repointing it
    # would orphan every snapshot already in the repository.
    passwordSecret = "paperless/restic_password";
    # The default 03:30 schedule has to stay after the 02:30 exporter run.
    after = [ "paperless-exporter.service" ];
    paths = [ config.services.paperless.exporter.directory ];
    prepare = ''
      install -d -m 0700 "$stage"
      secret_key=${lib.escapeShellArg "${config.services.paperless.dataDir}/nixos-paperless-secret-key.env"}
      if [ -r "$secret_key" ]; then
        install -m 0400 "$secret_key" "$stage/nixos-paperless-secret-key.env"
      else
        echo "$secret_key is not readable; refusing to take a restore-incomplete snapshot" >&2
        exit 1
      fi
    '';
    verifyPaths = [
      "/var/lib/offsite-backup/paperless/nixos-paperless-secret-key.env"
      config.services.paperless.exporter.directory
    ];
  };

  systemd.services.paperless-consumer.after = [ "var-lib-paperless.mount" ];
  systemd.services.paperless-scheduler.after = [ "var-lib-paperless.mount" ];
  systemd.services.paperless-task-queue.after = [ "var-lib-paperless.mount" ];
  systemd.services.paperless-web.after = [ "var-lib-paperless.mount" ];

  # Consumer/web/scheduler share task-queue's PrivateTmp namespace (JoinsNamespaceOf).
  # Bind their lifecycle so a task-queue restart cycles them too, otherwise they keep
  # a stale namespace where /tmp/paperless no longer exists and uploads fail with
  # "[Errno 2] No such file or directory: '/tmp/paperless/...'".
  systemd.services.paperless-consumer.unitConfig.PartOf = [ "paperless-task-queue.service" ];
  systemd.services.paperless-scheduler.unitConfig.PartOf = [ "paperless-task-queue.service" ];
  systemd.services.paperless-web.unitConfig.PartOf = [ "paperless-task-queue.service" ];
}
