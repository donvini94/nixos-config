# The customer-side stack. Every component is inert until enabled.
{
  imports = [
    ./ai-stack.nix
    ./backup.nix
    ./edge.nix
    ./egress.nix
    ./paperless.nix
    ./public.nix
    ./tailnet.nix
    ./observability/exporters.nix
    ./vulnerability-scan/container.nix
    ./vulnerability-scan/host.nix
  ];
}
