# Zed editor configuration, shared by every host with home-manager.
#
# Config only, never the package: dracula installs `zed-editor` from
# hm-modules/packages.nix, while on AC-0137 Zed is a hand-downloaded .app bundle (so it
# keeps its own auto-update path). Both read $XDG_CONFIG_HOME/zed, so one module serves
# both.
#
# The files are copied verbatim rather than generated from Nix. They are JSONC — comments
# and trailing commas — which means `builtins.fromJSON` cannot read them and
# `programs.zed-editor.userSettings` cannot round-trip them. Zed itself rewrites
# settings.json when you change a setting through the UI, so keeping the authored form is
# what makes the diff reviewable.
#
# Portable as written, checked rather than assumed:
#   * keymap.json binds only `ctrl-*` inside vim-mode contexts — no `cmd-*` at all — so
#     it means the same thing on Linux and macOS.
#   * "Iosevka Nerd Font" exists on both: modules/fonts.nix installs the whole
#     pkgs.nerd-fonts set on dracula, hosts/ac-0137/default.nix installs the iosevka one.
#   * The Python block selects `ty` + `ruff` and disables pyright/basedpyright/pylsp,
#     which matches hm-modules/lsp.nix on every host.
#
# auto_install_extensions makes the extension set reproducible instead of ambient state;
# see the comment at the top of settings.json. A `false` value means "never install", so
# retiring an extension means adding it as false, not deleting the line.
{ ... }:

{
  xdg.configFile = {
    "zed/settings.json".source = ./zed/settings.json;
    "zed/keymap.json".source = ./zed/keymap.json;
  };
}
