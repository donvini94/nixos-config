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

  sops.defaultSopsFile = ./secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";

  sops.secrets.example-key = { };
  sops.secrets."myservice/my_subdir/my_secret" = {
    owner = "sometestservice";
  };

}
