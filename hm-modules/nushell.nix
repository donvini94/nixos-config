{ config, lib, pkgs, ... }:

{
  programs = {
    nushell = {
      enable = true;
      shellAliases = {
        vim = "nvim";
        nano = "nvim";
        e = "nvim";
        cheat = "cht.sh";
        c = "cht.sh";
        cd = "z";
      };
      extraConfig = ''
        $env.config = {
               show_banner: false,
              }
        $env.PATH = ($env.PATH | split row (char esep) | append "~/.config/emacs/bin/doom")
      '';
    };

    direnv = {
      enable = true;
      enableNushellIntegration = true;
      nix-direnv.enable = true;
    };
  };
}
