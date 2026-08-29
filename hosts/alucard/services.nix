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
  jellyfinRuntimePolicy = pkgs.writeShellApplication {
    name = "jellyfin-runtime-policy";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.xmlstarlet
    ];
    text = ''
      set -euo pipefail

      network_config=/home/jellyfin/config/network.xml
      test -f "$network_config"

      current_addresses="$(xml sel -t -v 'count(/NetworkConfiguration/LocalNetworkAddresses/string[text() = "127.0.0.1"])' "$network_config")"
      current_ipv6="$(xml sel -t -v '/NetworkConfiguration/EnableIPv6' "$network_config")"
      if [ "$current_addresses" != 1 ] || [ "$current_ipv6" != false ]; then
        xml ed -P -L \
          -d '/NetworkConfiguration/LocalNetworkAddresses/*' \
          -s '/NetworkConfiguration/LocalNetworkAddresses' -t elem -n string -v 127.0.0.1 \
          -u '/NetworkConfiguration/EnableIPv6' -v false \
          "$network_config"
        chown jellyfin:jellyfin "$network_config"
      fi

      sso_config=/home/jellyfin/plugins/configurations/SSO-Auth.xml
      if [ -f "$sso_config" ]; then
        provider="/PluginConfiguration/OidConfigs/item[key/string = 'keycloak']/value/PluginConfiguration"
        provider_count="$(xml sel -t -v "count($provider)" "$sso_config")"
        if [ "$provider_count" = 1 ]; then
          setting_count="$(xml sel -t -v "count($provider/DisablePushedAuthorization)" "$sso_config")"
          if [ "$setting_count" = 0 ]; then
            xml ed -P -L \
              -s "$provider" -t elem -n DisablePushedAuthorization -v true \
              "$sso_config"
            chown jellyfin:jellyfin "$sso_config"
          elif [ "$setting_count" = 1 ] \
            && [ "$(xml sel -t -v "$provider/DisablePushedAuthorization" "$sso_config")" != true ]; then
            xml ed -P -L \
              -u "$provider/DisablePushedAuthorization" -v true \
              "$sso_config"
            chown jellyfin:jellyfin "$sso_config"
          elif [ "$setting_count" != 1 ]; then
            echo "expected at most one DisablePushedAuthorization setting for the keycloak provider" >&2
            exit 1
          fi
        elif [ "$provider_count" != 0 ]; then
          echo "expected at most one keycloak OIDC provider" >&2
          exit 1
        fi
      fi
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

  # Jellyfin SSO-Auth 4.x follows the provider's advertised PAR endpoint by
  # default, but Keycloak rejects this confidential client's pushed request.
  # Disable PAR through the plugin's supported setting before Jellyfin starts;
  # the ordinary authorization-code flow remains protected by state and PKCE.
  systemd.services.jellyfin-runtime-policy = {
    description = "Enforce Jellyfin network and SSO policy";
    before = [ "jellyfin.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe jellyfinRuntimePolicy;
    };
  };

  systemd.services.jellyfin = {
    requires = [ "jellyfin-runtime-policy.service" ];
    after = [ "jellyfin-runtime-policy.service" ];
    # A group-policy change is a security boundary, so the running process
    # must drop its old supplementary groups during the same activation.
    restartTriggers = [ (builtins.toJSON config.users.users.jellyfin.extraGroups) ];
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

  # Startup-critical state that a host loss would otherwise destroy. The
  # Paperless job lives in modules/paperless.nix because its snapshot depends on
  # that module's exporter directory and signing key.
  services.offsiteBackup = {
    enable = true;
    onCalendar = "*:0/2";
    verifyOnCalendar = "*:1/2";
    jobs.keycloak = {
      # pg_dump, not a file copy: Keycloak's cluster is live during the window,
      # and the realm export alone omits users, sessions and credentials.
      runtimeInputs = [ config.services.postgresql.package ];
      requires = [ "postgresql.service" ];
      after = [ "postgresql.service" ];
      prepare = ''
        install -d -m 0700 "$stage"
        runuser -u postgres -- pg_dump --format=custom --no-owner keycloak \
          > "$stage/keycloak.dump"
        test -s "$stage/keycloak.dump"
      '';
      verifyPaths = [ "${"/var/lib/offsite-backup/keycloak/keycloak.dump"}" ];
    };

    jobs.n8n = {
      # `.backup` takes a consistent copy of a database the container is still
      # writing to; copying database.sqlite under WAL would capture a torn page.
      # The rows stay encrypted: n8n/encryption_key lives only in SOPS, so this
      # snapshot is useless without the separately held key.
      runtimeInputs = [ pkgs.sqlite ];
      after = [ "docker-n8n.service" ];
      prepare = ''
        install -d -m 0700 "$stage"
        sqlite3 /var/lib/n8n-container/database.sqlite \
          ".backup '$stage/database.sqlite'"
        test -s "$stage/database.sqlite"
      '';
      verifyPaths = [ "${"/var/lib/offsite-backup/n8n/database.sqlite"}" ];
    };
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
