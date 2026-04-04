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
    ./hm-modules/kitty.nix
    ./hm-modules/mpv.nix
    ./hm-modules/packages.nix
    ./hm-modules/starship.nix
    ./hm-modules/yazi.nix
    ./hm-modules/zathura.nix
    ./hm-modules/doom.nix
    ./hm-modules/zellij.nix
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

  home.activation.ensureSshControlDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p $HOME/.ssh/sockets
    chmod 700 $HOME/.ssh/sockets
  '';

  fonts.fontconfig.enable = true;

  # ── Programs ───────────────────────────────────────────────────
  programs = {
    home-manager.enable = true;
    git = {
      enable = true;
      settings.user.name = "${fullName}";
      settings.user.email = "${mail}";
    };
    ssh = {
      enable = true;
      controlMaster = "auto";
      controlPath = "~/.ssh/sockets/%r@%h-%p";
      controlPersist = "600";
      matchBlocks = {
        "github.com" = {
          hostname = "ssh.github.com";
          port = 443;
        };
        "Bereitserver" = {
          hostname = "dumusstbereitsein.de";
          user = "vincenzo";
        };
        "media-admin" = {
          hostname = "dumusstbereitsein.de";
          user = "vincenzo";
          localForwards = [
            { bind.port = 18989; host.address = "localhost"; host.port = 18989; }
            { bind.port = 18080; host.address = "localhost"; host.port = 18080; }
            { bind.port = 19696; host.address = "localhost"; host.port = 19696; }
            { bind.port = 17878; host.address = "localhost"; host.port = 17878; }
            { bind.port = 16767; host.address = "localhost"; host.port = 16767; }
            { bind.port = 19090; host.address = "localhost"; host.port = 19090; }
          ];
          extraOptions = {
            SetEnv = "TERM=xterm";
          };
        };
      };
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
        arr = "ssh media-admin";
        py = "python3";
        lg = "lazygit";
        bereit = "ssh vincenzo@dumusstbereitsein.de";
        windows = "bash ~/nixos-config/scripts/windows.sh";
      };
      interactiveShellInit = ''
        set fish_greeting
        fish_add_path ~/.config/emacs/bin
        fish_add_path ~/.local/bin
        fish_add_path ~/.cargo/bin

        # Alt+E: edit current command line in emacs
        bind \ee edit_command_buffer

        # Alt+S: prepend sudo to current command
        bind \es 'fish_commandline_prepend sudo'
      '';
    };
  };

  # ── Caelestia shell (official module) ──────────────────────────
  # Based on https://github.com/mawkler/nixos/blob/main/home/caelestia.nix
  programs.caelestia = {
    enable = true;
    systemd.enable = true;
    settings = {
      bar.status.showBattery = false;
      paths.wallpaperDir = "/home/vincenzo/nixos-config/wallpapers";
      background.desktopClock = {
        enabled = true;
        position = "bottom-right";
      };
      general.idle = {
        lockBeforeSleep = true;
        inhibitWhenAudio = true;
        timeouts = [
          { timeout = 300; idleAction = "lock"; }
          { timeout = 600; idleAction = "dpms off"; returnAction = "dpms on"; }
        ];
      };
      notifs.expire = true;
      lock.sizes.heightMult = 1.0;
      general.apps = {
        terminal = [ "kitty" ];
        audio = [ "pavucontrol" ];
        explorer = [ "kitty" "-e" "yazi" ];
        playback = [ "mpv" ];
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
    adw-gtk3
    papirus-icon-theme
    nerd-fonts.jetbrains-mono
    wtype # programmatic keyboard input on Wayland (for scripting)
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

  xdg.mimeApps.defaultApplications = {
    "application/pdf" = [ "zathura.desktop" ];
    "image/*" = [ "viewnior.desktop" ];
    "video/*" = [ "mpv.desktop" ];
  };

  systemd.user.startServices = "sd-switch";
}
