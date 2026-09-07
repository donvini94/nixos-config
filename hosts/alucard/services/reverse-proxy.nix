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
  tls = {
    enableACME = true;
    forceSSL = true;
  };
  proxy = port: tls // { locations."/".proxyPass = "http://127.0.0.1:${toString port}"; };
  proxyWs =
    port:
    tls
    // {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString port}";
        proxyWebsockets = true;
      };
    };
  gone = tls // { locations."/".return = "404"; };
  # nginx evaluates the server-level `modsecurity` directive before a nested
  # location can turn it off, so the WAF is disabled for the server and
  # re-enabled on the catch-all; `exempt` locations stay uncovered.
  wafOffExcept =
    { exempt, catchAll }:
    tls
    // {
      extraConfig = "modsecurity off;";
      locations = lib.mapAttrs (_: loc: loc // { extraConfig = "modsecurity off;"; }) exempt // {
        "/" = catchAll // { extraConfig = "modsecurity on;"; };
      };
    };
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

  security.acme = {
    acceptTerms = true;
    defaults.email = "vincenzo.pace94@icloud.com";
  };

  services = {
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
        "${domain}" = gone;
        # CRS scores the admin REST API's writes (`PUT
        # /admin/realms/{realm}/clients/{id}` with a full client
        # representation) as attacks and answers with nginx's HTML 403, which
        # the admin console renders as an error with no message. Exempt only
        # that API, which already demands a bearer token with
        # realm-management rights; the unauthenticated login, token and
        # account endpoints keep the WAF.
        "auth.${domain}" = wafOffExcept {
          exempt."^~ /admin/realms/" = {
            proxyPass = "http://127.0.0.1:38080";
            proxyWebsockets = true;
          };
          catchAll = {
            proxyPass = "http://127.0.0.1:38080/";
            proxyWebsockets = true;
          };
        };
        "git.${domain}" = gone;
        "registry.${domain}" = proxy 5000 // {
          extraConfig = ''
            modsecurity off;
            client_max_body_size 0;
          '';
          basicAuthFile = config.sops.secrets."nginx/htpasswd".path;
        };
        "stream.${domain}" = wafOffExcept {
          exempt = {
            # CRS 4.25.1 lists `config.json` in both `restricted-files.data` and
            # `lfi-os-files.data`, so 930120/930130 score the Jellyfin web
            # client's own bootstrap file at CRITICAL and 949110 answers 403;
            # without it the client cannot start. An exact match outranks the
            # `^~` and prefix routes.
            "= /web/config.json".proxyPass = "http://127.0.0.1:8096";
            "^~ /Sessions/Playing".proxyPass = "http://127.0.0.1:8096";
          };
          catchAll.proxyPass = "http://127.0.0.1:8096";
        };
        "chat.${domain}" = proxy 1447;
        "music.${domain}" = proxy 4533;
        "docs.${domain}" = gone;
        "paperless.${domain}" = proxy 58080;
        "files.${domain}" = proxy 53842 // {
          extraConfig = ''
            modsecurity off;
            client_max_body_size 10g;
          '';
        };
        "budget.${domain2}" = proxy 5006;
        "read.${domain2}" = proxy 8083 // {
          extraConfig = "client_max_body_size 2g;";
        };
        "mail.${domain2}" = proxy 880;
        "comics.${domain2}" = proxyWs 25600;
        "requests.${domain}" = proxyWs 5055;
        "webdav.${domain2}" = tls // {
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

              limit_except PUT MKCOL PROPFIND OPTIONS {
                deny all;
              }
            '';
          };
        };
        "knowyourfiber.com" = tls // {
          root = "/var/www/knowyourfiber.com";
        };
      };
    };
  };

  # WebDAV uploads are written into the paperless consume dir.
  systemd.services.nginx.serviceConfig = {
    ReadWritePaths = [ (config.services.paperless.dataDir + "/consume") ];
    UMask = lib.mkForce "0022";
  };
}
