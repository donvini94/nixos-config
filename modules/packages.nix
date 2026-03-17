{
  config,
  pkgs,
  inputs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    git
    vim
    neovim
    fzf
    television
    entr
    fastfetch

    ripgrep
    ripgrep-all

    # Archives
    zip
    xz
    unzip
    p7zip
    unrar
    pigz

    wofi-pass
    powertop

    # Secrets
    age
    sops

    piper

    # Networking
    mtr
    iperf3
    dnsutils
    ldns
    aria2
    socat
    nmap
    ipcalc

    pandoc
    mupdf

    # Utilities
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    gnupg
    wget
    curl
    csvlens
    graphviz
    groff
    ghostscript

    # System monitoring
    sysstat
    lm_sensors
    ethtool
    pciutils
    usbutils
    libnotify
    btop
    iotop
    iftop
    lazydocker
    zoxide
    psmisc
    coreutils
    gnumake
    gcc
    pkg-config
    libtool
    cmake
    fd
    clang
    unar

    # Stress testing
    undervolt
    s-tui
    stress

    xdg-user-dirs
    cht-sh
    tldr
    btrfs-progs

    # System call monitoring
    strace
    ltrace
    lsof
    lact
    efibootmgr

    # Finance
    hledger
    hledger-ui
    hledger-utils
    hledger-interest
    hledger-web

    # Media tools
    mediainfo
    imagemagick
    picard
  ];
}
