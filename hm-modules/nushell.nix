{
  config,
  lib,
  pkgs,
  ...
}:

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
        switch = "sudo nixos-rebuild switch";
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

    atuin = {
      enable = true;
      enableNushellIntegration = true;
      settings = {
        auto_sync = true;
        sync_address = "https://dumusstbereitsein.de";
        search_mode = "prefix";
      };
    };
  };
}
