{
  inputs,
  lib,
  config,
  pkgs,
  username,
  fullName,
  mail,
  ...
}:

{

  imports = [
    ./hm-modules/dunst.nix
    ./hm-modules/helix.nix
    ./hm-modules/kitty.nix
    ./hm-modules/mpv.nix
    ./hm-modules/nushell.nix
    ./hm-modules/packages.nix
    ./hm-modules/starship.nix
    ./hm-modules/swaylock.nix
    ./hm-modules/waybar.nix
    ./hm-modules/yazi.nix
    ./hm-modules/zathura.nix
    ./modules/hyprland/config.nix
  ];

  nixpkgs.config.allowUnfree = true;

  home = {
    username = "${username}";
    homeDirectory = "/home/${username}";
    stateVersion = "23.05";
  };

  fonts.fontconfig.enable = true;

  programs = {
    home-manager.enable = true;
    git = {
      enable = true;
      userName = "${fullName}";
      userEmail = "${mail}";
    };
    bash = {
      enable = true;
      enableCompletion = true;
      bashrcExtra = ''
        export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin:$HOME/.config/emacs/bin/doom"
      '';
    };
    zoxide = {
      enable = true;
      enableNushellIntegration = true;
    };
  };

  services = {
    udiskie.enable = true; # Automounter for removable media
    syncthing.enable = true;
    mpd = {
      enable = true;
      musicDirectory = "/media/music";
      network.startWhenNeeded = true;
    };
    gammastep = {
      enable = true;
      provider = "manual";
      latitude = 49.782959;
      longitude = 7.65118;
    };
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
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
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
