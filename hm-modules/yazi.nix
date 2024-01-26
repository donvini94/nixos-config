{ config, lib, pkgs, ... }:

{
  programs.yazi = {
    enable = true;
    enableNushellIntegration = true;
    settings = {
      manager = {
        sort_by = "natural";
        sort_sensitive = false;
        sort_dir_first = true;
        sort_reverse = false;
        linemode = "size";
      };
      preview = {
        max_width = 1920;
        max_height = 1080;
        cache_dir = "~/.cache/yazi/";
      };
    };
    #keymap = {};

  };

}
