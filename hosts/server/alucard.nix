{ inputs, config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];
  boot.initrd.availableKernelModules =
    [ "ata_piix" "uhci_hcd" "virtio_pci" "sr_mod" "virtio_blk" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.ens3.useDHCP = lib.mkDefault true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 8096 22 58080 ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  time.timeZone = "Europe/Berlin";
  networking.hostName = "alucard";

  users.users.vincenzo = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDj2dxqVTVKEzFUBw4Ol8G2XBwTHEwxFquzYNIelKBOzDQLE2WNvjfBko1iQkUNHrVfr3GiAuxdsE+O3hltDvo4UsQqsEqCSu/HEWRfyXDJrcLSm7ogkOAGBZtrmIr73YfGhpzRqcfnoAqSJOkX6PFmaFJ+YgoOuJLH6KbQo3xv0r5RqFkZhfnOiD5gwMtEExP4uawycb9mrsqxOWoMANR870qYq6JERxcGZU4m0UcvnpB01EbvTuWMIACL11cCylkcCPoDnv9KD94k0nhqGOE5/UB6mxRPBBJdQk3Dd3KXe2u2s++Enpu2WKdqOFywxxvXZ2PHBh4Oy8eJpytzMWxSUcLNcNk54JgAgaUCYYN0s3CmKh2r+z6pGSo5xUuJxyl13TfsSzCTsx3dkUOAaRpQAIHDseIDKX983zDS831GZA1d4xiOOtC7ct8F8z3qMokHU+N8OB0ys2T7cS29Q9BKSgaPSBlM0YTWQwD0R2Tf+D74VQnSYPgNNGFByZwV8bc= vincenzo@nixos"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCPlhh/4miDPy8MD7ckimo0ZlEyRIIQymAeNrpvbURg+H0G+kztFgr2x0muzAVwy5noz7511zQBkG9q+lJfWHzjGvVibew5HhcdlECkzpStrkRkupM0l7Ql1ILlQb/lME1v4TM+JM1nCbOgIqkjKJ/dzE3WqHz8CfJ6ilf5QedKHnAFbMu6miOGHMJxDje+0t/51QPul513d2oyIjtUBjtW0Yo77PgSuopFbhEI//cn0P7QVJArbmv7YZqGNifVzMyzQBlvXQtJC0CR/bGTJwspCCU2xIangzHrkKxRqkZJrk1zC5JyMbW1oRUZ3ah7MbUq/ivAUfjvzvkrZS5DbigMmSIbGmoK9d/k6pQjj4gyL1Q5KZRq4g2JKkV6Uhaqr2yfG2F0T6FGKnhGO6P5PK2bkAobfCfLL5IGkceK/WB0InMKfdbii971CeUY0qk+1ad7Fn9txuR5omttkEtM9Hh9Afz1kGxa4ia9+d71OV4KoXVykqr/bD284rhOooX4/mU= vincenzo@dracula"
    ];

  };

  users.users.kyrill = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJtziDwyaqKfBPL1dDEM6kMdA+KTL+d0810PzAbOsWHn kyrill@kyrill-ThinkPad-T495"
    ];
  };

  users.users.overleaf = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
  };

users.users.git = {
    isSystemUser = true;
    extraGroups = [ "wheel"];
  };


  users.users.jellyfin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDj2dxqVTVKEzFUBw4Ol8G2XBwTHEwxFquzYNIelKBOzDQLE2WNvjfBko1iQkUNHrVfr3GiAuxdsE+O3hltDvo4UsQqsEqCSu/HEWRfyXDJrcLSm7ogkOAGBZtrmIr73YfGhpzRqcfnoAqSJOkX6PFmaFJ+YgoOuJLH6KbQo3xv0r5RqFkZhfnOiD5gwMtEExP4uawycb9mrsqxOWoMANR870qYq6JERxcGZU4m0UcvnpB01EbvTuWMIACL11cCylkcCPoDnv9KD94k0nhqGOE5/UB6mxRPBBJdQk3Dd3KXe2u2s++Enpu2WKdqOFywxxvXZ2PHBh4Oy8eJpytzMWxSUcLNcNk54JgAgaUCYYN0s3CmKh2r+z6pGSo5xUuJxyl13TfsSzCTsx3dkUOAaRpQAIHDseIDKX983zDS831GZA1d4xiOOtC7ct8F8z3qMokHU+N8OB0ys2T7cS29Q9BKSgaPSBlM0YTWQwD0R2Tf+D74VQnSYPgNNGFByZwV8bc= vincenzo@nixos"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCPlhh/4miDPy8MD7ckimo0ZlEyRIIQymAeNrpvbURg+H0G+kztFgr2x0muzAVwy5noz7511zQBkG9q+lJfWHzjGvVibew5HhcdlECkzpStrkRkupM0l7Ql1ILlQb/lME1v4TM+JM1nCbOgIqkjKJ/dzE3WqHz8CfJ6ilf5QedKHnAFbMu6miOGHMJxDje+0t/51QPul513d2oyIjtUBjtW0Yo77PgSuopFbhEI//cn0P7QVJArbmv7YZqGNifVzMyzQBlvXQtJC0CR/bGTJwspCCU2xIangzHrkKxRqkZJrk1zC5JyMbW1oRUZ3ah7MbUq/ivAUfjvzvkrZS5DbigMmSIbGmoK9d/k6pQjj4gyL1Q5KZRq4g2JKkV6Uhaqr2yfG2F0T6FGKnhGO6P5PK2bkAobfCfLL5IGkceK/WB0InMKfdbii971CeUY0qk+1ad7Fn9txuR5omttkEtM9Hh9Afz1kGxa4ia9+d71OV4KoXVykqr/bD284rhOooX4/mU= vincenzo@dracula"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJtziDwyaqKfBPL1dDEM6kMdA+KTL+d0810PzAbOsWHn kyrill@kyrill-ThinkPad-T495"
    ];

  };

  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    btop
    eza
    yazi
    mullvad-vpn
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    gnupg
    zip
    xz
    unzip
    p7zip

