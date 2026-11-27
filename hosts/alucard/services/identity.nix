{
  config,
  pkgs,
  site,
  ...
}:
{
  services = {
    postgresql = {
      enable = true;
      # Pinned: a major version change needs pg_upgrade, not just a new package.
      package = pkgs.postgresql_17;
    };

    keycloak = {
      enable = true;
      database = {
        createLocally = true;
        username = "keycloak";
        passwordFile = config.sops.secrets."keycloak/password".path;
      };
      settings = {
        hostname = "https://auth.${site.domains.primary}";
        http-port = 38080;
        http-host = "127.0.0.1";
        http-enabled = true;
        proxy-headers = "xforwarded";
        hostname-strict-https = false;
        hostname-strict = true;
        # The admin console and API live on the tailnet only (reverse-proxy.nix
        # keeps /admin/ off the public host).
        hostname-admin = "https://${site.server}.${site.tailnet}:28080";
        # Single node: no Infinispan cluster listeners.
        cache = "local";
      };
    };

    aiStack.tailnet.https.keycloak-admin = {
      listen = 28080;
      target = 38080;
    };

    # Keycloak sign-in for apps that only trust a login header (Navidrome,
    # Calibre-Web); nginx asks it on every request (reverse-proxy.nix). The identity
    # is the Keycloak username: several accounts have no or an unverified email, so
    # the email claim carries the username and email is never an access criterion.
    oauth2-proxy = {
      enable = true;
      provider = "keycloak-oidc";
      clientID = "oauth2-proxy";
      approvalPrompt = "auto";
      clientSecretFile = config.sops.secrets."oauth2_proxy/client_secret".path;
      cookie.secretFile = config.sops.secrets."oauth2_proxy/cookie_secret".path;
      oidcIssuerUrl = "https://auth.${site.domains.primary}/realms/Abschleppdienst";
      email.domains = [ "*" ];
      reverseProxy = true;
      trustedProxyIP = [ "127.0.0.1/32" ];
      setXauthrequest = true;
      extraConfig = {
        oidc-email-claim = "preferred_username";
        insecure-oidc-allow-unverified-email = true;
        # nginx only needs the username; Keycloak's tokens overflow its header buffer.
        session-cookie-minimal = true;
        code-challenge-method = "S256";
      };
    };
  };

  sops.secrets = {
    "oauth2_proxy/client_secret" = { };
    "oauth2_proxy/cookie_secret" = { };
  };

  systemd.services.keycloak.serviceConfig = {
    CapabilityBoundingSet = "";
    PrivateDevices = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
    ];
    LockPersonality = true;
    ProtectProc = "invisible";
    ProcSubset = "pid";
  };
}
