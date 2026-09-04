{ pkgs, ... }:

{
  # PATH additions live here rather than in interactiveShellInit so they reach
  # non-interactive and GUI-launched processes too: home-manager renders
  # home.sessionPath into hm-session-vars.fish, which fish sources from
  # config.fish. `fish_add_path` in interactiveShellInit only ever covered
  # interactive terminals.
  home.sessionPath = [
    "$HOME/.config/emacs/bin"
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
  ];

  programs.fish = {
    enable = true;
    shellAbbrs = {
      vim = "nvim";
      e = "nvim";
      cheat = "cht.sh";
      c = "cht.sh";
      cd = "z";
      switch =
        if pkgs.stdenv.hostPlatform.isDarwin then
          "sudo darwin-rebuild switch --flake ~/nixos-config"
        else
          "sudo nixos-rebuild switch";
      ccs = "codecrafters submit";
      cct = "codecrafters test";
      nano = "nvim";
      dr = "direnv reload";
      arr = "ssh media-admin";
      py = "python3";
      lg = "lazygit";
      bereit = "ssh vincenzo@dumusstbereitsein.de";
      windows = "bash ~/nixos-config/scripts/windows.sh";

      # Zellij workspace helpers. Abbreviations, not aliases, so they expand
      # inline — you see the full command before it runs.
      #   zj <name>   park OR resume a named session
      #   zjl         list parked sessions = the backburner index
      # Detach (park) from inside a session: Ctrl+o then d.
      # Retire one: zellij delete-session <name>.
      zj = "zellij attach -c";
      zjl = "zellij ls";
    };
    interactiveShellInit = ''
      set fish_greeting

      # Alt+E: edit current command line in emacs
      bind \ee edit_command_buffer

      # Alt+S: prepend sudo to current command
      bind \es 'fish_commandline_prepend sudo'
    '';
  };
}
