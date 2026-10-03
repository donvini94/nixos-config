# The customer-side stack. Every component is inert until enabled.
{
  imports = [
    ./ai-stack.nix
    ./egress.nix
    ./observability/exporters.nix
    ./vulnerability-scan/container.nix
    ./vulnerability-scan/host.nix
  ];
}
