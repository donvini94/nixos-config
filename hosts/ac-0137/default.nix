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
{ pkgs, ... }:

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

  # PATH ordering on this host, measured rather than assumed:
  #   1. nix-darwin's /etc/fish/nixos-env-preinit.fish sources set-environment, which
  #      OVERWRITES PATH with the nix profiles + /usr/bin & friends. /opt/homebrew/bin is
  #      not in that list.
  #   2. In a LOGIN fish, fish's own `__fish_macos_set_env` then emulates
  #      /usr/libexec/path_helper: /etc/paths and /etc/paths.d/* go FIRST, the inherited
  #      PATH is appended after. So /opt/homebrew/bin ends up AHEAD of
  #      /etc/profiles/per-user/vincenzopace/bin. Ghostty launches fish with argv[0]
  #      "-fish", i.e. as a login shell, so interactive terminals take this path.
  #   3. home-manager's hm-session-vars.fish then prepends home.sessionPath.
  #
  # Homebrew therefore WINS ties against the per-user nix profile. That is safe only
  # because ./homebrew.nix uninstalls every formula that duplicates a nix-provided tool;
  # the formulae it keeps are either keg-only (curl) or g-prefixed (coreutils, grep) and
  # collide with nothing. Adding a formula that shadows a nix tool would silently take
  # precedence — check with `command -v` after any change here.

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
