{
  inputs,
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ../../modules/packages.nix
    ../../configuration.nix
    ../../secrets/secrets.nix
  ];
  boot = {
    initrd.availableKernelModules = [
      "ata_piix"
      "uhci_hcd"
      "virtio_pci"
      "sr_mod"
      "virtio_blk"
    ];
    initrd.kernelModules = [ ];
    kernelModules = [ ];
    extraModulePackages = [ ];
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    supportedFilesystems = [ "cifs" ];
  };
  environment.systemPackages = with pkgs; [
    yazi
    openssl
    apacheHttpd
    filebot
    cifs-utils
    docker-compose
  ];

  fileSystems."/mnt/hetzner" = {
    device = "//u487137.your-storagebox.de/backup";
    fsType = "cifs";
    options = [
      "credentials=${config.sops.templates."smb-hetzner".path}"
      "vers=3.1.1"
      "sec=ntlmssp"
      "seal" # encrypt session
      "iocharset=utf8"
      "file_mode=0644"
      "dir_mode=0755"
      "uid=jellyfin"
      "gid=jellyfin"
      "_netdev"
      "x-systemd.automount" # on-demand
      "noauto"
      "nofail"
      "serverino"
    ];
  };

  # Create required directories for media automation
  systemd.tmpfiles.rules = [
    "d /var/lib/media-stack 0755 root root"
    "d /var/lib/media-stack/jellyseerr 0755 jellyfin jellyfin"
    "d /var/lib/media-stack/sonarr 0755 jellyfin jellyfin"
    "d /var/lib/media-stack/radarr 0755 jellyfin jellyfin"
    "d /var/lib/media-stack/prowlarr 0755 jellyfin jellyfin"
    "d /var/lib/media-stack/qbittorrent 0755 jellyfin jellyfin"
    "d /var/lib/media-stack/gluetun 0755 jellyfin jellyfin"
    "d /mnt/hetzner/downloads 0755 jellyfin jellyfin"
    "d /mnt/hetzner/shows 0755 jellyfin jellyfin"
    "d /mnt/hetzner/movies 0755 jellyfin jellyfin"
  ];

  networking = {
    hostName = "alucard";
    useDHCP = lib.mkDefault true;
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
        25
        53
        80
        110
        143
        443
        465
        587
        873
        993
        995
        4190
        11445
        11335
      ];
    };
  };

  nix = {
    settings = {
      download-buffer-size = 524288000;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      sandbox = true;
      max-jobs = 10; # should be 1 per CPU logical core
      auto-optimise-store = true;
      substituters = [
        "https://cache.nixos.org/"
        "https://ghcide-nix.cachix.org"
        "https://hercules-ci.cachix.org"
        "https://iohk.cachix.org"
        "https://nix-tools.cachix.org"
      ];
      trusted-public-keys = [
        "ghcide-nix.cachix.org-1:ibAY5FD+XWLzbLr8fxK6n8fL9zZe7jS+gYeyxyWYK5c="
        "hercules-ci.cachix.org-1:ZZeDl9Va+xe9j+KqdzoBZMFJHVQ42Uu/c/1/KMC5Lw0="
        "iohk.cachix.org-1:DpRUyj7h7V830dp/i6Nti+NEO2/nhblbov/8MW7Rqoo="
        "nix-tools.cachix.org-1:ebBEBZLogLxcCvipq2MTvuHlP7ZRdkazFSQsbs0Px1A="
      ];
    };
    gc = {
      automatic = true;
      dates = "23:00";
      options = "--delete-older-than 30d";
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  services = {
    calibre-web = {
      enable = true;
      listen.ip = "127.0.0.1";
      listen.port = 8083;
      openFirewall = true;
      # Data lies in /var/lib/calibre-web with its own user
      dataDir = "calibre-web";
      options.enableBookUploading = true;
      options.enableBookConversion = true;
    };
    coder = {
      enable = true;
      homeDir = "/var/lib/coder";
      accessUrl = "https://coder.istbereit.de";
      listenAddress = "127.0.0.1:1337";
      database.createLocally = true;
    };
    code-server = {
      enable = true;
      port = 4444;
    };
    fail2ban.enable = true;
    jellyfin = {
      enable = true;
      openFirewall = true;
      dataDir = "/home/jellyfin/";
    };
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
        proxy-headers = "xforwarded";        # Nginx sets X-Forwarded-* by default on NixOS
        hostname-strict-https = false;       # because backend is HTTP, but external is HTTPS
        hostname-strict = true;              # lock to the hostname you set (good practice)
        # (Optionally) proxy = "edge";       # typical when TLS ends at the proxy      };
    };
      };
    navidrome = {
      enable = true;
      openFirewall = true;
      settings = {
        MusicFolder = "/mnt/music";
      };
    };
    nginx = {
      enable = true;
      clientMaxBodySize = "0"; # needed so that docker images can be pushed, turns off limit
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts."dumusstbereitsein.de" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:4000";
      };
      virtualHosts."auth.dumusstbereitsein.de" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:38080/";
          proxyWebsockets = true;
        };
      };
      virtualHosts."git.dumusstbereitsein.de" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://unix:/run/gitlab/gitlab-workhorse.socket";
      };
      virtualHosts."registry.dumusstbereitsein.de" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://localhost:5000";
        basicAuthFile = ../../secrets/htpasswd;
      };
      virtualHosts."stream.dumusstbereitsein.de" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://localhost:8096";
      };
      virtualHosts."music.dumusstbereitsein.de" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://localhost:4533";
      };
      virtualHosts."docs.dumusstbereitsein.de" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:3000";
      };
      virtualHosts."paperless.dumusstbereitsein.de" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:58080";
      };
      virtualHosts."files.dumusstbereitsein.de" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:53842";
      };
      virtualHosts."read.istbereit.de" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:8083";
      };
      virtualHosts."mail.istbereit.de" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:880";
      };
      virtualHosts."coder.istbereit.de" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:1337";
          proxyWebsockets = true;
        };
      };
      virtualHosts."passwort.istbereit.de" = {
          enableACME = true;
          forceSSL = true;
          locations."/" = {
              proxyPass = "http://127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}";
          };
      };
      virtualHosts."requests.dumusstbereitsein.de" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:5055";
          proxyWebsockets = true;
        };
      };
    };
    openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
      settings.KbdInteractiveAuthentication = false;
      settings.PermitRootLogin = "no";
    };
    postgresql.enable = true;
    rustdesk-server = {
      enable = true;
      openFirewall = true;
      signal.relayHosts = [ "89.58.62.186" ];
    };
    # Disabled native Sonarr - using containerized version in media-stack
    sonarr.enable = false;
    #    gitlab = {
    #      enable = true;
    #      databasePasswordFile = "/var/keys/gitlab/db_password";
    #      initialRootPasswordFile = "/var/keys/gitlab/root_password";
    #      https = true;
    #      host = "git.dumusstbereitsein.de";
    #      port = 443;
    #      user = "git";
    #      databaseUsername = "git";
    #      group = "git";
    #      smtp = {
    #        enable = true;
    #        address = "localhost";
    #        port = 25;
    #      };
    #      secrets = {
    #        dbFile = "/var/keys/gitlab/db";
    #        secretFile = "/var/keys/gitlab/secret";
    #        activeRecordPrimaryKeyFile = "/var/keys/gitlab/secret";
    #        activeRecordDeterministicKeyFile = "/var/keys/gitlab/secret";
    #        activeRecordSaltFile = "/var/keys/gitlab/secret";
    #        otpFile = "/var/keys/gitlab/otp";
    #        jwsFile = "/var/keys/gitlab/jws";
    #      };
    #      extraConfig = {
    #        gitlab = {
    #          email_from = "gitlab-no-reply@dumusstbereitsein.de";
    #          email_display_name = "Vincenzos GitLab";
    #          email_reply_to = "gitlab-no-reply@dumusstbereitsein.de";
    #        };
    #      };
    #    };
    #
    #    gitlab-runner = {
    #      enable = true;
    #      gracefulTermination = true;
    #    };

    dockerRegistry = {
      enable = true;
      openFirewall = true;
    };
    syncthing = {
      enable = true;
      user = "vincenzo";
      openDefaultPorts = true;
      dataDir = "/home/vincenzo/";
      configDir = "/home/vincenzo/.config/syncthing";
      settings = {
        devices = {
          "dracula" = {
            id = "QGVRLBK-OZX7PIM-JMGKYHF-KSFI5VS-FJH6RGI-4YGB6H6-EYAJ27S-TM5LTQ6";
            autoAcceptFolders = true;
          };
          "bereitbook-pro-m4" = {
            id = "BS4FOGC-XQFLI5X-KQ7PP7R-5P37LRS-TTZGR24-7S2QCBE-5MLVWHM-5FVKNAW";
            autoAcceptFolders = true;
          };
          "asgar" = {
            id = "H5KT7VJ-OFUH3PD-6HH4KRI-VKOOOMY-Z5KNIQL-DVTBCAN-PQ44EAY-AAAS7AO";
            autoAcceptFolders = true;
          };
          "kyrill-thinkpad-t495" = {
            id = "DULG3KX-PYY3RT7-4CW2JVC-64F5J2T-24JRG3J-IDDKBJN-X535SHF-5IBO3QZ";
            autoAcceptFolders = true;
          };
          "kyrill-handy" = {
            id = "VKWKKOP-4ZNV7AY-MSDT3EA-LOJQFAS-BJ7MPWT-ZJ353LV-7HRXYA3-3763VAH";
            autoAcceptFolders = true;
          };
          "kyrill-tablet" = {
            id = "T7SVLB6-ZWQM7DO-ZDULZNB-I6QGSQZ-JJUFPO2-7N3GVP7-HONELH2-3GDJSAE";
            autoAcceptFolders = true;
          };
          "kyrill-mint-laptop" = {
            id = "X6J6CVJ-K7BTU4D-5VIYQ6I-VEMAAF6-EV7CLXN-5XD4277-AKFOZLB-X66Y6A4";
            autoAcceptFolders = true;
          };
          "kyrill-macbook" = {
            id = "J7G2USF-UU35NDR-4AWVN7M-DPV7FLX-7IZFPQ2-I3JOU7R-3KCJ73I-2JRBUAU";
            autoAcceptFolders = true;
          };
          "marius-macbook-pro" = {
            id = "TD6EE2L-NYXXBBC-TNERZDG-D25X2OS-EBK6BHO-STJEUNS-PG5WD6Y-M4XPKA5";
            autoAcceptFolders = true;
          };
          "marius-notebook-nixsilden" = {
            id = "BUSMJXH-QLT4K4O-4LE4XDF-2A7YH7W-6LXA3TM-E7E3OWL-PWXOLGP-5V25YAY";
            autoAcceptFolders = true;
          };
          "mariusbox11" = {
            id = "3MUCAXD-FOBQVWY-FAZEBM2-MV3TVG7-6RA6V5N-WCO34SU-YFFZKXK-BDHQIAQ";
            autoAcceptFolders = true;
          };
          "marius-handy" = {
            id = "YJKXWDI-QKUHP3F-FQHQ3YG-KRQNN7U-EHOASUO-6V6II2W-SB3NTH3-D5FJEA5";
            autoAcceptFolders = true;
          };
        };
        folders = {
          "default" = {
            id = "default";
            path = "/home/vincenzo/default";
            devices = [
              "kyrill-handy"
              "kyrill-tablet"
              "kyrill-thinkpad-t495"
            ];
            type = "sendreceive";
            enable = true;
            versioning = {
              type = "simple";
              params.keep = 5;
            };
          };
          "documents" = {
            id = "baqfs-svyhe";
            path = "/home/vincenzo/documents";
            devices = [
              "dracula"
              "asgar"
              "bereitbook-pro-m4"
            ];
            type = "sendreceive";
            enable = true;
            versioning = {
              type = "simple";
              params.keep = 5;
            };
          };
          "org" = {
            id = "cccdk-miidx";
            path = "/home/vincenzo/org";
            devices = [
              "dracula"
              "asgar"
              "bereitbook-pro-m4"
            ];
            type = "sendreceive";
            enable = true;
            versioning = {
              type = "simple";
              params.keep = 5;
            };
          };
          "code" = {
            id = "wnku3-6n7g5";
            path = "/home/vincenzo/code";
            devices = [
              "dracula"
              "asgar"
              "bereitbook-pro-m4"
            ];
            type = "sendreceive";
            enable = true;
            versioning = {
              type = "simple";
              params.keep = 5;
            };
          };
          "doom-config" = {
            id = "doom-config";
            path = "/home/vincenzo/doom-config";
            devices = [
              "dracula"
              "asgar"
              "bereitbook-pro-m4"
            ];
            type = "sendreceive";
            enable = true;
            versioning = {
              type = "simple";
              params.keep = 5;
            };
          };
          "nixos-config" = {
            id = "nixos-config";
            path = "/home/vincenzo/nixos-config";
            devices = [
              "dracula"
              "asgar"
              "bereitbook-pro-m4"
            ];
            type = "sendreceive";
            enable = true;
            versioning = {
              type = "simple";
              params.keep = 5;
            };
          };
          "amiconsult" = {
            id = "amiconsult";
            path = "/home/vincenzo/amiconsult";
            devices = [
              "dracula"
              "bereitbook-pro-m4"
            ];
            type = "sendreceive";
            enable = true;
            versioning = {
              type = "simple";
              params.keep = 5;
            };
          };
        };
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
    vaultwarden = {
        enable = true;
        backupDir = "/var/lib/vaultwarden/backup";
        environmentFile = config.sops.templates."vaultwarden.env".path;

        config = {
            # Refer to https://github.com/dani-garcia/vaultwarden/blob/main/.env.template
            DOMAIN = "https://passwort.istbereit.de";
            SIGNUPS_ALLOWED = false;

            ROCKET_ADDRESS = "127.0.0.1";
            ROCKET_PORT = 8222;
            ROCKET_LOG = "critical";

            # This example assumes a mailserver running on localhost,
            # thus without transport encryption.
            # If you use an external mail server, follow:
            #   https://github.com/dani-garcia/vaultwarden/wiki/SMTP-configuration
            SMTP_HOST = "127.0.0.1";
            SMTP_PORT = 25;
            SMTP_SSL = false;

            SMTP_FROM = "admin@passwort.istbereit.de";
            SMTP_FROM_NAME = "Bereitwarden";
        };
      };
    };

  # Media automation Docker Compose stack
  systemd.services.media-stack = {
    description = "Media automation stack with VPN-isolated torrenting";
    after = [ "docker.service" "mnt-hetzner.mount" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = "/var/lib/media-stack";
      EnvironmentFile = config.sops.templates."mullvad.env".path;
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p /var/lib/media-stack"
        "${pkgs.coreutils}/bin/cp ${./media-stack/docker-compose.yml} /var/lib/media-stack/docker-compose.yml"
      ];
      ExecStart = "${pkgs.docker-compose}/bin/docker-compose up -d";
      ExecStop = "${pkgs.docker-compose}/bin/docker-compose down";
      User = "root";
      Group = "root";
    };
  };

  systemd.services.paperless-consumer.after = [ "var-lib-paperless.mount" ];
  systemd.services.paperless-scheduler.after = [ "var-lib-paperless.mount" ];
  systemd.services.paperless-task-queue.after = [ "var-lib-paperless.mount" ];
  systemd.services.paperless-web.after = [ "var-lib-paperless.mount" ];

  users.users = {
    vincenzo = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "docker"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDj2dxqVTVKEzFUBw4Ol8G2XBwTHEwxFquzYNIelKBOzDQLE2WNvjfBko1iQkUNHrVfr3GiAuxdsE+O3hltDvo4UsQqsEqCSu/HEWRfyXDJrcLSm7ogkOAGBZtrmIr73YfGhpzRqcfnoAqSJOkX6PFmaFJ+YgoOuJLH6KbQo3xv0r5RqFkZhfnOiD5gwMtEExP4uawycb9mrsqxOWoMANR870qYq6JERxcGZU4m0UcvnpB01EbvTuWMIACL11cCylkcCPoDnv9KD94k0nhqGOE5/UB6mxRPBBJdQk3Dd3KXe2u2s++Enpu2WKdqOFywxxvXZ2PHBh4Oy8eJpytzMWxSUcLNcNk54JgAgaUCYYN0s3CmKh2r+z6pGSo5xUuJxyl13TfsSzCTsx3dkUOAaRpQAIHDseIDKX983zDS831GZA1d4xiOOtC7ct8F8z3qMokHU+N8OB0ys2T7cS29Q9BKSgaPSBlM0YTWQwD0R2Tf+D74VQnSYPgNNGFByZwV8bc= vincenzo@nixos"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCPlhh/4miDPy8MD7ckimo0ZlEyRIIQymAeNrpvbURg+H0G+kztFgr2x0muzAVwy5noz7511zQBkG9q+lJfWHzjGvVibew5HhcdlECkzpStrkRkupM0l7Ql1ILlQb/lME1v4TM+JM1nCbOgIqkjKJ/dzE3WqHz8CfJ6ilf5QedKHnAFbMu6miOGHMJxDje+0t/51QPul513d2oyIjtUBjtW0Yo77PgSuopFbhEI//cn0P7QVJArbmv7YZqGNifVzMyzQBlvXQtJC0CR/bGTJwspCCU2xIangzHrkKxRqkZJrk1zC5JyMbW1oRUZ3ah7MbUq/ivAUfjvzvkrZS5DbigMmSIbGmoK9d/k6pQjj4gyL1Q5KZRq4g2JKkV6Uhaqr2yfG2F0T6FGKnhGO6P5PK2bkAobfCfLL5IGkceK/WB0InMKfdbii971CeUY0qk+1ad7Fn9txuR5omttkEtM9Hh9Afz1kGxa4ia9+d71OV4KoXVykqr/bD284rhOooX4/mU= vincenzo@dracula"
      ];
    };
    nix = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "docker"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDj2dxqVTVKEzFUBw4Ol8G2XBwTHEwxFquzYNIelKBOzDQLE2WNvjfBko1iQkUNHrVfr3GiAuxdsE+O3hltDvo4UsQqsEqCSu/HEWRfyXDJrcLSm7ogkOAGBZtrmIr73YfGhpzRqcfnoAqSJOkX6PFmaFJ+YgoOuJLH6KbQo3xv0r5RqFkZhfnOiD5gwMtEExP4uawycb9mrsqxOWoMANR870qYq6JERxcGZU4m0UcvnpB01EbvTuWMIACL11cCylkcCPoDnv9KD94k0nhqGOE5/UB6mxRPBBJdQk3Dd3KXe2u2s++Enpu2WKdqOFywxxvXZ2PHBh4Oy8eJpytzMWxSUcLNcNk54JgAgaUCYYN0s3CmKh2r+z6pGSo5xUuJxyl13TfsSzCTsx3dkUOAaRpQAIHDseIDKX983zDS831GZA1d4xiOOtC7ct8F8z3qMokHU+N8OB0ys2T7cS29Q9BKSgaPSBlM0YTWQwD0R2Tf+D74VQnSYPgNNGFByZwV8bc= vincenzo@nixos"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCPlhh/4miDPy8MD7ckimo0ZlEyRIIQymAeNrpvbURg+H0G+kztFgr2x0muzAVwy5noz7511zQBkG9q+lJfWHzjGvVibew5HhcdlECkzpStrkRkupM0l7Ql1ILlQb/lME1v4TM+JM1nCbOgIqkjKJ/dzE3WqHz8CfJ6ilf5QedKHnAFbMu6miOGHMJxDje+0t/51QPul513d2oyIjtUBjtW0Yo77PgSuopFbhEI//cn0P7QVJArbmv7YZqGNifVzMyzQBlvXQtJC0CR/bGTJwspCCU2xIangzHrkKxRqkZJrk1zC5JyMbW1oRUZ3ah7MbUq/ivAUfjvzvkrZS5DbigMmSIbGmoK9d/k6pQjj4gyL1Q5KZRq4g2JKkV6Uhaqr2yfG2F0T6FGKnhGO6P5PK2bkAobfCfLL5IGkceK/WB0InMKfdbii971CeUY0qk+1ad7Fn9txuR5omttkEtM9Hh9Afz1kGxa4ia9+d71OV4KoXVykqr/bD284rhOooX4/mU= vincenzo@dracula"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDg8T7GRlyOP6jme62lF6xTfLEK137MFP766m3C2G+0K3vckxxutE1dW3GPT/kqsDgGHIysRAFWeUm60X2tfdEWVaSNi9g1kb8uss+9EA8zrUuI596/HDeJnsHFo3K/hf7PhjEDhxblo8JzDMz7IF6y58Annh7fTQCdHk564k429YI65mMY16D1GiE0aL0hkiEvAk25gp5mLjEYyAHDHE2ma8csGWJCap5OaAqJ9h0mkf9mcrhczo7MlEF6iL6EWTDToDw0NWPpEVPFRvJUJM+2gNSSxIVIFZkt8eczX/TY0lFkSkSPy5FXqtedHTOazU4mxGU5Lwy3A4gmg3/3ibZ1 Marius"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJtziDwyaqKfBPL1dDEM6kMdA+KTL+d0810PzAbOsWHn kyrill@kyrill-ThinkPad-T495"
      ];

    };
    marius = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "docker"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDg8T7GRlyOP6jme62lF6xTfLEK137MFP766m3C2G+0K3vckxxutE1dW3GPT/kqsDgGHIysRAFWeUm60X2tfdEWVaSNi9g1kb8uss+9EA8zrUuI596/HDeJnsHFo3K/hf7PhjEDhxblo8JzDMz7IF6y58Annh7fTQCdHk564k429YI65mMY16D1GiE0aL0hkiEvAk25gp5mLjEYyAHDHE2ma8csGWJCap5OaAqJ9h0mkf9mcrhczo7MlEF6iL6EWTDToDw0NWPpEVPFRvJUJM+2gNSSxIVIFZkt8eczX/TY0lFkSkSPy5FXqtedHTOazU4mxGU5Lwy3A4gmg3/3ibZ1 Marius"
      ];
    };
    kyrill = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "docker"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJtziDwyaqKfBPL1dDEM6kMdA+KTL+d0810PzAbOsWHn kyrill@kyrill-ThinkPad-T495"
      ];
    };
    overleaf = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "docker"
      ];
    };
    #    git = {
    #      isSystemUser = true;
    #      extraGroups = [
    #        "wheel"
    #        "docker"
    #      ];
    #    };
    coder = {
      extraGroups = [ "docker" ];
    };
    jellyfin = {
      extraGroups = [
        "wheel"
        "docker"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDj2dxqVTVKEzFUBw4Ol8G2XBwTHEwxFquzYNIelKBOzDQLE2WNvjfBko1iQkUNHrVfr3GiAuxdsE+O3hltDvo4UsQqsEqCSu/HEWRfyXDJrcLSm7ogkOAGBZtrmIr73YfGhpzRqcfnoAqSJOkX6PFmaFJ+YgoOuJLH6KbQo3xv0r5RqFkZhfnOiD5gwMtEExP4uawycb9mrsqxOWoMANR870qYq6JERxcGZU4m0UcvnpB01EbvTuWMIACL11cCylkcCPoDnv9KD94k0nhqGOE5/UB6mxRPBBJdQk3Dd3KXe2u2s++Enpu2WKdqOFywxxvXZ2PHBh4Oy8eJpytzMWxSUcLNcNk54JgAgaUCYYN0s3CmKh2r+z6pGSo5xUuJxyl13TfsSzCTsx3dkUOAaRpQAIHDseIDKX983zDS831GZA1d4xiOOtC7ct8F8z3qMokHU+N8OB0ys2T7cS29Q9BKSgaPSBlM0YTWQwD0R2Tf+D74VQnSYPgNNGFByZwV8bc= vincenzo@nixos"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCPlhh/4miDPy8MD7ckimo0ZlEyRIIQymAeNrpvbURg+H0G+kztFgr2x0muzAVwy5noz7511zQBkG9q+lJfWHzjGvVibew5HhcdlECkzpStrkRkupM0l7Ql1ILlQb/lME1v4TM+JM1nCbOgIqkjKJ/dzE3WqHz8CfJ6ilf5QedKHnAFbMu6miOGHMJxDje+0t/51QPul513d2oyIjtUBjtW0Yo77PgSuopFbhEI//cn0P7QVJArbmv7YZqGNifVzMyzQBlvXQtJC0CR/bGTJwspCCU2xIangzHrkKxRqkZJrk1zC5JyMbW1oRUZ3ah7MbUq/ivAUfjvzvkrZS5DbigMmSIbGmoK9d/k6pQjj4gyL1Q5KZRq4g2JKkV6Uhaqr2yfG2F0T6FGKnhGO6P5PK2bkAobfCfLL5IGkceK/WB0InMKfdbii971CeUY0qk+1ad7Fn9txuR5omttkEtM9Hh9Afz1kGxa4ia9+d71OV4KoXVykqr/bD284rhOooX4/mU= vincenzo@dracula"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJtziDwyaqKfBPL1dDEM6kMdA+KTL+d0810PzAbOsWHn kyrill@kyrill-ThinkPad-T495"
      ];
    };
  };
  virtualisation.docker = {
    enable = true;
    storageDriver = "btrfs";
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };

  security.acme.acceptTerms = true;
  security.acme.defaults.email = "vincenzo.pace94@icloud.com";
  system.stateVersion = "23.05";
}
