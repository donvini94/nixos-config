{ inputs, lib, config, pkgs, ... }:

{

  imports = [
    ./hm-modules/packages.nix
    ./hm-modules/kitty.nix
    ./hm-modules/yazi.nix
    ./hm-modules/nushell.nix
    ./hm-modules/starship.nix
  ];

  home = {
    username = "vincenzo";
    homeDirectory = "/home/vincenzo";
    stateVersion = "23.05";

  };
  programs.git = {
    enable = true;
    userName = "Vincenzo Pace";
    userEmail = "vincenzo.pace@mailbox.org";
  };

  nixpkgs.config.allowUnfree = true;
  fonts.fontconfig.enable = true;

  programs.wofi.enable = true;

  programs.bash = {
    enable = true;
    enableCompletion = true;
    bashrcExtra = ''
      export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin:$HOME/.config/emacs/bin/doom"
    '';
  };

  programs.home-manager.enable = true;

  services = {
    udiskie.enable = true;
    syncthing.enable = true;
  };

  # Enable GTK themes
  gtk = {
    enable = true;
    theme = {
      name = "Tokyonight-Dark-B";
      package = pkgs.tokyo-night-gtk;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme.override { color = "blue"; };
    };
    cursorTheme = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 16;
    };
  };

  # Mimetypes
  xdg.mimeApps.defaultApplications = {
    "application/pdf" = [ "zathura.desktop" ];
    "image/*" = [ "viewnior.desktop" ];
    "video/png" = [ "mpv.desktop" ];
    "video/jpg" = [ "mpv.desktop" ];
    "video/*" = [ "mpv.desktop" ];
  };
  systemd.user.startServices = "sd-switch";
}
