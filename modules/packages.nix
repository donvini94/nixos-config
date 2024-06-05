{ config, pkgs, ... }:

{

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    git
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    neovim
    fzf # A command-line fuzzy finder
    entr

    ripgrep # recursively searches directories for a regex pattern
    ripgrep-all
    # archives
    zip
    xz
    unzip
    p7zip
    unrar
    pigz

    # networking tools
    mtr # A network diagnostic tool
    iperf3
    dnsutils # `dig` + `nslookup`
    ldns # replacement of `dig`, it provide the command `drill`
    aria2 # A lightweight multi-protocol & multi-source command-line download utility
    socat # replacement of openbsd-netcat
    nmap # A utility for network discovery and security auditing
    ipcalc # it is a calculator for the IPv4/v6 addresses
    nextdns

    pandoc
    mupdf

    # misc
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
    graphviz
    lazydocker

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
    psmisc
    coreutils
    gnumake
    libtool
    cmake
    fd
    clang
    unar

    xdg-user-dirs
    cht-sh # Cheatsheet
    btrfs-progs
    # system call monitoring
    strace # system call monitoring
    ltrace # library call monitoring
    lsof # list open files
  ];
}
