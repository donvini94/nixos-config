{ config, lib, ... }:
let
  home = config.home.homeDirectory;
  both = [
    "dracula"
    "alucard"
  ];
  folder = id: path: devices: {
    inherit id path devices;
    rescanIntervalS = 86400;
  };
in
{
  services.syncthing = {
    enable = true;
    settings = {
      devices = lib.mapAttrs (_: id: { inherit id; }) {
        dracula = "QGVRLBK-OZX7PIM-JMGKYHF-KSFI5VS-FJH6RGI-4YGB6H6-EYAJ27S-TM5LTQ6";
        alucard = "TD6EE2L-NYXXBBC-TNERZDG-D25X2OS-EBK6BHO-STJEUNS-PG5WD6Y-M4XPKA5";
      };
      folders = {
        amiconsult = folder "amiconsult" "${home}/amiconsult" both;
        code = folder "wnku3-6n7g5" "${home}/code" both;
        documents = folder "baqfs-svyhe" "${home}/documents" both;
        org = folder "cccdk-miidx" "${home}/org" both;
        Claude = folder "claude" "${home}/.claude" [ "alucard" ];
        nixos-config = folder "nixos-config" "${home}/nixos-config" [ "alucard" ];
      };
    };
  };
}
