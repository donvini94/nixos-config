{ pkgs, ... }:

{
  # Gives `use devenv` in .envrc; devenv ships its own nix-direnv-derived direnvrc.
  xdg.configFile."direnv/lib/devenv.sh".source =
    pkgs.runCommand "devenv-direnvrc" { } "HOME=$TMPDIR ${pkgs.devenv}/bin/devenv direnvrc > $out";

  programs = {
    bash = {
      enable = true;
      enableCompletion = true;
      bashrcExtra = ''
        export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin:$HOME/.config/emacs/bin"
      '';
    };
    zoxide = {
      enable = true;
      enableFishIntegration = true;
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
