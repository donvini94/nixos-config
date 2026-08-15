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
      "https://hermes-agent.cachix.org"
    ];
    trusted-public-keys = [
      "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "hermes-agent.cachix.org-1:jN3pjR50Mxi4SESKC/FIMNM6/LCosvPk2VUwzVvebzU="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";

    sops-nix.url = "github:Mic92/sops-nix";
    disko.url = "github:nix-community/disko";
    hosts.url = "github:StevenBlack/hosts";

    hermes-agent.url = "github:NousResearch/hermes-agent/v2026.8.3";

    # Pinned to the last .conf-primary release: 0.55 deprecated hyprlang in favour
    # of Lua config, and home-manager still only emits hyprland.conf. Unpin (drop
    # the ref) once HM can generate hyprland.lua, then migrate the config.
    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1&ref=refs/tags/v0.54.3";
    nil.url = "github:oxalica/nil";

    lsfg-vk-flake = {
      url = "github:pabloaul/lsfg-vk-flake/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    emacs-overlay.url = "github:nix-community/emacs-overlay";
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
      lsfg-vk-flake,
      caelestia-shell,
      emacs-overlay,
      ...
    }@inputs:
    let
      username = "vincenzo";
      fullName = "Vincenzo Pace";
      mail = "vincenzo.pace94@icloud.com";
      system = "x86_64-linux";

      # TEMP: nixpkgs ships highlight-4.20 with shellscript-crash-fix.patch, but the
      # upstream tarball already contains those changes — patch is rejected as
      # "Reversed (or previously applied)" and the build fails. Drop the patch list
      # until nixpkgs drops it. Tracked in memory/highlight_overlay_temp.md.
      highlightFixOverlay = _final: prev: {
        highlight = prev.highlight.overrideAttrs (_old: {
          patches = [ ];
        });
      };

      overlays = [
        emacs-overlay.overlay
        highlightFixOverlay
      ];

      mkDesktopHost =
        hostname:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs username; };
          modules = [
            # Local configuration
            ./configuration.nix
            ./hosts/${hostname}

            # Flake modules
            hyprland.nixosModules.default
            sops-nix.nixosModules.sops
            lsfg-vk-flake.nixosModules.default
            hosts.nixosModule
            home-manager.nixosModules.home-manager

            # Desktop wiring
            {
              nixpkgs.overlays = overlays;
              home-manager = {
                extraSpecialArgs = {
                  inherit
                    username
                    mail
                    fullName
                    inputs
                    ;
                };
                backupFileExtension = "hm-backup";
                sharedModules = [ { nixpkgs.overlays = [ highlightFixOverlay ]; } ];
                users.${username} = import ./home.nix;
              };
            }
          ];
        };

      mkServerHost =
        hostname:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs username; };
          modules = [
            ./configuration.nix
            ./hosts/${hostname}
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                extraSpecialArgs = { inherit username; };
                backupFileExtension = "hm-backup";
                users.${username} = import ./hosts/${hostname}/home.nix;
              };
            }
          ];
        };
    in
    {
      nixosConfigurations = {
        dracula = mkDesktopHost "dracula";
        alucard = mkServerHost "alucard";
      };
    };
}
