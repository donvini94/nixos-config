{ ... }:
{
  services.syncthing = {
    enable = true;
    user = "vincenzo";
    openDefaultPorts = true;
    dataDir = "/home/vincenzo/";
    configDir = "/home/vincenzo/.config/syncthing";
    # No peer may introduce a folder on this host. Every device previously
    # carried autoAcceptFolders, which silently made `overrideFolders` default
    # to false and left the declarations below decorative: nine folders existed
    # only in runtime state. The set below is the live state, now authoritative.
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      devices = {
        "dracula" = {
          id = "QGVRLBK-OZX7PIM-JMGKYHF-KSFI5VS-FJH6RGI-4YGB6H6-EYAJ27S-TM5LTQ6";
        };
        "bereitbook-pro-m4" = {
          id = "BS4FOGC-XQFLI5X-KQ7PP7R-5P37LRS-TTZGR24-7S2QCBE-5MLVWHM-5FVKNAW";
        };
        "kyrill-thinkpad-t495" = {
          id = "DULG3KX-PYY3RT7-4CW2JVC-64F5J2T-24JRG3J-IDDKBJN-X535SHF-5IBO3QZ";
        };
        "kyrill-handy" = {
          id = "VKWKKOP-4ZNV7AY-MSDT3EA-LOJQFAS-BJ7MPWT-ZJ353LV-7HRXYA3-3763VAH";
        };
        "kyrill-tablet" = {
          id = "T7SVLB6-ZWQM7DO-ZDULZNB-I6QGSQZ-JJUFPO2-7N3GVP7-HONELH2-3GDJSAE";
        };
        "kyrill-mint-laptop" = {
          id = "X6J6CVJ-K7BTU4D-5VIYQ6I-VEMAAF6-EV7CLXN-5XD4277-AKFOZLB-X66Y6A4";
        };
        "kyrill-macbook" = {
          id = "J7G2USF-UU35NDR-4AWVN7M-DPV7FLX-7IZFPQ2-I3JOU7R-3KCJ73I-2JRBUAU";
        };
        "marius-macbook-pro" = {
          id = "TD6EE2L-NYXXBBC-TNERZDG-D25X2OS-EBK6BHO-STJEUNS-PG5WD6Y-M4XPKA5";
        };
        "marius-notebook-nixsilden" = {
          id = "BUSMJXH-QLT4K4O-4LE4XDF-2A7YH7W-6LXA3TM-E7E3OWL-PWXOLGP-5V25YAY";
        };
        "mariusbox11" = {
          id = "3MUCAXD-FOBQVWY-FAZEBM2-MV3TVG7-6RA6V5N-WCO34SU-YFFZKXK-BDHQIAQ";
        };
        "marius-handy" = {
          id = "YJKXWDI-QKUHP3F-FQHQ3YG-KRQNN7U-EHOASUO-6V6II2W-SB3NTH3-D5FJEA5";
        };
      };
      folders = {
        "Claude" = {
          id = "claude";
          label = "Claude";
          path = "/home/vincenzo/Claude";
          devices = [
            "bereitbook-pro-m4"
            "marius-macbook-pro"
          ];
          type = "sendreceive";
        };
        "Cloud" = {
          id = "default";
          label = "Cloud";
          path = "/home/vincenzo/Cloud";
          devices = [
            "kyrill-thinkpad-t495"
            "kyrill-macbook"
            "marius-macbook-pro"
            "kyrill-tablet"
            "kyrill-handy"
            "kyrill-mint-laptop"
          ];
          type = "sendreceive";
        };
        "GlazeWM" = {
          id = "glazewm-config";
          label = "GlazeWM";
          path = "/home/vincenzo/GlazeWM";
          devices = [
            "marius-macbook-pro"
            "mariusbox11"
          ];
          type = "sendreceive";
        };
        "LGHUB" = {
          id = "lghub-config";
          label = "LGHUB";
          path = "/home/vincenzo/LGHUB";
          devices = [
            "marius-macbook-pro"
            "mariusbox11"
          ];
          type = "sendreceive";
        };
        "PowerToys" = {
          id = "powertoys-config";
          label = "PowerToys";
          path = "/home/vincenzo/PowerToys";
          devices = [
            "marius-macbook-pro"
            "mariusbox11"
          ];
          type = "sendreceive";
        };
        "Syncthing_light" = {
          id = "8jb5q-sxckl";
          label = "Syncthing_light";
          path = "/home/vincenzo/Syncthing_light";
          devices = [
            "marius-notebook-nixsilden"
            "marius-macbook-pro"
          ];
          type = "sendreceive";
        };
        "Syncthing_lighteningv1.0" = {
          id = "jzuai-hfpzz";
          label = "Syncthing_lighteningv1.0";
          path = "/home/vincenzo/Syncthing_lighteningv1.0";
          devices = [
            "marius-macbook-pro"
            "marius-handy"
          ];
          type = "sendreceive";
        };
        "Syncthing_mini" = {
          id = "jjh7e-q7gzr";
          label = "Syncthing_mini";
          path = "/home/vincenzo/Syncthing_mini";
          devices = [
            "marius-macbook-pro"
            "marius-handy"
          ];
          type = "sendreceive";
        };
        "UniGetUI" = {
          id = "unigetui-config";
          label = "UniGetUI";
          path = "/home/vincenzo/UniGetUI";
          devices = [
            "marius-macbook-pro"
            "mariusbox11"
          ];
          type = "sendreceive";
        };
        "amiconsult" = {
          id = "amiconsult";
          label = "amiconsult";
          path = "/home/vincenzo/amiconsult";
          devices = [
            "bereitbook-pro-m4"
            "dracula"
            "marius-macbook-pro"
          ];
          type = "sendreceive";
        };
        "code" = {
          id = "wnku3-6n7g5";
          label = "code";
          path = "/home/vincenzo/code";
          devices = [
            "bereitbook-pro-m4"
            "dracula"
            "marius-macbook-pro"
          ];
          type = "sendreceive";
        };
        "documents" = {
          id = "baqfs-svyhe";
          label = "documents";
          path = "/home/vincenzo/documents";
          devices = [
            "bereitbook-pro-m4"
            "dracula"
            "marius-macbook-pro"
          ];
          type = "sendreceive";
        };
        "doom-config" = {
          id = "doom-config";
          label = "";
          path = "/home/vincenzo/doom-config";
          devices = [
            "bereitbook-pro-m4"
            "dracula"
            "marius-macbook-pro"
          ];
          type = "sendreceive";
        };
        "nixos-config" = {
          id = "nixos-config";
          label = "";
          path = "/home/vincenzo/nixos-config";
          devices = [
            "bereitbook-pro-m4"
            "dracula"
            "marius-macbook-pro"
          ];
          type = "sendreceive";
        };
        "org" = {
          id = "cccdk-miidx";
          label = "org";
          path = "/home/vincenzo/org";
          devices = [
            "bereitbook-pro-m4"
            "dracula"
            "marius-macbook-pro"
          ];
          type = "sendreceive";
          versioning = {
            type = "simple";
            params = {
              cleanoutDays = "0";
              keep = "5";
            };
          };
        };
      };
    };
  };
}
