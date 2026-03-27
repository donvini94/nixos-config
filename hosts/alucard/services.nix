{ config, lib, pkgs, ... }:
let
  domain = "dumusstbereitsein.de";
  domain2 = "istbereit.de";
in
{
  # ACME / Let's Encrypt
  security.acme = {
    acceptTerms = true;
    defaults.email = "vincenzo.pace94@icloud.com";
  };

  services = {
    postgresql.enable = true;

    keycloak = {
      enable = true;
      database = {
        createLocally = true;
        username = "keycloak";
        passwordFile = config.sops.secrets."keycloak/password".path;
      };
      settings = {
        hostname = "auth.${domain}";
        http-port = 38080;
        http-enabled = true;
        proxy-headers = "xforwarded";
        hostname-strict-https = false;
        hostname-strict = true;
      };
    };

    jellyfin = {
      enable = true;
      openFirewall = true;
      dataDir = "/home/jellyfin/";
    };

    navidrome = {
      enable = true;
      openFirewall = true;
      settings.MusicFolder = "/mnt/music";
    };

    calibre-web = {
      enable = true;
      listen.ip = "127.0.0.1";
      listen.port = 8083;
      openFirewall = true;
      dataDir = "calibre-web";
      options = {
        enableBookUploading = true;
        enableBookConversion = true;
      };
    };

    paperless = {
      enable = true;
      address = "127.0.0.1";
      port = 58080;
      consumptionDirIsPublic = true;
      settings = {
        PAPERLESS_OCR_LANGUAGE = "deu+eng";
        PAPERLESS_URL = "https://paperless.${domain}";
        PAPERLESS_ALLOWED_HOSTS = "paperless.${domain}";
        PAPERLESS_CSRF_TRUSTED_ORIGINS = "https://paperless.${domain}";
      };
      passwordFile = config.sops.secrets."paperless/password".path;
    };

    dockerRegistry = {
      enable = true;
      openFirewall = true;
    };

    # Nginx reverse proxy
    nginx = {
      enable = true;
      additionalModules = [ pkgs.nginxModules.dav ];
      clientMaxBodySize = "0";
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts = {
        "${domain}" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://127.0.0.1:4000";
        };
        "auth.${domain}" = {
          enableACME = true;
          forceSSL = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:38080/";
            proxyWebsockets = true;
          };
        };
        "git.${domain}" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://unix:/run/gitlab/gitlab-workhorse.socket";
        };
        "registry.${domain}" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://localhost:5000";
          basicAuthFile = ../../secrets/htpasswd;
        };
        "stream.${domain}" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://localhost:8096";
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
          locations."/".proxyPass = "http://127.0.0.1:3000";
        };
        "paperless.${domain}" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://127.0.0.1:58080";
        };
        "files.${domain}" = {
          enableACME = true;
          forceSSL = true;
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
          locations."/".proxyPass = "http://127.0.0.1:8083";
        };
        "mail.${domain2}" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://127.0.0.1:880";
        };
        "coder.${domain2}" = {
          enableACME = true;
          forceSSL = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:1337";
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
          basicAuthFile = ../../secrets/htpasswd;
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
      };
    };
  };

  # Keycloak realm export (manual activation only)
  systemd.services.keycloakExportRealms =
    let
      p = config.systemd.services.keycloak;
    in
    lib.mkIf config.services.keycloak.enable {
      after = p.after;
      before = [ "keycloak.service" ];
      wantedBy = [ ];
      environment = lib.mkForce p.environment;
      serviceConfig =
        let
          origin = p.serviceConfig;
        in
        {
          Type = "oneshot";
          RemainAfterExit = true;
          User = origin.User;
          Group = origin.Group;
          LoadCredential = origin.LoadCredential;
          DynamicUser = origin.DynamicUser;
          RuntimeDirectory = origin.RuntimeDirectory;
          RuntimeDirectoryMode = origin.RuntimeDirectoryMode;
          AmbientCapabilities = origin.AmbientCapabilities;
          StateDirectory = "keycloak";
          StateDirectoryMode = "0750";
        };
      script = ''
        EDIR="/var/lib/keycloak"
        EDIRT="$EDIR/$(date '+%Y-%m-%d_%H-%M-%S')"
        mkdir -p $EDIRT
        kc.sh export --dir=$EDIRT
        echo "Keycloak export completed successfully to: $EDIRT"
      '';
    };

  # Allow nginx to write to paperless consume dir (WebDAV uploads)
  systemd.services.nginx.serviceConfig = {
    ReadWritePaths = [ (config.services.paperless.dataDir + "/consume") ];
    UMask = lib.mkForce "0022";
  };

  # Paperless depends on mount
  systemd.services.paperless-consumer.after = [ "var-lib-paperless.mount" ];
  systemd.services.paperless-scheduler.after = [ "var-lib-paperless.mount" ];
  systemd.services.paperless-task-queue.after = [ "var-lib-paperless.mount" ];
  systemd.services.paperless-web.after = [ "var-lib-paperless.mount" ];
}
