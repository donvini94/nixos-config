{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    vim
    neovim

    ripgrep
    fd
    tree
    fzf
    fastfetch

    # Archives (other packages depend on these)
    zip
    xz
    unzip
    p7zip
    unrar
    pigz
    unar
    zstd

    age
    sops

    # Networking (setuid/capabilities required)
    mtr
    iperf3
    dnsutils
    ldns
    socat
    nmap
    ipcalc
    mullvad-vpn

    file
    which
    coreutils
    gnused
    gnutar
    gawk
    gnupg
    wget
    curl
    groff
    ghostscript
    gnumake
    gcc
    pkg-config
    libtool
    cmake
    clang

    btrfs-progs
    efibootmgr
    pciutils
    usbutils

    sysstat
    lm_sensors
    ethtool
    btop
    iotop
    iftop
    lazydocker
    psmisc

    strace
    ltrace
    lsof

    # Media tools (server has media stack too)
    mediainfo
    imagemagick

    xdg-user-dirs
    libnotify
  ];
}
