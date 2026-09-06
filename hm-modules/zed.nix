# Zed editor configuration, shared by every host with home-manager.
#
# Config only, never the package: dracula installs `zed-editor` from hm-modules/packages.nix,
# while on AC-0137 Zed is a hand-downloaded .app bundle that keeps its own auto-update path.
#
# The files are copied verbatim because they are JSONC: `builtins.fromJSON` cannot read them
# and `programs.zed-editor.userSettings` cannot round-trip them.
#
# In settings.json a `false` in auto_install_extensions means "never install", so retiring an
# extension means setting it to false, not deleting the line.
{ ... }:

{
  xdg.configFile = {
    "zed/settings.json".source = ./zed/settings.json;
    "zed/keymap.json".source = ./zed/keymap.json;
  };
}
