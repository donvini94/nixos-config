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

    # `inputs.nixpkgs.follows` keeps the darwin closure on the same locked nixpkgs as
    # dracula and alucard, so a package is the same build everywhere.
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix.url = "github:Mic92/sops-nix";
    disko.url = "github:nix-community/disko";
    hosts.url = "github:StevenBlack/hosts";

    hermes-agent.url = "github:NousResearch/hermes-agent/v2026.8.3";

    # Pinned to 0.54.3, the last .conf-primary release: 0.55 deprecated hyprlang in
    # favour of Lua config and home-manager still only emits hyprland.conf. Unpin once
    # HM can generate hyprland.lua.
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

      # darwinSystem reads this host's platform from nixpkgs.hostPlatform in
      # hosts/ac-0137/default.nix.
      macUsername = "vincenzopace";

      overlays = [ emacs-overlay.overlay ];

      mkDesktopHost =
        hostname:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs username; };
          modules = [
            ./configuration.nix
            ./hosts/${hostname}

            hyprland.nixosModules.default
            sops-nix.nixosModules.sops
            lsfg-vk-flake.nixosModules.default
            hosts.nixosModule
            home-manager.nixosModules.home-manager
            hermes-agent.nixosModules.default

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
                # fullName/mail are here for hm-modules/git.nix, which the server
                # home now imports; without them evaluation fails on a missing
                # argument rather than silently producing an unconfigured git.
                extraSpecialArgs = {
                  inherit
                    username
                    fullName
                    mail
                    ;
                };
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

      # `useUserPackages = true` is load-bearing: it routes home-manager's packages
      # through users.users.<name>.packages -> /etc/profiles/per-user/vincenzopace
      # (nix-darwin/modules/users/default.nix:336-346, which also adds that profile to
      # environment.profiles at mkOrder 900, ahead of /run/current-system/sw). That keeps
      # activation away from ~/.nix-profile, which on this machine is a flake-style
      # `nix profile`.
      #
      # No overlays: emacs-overlay is dracula's; the Mac's Emacs is the emacs-plus-app cask.
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

      # These pin a content hash, which is why they are outputs. CI plans the host
      # closures with `nix build --dry-run`, which never realizes a fixed-output
      # derivation, so a stale `hash`/`vendorHash` passes every check and fails on the
      # machine at switch time instead; .github/workflows/nix-build.yml realizes exactly
      # this set. `nix-update` also addresses a flake attribute, which is how
      # .github/workflows/package-update.yml bumps version AND hashes together —
      # Renovate can only rewrite the version string.
      #
      # Packages that pin nothing (pokemmo, hermes-n8n-handoff) are absent: host
      # evaluation is full coverage for them. omp-harness takes per-account arguments.
      packages = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-darwin" ] (
        packageSystem:
        let
          pkgs = nixpkgs.legacyPackages.${packageSystem};
        in
        {
          lathe = pkgs.callPackage ./packages/lathe.nix { };
        }
        // nixpkgs.lib.optionalAttrs (packageSystem == "x86_64-linux") {
          omp = pkgs.callPackage ./packages/omp.nix { };
        }
      );

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
