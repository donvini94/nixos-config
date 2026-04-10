{ ... }:

{
  programs.fish = {
    enable = true;
    shellAbbrs = {
      vim = "nvim";
      e = "nvim";
      cheat = "cht.sh";
      c = "cht.sh";
      cd = "z";
      switch = "sudo nixos-rebuild switch";
      ccs = "codecrafters submit";
      cct = "codecrafters test";
      nano = "nvim";
      dr = "direnv reload";
      arr = "ssh media-admin";
      py = "python3";
      lg = "lazygit";
      bereit = "ssh vincenzo@dumusstbereitsein.de";
      windows = "bash ~/nixos-config/scripts/windows.sh";
    };
    interactiveShellInit = ''
      set fish_greeting
      fish_add_path ~/.config/emacs/bin
      fish_add_path ~/.local/bin
      fish_add_path ~/.cargo/bin

      # Alt+E: edit current command line in emacs
      bind \ee edit_command_buffer

      # Alt+S: prepend sudo to current command
      bind \es 'fish_commandline_prepend sudo'
    '';
  };
}
