{ lib, ... }:
let
  home = "/home/vincenzo";

  claudePeers = [
    "bereitbook-pro-m4"
    "marius-macbook-pro"
  ];
  cloudPeers = [
    "kyrill-thinkpad-t495"
    "kyrill-macbook"
    "marius-macbook-pro"
    "kyrill-tablet"
    "kyrill-handy"
    "kyrill-mint-laptop"
  ];
  mariusWindows = [
    "marius-macbook-pro"
    "mariusbox11"
  ];
  mariusMobile = [
    "marius-macbook-pro"
    "marius-handy"
  ];
  nixsilden = [
    "marius-notebook-nixsilden"
    "marius-macbook-pro"
  ];
  workstations = [
    "bereitbook-pro-m4"
    "dracula"
    "marius-macbook-pro"
  ];

  # Folder name is the label and the last path component; both are overridable.
  mkFolder =
    name: folder:
    {
      inherit (folder) id devices;
      label = folder.label or name;
      path = "${home}/${name}";
      type = "sendreceive";
    }
    // lib.optionalAttrs (folder ? versioning) { inherit (folder) versioning; };
in
{
  services.syncthing = {
    enable = true;
    user = "vincenzo";
    openDefaultPorts = true;
    dataDir = "/home/vincenzo/";
    configDir = "/home/vincenzo/.config/syncthing";
    # No peer may introduce a folder here: autoAcceptFolders on a device
    # silently defaults `overrideFolders` to false, which leaves the
    # declarations below decorative.
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      devices = lib.mapAttrs (_: id: { inherit id; }) {
        dracula = "QGVRLBK-OZX7PIM-JMGKYHF-KSFI5VS-FJH6RGI-4YGB6H6-EYAJ27S-TM5LTQ6";
        bereitbook-pro-m4 = "BS4FOGC-XQFLI5X-KQ7PP7R-5P37LRS-TTZGR24-7S2QCBE-5MLVWHM-5FVKNAW";
        kyrill-thinkpad-t495 = "DULG3KX-PYY3RT7-4CW2JVC-64F5J2T-24JRG3J-IDDKBJN-X535SHF-5IBO3QZ";
        kyrill-handy = "VKWKKOP-4ZNV7AY-MSDT3EA-LOJQFAS-BJ7MPWT-ZJ353LV-7HRXYA3-3763VAH";
        kyrill-tablet = "T7SVLB6-ZWQM7DO-ZDULZNB-I6QGSQZ-JJUFPO2-7N3GVP7-HONELH2-3GDJSAE";
        kyrill-mint-laptop = "X6J6CVJ-K7BTU4D-5VIYQ6I-VEMAAF6-EV7CLXN-5XD4277-AKFOZLB-X66Y6A4";
        kyrill-macbook = "J7G2USF-UU35NDR-4AWVN7M-DPV7FLX-7IZFPQ2-I3JOU7R-3KCJ73I-2JRBUAU";
        marius-macbook-pro = "TD6EE2L-NYXXBBC-TNERZDG-D25X2OS-EBK6BHO-STJEUNS-PG5WD6Y-M4XPKA5";
        marius-notebook-nixsilden = "BUSMJXH-QLT4K4O-4LE4XDF-2A7YH7W-6LXA3TM-E7E3OWL-PWXOLGP-5V25YAY";
        mariusbox11 = "3MUCAXD-FOBQVWY-FAZEBM2-MV3TVG7-6RA6V5N-WCO34SU-YFFZKXK-BDHQIAQ";
        marius-handy = "YJKXWDI-QKUHP3F-FQHQ3YG-KRQNN7U-EHOASUO-6V6II2W-SB3NTH3-D5FJEA5";
      };
      folders = lib.mapAttrs mkFolder {
        Claude = {
          id = "claude";
          devices = claudePeers;
        };
        Cloud = {
          id = "default";
          devices = cloudPeers;
        };
        GlazeWM = {
          id = "glazewm-config";
          devices = mariusWindows;
        };
        LGHUB = {
          id = "lghub-config";
          devices = mariusWindows;
        };
        PowerToys = {
          id = "powertoys-config";
          devices = mariusWindows;
        };
        Syncthing_light = {
          id = "8jb5q-sxckl";
          devices = nixsilden;
        };
        "Syncthing_lighteningv1.0" = {
          id = "jzuai-hfpzz";
          devices = mariusMobile;
        };
        Syncthing_mini = {
          id = "jjh7e-q7gzr";
          devices = mariusMobile;
        };
        UniGetUI = {
          id = "unigetui-config";
          devices = mariusWindows;
        };
        amiconsult = {
          id = "amiconsult";
          devices = workstations;
        };
        code = {
          id = "wnku3-6n7g5";
          devices = workstations;
        };
        documents = {
          id = "baqfs-svyhe";
          devices = workstations;
        };
        doom-config = {
          id = "doom-config";
          label = "";
          devices = workstations;
        };
        nixos-config = {
          id = "nixos-config";
          label = "";
          devices = workstations;
        };
        org = {
          id = "cccdk-miidx";
          devices = workstations;
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
