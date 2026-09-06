{ pkgs, ... }:

{
  # PATH lives here rather than in interactiveShellInit so it reaches non-interactive and
  # GUI-launched processes too: home-manager renders home.sessionPath into
  # hm-session-vars.fish, while `fish_add_path` only ever covers interactive terminals.
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

      # The zellij helpers (zj / zjr / zjls / zjl) are functions in hm-modules/zellij, next
      # to the keymap they belong to: they branch on whether the session already exists.
    };
    interactiveShellInit = ''
      set fish_greeting

      bind \ee edit_command_buffer

      bind \es 'fish_commandline_prepend sudo'
    '';
  };
}
