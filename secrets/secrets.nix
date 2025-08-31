{
  inputs,
  config,
  ...
}:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = ./dmbs.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/vincenzo/.config/sops/age/keys.txt";
    secrets = {
      "keycloak/password".mode = "640";
      "paperless/password".mode = "640";
      "smb_hetzner/username" = { };
      "smb_hetzner/password" = { };
    };

    templates."smb-hetzner".content = ''
      username=${config.sops.placeholder."smb_hetzner/username"}
      password=${config.sops.placeholder."smb_hetzner/password"}
    '';
    templates."smb-hetzner".mode = "0600";
    templates."smb-hetzner".owner = "root";
    templates."smb-hetzner".group = "root";
  };

}
