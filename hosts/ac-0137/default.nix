{
  lib,
  pkgs,
  username,
  ...
}:

{
  imports = [
    ./homebrew.nix
    ./ui.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 7;
  system.primaryUser = username;

  # Do not add this existing macOS account to users.knownUsers.
  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  # Exact command match, like the Linux hosts: rebuilding a writable checkout is root-equivalent.
  security.sudo.extraConfig = ''
    ${username} ALL = (root) NOPASSWD: /run/current-system/sw/bin/darwin-rebuild switch --flake /Users/${username}/nixos-config\#AC-0137
  '';

  # The installer still owns the Determinate Nix runtime and main nix.conf. This module
  # makes its supported custom and daemon policy files declarative through nix-darwin.
  determinateNix = {
    enable = true;
    determinateNixd = {
      garbageCollector.strategy = "automatic";
      builder.state = "disabled";
      telemetry.sentry.endpoint = null;
    };
  };

  # environment.shells is what lands the nix fish in /etc/shells as
  # /run/current-system/sw/bin/fish, so `chsh` will accept it.
  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];

  # nix-darwin replaces login PATH; restore non-Nix tools after system profiles.
  environment.systemPath = lib.mkOrder 1500 [
    "/opt/homebrew/bin"
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

  # Leave AppleInterfaceStyle unset so activation does not override automatic switching.
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
