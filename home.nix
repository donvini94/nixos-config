{ inputs, lib, config, pkgs, ... }:

{

  imports = [
    ./hm-modules/packages.nix
    ./hm-modules/kitty.nix
    ./hm-modules/yazi.nix
    ./hm-modules/nushell.nix
    ./hm-modules/zathura.nix
    ./hm-modules/mpv.nix
    ./hm-modules/starship.nix
    ./modules/hyprland/config.nix
    ./hm-modules/swaylock.nix
    ./hm-modules/waybar.nix
  ];

  programs.home-manager.enable = true;
  nixpkgs.config.allowUnfree = true;

  home = {
    username = "vincenzo";
    homeDirectory = "/home/vincenzo";
    stateVersion = "23.05";

  };

  fonts.fontconfig.enable = true;

  programs.git = {
    enable = true;
    userName = "Vincenzo Pace";
    userEmail = "pace@amiconsult.de";
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
    bashrcExtra = ''
      export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin:$HOME/.config/emacs/bin/doom"
    '';
  };

  programs.zoxide = {
    enable = true;
    enableNushellIntegration = true;
  };

  services = {
    udiskie.enable = true; # Automounter for removable media
    syncthing.enable = true;
    mpd = {
      enable = true;
      musicDirectory = "/media/music";
      network.startWhenNeeded = true;
    };
  };
  services.gammastep = {
    enable = true;
    provider = "manual";
    latitude = 49.782959;
    longitude = 7.65118;
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
home.sessionVariables = {
    STEAM_EXTRA_COMPAT_TOOLS_PATHS =
      "\${HOME}/.steam/root/compatibilitytools.d";
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
