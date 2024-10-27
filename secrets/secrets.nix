{
  pkgs,
  inputs,
  config,
  ...
}:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/nix/.config/sops/age/keys.txt";
    secrets = {
      "keycloak/password".mode = "640";
      "paperless/password".mode = "640";
    };
  };
}
