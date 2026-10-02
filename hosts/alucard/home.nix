{
  username,
  ...
}:

{
  imports = [
    ../../hm-modules/omp.nix
    ../../hm-modules/pi.nix
    ../../hm-modules/agent-skills.nix
    ../../hm-modules/lsp.nix
    ./zellij.nix

    # fish's cd abbreviation needs shell.nix's zoxide.
    ../../hm-modules/fish.nix
    ../../hm-modules/shell.nix
    ../../hm-modules/starship.nix
    ../../hm-modules/atuin.nix
    ../../hm-modules/git.nix
    ../../hm-modules/cli-tools.nix
    ../../hm-modules/helix.nix
    ../../hm-modules/yazi.nix
    ../../hm-modules/mail-hub.nix
  ];

  nixpkgs.config.allowUnfree = true;
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "23.05";
  };
  programs.home-manager.enable = true;
  programs.ompClient.enable = true;
  programs.piClient.enable = true;
}
