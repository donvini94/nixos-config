{
  description = "NixOS Configuration of Vincenzo Pace";

  nixConfig = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [
      "https://cache.nixos.org/"
      "https://anyrun.cachix.org"
      "https://hyprland.cachix.org"
    ];

    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://nixpkgs-wayland.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    hosts.url = "github:StevenBlack/hosts";
    hosts.inputs.nixpkgs.follows = "nixpkgs";

    hyprland.url = "github:hyprwm/Hyprland";
    hyprland.inputs.nixpkgs.follows = "nixpkgs";
    hyprland-contrib = {
      url = "github:hyprwm/contrib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";

  };

  outputs = { nixpkgs, home-manager, hyprland, disko, hosts, ... }@inputs:
    let
      commonNixosModules = [
        ./configuration.nix
        hosts.nixosModule
        { networking.stevenBlackHosts.enable = true; }
        home-manager.nixosModules.home-manager
        hyprland.nixosModules.default
        { programs.hyprland.enable = true; }
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.vincenzo = import ./home.nix;
        }
      ];

      makeNixosSystem = hostName:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = commonNixosModules ++ [ ./hosts/desktop/${hostName}.nix ];
        };

      makeHomeManagerConfig = hostname:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs; };
          modules = [ ./home.nix ];
        };
    in {
      nixosConfigurations = {
        asgar = makeNixosSystem "asgar";
        valnar = makeNixosSystem "valnar";
        dracula = makeNixosSystem "dracula";

        #Server
        alucard = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [ ./hosts/server/alucard.nix ];
        };
      };
      homeConfigurations = {
        "vincenzo@asgar" = makeHomeManagerConfig "asgar";
        "vincenzo@valnar" = makeHomeManagerConfig "valnar";
        "vincenzo@dracula" = makeHomeManagerConfig "dracula";
      };
    };
}
