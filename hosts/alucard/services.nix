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
  jellyfinNetworkPolicy = pkgs.writeShellApplication {
    name = "jellyfin-network-policy";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.xmlstarlet
    ];
    text = ''
      set -euo pipefail

      config_file=/home/jellyfin/config/network.xml
      test -f "$config_file"

      current_addresses="$(xml sel -t -v 'count(/NetworkConfiguration/LocalNetworkAddresses/string[text() = "127.0.0.1"])' "$config_file")"
      current_ipv6="$(xml sel -t -v '/NetworkConfiguration/EnableIPv6' "$config_file")"
      if [ "$current_addresses" = 1 ] && [ "$current_ipv6" = false ]; then
        exit 0
      fi

      xml ed -P -L \
        -d '/NetworkConfiguration/LocalNetworkAddresses/*' \
        -s '/NetworkConfiguration/LocalNetworkAddresses' -t elem -n string -v 127.0.0.1 \
        -u '/NetworkConfiguration/EnableIPv6' -v false \
        "$config_file"
      chown jellyfin:jellyfin "$config_file"
    '';
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
    {
      assertion =
        lib.intersectLists [
          "docker"
          "wheel"
        ] config.users.users.jellyfin.extraGroups == [ ]
        && config.users.users.jellyfin.openssh.authorizedKeys.keys == [ ];
      message = "The public Jellyfin service account must not have host administrator access";
    }
  ];

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
        http-host = "127.0.0.1";
        http-enabled = true;
        proxy-headers = "xforwarded";
        hostname-strict-https = false;
        hostname-strict = true;
      };
    };

    jellyfin = {
      enable = true;
      openFirewall = false;
      dataDir = "/home/jellyfin/";
    };

    navidrome = {
      enable = true;
      openFirewall = false;
      settings.MusicFolder = "/mnt/music";
    };

    calibre-web = {
      enable = true;
      listen.ip = "127.0.0.1";
      listen.port = 8083;
      openFirewall = false;
      dataDir = "calibre-web";
      options = {
        enableBookUploading = true;
        enableBookConversion = true;
      };
    };

    # Paperless itself lives in modules/paperless.nix — taxonomy, mail rules,
    # provisioning, and backup travel with it. Only the vhost stays here.
    paperlessStack = {
      enable = true;
      domain = "paperless.${domain}";
      port = 58080;
      # Nightly document_exporter at 02:30, pushed to the Hetzner box at 03:30.
      offsite.enable = true;
    };

    # mailcow's own ACME cannot work behind this nginx, so hand it our cert.
    mailcowTls = {
      enable = true;
      domain = "mail.${domain2}";
    };

    dockerRegistry = {
      enable = true;
      openFirewall = false;
    };

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
          basicAuthFile = ../../secrets/htpasswd;
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
        "knowyourfiber.com" = {
          enableACME = true;
          forceSSL = true;
          root = "/var/www/knowyourfiber.com";
        };
      };
    };
  };

  systemd.services.jellyfin-network-policy = {
    description = "Bind Jellyfin to IPv4 loopback behind nginx";
    before = [ "jellyfin.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe jellyfinNetworkPolicy;
    };
  };

  systemd.services.jellyfin = {
    requires = [ "jellyfin-network-policy.service" ];
    after = [ "jellyfin-network-policy.service" ];
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
