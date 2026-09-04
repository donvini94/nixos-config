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

    # The Mac (AC-0137). `inputs.nixpkgs.follows` is what keeps the darwin closure on
    # the same locked nixpkgs as dracula and alucard, so a package is the same build
    # everywhere.
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
      nix-darwin,
      hyprland,
      disko,
      hosts,
      sops-nix,
      nil,
      lsfg-vk-flake,
      caelestia-shell,
      hermes-agent,
      emacs-overlay,
      ...
    }@inputs:
    let
      username = "vincenzo";
      fullName = "Vincenzo Pace";
      mail = "vincenzo.pace94@icloud.com";
      system = "x86_64-linux";

      # The Mac's local account name differs from the NixOS hosts'. Its platform is set
      # in hosts/ac-0137/default.nix via nixpkgs.hostPlatform, which is where
      # darwinSystem reads it from.
      macUsername = "vincenzopace";

      overlays = [ emacs-overlay.overlay ];

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
            hermes-agent.nixosModules.default

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
            hermes-agent.nixosModules.default
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

      # Exactly one Mac, so this is inline rather than an mkDarwinHost factory.
      #
      # `useUserPackages = true` is load-bearing: it routes home-manager's packages
      # through users.users.<name>.packages -> /etc/profiles/per-user/vincenzopace
      # (nix-darwin/modules/users/default.nix:336-346, which also adds that profile to
      # environment.profiles at mkOrder 900, ahead of /run/current-system/sw). That keeps
      # activation away from ~/.nix-profile, which on this machine is a flake-style
      # `nix profile`.
      #
      # No `overlays` here on purpose: emacs-overlay is for dracula's Emacs. On the Mac,
      # Emacs is the emacs-plus-app cask.
      darwinConfigurations."AC-0137" = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit inputs;
          username = macUsername;
        };
        modules = [
          ./hosts/ac-0137
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useUserPackages = true;
              backupFileExtension = "hm-backup";
              extraSpecialArgs = {
                inherit fullName mail inputs;
                username = macUsername;
              };
              users.${macUsername} = import ./hosts/ac-0137/home.nix;
            };
          }
        ];
      };

      # `nix flake check` is the local and CI gate for repository invariants.
      checks.${system} = {
        no-package-patches =
          nixpkgs.legacyPackages.${system}.runCommand "check-no-package-patches"
            { nativeBuildInputs = [ nixpkgs.legacyPackages.${system}.bash ]; }
            ''
              bash ${./scripts/check-no-package-patches.sh} ${./.} | tee "$out"
            '';

        ai-ingress-tests =
          nixpkgs.legacyPackages.${system}.runCommand "check-ai-ingress-tests"
            { nativeBuildInputs = [ nixpkgs.legacyPackages.${system}.python3 ]; }
            ''
              PYTHONDONTWRITEBYTECODE=1 python3 ${./ai-ingress}/test_proxy.py
              touch "$out"
            '';
      };
    };
}
