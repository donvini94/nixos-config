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
    # Core inputs
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    unstable.url = "github:NixOS/nixpkgs/master";
    home-manager.url = "github:nix-community/home-manager/release-24.11";

    # System management
    sops-nix.url = "github:Mic92/sops-nix"; # Secret management
    disko.url = "github:nix-community/disko"; # Declarative partitioning
    hosts.url = "github:StevenBlack/hosts"; # Block unwanted websites

    # Desktop environment
    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1"; # Modern tiling window manager

    # Development tools
    nil.url = "github:oxalica/nil"; # Nix LSP
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
      ...
    }@inputs:
    let
      # User configuration
      username = "vincenzo";
      fullName = "Vincenzo Pace";
      mail = "vincenzo.pace94@icloud.com";

      # System configuration
      system = "x86_64-linux";

      # Unstable packages with allowUnfree configuration
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

      # Common modules for desktop systems
      commonDesktopModules = [
        ./configuration.nix
        ./modules/desktop.nix
        ./hosts/desktop/common.nix
        hosts.nixosModule
        {
          networking.stevenBlackHosts = {
            enable = true;
            blockFakenews = true;
            blockGambling = true;
            blockPorn = true;
            blockSocial = true;
          };
        }
        { programs.hyprland.enable = true; }
        hyprland.nixosModules.default
        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        {
          environment.systemPackages = [
            nil.packages.${system}.default
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
              inputs
              ;
          };
          home-manager.backupFileExtension = "hm-backup";
          home-manager.users.${username} = import ./home.nix;
        }
      ];

      # Function to create a desktop NixOS configuration
      mkDesktopSystem =
        hostName:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs username unstablePkgs;
            nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
          };
          modules = commonDesktopModules ++ [ ./hosts/desktop/${hostName}.nix ];
        };

      # Function to create a server NixOS configuration
      mkServerSystem =
        hostName:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
          };
          modules = [ ./hosts/server/${hostName}.nix ];
        };
    in
    {
      nixosConfigurations = {
        # Desktop configurations
        asgar = mkDesktopSystem "asgar";
        valnar = mkDesktopSystem "valnar";
        dracula = mkDesktopSystem "dracula";

        # Server configurations
        alucard = mkServerSystem "alucard";
      };
    };
}
