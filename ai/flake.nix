{
  description = "AI stack for single-tenant customer servers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Consumers import sops-nix themselves; checks need it to evaluate the modules.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, sops-nix, ... }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
    in
    {
      nixosModules = {
        default = ./nixos;
        monitoringServer = {
          imports = [
            ./nixos/observability/exporters.nix
            ./nixos/observability/server.nix
            ./nixos/tailnet.nix
          ];
        };
      };

      packages = lib.genAttrs systems (
        system:
        {
          coreruleset = nixpkgs.legacyPackages.${system}.callPackage ./packages/coreruleset.nix { };
          n8n-chat = nixpkgs.legacyPackages.${system}.callPackage ./packages/n8n-chat.nix { };
          onyx-deployment = nixpkgs.legacyPackages.${system}.callPackage ./packages/onyx-deployment.nix { };
        }
        // lib.optionalAttrs (system == "x86_64-linux") {
          tika = nixpkgs.legacyPackages.${system}.callPackage ./packages/tika.nix { };
        }
      );

      checks = lib.genAttrs systems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          shell-scripts =
            pkgs.runCommand "check-shell-scripts" { nativeBuildInputs = [ pkgs.shellcheck ]; }
              ''
                shellcheck ${./nixos/vulnerability-scan}/*.sh
                touch "$out"
              '';
        }
        // lib.optionalAttrs (system == "x86_64-linux") {
          egress = pkgs.testers.runNixOSTest ./tests/egress.nix;
          public = pkgs.testers.runNixOSTest ./tests/public.nix;
          # Every module enabled on a bare host must evaluate, assertions included.
          evaluation =
            let
              host = lib.nixosSystem {
                inherit system;
                modules = [
                  sops-nix.nixosModules.sops
                  ./nixos
                  ./nixos/observability/server.nix
                  {
                    system.stateVersion = "26.05";
                    boot.loader.grub.enable = false;
                    fileSystems."/" = {
                      device = "/dev/vda";
                      fsType = "ext4";
                    };
                    sops = {
                      validateSopsFiles = false;
                      age.keyFile = "/var/lib/sops/age/keys.txt";
                    };
                    virtualisation.docker.enable = true;
                    services = {
                      aiStack = {
                        enable = true;
                        secretsFile = "/dev/null";
                        hermes.telegram = true;
                        tailnet.domain = "example.ts.net";
                        tier = "plus";
                        features.paperless.domain = "docs.example.test";
                        features.onyx = {
                          enable = true;
                          domain = "search.example.test";
                        };
                        public = {
                          domain = "agent.example.test";
                          acmeEmail = "ops@example.test";
                        };
                        backup.repository = "sftp:u1-sub1@u1.your-storagebox.de:restic";
                      };
                      observability = {
                        exporters.enable = true;
                        server = {
                          enable = true;
                          secretsFile = "/dev/null";
                        };
                      };
                      containerVulnerabilityScan.enable = true;
                      hostVulnerabilityScan.enable = true;
                    };
                  }
                ];
              };
            in
            pkgs.writeText "ai-stack-evaluation" (
              builtins.unsafeDiscardStringContext host.config.system.build.toplevel.drvPath
            );
        }
      );
    };
}
