# AC-0137 — the Mac daily driver, under nix-darwin.
#
# Division of labour on this host:
#   * Determinate Nix owns /etc/nix, nix.custom.conf and the daemon, so `nix.enable` is
#     false and nix-darwin never writes Nix configuration
#     (docs.determinate.systems/guides/nix-darwin). home-manager forwards that flag, so
#     its activation does not try to manage Nix either.
#   * nix-darwin owns the system layer: fonts, /etc/shells, macOS defaults, the launchd
#     agents for the bar and borders, and the Brewfile.
#   * home-manager owns ~/.config and the per-user package set (see ./home.nix).
#   * Homebrew keeps toolchains, macOS-integrated tools and GUI casks (see ./homebrew.nix).
{ lib, pkgs, ... }:

{
  imports = [
    ./homebrew.nix
    ./ui.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 7;
  system.primaryUser = "vincenzopace";

  # Deliberately NOT in users.knownUsers: nix-darwin must not try to create, re-own or
  # delete an account that already exists with a pre-nix uid. These two attributes exist
  # only to feed home-manager's home.username / home.homeDirectory
  # (home-manager/nixos/common.nix:64-65, which reads .name and .home and probes .uid
  # with tryEval).
  users.users.vincenzopace = {
    name = "vincenzopace";
    home = "/Users/vincenzopace";
  };

  nix.enable = false;

  # Writes /etc/fish/config.fish + nixos-env-preinit.fish and puts pkgs.fish in
  # systemPackages; environment.shells is what lands the nix fish in /etc/shells as
  # /run/current-system/sw/bin/fish so `chsh` will accept it.
  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];

  # PATH on this host, measured on the activated system rather than reasoned about.
  #
  # nix-darwin's /etc/fish/nixos-env-preinit.fish sources set-environment, which does a
  # hard `export PATH=<nix profiles>:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin`. fish's
  # own `__fish_macos_set_env` (its /usr/libexec/path_helper emulation, login shells only)
  # runs BEFORE that and its result is therefore discarded. Net effect: everything
  # /etc/paths.d contributes is silently dropped — verified empirically, 20 of 23 retained
  # Homebrew formulae became unreachable by name after the first switch.
  #
  # So the non-nix prefixes are restored here explicitly. mkOrder 1500 puts them AFTER
  # both the nix profiles (order 1000) and the macOS system dirs (order 1200), which is a
  # deliberate change from the pre-nix-darwin order: nix and the base system now win every
  # tie, and Homebrew is a fallback rather than an override.
  #
  # /pkg/env/global/bin and the three cryptexd bootstrap dirs from /etc/paths.d are
  # omitted because they do not exist on this machine; /System/Cryptexes/App/usr/bin is
  # omitted because nix-darwin's own 1200 entry omits it and it holds only safaridriver.
  environment.systemPath = lib.mkOrder 1500 [
    "/opt/homebrew/bin" # 689 binaries: rustup, openstack, mvn, pass, mu, emacsclient, …
    "/opt/homebrew/sbin" # gnupg helpers, unbound
    "/Library/TeX/texbin" # MacTeX; texliveMedium is Linux-only in this repo
    "/usr/local/go/bin" # go, gofmt — gopls/gotests/gomodifytags are brew formulae
    "/Library/Apple/usr/bin" # rvictl
  ];

  # Replaces the five font-*-nerd-font casks. nix-darwin links these into
  # "/Library/Fonts/Nix Fonts", so they coexist with the SF casks and anything installed
  # by hand.
  fonts.packages = with pkgs.nerd-fonts; [
    iosevka
    jetbrains-mono
    fira-code
    hack
    symbols-only
  ];

  # Every value below was read off this machine with `defaults read`, so activation
  # asserts the status quo instead of changing behaviour.
  #
  # AppleInterfaceStyle is deliberately NOT set. macOS owns that key while
  # AppleInterfaceStyleSwitchesAutomatically is on — it writes "Dark" during the dark
  # window and deletes the key during the light one. Declaring "Dark" alongside the
  # scheduler would re-assert dark at every activation and flip the UI if a rebuild
  # happened in a light window. nix-darwin types the option as `nullOr (enum [ "Dark" ])`
  # with a null default, so leaving it out means nothing is written and the scheduler
  # keeps the key to itself.
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyleSwitchesAutomatically = true;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      NSAutomaticCapitalizationEnabled = true;
      NSAutomaticPeriodSubstitutionEnabled = true;
      NSWindowShouldDragOnGesture = true;
      _HIHideMenuBar = true; # sketchybar replaces the menu bar
      "com.apple.swipescrolldirection" = true; # natural scrolling stays on
    };
    dock = {
      autohide = true;
      tilesize = 65;
      show-recents = false;
      mru-spaces = false; # required by AeroSpace
      minimize-to-application = true;
    };
    finder = {
      FXPreferredViewStyle = "Nlsv";
      FXDefaultSearchScope = "SCev";
    };
  };
}
