# Doom Emacs configuration.
#
# Config files live in nixos-config/doom/ and are symlinked as a directory:
#   ~/.config/doom → ~/nixos-config/doom
#
# This keeps config.org writable (needed for org-auto-tangle) and lets you
# edit directly without rebuild. After changes to init.el or packages.el,
# run `doom sync`.
{ config, ... }:

{
  # Symlink the entire doom directory so all files are writable and editable.
  # Generated files (config.el, custom.el) live alongside the source files.
  xdg.configFile."doom".source = config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/nixos-config/doom";
}
