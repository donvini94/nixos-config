{ ... }:
{
  programs.zellij = {
    enable = true;
    enableFishIntegration = false; # don't auto-start in every shell
    settings = {
      theme = "default";
      default_layout = "compact"; # minimal UI, more terminal space
      pane_frames = false; # cleaner look, borders only
      copy_on_select = true;
      scrollback_editor = "emacsclient -a '' -c";
    };
  };
}
