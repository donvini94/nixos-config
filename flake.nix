{
  description = "NixOS Configuration of Vincenzo Pace";

  nixConfig = {
    substituters = [
      "https://cache.nixos.org/"
      "https://hyprland.cachix.org"
      "https://helix.cachix.org"
      "https://nix-community.cachix.org"
      "https://nixpkgs-wayland.cachix.org"
      "https://cache.nixos-cuda.org"
    ];
    trusted-public-keys = [
      "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    unstable.url = "github:NixOS/nixpkgs/master";
    home-manager.url = "github:nix-community/home-manager/master";

    sops-nix.url = "github:Mic92/sops-nix";
    disko.url = "github:nix-community/disko";
    hosts.url = "github:StevenBlack/hosts";

    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    nil.url = "github:oxalica/nil";

    lsfg-vk-flake = {
      url = "github:pabloaul/lsfg-vk-flake/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      hyprland,
      disko,
      hosts,
      sops-nix,
      nil,
      unstable,
      lsfg-vk-flake,
      caelestia-shell,
      ...
    }@inputs:
    let
      username = "vincenzo";
      fullName = "Vincenzo Pace";
      mail = "vincenzo.pace94@icloud.com";
      system = "x86_64-linux";

      unstablePkgs = import unstable {
        inherit system;
        config = {
          allowUnfree = true;
          cudaSupport = true;
          allowUnfreePredicate =
            pkg:
            builtins.elem (unstable.lib.getName pkg) [
              "claude-code"
            ];
        };
      };
    in
    {
      nixosConfigurations = {
        dracula = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs username unstablePkgs;
          };
          modules = [
            ./configuration.nix
            ./modules/desktop.nix
            ./hosts/dracula

            hyprland.nixosModules.default
            sops-nix.nixosModules.sops
            lsfg-vk-flake.nixosModules.default
            hosts.nixosModule
            home-manager.nixosModules.home-manager

            {
              programs.hyprland.enable = true;

              networking.stevenBlackHosts = {
                enable = true;
                blockFakenews = true;
                blockGambling = true;
                blockSocial = true;
              };

              environment.systemPackages = [
                nil.packages.${system}.default
                unstablePkgs.claude-code
              ];

              home-manager = {
                extraSpecialArgs = {
                  inherit username mail fullName unstablePkgs inputs;
                };
                backupFileExtension = "hm-backup";
                users.${username} = import ./home.nix;
              };
            }
          ];
        };

        alucard = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
          };
          modules = [ ./hosts/alucard ];
        };
      };
    };
}
