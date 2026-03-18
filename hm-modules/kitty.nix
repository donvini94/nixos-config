{ ... }:
{
  programs.kitty = {
    enable = true;
    font = {
      name = "Oxygen Mono";
      size = 18;
    };
    themeFile = "Modus_Vivendi";
    shellIntegration.enableFishIntegration = true;
    keybindings = {
      # Tabs
      "ctrl+t" = "new_tab";
      "ctrl+w" = "close_tab";
      "ctrl+j" = "next_tab";
      "ctrl+k" = "previous_tab";

      # Vim-style window (split) navigation
      "ctrl+shift+h" = "neighboring_window left";
      "ctrl+shift+j" = "neighboring_window down";
      "ctrl+shift+k" = "neighboring_window up";
      "ctrl+shift+l" = "neighboring_window right";

      # Splits
      "ctrl+shift+enter" = "new_window";
      "ctrl+shift+minus" = "launch --location=hsplit";
      "ctrl+shift+backslash" = "launch --location=vsplit";

      # Scrollback in nvim
      "ctrl+shift+s" = "show_scrollback";
    };
    environment = {
      "LANG" = "en_US.UTF-8";
    };
    settings = {
      shell = "fish";
      scrollback_lines = 10000;
      scrollback_pager = "nvim -c 'set ft=man' -";
      cursor_shape = "beam";
      window_padding_width = 8;
      confirm_os_window_close = 0;
      background_opacity = "0.9";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";
      enabled_layouts = "splits,tall,stack";
      allow_remote_control = "socket-only";
      listen_on = "unix:/tmp/kitty";
    };
  };
}
