# Doom Emacs configuration. ~/.config/doom is an out-of-store symlink to nixos-config/doom
# so config.org stays writable for org-auto-tangle and the generated files (config.el,
# custom.el) can land beside their sources.
{ config, ... }:

{
  xdg.configFile."doom".source = config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/nixos-config/doom";
}
