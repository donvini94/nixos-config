{
  description = "Personal devices and Alucard infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
    sops-nix.url = "github:Mic92/sops-nix";
    disko.url = "github:nix-community/disko";
    hosts.url = "github:StevenBlack/hosts";

    # Keep hyprlang until Home Manager supports Hyprland's Lua configuration.
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
    # Private; fetched over SSH (root on Alucard and CI use read-only deploy keys).
    ai-stack = {
      url = "git+ssh://git@github.com/donvini94/ai-stack?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.sops-nix.follows = "sops-nix";
      inputs.disko.follows = "disko";
    };
    ai-library = {
      url = "git+ssh://git@github.com/donvini94/ai-library?ref=main";
      flake = false;
    };
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      systems = [
        system
        "aarch64-darwin"
      ];
      site = import ./site.nix;
      inherit (site.owner)
        username
        macUsername
        fullName
        mail
        ;
      mkLinuxHost =
        hostname: homeModule: extraModules:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs site username; };
          modules = [
            ./configuration.nix
            ./hosts/${hostname}
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager = {
                extraSpecialArgs = {
                  inherit
                    username
                    fullName
                    mail
                    inputs
                    site
                    ;
                };
                backupFileExtension = "hm-backup";
                users.${username} = import homeModule;
              };
            }
          ]
          ++ extraModules;
        };
    in
    {
      nixosConfigurations = {
        dracula = mkLinuxHost "dracula" ./home.nix [
          inputs.hyprland.nixosModules.default
          inputs.sops-nix.nixosModules.sops
          inputs.lsfg-vk-flake.nixosModules.default
          inputs.hosts.nixosModule
          { nixpkgs.overlays = [ inputs.emacs-overlay.overlay ]; }
        ];
        alucard = mkLinuxHost "alucard" ./hosts/alucard/home.nix [ ];
      };

      darwinConfigurations."AC-0137" = inputs.nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit inputs site;
          username = macUsername;
        };
        modules = [
          inputs.determinate.darwinModules.default
          ./hosts/ac-0137
          inputs.home-manager.darwinModules.home-manager
          {
            home-manager = {
              # Use the per-user system profile, not the existing ~/.nix-profile.
              useUserPackages = true;
              backupFileExtension = "hm-backup";
              extraSpecialArgs = {
                inherit
                  fullName
                  mail
                  inputs
                  site
                  ;
                username = macUsername;
              };
              users.${macUsername} = import ./hosts/ac-0137/home.nix;
            };
          }
        ];
      };

      # Expose hash-pinned packages so CI realizes sources, not just build plans.
      packages = nixpkgs.lib.genAttrs systems (
        packageSystem:
        let
          pkgs = nixpkgs.legacyPackages.${packageSystem};
        in
        {
          lathe = pkgs.callPackage ./coding-agents/packages/lathe.nix { };
          linear-cli = pkgs.callPackage ./packages/linear-cli.nix { };
        }
        // nixpkgs.lib.optionalAttrs (packageSystem == "x86_64-linux") {
          omp = pkgs.callPackage ./coding-agents/packages/omp.nix { };
          local-transcription-client = pkgs.callPackage ./transcription/client.nix { };
        }
      );

      checks = nixpkgs.lib.genAttrs systems (
        checkSystem:
        let
          pkgs = nixpkgs.legacyPackages.${checkSystem};
          clientConfig =
            module: option: enabled:
            (inputs.home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              modules = [
                module
                {
                  home.username = "client-check";
                  home.homeDirectory = "/tmp/client-check";
                  home.stateVersion = "25.05";
                  programs.${option}.enable = enabled;
                }
              ];
            }).config;
          piOnly = clientConfig ./coding-agents/home/pi.nix "piClient" true;
          ompOnly = clientConfig ./coding-agents/home/omp.nix "ompClient" true;
          piDisabled = clientConfig ./coding-agents/home/pi.nix "piClient" false;
          ompDisabled = clientConfig ./coding-agents/home/omp.nix "ompClient" false;
          owns =
            prefix: cfg: builtins.any (n: nixpkgs.lib.hasPrefix prefix n) (builtins.attrNames cfg.home.file);
        in
        {
          shell-scripts =
            pkgs.runCommand "check-shell-scripts" { nativeBuildInputs = [ pkgs.shellcheck ]; }
              ''
                shellcheck ${./coding-agents/scripts}/*.sh ${./mail/bin}/* ${./mail/nixos}/*.sh ${./hosts/alucard/services}/*.sh
                touch "$out"
              '';
          python-lint = pkgs.runCommand "check-python-lint" { nativeBuildInputs = [ pkgs.ruff ]; } ''
            ruff check --no-cache --select F ${./transcription}/server.py ${./coding-agents/scripts/tests}
            touch "$out"
          '';
          model-download =
            pkgs.runCommand "check-model-download"
              {
                nativeBuildInputs = with pkgs; [
                  bash
                  coreutils
                  curl
                ];
              }
              ''
                script=${./scripts/download-model-file.sh}
                printf 'test model\n' > source
                hash=$(sha256sum source | cut -d ' ' -f 1)
                bash "$script" "$PWD/model/file" "$hash" "file://$PWD/source"
                cmp source model/file
                if bash "$script" "$PWD/bad" "$(printf '%064d' 0)" "file://$PWD/source"; then
                  echo "A mismatched checksum was accepted" >&2
                  exit 1
                fi
                test ! -e bad
                rm source
                bash "$script" "$PWD/model/file" "$hash" "file://$PWD/source"
                touch "$out"
              '';
          client-independence =
            assert owns ".pi/" piOnly && !(owns ".omp/" piOnly);
            assert owns ".omp/" ompOnly && !(owns ".pi/" ompOnly);
            assert !(owns ".pi/" piDisabled) && !(owns ".omp/" ompDisabled);
            assert
              !(piOnly.home.activation ? ompLearningPlugin) && !(ompOnly.home.activation ? piAgentBootstrap);
            assert
              !(piDisabled.home.activation ? piAgentBootstrap)
              && !(ompDisabled.home.activation ? ompLearningPlugin);
            assert !piDisabled.home.agentContent.enable && !ompDisabled.home.agentContent.enable;
            pkgs.writeText "check-client-independence" "Client modules own separate resources and can be disabled independently.\n";
          agent-tools-tests =
            pkgs.runCommand "check-agent-tools-tests"
              {
                nativeBuildInputs = with pkgs; [
                  bash
                  coreutils
                  diffutils
                  git
                  jq
                  python3
                  rsync
                  unzip
                ];
              }
              ''
                PYTHONDONTWRITEBYTECODE=1 python3 ${./coding-agents/scripts/tests}/test_update_skills.py ${./coding-agents/scripts/update-skills.sh}
                PYTHONDONTWRITEBYTECODE=1 python3 ${./coding-agents/scripts/tests}/test_bootstrap_pi.py ${./coding-agents/scripts/bootstrap-pi.sh}
                touch "$out"
              '';
        }
      );
    };
}
