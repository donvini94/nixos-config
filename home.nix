{ inputs, lib, config, pkgs, ... }:

{

  imports = [
    #    inputs.hyprland.homeManagerModules.default
  ];

  home.username = "vincenzo";
  home.homeDirectory = "/home/vincenzo";

  programs.git = {
    enable = true;
    userName = "Vincenzo Pace";
    userEmail = "vincenzo.pace@mailbox.org";
  };

  nixpkgs.config.allowUnfree = true;
  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [

    neofetch
    exercism
    stack
    ranger

    # archives
    zip
    xz
    unzip
    p7zip

    # utils
    ripgrep # recursively searches directories for a regex pattern
    jq # A lightweight and flexible command-line JSON processor
    yq-go # yaml processer https://github.com/mikefarah/yq
    fzf # A command-line fuzzy finder
    zoxide
    mathpix-snipping-tool

    # networking tools
    mtr # A network diagnostic tool
    iperf3
    dnsutils # `dig` + `nslookup`
    ldns # replacement of `dig`, it provide the command `drill`
    aria2 # A lightweight multi-protocol & multi-source command-line download utility
    socat # replacement of openbsd-netcat
    nmap # A utility for network discovery and security auditing
    ipcalc # it is a calculator for the IPv4/v6 addresses

    # misc
    file
    which
    tree
    helix
    gnused
    gnutar
    gawk
    zstd
    gnupg
    mpv
    sxiv

    nix-output-monitor
    nixfmt

    # productivity
    glow # markdown previewer in terminal
    zathura
    pass-wayland
    rofi-pass
    anki
    waybar
    dunst
    libnotify
    swww
    rofi-wayland

    # communication
    telegram-desktop
    discord
    thunderbirdPackages.thunderbird-115
    zoom-us
    slack

    btop # replacement of htop/nmon
    iotop # io monitoring
    iftop # network monitoring

    # system call monitoring
    strace # system call monitoring
    ltrace # library call monitoring
    lsof # list open files

    # Python
    python311
    python311Packages.pip
    # system tools
    sysstat
    lm_sensors # for `sensors` command
    ethtool
    pciutils # lspci
    usbutils # lsusb
    libnotify
  ];

  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      aws.disabled = true;
      gcloud.disabled = true;
      line_break.disabled = true;
    };
  };

  programs.nushell = {
    enable = true;
    shellAliases = {
      vim = "nvim";
      nano = "nvim";
      e = "nvim";
      cheat = "cht.sh";
      c = "cht.sh";
    };
    extraConfig = ''
            let carapace_completer = {|spans|
            carapace $spans.0 nushell $spans | from json
            }
      $env.config = {
             show_banner: false,
             completions: {
             case_sensitive: false # case-sensitive completions
             quick: true    # set to false to prevent auto-selecting completions
             partial: true    # set to false to prevent partial filling of the prompt
             algorithm: "fuzzy"    # prefix or fuzzy
             external: {
             # set to false to prevent nushell looking into $env.PATH to find more suggestions
                 enable: true
             # set to lower can improve completion performance at the cost of omitting some options
                 max_results: 100
                 completer: $carapace_completer # check 'carapace_completer'
               }
             }
            }
    '';
  };

  programs.kitty = {
    enable = true;
    keybindings = {
      "ctrl+t" = "new_tab";
      "ctrl+w" = "close_tab";
      "ctrl+j" = "next_tab";
      "ctrl+k" = "previous_tab";
    };
    settings = {
      confirm_os_window_close = 0;
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";
    };
    theme = "Doom One";
    extraConfig = "shell nu";
  };

  programs.yazi = {
    enable = true;
    enableNushellIntegration = true;
    settings = {
      manager = {
        sort_by = "natural";
        sort_sensitive = false;
        sort_dir_first = true;
        sort_reverse = false;
        linemode = "size";
      };
      preview = {
        max_width = 20000;
        max_height = 10000;
      };
    };
    #keymap = {};

  };
  programs.carapace.enable = true;
  programs.carapace.enableNushellIntegration = true;

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

  systemd.user.startServices = "sd-switch";
  home.stateVersion = "23.05";
}
