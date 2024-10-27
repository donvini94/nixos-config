{
  inputs,
  ...
}:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = ./dmbs.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/nix/.config/sops/age/keys.txt";
    secrets = {
      "keycloak/password".mode = "640";
      "paperless/password".mode = "640";
    };
  };
}
