{ inputs, lib, config, pkgs, ... }:


{

imports = [
#    inputs.hyprland.homeManagerModules.default
];

  home.username = "vincenzo";
  home.homeDirectory = "/home/vincenzo";
  # set cursor size and dpi for 4k monitor
#  xresources.properties = {
#    "Xcursor.size" = 16;
#    "Xft.dpi" = 172;
#  };

  programs.git = {
    enable = true;
    userName = "Vincenzo Pace";
    userEmail = "vincenzo.pace@mailbox.org";
  };

  nixpkgs.config.allowUnfree = true;
  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [

    neofetch
    nnn # terminal file manager

    # archives
    zip
    xz
    unzip
    p7zip

    # utils
    ripgrep # recursively searches directories for a regex pattern
    jq # A lightweight and flexible command-line JSON processor
    yq-go # yaml processer https://github.com/mikefarah/yq
    exa # A modern replacement for ‘ls’
    fzf # A command-line fuzzy finder
    mathpix-snipping-tool

    # networking tools
    mtr # A network diagnostic tool
    iperf3
    dnsutils  # `dig` + `nslookup`
    ldns # replacement of `dig`, it provide the command `drill`
    aria2 # A lightweight multi-protocol & multi-source command-line download utility
    socat # replacement of openbsd-netcat
    nmap # A utility for network discovery and security auditing
    ipcalc  # it is a calculator for the IPv4/v6 addresses

    # misc
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    gnupg
    mpv

    # nix related
    #
    # it provides the command `nom` works just like `nix`
    # with more details log output
    nix-output-monitor
    nixfmt

    # productivity
    glow # markdown previewer in terminal
    zathura
    pass-wayland
    rofi-pass
    vimiv-qt
    anki
    waybar
    dunst
    libnotify
    swww
    rofi-wayland

    # communication
    signal-desktop
    telegram-desktop
    discord
    fractal-next
    thunderbirdPackages.thunderbird-115
    zoom-us


    btop  # replacement of htop/nmon
    iotop # io monitoring
    iftop # network monitoring

    # system call monitoring
    strace # system call monitoring
    ltrace # library call monitoring
    lsof # list open files

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
      add_newline = false;
      aws.disabled = true;
      gcloud.disabled = true;
      line_break.disabled = true;
    };
  };


  # alacritty - a cross-platform, GPU-accelerated terminal emulator
  programs.alacritty = {
    enable = true;
    # custom settings
    settings = {
      env.TERM = "xterm-256color";
      font = {
        size = 12;
        draw_bold_text_with_bright_colors = true;
      };
      scrolling.multiplier = 5;
      selection.save_to_clipboard = true;
    };
  };

  programs.kitty = {
    enable = true;
  };


  programs.wofi.enable = true;

  programs.bash = {
    enable = true;
    enableCompletion = true;
    bashrcExtra = ''
      export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin:$HOME/.config/emacs/bin/doom"
    '';

    # set some aliases, feel free to add more or remove some
    shellAliases = {
    };
  };

  programs.home-manager.enable = true;


  services = {
    udiskie.enable = true;
    syncthing.enable = true;
  };

  systemd.user.startServices = "sd-switch";
  home.stateVersion = "23.05";
}
