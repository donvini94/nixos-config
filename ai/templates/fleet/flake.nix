{
  description = "Customer servers running the ai-stack";

  inputs = {
    # Customers follow release tags; the canary runs main first.
    ai-stack.url = "github:OWNER/ai-stack/v2026.10.1";
    nixpkgs.follows = "ai-stack/nixpkgs";
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      ai-stack,
      deploy-rs,
      ...
    }:
    let
      customers = import ./customers;
    in
    {
      nixosConfigurations = builtins.mapAttrs (
        name: module:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ai-stack.nixosModules.customerHost
            ./common.nix
            module
            { networking.hostName = name; }
          ];
        }
      ) customers;

      # Deployed from the operator's machine over the tailnet; the server builds its own
      # closure, and magic rollback reverts an activation that cuts the connection.
      deploy.nodes = builtins.mapAttrs (name: _: {
        hostname = name;
        sshUser = "root";
        remoteBuild = true;
        profiles.system = {
          user = "root";
          path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.${name};
        };
      }) customers;

      checks.x86_64-linux = deploy-rs.lib.x86_64-linux.deployChecks self.deploy;
    };
}
