# The shell, editor and agent setup every host shares.
{
  imports = [
    ../ai/home
    ./git.nix
    # fish's cd abbreviation needs shell.nix's zoxide.
    ./fish.nix
    ./shell.nix
    ./atuin.nix
    ./helix.nix
    ./yazi.nix
    ./lsp.nix
    ./cli-tools.nix
  ];

  programs.home-manager.enable = true;
  programs.ompClient.enable = true;
  programs.piClient.enable = true;
}
