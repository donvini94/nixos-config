# Alucard's Paperless: the ai-stack feature plus the household specifics.
{ config, site, ... }:
let
  paperless = config.services.paperless;
in
{
  services.aiStack.features.paperless = {
    enable = true;
    domain = "paperless.${site.domains.primary}";
  };

  # The admin password predates the stack's secrets file.
  sops.secrets."paperless/admin_password" = {
    sopsFile = config.sops.defaultSopsFile;
    key = "paperless/password";
  };

  # The WebDAV share in reverse-proxy.nix writes into the consumption directory as
  # nginx. The setgid paperless group keeps uploads between nginx and Paperless.
  users.users.nginx.extraGroups = [ paperless.group ];
  systemd.tmpfiles.settings."10-paperless".${paperless.consumptionDir}.d.mode = "2770";

  # Paperless' date parser takes the first plausible date in a document, so
  # "geboren am 14.07.1994" wins over the actual letter date. Those values are
  # birthdates, so they cannot live in `settings`: that lands world-readable in the
  # Nix store.
  sops.secrets."paperless/ignore_dates" = {
    sopsFile = ../../secrets/paperless.yaml;
    key = "ignore_dates";
    owner = paperless.user;
    mode = "0400";
  };
  sops.secrets."paperless/oidc_secret" = { };
  sops.templates."paperless.env" = {
    content = ''
      PAPERLESS_IGNORE_DATES=${config.sops.placeholder."paperless/ignore_dates"}
      PAPERLESS_SOCIALACCOUNT_PROVIDERS='${
        builtins.toJSON {
          openid_connect = {
            OAUTH_PKCE_ENABLED = true;
            APPS = [
              {
                provider_id = "keycloak";
                name = "Keycloak";
                client_id = "paperless";
                secret = config.sops.placeholder."paperless/oidc_secret";
                settings.server_url = "https://auth.${site.domains.primary}/realms/Abschleppdienst";
              }
            ];
          };
        }
      }'
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
  services.paperless.environmentFile = config.sops.templates."paperless.env".path;

  # Keycloak sign-in for existing accounts: each user links Keycloak once under
  # Profile → Connect, after which the Keycloak button signs them in. Realm members
  # without a Paperless account are not admitted.
  services.paperless.settings = {
    PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
    PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS = false;
  };

  # The data directory is a separate mount.
  systemd.services = {
    paperless-consumer.after = [ "var-lib-paperless.mount" ];
    paperless-scheduler.after = [ "var-lib-paperless.mount" ];
    paperless-task-queue.after = [ "var-lib-paperless.mount" ];
    paperless-web.after = [ "var-lib-paperless.mount" ];
  };
}
