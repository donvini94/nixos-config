{
  pkgs,
  username,
  ...
}:

{
  imports = [ ../../hm-modules/ai-clients.nix ];

  nixpkgs.config.allowUnfree = true;
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "23.05";
  };
  programs.home-manager.enable = true;
}
