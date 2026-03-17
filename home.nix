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
    ./hm-modules/helix.nix
    ./hm-modules/hyprland.nix
    ./hm-modules/mpv.nix
    ./hm-modules/packages.nix
    ./hm-modules/yazi.nix
    ./hm-modules/zathura.nix
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

  # ── Programs ───────────────────────────────────────────────────
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
      enableFishIntegration = true;
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    atuin = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        auto_sync = true;
        sync_address = "https://dumusstbereitsein.de";
        search_mode = "prefix";
      };
    };
    fish = {
      enable = true;
      shellAbbrs = {
        vim = "nvim";
        e = "nvim";
        cheat = "cht.sh";
        c = "cht.sh";
        cd = "z";
        switch = "sudo nixos-rebuild switch";
        ccs = "codecrafters submit";
        cct = "codecrafters test";
        nano = "nvim";
        dr = "direnv reload";
        bereit = "ssh vincenzo@dumusstbereitsein.de";
        fzi = "ssh -l nl810@fzi.de fzi-gpu-mgmt-01.fzi.de";
        windows = "bash ~/nixos-config/scripts/windows.sh";
      };
      interactiveShellInit = ''
        set fish_greeting
        fish_add_path ~/.config/emacs/bin
      '';
    };
    kitty = {
      enable = true;
      font = {
        name = "Oxygen Mono";
        size = 18;
      };
      shellIntegration.enableFishIntegration = true;
      settings = {
        shell = "fish";
        scrollback_lines = 10000;
        cursor_shape = "beam";
        window_padding_width = 8;
        confirm_os_window_close = 0;
        background_opacity = "0.9";
      };
    };
  };

  # ── Caelestia shell (official module) ──────────────────────────
  # Based on https://github.com/mawkler/nixos/blob/main/home/caelestia.nix
  programs.caelestia = {
    enable = true;
    systemd = {
      enable = true;
      target = "xdg-desktop-portal-hyprland.service";
    };
    settings = {
      bar.status.showBattery = false;
      paths.wallpaperDir = "/home/vincenzo/nixos-config/wallpapers";
      general.apps = {
        terminal = [ "kitty" ];
        audio = [ "pavucontrol" ];
      };
    };
    cli = {
      enable = true;
      settings.theme = {
        enableGtk = true;
        enableQt = true;
        enableHypr = true;
      };
    };
  };

  # ── Caelestia runtime dependencies ─────────────────────────────
  # Only packages caelestia needs that aren't already in system modules.
  # System-level: wl-clipboard, xdg-desktop-portal-hyprland, fastfetch,
  #   btop, jq, socat, imagemagick, curl, qt5ct, qt6ct, pavucontrol
  home.packages = with pkgs; [
    xdg-desktop-portal-gtk
    hyprpicker
    cliphist
    inotify-tools
    app2unit
    trash-cli
    kitty
    fish
    starship
    adw-gtk3
    papirus-icon-theme
    nerd-fonts.jetbrains-mono
  ];

  # ── Services ───────────────────────────────────────────────────
  services = {
    udiskie.enable = true;
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

  home.sessionVariables = {
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
  };

  xdg.mimeApps.defaultApplications = {
    "application/pdf" = [ "zathura.desktop" ];
    "image/*" = [ "viewnior.desktop" ];
    "video/png" = [ "mpv.desktop" ];
    "video/jpg" = [ "mpv.desktop" ];
    "video/*" = [ "mpv.desktop" ];
  };

  systemd.user.startServices = "sd-switch";
}
