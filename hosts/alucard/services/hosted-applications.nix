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

    # Keep UI-managed settings, with Nix taking precedence for domain and theme policy.
    mattermost = {
      enable = true;
      siteName = "Bereit Chat";
      siteUrl = "https://chat.istbereit.de";
      host = "127.0.0.1";
      port = 8065;
      mutableConfig = true;
      preferNixConfig = true;
      settings = {
        TeamSettings = {
          # Signup stays open (no invite needed) but only istbereit.de
          # addresses can create an account.
          EnableOpenServer = true;
          RestrictCreationToDomains = "istbereit.de";
        };
        ThemeSettings.DefaultTheme = "onyx";
      };
      database = {
        create = true;
        peerAuth = true;
      };
    };

    # Tailnet-only; registration remains open so new devices can enroll.
    atuin = {
      enable = true;
      openRegistration = true;
    };
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
