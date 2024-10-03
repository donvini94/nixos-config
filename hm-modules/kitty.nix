{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.kitty = {
    enable = true;
    keybindings = {
      "ctrl+t" = "new_tab";
      "ctrl+w" = "close_tab";
      "ctrl+j" = "next_tab";
      "ctrl+k" = "previous_tab";
    };
    settings = {
      confirm_os_window_close = 0;
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";
    };
    themeFile = "Modus_Vivendi";
    environment = {
      "LANG" = "en_US.UTF-8";
    };
    font = {
      name = "Oxygen Mono";
      size = 16;
    };

    extraConfig = "shell nu";
  };
}
