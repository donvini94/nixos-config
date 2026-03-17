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
    ./hm-modules/mpv.nix
    ./hm-modules/packages.nix
    ./hm-modules/yazi.nix
    ./hm-modules/zathura.nix
    inputs.caelestia-nixos.homeManagerModules.default
  ];

  nixpkgs.config.allowUnfree = true;

  home = {
    username = "${username}";
    homeDirectory = "/home/${username}";
    stateVersion = "23.05";
  };

  fonts.fontconfig.enable = true;

  # ── Core programs ──────────────────────────────────────────────
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
  };

  # ── Caelestia (full desktop environment) ───────────────────────
  programs.caelestia-dots = {
    enable = true;

    hypr = {
      enable = true;
      variables.settings = {
        "$editor" = "emacsclient -c";
      };
    };

    caelestia = {
      shell = {
        enable = true;
        settings = {
          bar.status.showBattery = false;
          paths.wallpaperDir = "~/nixos-config/wallpapers/";
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
  };

  # ── NVIDIA hardware workarounds (sourced last by hyprland.conf) ─
  xdg.configFile."caelestia/hypr-user.conf".text = ''
    env = LIBVA_DRIVER_NAME,nvidia
    env = GBM_BACKEND,nvidia-drm
    env = NVD_BACKEND,direct
    env = AQ_DRM_DEVICES,/dev/dri/card2:/dev/dri/card1
    cursor {
        no_hardware_cursors = true
    }
  '';

  # ── Services ───────────────────────────────────────────────────
  services = {
    udiskie.enable = true;
    syncthing.enable = true;
    mpd = {
      enable = true;
      musicDirectory = "/media/music";
      network.startWhenNeeded = true;
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
