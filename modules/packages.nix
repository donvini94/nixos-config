{ config, pkgs, ... }:

{
  
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    git
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    neovim
    helix
    fzf # A command-line fuzzy finder

    ripgrep # recursively searches directories for a regex pattern
    # archives
    zip
    xz
    unzip
    p7zip

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
    gnused
    gnutar
    gawk
    zstd
    gnupg

    # system tools
    sysstat
    lm_sensors # for `sensors` command
    ethtool
    pciutils # lspci
    usbutils # lsusb
    libnotify
    btop # replacement of htop/nmon
    iotop # io monitoring
    iftop # network monitoring



    zoxide
    wget
    curl
    psmisc
    emacs29
    coreutils
    fd
    clang
    blueberry
    unar

    xdg-user-dirs
    xdg-desktop-portal-hyprland
    swaylock-effects

    brightnessctl
    #pinentry
    #pinentry-rofi
    starship
    pcmanfm
    xfce.thunar
    gparted
    grim
    slurp
    wl-clipboard
    networkmanagerapplet
    wlogout
    texlive.combined.scheme-full
    magic-wormhole
    pavucontrol
    rust-analyzer
    rustup
    rustfmt
    jdk17
    cabal-install
    haskell-language-server
    ghc
    ghcid
    qt5ct
    qt6ct
    nwg-look
    font-awesome
    cht-sh
    swaylock
    btrfs-progs
    # system call monitoring
    strace # system call monitoring
    ltrace # library call monitoring
    lsof # list open files

    waybar
    dunst
    swww


    rofi-wayland
    pass-wayland
    rofi-pass
    # Python
    python311
    python311Packages.pip
    stack
    nix-output-monitor
    nixfmt
    # Japanese fonts
    noto-fonts-cjk
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    kochi-substitute
    # iosevka
    # oxygenfonts
  ];
}
