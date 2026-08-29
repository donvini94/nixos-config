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
    age.keyFile = "/var/lib/sops/age/keys.txt";
    secrets = {
      "keycloak/password".mode = "640";
      "paperless/password".mode = "640";
      "smb_hetzner/username" = { };
      "smb_hetzner/password" = { };
      "mullvad/private_key" = { };
      "mullvad/addresses" = { };
      "komga/oidc_secret" = { };
      # nginx basic-auth realm for the Docker registry and the Paperless WebDAV
      # drop box. Read by the nginx master, which starts as root and keeps the
      # descriptor across worker forks.
      "nginx/htpasswd" = {
        owner = config.services.nginx.user;
        group = config.services.nginx.group;
        mode = "0400";
      };
    };

    templates."smb-hetzner".content = ''
      username=${config.sops.placeholder."smb_hetzner/username"}
      password=${config.sops.placeholder."smb_hetzner/password"}
    '';
    templates."smb-hetzner".mode = "0600";
    templates."smb-hetzner".owner = "root";
    templates."smb-hetzner".group = "root";

    templates."mullvad.env".content = ''
      MULLVAD_PRIVATE_KEY=${config.sops.placeholder."mullvad/private_key"}
      MULLVAD_ADDRESSES=${config.sops.placeholder."mullvad/addresses"}
      KOMGA_OIDC_SECRET=${config.sops.placeholder."komga/oidc_secret"}
    '';
    templates."mullvad.env".mode = "0640";
    templates."mullvad.env".owner = "root";
    templates."mullvad.env".group = "root";
  };
}
