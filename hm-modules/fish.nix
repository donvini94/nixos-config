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

      # Zellij helpers (zj / zjr / zjls / zjl) live in hm-modules/zellij, next
      # to the keymap they belong to. They are functions rather than
      # abbreviations because they branch on whether the session already exists.
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
