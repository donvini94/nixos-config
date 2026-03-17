{ ... }:
{
  services.syncthing = {
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
}
