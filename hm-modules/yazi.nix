{
  pkgs,
  ...
}:

let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in
{
  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
    enableNushellIntegration = true;
    settings = {
      mgr = {
        sort_by = "natural";
        sort_sensitive = false;
        sort_dir_first = true;
        sort_reverse = false;
        linemode = "size";
      };
      # Sized for the host's panel: 1920x1080 on dracula, the Mac's HiDPI
      # external at 5120x2160.
      preview = {
        max_width = if isDarwin then 5120 else 1920;
        max_height = if isDarwin then 2160 else 1080;
        cache_dir = "~/.cache/yazi/";
      };
    };
    keymap = {
      # Bookmarks are mount points and project dirs, so they are per-platform:
      # /media and /run/media do not exist on macOS, and ~/documents/KIT is a
      # Linux-only checkout.
      mgr.prepend_keymap =
        if isDarwin then
          [
            {
              run = "cd /Volumes";
              on = [
                "g"
                "m"
              ];
              desc = "Go to volumes";
            }
            {
              run = "cd ~/Documents";
              on = [
                "g"
                "k"
              ];
              desc = "Go to Documents";
            }
            {
              run = "cd ~/nixos-config";
              on = [
                "g"
                "r"
              ];
              desc = "Go to nixos-config";
            }
          ]
        else
          [
            {
              run = "cd /media/";
              on = [
                "g"
                "m"
              ];
              desc = "Go to media directory";
            }
            {
              run = "cd ~/documents/KIT";
              on = [
                "g"
                "k"
              ];
              desc = "Go to KIT directory";
            }
            {
              run = "cd /run/media/vincenzo/data";
              on = [
                "g"
                "p"
              ];
              desc = "Go to data directory";
            }
          ];
    };
  };
}
