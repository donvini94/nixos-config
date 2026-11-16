# Rebuilds the prompt picked in Tern (Catppuccin Powerline, Tokyo Night palette, rounded
# start with arrow joins, λ, git counts, repo-relative directory) for every host and terminal.
{ ... }:
{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      palette = "tokyonight";
      palettes.tokyonight = {
        text = "#1a1b26";
        red = "#f7768e";
        orange = "#ff9e64";
        yellow = "#e0af68";
        green = "#9ece6a";
        cyan = "#7dcfff";
        purple = "#bb9af7";
      };

      # Rounded start, arrows between the blocks and at the end; the clock sits at the
      # right edge of the first line, mirrored.
      format = builtins.concatStringsSep "" [
        "[](fg:red)$os$username"
        "[](fg:red bg:orange)$directory"
        "[](fg:orange bg:yellow)$git_branch$git_status"
        "[](fg:yellow bg:green)$c$rust$golang$nodejs$java$haskell$python$nix_shell"
        "[ ](fg:green)$cmd_duration"
        "$fill"
        "[](fg:purple)$time[](fg:purple)"
        "$line_break"
        "$character"
      ];
      fill.symbol = " ";

      os = {
        disabled = false;
        style = "bg:red fg:text";
        format = "[$symbol ]($style)";
        symbols = {
          Macos = "";
          NixOS = "";
          Linux = "";
        };
      };
      username = {
        show_always = true;
        style_user = "bg:red fg:text";
        style_root = "bg:red fg:text";
        format = "[$user ]($style)";
      };
      directory = {
        style = "bg:orange fg:text";
        format = "[ $path$read_only ]($style)";
        truncate_to_repo = true;
        truncation_length = 3;
        truncation_symbol = "";
      };
      git_branch = {
        style = "bg:yellow fg:text";
        format = "[ $symbol$branch ]($style)";
        symbol = " ";
      };
      git_status = {
        style = "bg:yellow fg:text";
        format = "[($all_status$ahead_behind )]($style)";
        conflicted = "=\${count}";
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇡\${ahead_count}⇣\${behind_count}";
        untracked = "?\${count}";
        stashed = "\\$\${count}";
        modified = "!\${count}";
        staged = "+\${count}";
        renamed = "»\${count}";
        deleted = "✘\${count}";
      };
      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:purple fg:text";
        format = "[  $time ]($style)";
      };
      cmd_duration = {
        format = "[ $duration]($style) ";
        style = "fg:yellow";
      };
      character = {
        success_symbol = "[λ](bold fg:green)";
        error_symbol = "[λ](bold fg:red)";
        vimcmd_symbol = "[λ](bold fg:purple)";
      };

      aws.disabled = true;
      gcloud.disabled = true;
      # Spawning a JVM/node per prompt exceeds starship's 500ms command timeout under load.
      java.disabled = true;
      nodejs.disabled = true;
    }
    # Language modules share the green block and show only their version.
    // builtins.listToAttrs (
      map
        (name: {
          inherit name;
          value = {
            style = "bg:green fg:text";
            format = "[  $time ]($style)";
          };
        })
        [
          "c"
          "rust"
          "golang"
          "haskell"
          "python"
        ]
    )
    // {
      nix_shell = {
        style = "bg:green fg:text";
        format = "[ $symbol$name ]($style)";
        symbol = " ";
      };
    };
  };
}
