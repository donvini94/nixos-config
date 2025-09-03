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
      "vaultwarden/admin_token" = {};
    };

    templates."smb-hetzner".content = ''
      username=${config.sops.placeholder."smb_hetzner/username"}
      password=${config.sops.placeholder."smb_hetzner/password"}
    '';
    templates."smb-hetzner".mode = "0600";
    templates."smb-hetzner".owner = "root";
    templates."smb-hetzner".group = "root";

    templates."vaultwarden.env".content = ''
      ADMIN_TOKEN=${config.sops.placeholder."vaultwarden/admin_token"}
    '';
    # Permissions: systemd reads it as root; keep it tight
    templates."vaultwarden.env".mode  = "0640";
    templates."vaultwarden.env".owner = "root";
    templates."vaultwarden.env".group = "root";
  };
}
