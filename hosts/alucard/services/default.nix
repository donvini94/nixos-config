{
  imports = [
    ./reverse-proxy.nix
    ./identity.nix
    ./media-services.nix
    ./hosted-applications.nix
  ];

  services.offsiteBackup.enable = true;
}
