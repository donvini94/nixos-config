{
  config,
  lib,
  pkgs,
  ...
}:
let
  domain = "dumusstbereitsein.de";
  domain2 = "istbereit.de";
  harden = lib.mapAttrs (
    _: host:
    host
    // {
      extraConfig = (host.extraConfig or "") + ''
        limit_req zone=public_per_ip burst=120 nodelay;
        limit_conn public_connections 50;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header Permissions-Policy "camera=(), geolocation=(), microphone=()" always;
      '';
    }
  );
in
{
  assertions = [
    {
      assertion =
        lib.intersectLists [
          4533
          5000
          8083
          8096
          8920
        ] config.networking.firewall.allowedTCPPorts == [ ];
      message = "Alucard web backends must remain behind nginx instead of being globally firewalled";
    }
  ];

  # ACME / Let's Encrypt
  security.acme = {
    acceptTerms = true;
    defaults.email = "vincenzo.pace94@icloud.com";
  };

  services = {
    # Nginx reverse proxy
    nginx = {
      enable = true;
      additionalModules = [ pkgs.nginxModules.dav ];
      clientMaxBodySize = "64m";
      serverTokens = false;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts = harden {
        "${domain}" = {
          enableACME = true;
          forceSSL = true;
          locations."/".return = "404";
        };
        "auth.${domain}" = {
          enableACME = true;
          forceSSL = true;
          # CRS blocks the admin REST API's writes: a `PUT
          # /admin/realms/{realm}/clients/{id}` carrying a full client
          # representation returned nginx's own HTML 403, which is why the
          # admin console reported "Client could not be updated:" with no
          # message — it had no JSON error to render. Verified on 2026-08-16
          # against the Onyx client; the same call to 127.0.0.1:38080 answered
          # 204. Exempt only that API, which already demands a bearer token
          # with realm-management rights, and keep the WAF on the login,
          # token, and account endpoints that face the internet unauthenticated.
          # As on the Jellyfin vhost, the connector evaluates the server-level
          # WAF before a nested location can turn it off, so it is disabled
          # here and re-enabled on the catch-all route.
          extraConfig = "modsecurity off;";
          locations."^~ /admin/realms/" = {
            proxyPass = "http://127.0.0.1:38080";
            proxyWebsockets = true;
            extraConfig = "modsecurity off;";
          };
          locations."/" = {
            proxyPass = "http://127.0.0.1:38080/";
            proxyWebsockets = true;
            extraConfig = "modsecurity on;";
          };
        };
        "git.${domain}" = {
          enableACME = true;
          forceSSL = true;
          locations."/".return = "404";
        };
        "registry.${domain}" = {
          enableACME = true;
          forceSSL = true;
          extraConfig = ''
            modsecurity off;
            client_max_body_size 0;
          '';
          locations."/".proxyPass = "http://localhost:5000";
          basicAuthFile = config.sops.secrets."nginx/htpasswd".path;
        };
        "stream.${domain}" = {
          enableACME = true;
          forceSSL = true;
          # The connector evaluates a global/server WAF before a nested location
          # can disable it. Disable it at this vhost, then re-enable it for the
          # catch-all route so only the authenticated playback endpoint family
          # is exempt.
          extraConfig = "modsecurity off;";
          # CRS 4.25.1 ships `config.json` in both `restricted-files.data` and
          # `lfi-os-files.data`, so 930120/930130 score the Jellyfin web
          # client's own bootstrap file at CRITICAL and 949110 answers 403.
          # The client cannot start without it: the public UI was dead while
          # `/web/index.html` and the API both answered 200. Verified on
          # 2026-08-16, 16 such 403s from the operator's address in 90
          # minutes, and reproduced with a bare `curl` on 2026-08-17. An exact
          # match outranks the `^~` and prefix routes below.
          locations."= /web/config.json" = {
            proxyPass = "http://127.0.0.1:8096";
            extraConfig = "modsecurity off;";
          };
          locations."^~ /Sessions/Playing" = {
            proxyPass = "http://127.0.0.1:8096";
            extraConfig = "modsecurity off;";
          };
          locations."/" = {
            proxyPass = "http://127.0.0.1:8096";
            extraConfig = "modsecurity on;";
          };
        };
        "chat.${domain}" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://localhost:1447";
        };
        "music.${domain}" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://localhost:4533";
        };
        "docs.${domain}" = {
          enableACME = true;
          forceSSL = true;
          locations."/".return = "404";
        };
        "paperless.${domain}" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://127.0.0.1:58080";
        };
        "files.${domain}" = {
          enableACME = true;
          forceSSL = true;
          extraConfig = ''
            modsecurity off;
            client_max_body_size 10g;
          '';
          locations."/".proxyPass = "http://127.0.0.1:53842";
        };
        "budget.${domain2}" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://127.0.0.1:5006";
        };
        "read.${domain2}" = {
          enableACME = true;
          forceSSL = true;
          extraConfig = "client_max_body_size 2g;";
          locations."/".proxyPass = "http://127.0.0.1:8083";
        };
        "mail.${domain2}" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://127.0.0.1:880";
        };
        "comics.${domain2}" = {
          enableACME = true;
          forceSSL = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:25600";
            proxyWebsockets = true;
          };
        };
        "requests.${domain}" = {
          enableACME = true;
          forceSSL = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:5055";
            proxyWebsockets = true;
          };
        };
        "webdav.${domain2}" = {
          enableACME = true;
          forceSSL = true;
          extraConfig = "modsecurity off;";
          basicAuthFile = config.sops.secrets."nginx/htpasswd".path;
          locations."/" = {
            root = config.services.paperless.consumptionDir;
            extraConfig = ''
              dav_methods PUT MKCOL;
              dav_ext_methods PROPFIND OPTIONS;
              create_full_put_path on;
              dav_access user:rw group:rw all:r;
              client_max_body_size 100m;

              # Block read/delete methods, allow upload and discovery
              limit_except PUT MKCOL PROPFIND OPTIONS {
                deny all;
              }
            '';
          };
        };
        "knowyourfiber.com" = {
          enableACME = true;
          forceSSL = true;
          root = "/var/www/knowyourfiber.com";
        };
      };
    };
  };

  # Allow nginx to write to paperless consume dir (WebDAV uploads)
  systemd.services.nginx.serviceConfig = {
    ReadWritePaths = [ (config.services.paperless.dataDir + "/consume") ];
    UMask = lib.mkForce "0022";
  };
}
