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
      # Window navigation (vim hjkl — shadows ctrl+l clear and ctrl+j newline in shell)
      "ctrl+h" = "neighboring_window left";
      "ctrl+j" = "neighboring_window down";
      "ctrl+k" = "neighboring_window up";
      "ctrl+l" = "neighboring_window right";

      # Splits (mirrors vim <C-w>v / <C-w>s)
      "ctrl+backslash" = "launch --location=vsplit";
      "ctrl+minus" = "launch --location=hsplit";
      "ctrl+shift+w" = "close_window";

      # Tabs (bracket nav, doom-style)
      "ctrl+t" = "new_tab";
      "ctrl+shift+t" = "close_tab";
      "ctrl+shift+]" = "next_tab";
      "ctrl+shift+[" = "previous_tab";

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
