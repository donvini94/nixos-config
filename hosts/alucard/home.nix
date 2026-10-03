{
  username,
  ...
}:

{
  imports = [
    ../../hm-modules/base.nix
    ./zellij.nix

    ../../hm-modules/starship.nix
    ../../mail/home/mail-hub.nix
  ];

  nixpkgs.config.allowUnfree = true;
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "23.05";
  };
}
