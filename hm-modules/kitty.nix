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
    # No multiplexing keybinds: kitty grabs ctrl+t and ctrl+s before zellij,
    # breaking zellij's tab and scroll modes.
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
    };
  };
}
