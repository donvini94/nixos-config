{ ... }:
{
  programs.kitty = {
    enable = true;
    font = {
      name = "Iosevka Term";
      size = 18;
    };
    themeFile = "Modus_Vivendi_Tinted";
    shellIntegration.enableFishIntegration = true;
    # No multiplexing keybinds: zellij owns panes/tabs/nav/scrollback uniformly
    # (local + remote), so kitty is a clean single-window host. Crucially this
    # frees ctrl+t and ctrl+s, which kitty would otherwise grab before zellij
    # (breaking zellij's tab and scroll modes inside kitty). hjkl/splits/tabs
    # removed too — zellij replaces them, and ctrl+hjkl no longer shadows shell
    # editing keys. Re-add a bind here only if it must beat the running program.
    environment = {
      "LANG" = "en_US.UTF-8";
    };
    settings = {
      shell = "fish";
      scrollback_lines = 10000; # bare-kitty mouse scroll still uses this
      cursor_shape = "beam";
      window_padding_width = 8;
      confirm_os_window_close = 0;
      background_opacity = "0.9";
      allow_remote_control = "socket-only";
      listen_on = "unix:/tmp/kitty";
      # Removed (zellij now owns multiplexing, so these only configured kitty's
      # own splits/tabs/scrollback that we no longer cultivate): tab_bar_style,
      # tab_powerline_style, enabled_layouts, scrollback_pager. kitty's built-in
      # ctrl+shift+* bindings still work; they just fall back to kitty defaults.
    };
  };
}
