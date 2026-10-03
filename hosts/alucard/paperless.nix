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

  # The WebDAV share in reverse-proxy.nix writes into the consumption directory.
  services.paperless.consumptionDirIsPublic = true;

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
  services.paperless.environmentFile = config.sops.templates."paperless.env".path;

  # The data directory is a separate mount.
  systemd.services = {
    paperless-consumer.after = [ "var-lib-paperless.mount" ];
    paperless-scheduler.after = [ "var-lib-paperless.mount" ];
    paperless-task-queue.after = [ "var-lib-paperless.mount" ];
    paperless-web.after = [ "var-lib-paperless.mount" ];
  };
}
