{
  config,
  lib,
  pkgs,
  site,
  ...
}:
{
  services = {
    # mailcow's own ACME cannot work behind this nginx, so hand it our cert.
    mailcowTls = {
      enable = true;
      domain = "mail.${site.domains.secondary}";
    };

    dockerRegistry = {
      enable = true;
      openFirewall = false;
    };

    # Keep UI-managed settings, with Nix taking precedence for domain and theme policy.
    mattermost = {
      enable = true;
      siteName = "Bereit Chat";
      siteUrl = "https://chat.${site.domains.secondary}";
      host = "127.0.0.1";
      port = 8065;
      mutableConfig = true;
      preferNixConfig = true;
      settings = {
        TeamSettings = {
          # Signup stays open (no invite needed) but only the secondary domain
          # addresses can create an account.
          EnableOpenServer = true;
          RestrictCreationToDomains = site.domains.secondary;
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

}
