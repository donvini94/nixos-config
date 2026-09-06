{ ... }:
{
  programs.zathura = {
    enable = true;
    options = {
      pages-per-row = "1";
      scroll-page-aware = "true";
      scroll-full-overlap = "0.01";
      scroll-step = "100";
      statusbar-basename = true;
      font = "Iosevka";

      recolor-keephue = "true";

      recolor-reverse-video = "false";

      completion-fg = "#c0caf5";
      completion-bg = "#1a1b26";

      completion-group-fg = "#7aa2f7";
      completion-group-bg = "#1a1b26";

      completion-highlight-fg = "#1a1b26";
      completion-highlight-bg = "#c0caf5";

      default-bg = "rgba(26, 27, 38, 0.95)";

      inputbar-fg = "#c0caf5";
      inputbar-bg = "#1a1b26";

      notification-fg = "#c0caf5";
      notification-bg = "#1a1b26";

      notification-error-fg = "#c0caf5";
      notification-error-bg = "#355B88";

      notification-warning-fg = "#c0caf5";
      notification-warning-bg = "#355B88";

      statusbar-fg = "#c0caf5";
      statusbar-bg = "#1a1b26";

      highlight-color = "#7aa2f7";
      highlight-active-color = "#7aa2f7";

      recolor-lightcolor = "rgba(0, 0, 0, 0)";
      recolor-darkcolor = "#c0caf5";

      render-loading-fg = "#c0caf5";
      render-loading-bg = "#1a1b26";

      index-fg = "#c0caf5";
      index-bg = "#1a1b26";

      index-active-fg = "#1a1b26";
      index-active-bg = "#c0caf5";
    };
    mappings = {
      i = "recolor";
      "," = "navigate previous";
      "." = "navigate next";
    };
  };
}
