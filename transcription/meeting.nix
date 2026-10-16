{ pkgs, inputs, ... }:
let
  tapeback = pkgs.callPackage ./package.nix {
    cudaNixpkgs = inputs.tapeback-nixpkgs;
  };
  localTapeback = pkgs.writeShellApplication {
    name = "tapeback";
    runtimeInputs = [ tapeback ];
    text = builtins.readFile ./tapeback-local.sh;
  };
in
{
  home.packages = [ localTapeback ];

  systemd.user.services.tapeback-tray = {
    Unit = {
      Description = "Local meeting recorder";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service.ExecStart = "${localTapeback}/bin/tapeback tray";
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
