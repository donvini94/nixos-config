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

  # Determinate Nix owns /etc/nix, nix.custom.conf and the daemon
  # (docs.determinate.systems/guides/nix-darwin); home-manager forwards this flag, so its
  # activation does not manage Nix either.
  nix.enable = false;

  # environment.shells is what lands the nix fish in /etc/shells as
  # /run/current-system/sw/bin/fish, so `chsh` will accept it.
  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];

  # fish's `__fish_macos_set_env` (login shells only) runs before nix-darwin's
  # set-environment, whose hard `export PATH=…` discards it, so everything /etc/paths.d
  # contributes is dropped and the non-nix prefixes are re-added here. mkOrder 1500 puts
  # them after the nix profiles (1000) and the macOS system dirs (1200), so Homebrew is a
  # fallback rather than an override.
  environment.systemPath = lib.mkOrder 1500 [
    "/opt/homebrew/bin" # 689 binaries: rustup, openstack, mvn, pass, mu, emacsclient, …
    "/opt/homebrew/sbin" # gnupg helpers, unbound
    "/Library/TeX/texbin" # MacTeX; texliveMedium is Linux-only in this repo
    "/usr/local/go/bin" # go, gofmt — gopls/gotests/gomodifytags are brew formulae
    "/Library/Apple/usr/bin" # rvictl
  ];

  # nix-darwin links these into "/Library/Fonts/Nix Fonts", so they coexist with the SF
  # casks and anything installed by hand.
  fonts.packages = with pkgs.nerd-fonts; [
    iosevka
    jetbrains-mono
    fira-code
    hack
    symbols-only
  ];

  # AppleInterfaceStyle is deliberately NOT set: macOS owns that key while
  # AppleInterfaceStyleSwitchesAutomatically is on, and declaring "Dark" alongside the
  # scheduler would re-assert dark at every activation and flip the UI if a rebuild
  # happened in a light window. nix-darwin types it as `nullOr (enum [ "Dark" ])` with a
  # null default, so leaving it out writes nothing.
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
