{ config, lib, pkgs, ... }:
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
        hostname = "auth.dumusstbereitsein.de";
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
        PAPERLESS_URL = "https://paperless.dumusstbereitsein.de";
        PAPERLESS_ALLOWED_HOSTS = "paperless.dumusstbereitsein.de";
        PAPERLESS_CSRF_TRUSTED_ORIGINS = "https://paperless.dumusstbereitsein.de";
      };
      passwordFile = config.sops.secrets."paperless/password".path;
    };

    dockerRegistry = {
      enable = true;
      openFirewall = true;
    };

    # Vaultwarden (disabled, pending fix)
    # vaultwarden = {
    #   enable = true;
    #   backupDir = "/var/lib/vaultwarden/backup";
    #   environmentFile = config.sops.templates."vaultwarden.env".path;
    #   config = {
    #     DOMAIN = "https://passwort.istbereit.de";
    #     SIGNUPS_ALLOWED = false;
    #     ROCKET_ADDRESS = "127.0.0.1";
    #     ROCKET_PORT = 8222;
    #     ROCKET_LOG = "critical";
    #     SMTP_HOST = "127.0.0.1";
    #     SMTP_PORT = 25;
    #     SMTP_SSL = false;
    #     SMTP_FROM = "admin@passwort.istbereit.de";
    #     SMTP_FROM_NAME = "Bereitwarden";
    #   };
    # };

    # Nginx reverse proxy
    nginx = {
      enable = true;
      clientMaxBodySize = "0";
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts = {
        "dumusstbereitsein.de" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://127.0.0.1:4000";
        };
        "auth.dumusstbereitsein.de" = {
          enableACME = true;
          forceSSL = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:38080/";
            proxyWebsockets = true;
          };
        };
        "git.dumusstbereitsein.de" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://unix:/run/gitlab/gitlab-workhorse.socket";
        };
        "registry.dumusstbereitsein.de" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://localhost:5000";
          basicAuthFile = ../../secrets/htpasswd;
        };
        "stream.dumusstbereitsein.de" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://localhost:8096";
        };
        "chat.dumusstbereitsein.de" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://localhost:1447";
        };
        "music.dumusstbereitsein.de" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://localhost:4533";
        };
        "docs.dumusstbereitsein.de" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://127.0.0.1:3000";
        };
        "paperless.dumusstbereitsein.de" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://127.0.0.1:58080";
        };
        "files.dumusstbereitsein.de" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://127.0.0.1:53842";
        };
        "budget.istbereit.de" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://127.0.0.1:5006";
        };
        "read.istbereit.de" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://127.0.0.1:8083";
        };
        "mail.istbereit.de" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://127.0.0.1:880";
        };
        "coder.istbereit.de" = {
          enableACME = true;
          forceSSL = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:1337";
            proxyWebsockets = true;
          };
        };
        "passwort.istbereit.de" = {
          enableACME = true;
          forceSSL = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:8222"; # vaultwarden ROCKET_PORT
          };
        };
        "requests.dumusstbereitsein.de" = {
          enableACME = true;
          forceSSL = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:5055";
            proxyWebsockets = true;
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

  # Paperless depends on mount
  systemd.services.paperless-consumer.after = [ "var-lib-paperless.mount" ];
  systemd.services.paperless-scheduler.after = [ "var-lib-paperless.mount" ];
  systemd.services.paperless-task-queue.after = [ "var-lib-paperless.mount" ];
  systemd.services.paperless-web.after = [ "var-lib-paperless.mount" ];
}
