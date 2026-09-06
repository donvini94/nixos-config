# Config only: nixpkgs' ghostty has no darwin build and Zed's darwin build is not the one
# carrying the app's auto-update path, so both are hand-downloaded bundles; AeroSpace and
# emacs-plus are casks (./homebrew.nix).
{
  config,
  lib,
  pkgs,
  ...
}:

{
  xdg.configFile = {
    "ghostty/config".source = pkgs.replaceVars ./ghostty/config {
      fish = lib.getExe pkgs.fish;
    };
    "ghostty/themes/modus-vivendi-tinted".source = ./ghostty/themes/modus-vivendi-tinted;

    # AeroSpace's login-item environment has neither nix nor brew on PATH, so every
    # command it shells out to is absolute: @sketchybar@ and @fish@ become store paths,
    # and `aerospace list-workspaces --focused` is called via /opt/homebrew/bin.
    "aerospace/aerospace.toml".source = pkgs.replaceVars ./aerospace.toml {
      sketchybar = lib.getExe pkgs.sketchybar;
      fish = lib.getExe pkgs.fish;
    };

    # Zed's settings and keymap are shared with dracula, in hm-modules/zed.nix.

    # Out-of-store because the tree must stay WRITABLE: helpers/init.lua compiles the C
    # event providers into helpers/**/bin at every sketchybar startup, and $CONFIG_DIR
    # must be this directory for `require("helpers")` and the item scripts'
    # "$CONFIG_DIR/helpers/..." paths to resolve.
    "sketchybar".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/hosts/ac-0137/sketchybar";
  };
}
