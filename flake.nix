{
  description = "NixOS Configuration of Vincenzo Pace";

  nixConfig = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = [
      "https://cache.nixos.org/"
      "https://anyrun.cachix.org"
      "https://hyprland.cachix.org"
      "https://helix.cachix.org"
    ];

    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://nixpkgs-wayland.cachix.org"
    ];
    extra-trusted-public-keys = [
      "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
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
    sops-nix.url = "github:Mic92/sops-nix";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    hosts.url = "github:StevenBlack/hosts";
    hosts.inputs.nixpkgs.follows = "nixpkgs";

    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      hyprland,
      disko,
      hosts,
      sops-nix,
      ...
    }@inputs:
    let
      username = "vincenzo";
      fullName = "Vincenzo Pace";
      mail = "vincenzo.pace94@icloud.com";
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
          };
        }
        hyprland.nixosModules.default
        sops-nix.nixosModules.sops
        { programs.hyprland.enable = true; }
        home-manager.nixosModules.home-manager
        {
          home-manager.extraSpecialArgs = {
            inherit username mail fullName;
          };
          home-manager.useGlobalPkgs = true;
          home-manager.backupFileExtension = "backup";
          home-manager.useUserPackages = true;
          home-manager.users.${username} = import ./home.nix;
        }
      ];

      makeNixosSystem =
        hostName:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs username;
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
