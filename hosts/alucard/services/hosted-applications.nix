{
  pkgs,
  ...
}:
{
  services = {
    # Paperless itself lives in modules/paperless.nix — taxonomy, mail rules,
    # provisioning, and backup travel with it. Only the vhost stays here.
    paperlessStack = {
      enable = true;
      domain = "paperless.dumusstbereitsein.de";
      port = 58080;
      # Nightly document_exporter at 02:30, pushed to the Hetzner box at 03:30.
      offsite.enable = true;
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
  };

  services.offsiteBackup.jobs.n8n = {
    # `.backup` takes a consistent copy of a database the container is still
    # writing to; copying database.sqlite under WAL would capture a torn page.
    # The rows stay encrypted: n8n/encryption_key lives only in SOPS, so this
    # snapshot is useless without the separately held key.
    runtimeInputs = [ pkgs.sqlite ];
    after = [ "docker-n8n.service" ];
    prepare = ''
      install -d -m 0700 "$stage"
      sqlite3 /var/lib/n8n-container/database.sqlite \
        ".backup '$stage/database.sqlite'"
      test -s "$stage/database.sqlite"
    '';
    verifyPaths = [ "${"/var/lib/offsite-backup/n8n/database.sqlite"}" ];
  };

  # Paperless depends on mount
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
