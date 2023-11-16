# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, lib, config, pkgs, ... }:

{
  imports = [ # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "asgar"; # Define your hostname.
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  hardware.bluetooth.enable = true;
  security.rtkit.enable = true;

  services = {
    emacs.enable = true;
    printing.enable = true;
    xserver = {
      enable = true;
      layout = "us";
      xkbVariant = "";
      desktopManager.plasma5.enable = true;
      displayManager.sddm.enable = true;
    };
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      # If you want to use JACK applications, uncomment this
      #jack.enable = true;

      # use the example session manager (no others are packaged yet so this is enabled by default,
      # no need to redefine it in your config for now)
      #media-session.enable = true;
    };
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  users.users.vincenzo = {
    isNormalUser = true;
    description = "Vincenzo Pace";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [ firefox kate ];
  };

  nixpkgs.config.allowUnfree = true;

  nix = {
    settings.experimental-features = [ "nix-command" "flakes" ];
    settings.trusted-users = [ "vincenzo" ];
    settings.auto-optimise-store = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 1w";
    };
  };

  # add user's shell into /etc/shells
  environment.shells = with pkgs; [ bash nushell ];
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    git
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    neovim
    helix
    wget
    curl
    psmisc
    emacs29
    ripgrep
    coreutils
    fd
    clang
    pferd
    blueberry
    unar

    brightnessctl
    pinentry
    pinentry-rofi
    starship
    pcmanfm
    xfce.thunar
    gparted
    grim
    slurp
    wl-clipboard
    networkmanagerapplet
    wlogout
    oxygenfonts
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
    mullvad-vpn
    signal-desktop
    qt5ct
    qt6ct
    nwg-look
    font-awesome
  ];

  environment.variables.EDITOR = "nvim";

  #  xdg.portal = {
  #    enable = true;
  #    wlr.enable = true;
  #    extraPortals = with pkgs; [
  #      xdg-desktop-portal-wlr
  #    ];
  #  };

  fonts.packages = with pkgs;
    [ (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" "Hack" ]; }) ];

  programs.steam = {
    enable = true;
  };
  hardware.opengl.driSupport32Bit = true; # Enables support for 32bit libs that steam uses

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    # package = inputs.hyprland.packages.${pkgs.system}.hyprland;
  };
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  services.pcscd.enable = true;
  services.mullvad-vpn.enable = true;
  services.logind.lidSwitchExternalPower = "ignore";
  services.pipewire.wireplumber.enable = true;
  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  system.stateVersion = "23.05";

}
