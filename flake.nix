{
  description = "NixOS Configuration of Vincenzo Pace";
  nixConfig = {
    substituters = [
      "https://cache.nixos.org/"
      "https://hyprland.cachix.org"
      "https://helix.cachix.org"
      "https://nix-community.cachix.org"
      "https://nixpkgs-wayland.cachix.org"
    ];
    extra-trusted-public-keys = [
      "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    unstable.url = "github:NixOS/nixpkgs/master";
    home-manager.url = "github:nix-community/home-manager/release-24.11";
    sops-nix.url = "github:Mic92/sops-nix"; # secret management
    disko.url = "github:nix-community/disko"; # declarative partitioning
    hosts.url = "github:StevenBlack/hosts"; # block unwanted websites
    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1"; # Modern tiling window manager
    nil.url = "github:oxalica/nil"; # nix lsp
  };
  outputs =
    {
      nixpkgs,
      home-manager,
      hyprland,
      disko,
      hosts,
      sops-nix,
      nil,
      unstable,
      ...
    }@inputs:
    let
      # Declare some user variables
      username = "vincenzo";
      fullName = "Vincenzo Pace";
      mail = "vincenzo.pace94@icloud.com";

      unstablePkgs = import unstable {
        system = "x86_64-linux";
        config = {
          allowUnfree = true;
          allowUnfreePredicate =
            pkg:
            builtins.elem (unstable.lib.getName pkg) [
              "claude-code"
            ];
        };
      };

      # Desktop specific modules and settings
      commonNixosModules = [
        ./configuration.nix
        ./modules/desktop.nix
        ./hosts/desktop/common.nix
        hosts.nixosModule
        {
          networking.stevenBlackHosts.enable = true;
          networking.stevenBlackHosts = {
            blockFakenews = true;
            blockGambling = true;
            blockPorn = true;
          };
        }
        { programs.hyprland.enable = true; }
        hyprland.nixosModules.default
        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        {
          environment.systemPackages = [
            inputs.nil
            unstablePkgs.claude-code
          ];
        }
        {
          home-manager.extraSpecialArgs = {
            inherit
              username
              mail
              fullName
              unstablePkgs
              ;
          };
          home-manager.useGlobalPkgs = true;
          home-manager.backupFileExtension = "backup";
          home-manager.useUserPackages = true;
          home-manager.users.${username} = import ./home.nix;
        }
      ];

      # Build a system based on the commonNixosModules and stable branch
      makeNixosSystem =
        hostName:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs username unstablePkgs;
            nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
          };
          modules = commonNixosModules ++ [ ./hosts/desktop/${hostName}.nix ];
        };
    in
    {
      nixosConfigurations = {
        asgar = makeNixosSystem "asgar";
        valnar = makeNixosSystem "valnar";
        dracula = makeNixosSystem "dracula";
        #Server
        alucard = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs;
          };
          modules = [ ./hosts/server/alucard.nix ];
        };
      };
    };
}
