{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    vim
    neovim

    # Search & navigation (useful on all hosts)
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

    # Secrets
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

    # Base system utilities
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

    # Hardware / filesystem
    btrfs-progs
    efibootmgr
    pciutils
    usbutils

    # System monitoring
    sysstat
    lm_sensors
    ethtool
    btop
    iotop
    iftop
    lazydocker
    psmisc

    # System debugging
    strace
    ltrace
    lsof

    # Media tools (server has media stack too)
    mediainfo
    imagemagick

    # XDG / dbus integration
    xdg-user-dirs
    libnotify
  ];
}
