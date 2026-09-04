{
  pkgs,
  username,
  ...
}:

{
  imports = [
    ../../hm-modules/ai-clients.nix
    # The harness context must be identical on every machine an agent runs on.
    # alucard is a server host and does not import the root home.nix, so omp.nix
    # has to be named here explicitly or this box silently has no AGENTS.md,
    # no RULES.md and none of the language rules.
    ../../hm-modules/omp.nix
    # Same reasoning for the language servers: without this the `lsp` tool is
    # inert on alucard for every language, because the servers otherwise arrive
    # only through the desktop package set in the root home.nix.
    ../../hm-modules/lsp.nix
  ];

  nixpkgs.config.allowUnfree = true;
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "23.05";
  };
  programs.home-manager.enable = true;
}