#    certbot # for SSL certificate / let's encrypt
  ];

  services = {
    openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
      settings.KbdInteractiveAuthentication = false;
      settings.PermitRootLogin = "no";

    };
    fail2ban.enable = true;
    # gitlab needs nginx proxy
nginx = {
  enable = true;
  recommendedGzipSettings = true;
  recommendedOptimisation = true;
  recommendedProxySettings = true;
  recommendedTlsSettings = true;
  virtualHosts."stream.dumustbereitsein.de" = {
    locations."/".proxyPass = "http://localhost:8096";
  };
 virtualHosts."docs.dumustbereitsein.de" = {
    locations."/".proxyPass = "http://localhost:58080";
  };
  virtualHosts."git.dumustbereitsein.de" = {
    enableACME = true;
    forceSSL = true;
    locations."/".proxyPass = "http://unix:/run/gitlab/gitlab-workhorse.socket";
  };
};
gitlab = {
  enable = true;
  databasePasswordFile = "/var/keys/gitlab/db_password";
  initialRootPasswordFile = "/var/keys/gitlab/root_password";
  https = false;
  host = "git.dumustbereitsein.de";
  port = 80;
  user = "git";
  databaseUsername = "git";
  group = "git";
  smtp = {
    enable = true;
    address = "localhost";
    port = 25;
  };
  secrets = {
    dbFile = "/var/keys/gitlab/db";
    secretFile = "/var/keys/gitlab/secret";
    otpFile = "/var/keys/gitlab/otp";
    jwsFile = "/var/keys/gitlab/jws";
  };
  extraConfig = {
    gitlab = {
      email_from = "gitlab-no-reply@example.com";
      email_display_name = "Vincenzos GitLab";
      email_reply_to = "gitlab-no-reply@example.com";
    };
  };
};

gitlab-runner = {
  enable =true;
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
            id =
              "QGVRLBK-OZX7PIM-JMGKYHF-KSFI5VS-FJH6RGI-4YGB6H6-EYAJ27S-TM5LTQ6";
            autoAcceptFolders = true;
          };
          "valnar" = {
            id =
              "RUL7KJT-FSXO3VI-QP76KVO-LAY5CYT-NERMG3C-EY3TYUU-FQDDKG5-NJ5V4AS";
            autoAcceptFolders = true;
          };
          "asgar" = {
            id =
              "H5KT7VJ-OFUH3PD-6HH4KRI-VKOOOMY-Z5KNIQL-DVTBCAN-PQ44EAY-AAAS7AO";
            autoAcceptFolders = true;
          };
          "kyrill-thinkpad-t495" = {
            id =
              "PERVZSH-ZPN5MET-MM6ADZG-TTDUOV5-USGIDY3-4K4UT6N-JPUCYGM-6PIIWQQ";
            autoAcceptFolders = true;
          };
          "kyrill-handy" = {
            id =
              "VKWKKOP-4ZNV7AY-MSDT3EA-LOJQFAS-BJ7MPWT-ZJ353LV-7HRXYA3-3763VAH";
            autoAcceptFolders = true;
          };
          "kyrill-tablet" = {
            id =
              "T7SVLB6-ZWQM7DO-ZDULZNB-I6QGSQZ-JJUFPO2-7N3GVP7-HONELH2-3GDJSAE";
            autoAcceptFolders = true;
          };
        };
        folders = {
          "default" = {
            id = "default";
            path = "/home/vincenzo/default";
            devices = [ "kyrill-handy" "kyrill-tablet" "kyrill-thinkpad-t495" ];
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
            devices = [ "dracula" "asgar" "valnar" ];
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
            devices = [ "dracula" "asgar" "valnar" ];
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
            devices = [ "dracula" "asgar" "valnar" ];
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
            devices = [ "dracula" "valnar" ];
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
      address = "docs.dumustbereitsein.de";
      port = 58080;
      consumptionDirIsPublic = true;
      settings.PAPERLESS_OCR_LANGUAGE = "deu+eng";
      passwordFile = "/home/vincenzo/keys/paperless-password";
    };
  };

  systemd.services.paperless-consumer.after = [ "var-lib-paperless.mount" ];
  systemd.services.paperless-scheduler.after = [ "var-lib-paperless.mount" ];
  systemd.services.paperless-task-queue.after = [ "var-lib-paperless.mount" ];
  systemd.services.paperless-web.after = [ "var-lib-paperless.mount" ];

  nix = {
    settings = {
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
