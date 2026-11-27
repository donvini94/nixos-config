{
  imports = [
    ./reverse-proxy.nix
    ./dashboard.nix
    ./identity.nix
    ./media-services.nix
    ./hosted-applications.nix
    ../backups.nix
  ];
}
