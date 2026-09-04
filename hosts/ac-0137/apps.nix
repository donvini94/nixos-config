# Configuration for apps nix does not install on this host.
#
# Ghostty and Zed are hand-downloaded .app bundles (nixpkgs' ghostty has no darwin build;
# Zed's darwin build is not the one carrying the app's auto-update path), AeroSpace and
# emacs-plus are casks. `brew install --cask` refuses a pre-existing unmanaged bundle, so
# none of them are adopted into ./homebrew.nix — only their config files are managed.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  xdg.configFile = {
    # @fish@ replaces the hardcoded `command = /opt/homebrew/bin/fish`, which points at a
    # formula ./homebrew.nix no longer installs.
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

    # Zed's settings and keymap are shared with dracula — see hm-modules/zed.nix.

    # Out-of-store, like hm-modules/doom.nix, because the tree must stay WRITABLE:
    # helpers/init.lua compiles the C event providers into helpers/**/bin at every
    # sketchybar startup, and $CONFIG_DIR must be this directory for
    # `require("helpers")` and the item scripts' "$CONFIG_DIR/helpers/..." paths to
    # resolve. The built bin/ dirs are gitignored by sketchybar/helpers/.gitignore.
    "sketchybar".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/hosts/ac-0137/sketchybar";
  };
}
