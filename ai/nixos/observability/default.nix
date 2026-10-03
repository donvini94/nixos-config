# Monitoring split for fleet operation: every customer host runs exporters (this host's
# metrics, scan results); one central server of ours scrapes them over the tailnet.
{
  imports = [
    ./exporters.nix
    ./server.nix
  ];
}
