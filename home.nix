{
  inputs,
  pkgs,
  username,
  ...
}:

{
  imports = [
    ./hm-modules/git.nix
    ./hm-modules/ssh.nix
    ./hm-modules/fish.nix
    ./hm-modules/shell.nix
    ./hm-modules/helix.nix
    ./hm-modules/hyprland.nix
    ./hm-modules/kitty.nix
    ./hm-modules/mpv.nix
    ./hm-modules/packages.nix
    ./hm-modules/starship.nix
    ./hm-modules/yazi.nix
    ./hm-modules/zathura.nix
    ./hm-modules/doom.nix
    ./hm-modules/zellij.nix
    ./hm-modules/caelestia.nix
    ./hm-modules/services.nix
    inputs.caelestia-shell.homeManagerModules.default
  ];

  nixpkgs.config.allowUnfree = true;

  home = {
    username = "${username}";
    homeDirectory = "/home/${username}";
    stateVersion = "23.05";
    pointerCursor = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 24;
      gtk.enable = true;
    };
  };

  fonts.fontconfig.enable = true;
  programs.home-manager.enable = true;

  xdg.mimeApps.defaultApplications = {
    "application/pdf" = [ "zathura.desktop" ];
    "image/*" = [ "viewnior.desktop" ];
    "video/*" = [ "mpv.desktop" ];
  };

  systemd.user.startServices = "sd-switch";
}
