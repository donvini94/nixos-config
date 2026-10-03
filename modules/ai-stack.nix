# Alucard's agent and workflow services, backed by the AI ingress.
{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  cfg = config.services.aiStack;
  hermes = import ../lib/hermes-agent.nix;
  hermesHome = "${config.services.hermes-agent.stateDir}/.hermes";
  policyDirectory = "${config.services.hermes-agent.stateDir}/policy";
  ingressUrl = "http://127.0.0.1:8080/v1";
  defaults = pkgs.writeText "hermes-defaults.json" (
    builtins.toJSON (
      hermes.mkDefaults {
        inherit (cfg.hermes) providerName defaultModel;
      }
    )
  );
  policy = pkgs.writeText "hermes-policy.json" (
    builtins.toJSON (
      hermes.mkPolicy {
        inherit (cfg.hermes) providerName;
        inherit ingressUrl;
      }
    )
  );
  python = pkgs.python3.withPackages (ps: [
    ps.pyyaml
    ps.python-dotenv
  ]);
  stateTool = "${python}/bin/python3 ${../scripts/hermes-state.py}";
in
{
  imports = [
    ./ai-ingress.nix
    ./n8n.nix
    ./hermes-dashboard.nix
    ./container-updates.nix
  ];

  options.services.aiStack = {
    enable = lib.mkEnableOption "AI ingress, n8n and Hermes";

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether the AI stack starts automatically at boot.";
    };

    secretsFile = lib.mkOption {
      type = lib.types.path;
      description = "SOPS file holding n8n and Hermes secrets.";
    };

    hermes = {
      egressHosts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "api.telegram.org"
          "setup.hermes-agent.nousresearch.com"
          "registry.npmjs.org"
          "pypi.org"
          "files.pythonhosted.org"
          "github.com"
          "api.github.com"
          "raw.githubusercontent.com"
          "codeload.github.com"
          "objects.githubusercontent.com"
          "release-assets.githubusercontent.com"
        ];
        description = "Exact HTTPS hosts approved for messaging and operator-installed MCP dependencies.";
      };
      providerName = lib.mkOption {
        type = lib.types.str;
        description = "Name Hermes gives the ingress-backed provider.";
      };

      defaultModel = lib.mkOption {
        type = lib.types.str;
        description = "Model Hermes requests from the ingress.";
      };

    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = {
      "n8n/encryption_key" = {
        sopsFile = cfg.secretsFile;
        owner = username;
        mode = "0400";
      };
      "hermes/api_server_key" = {
        sopsFile = cfg.secretsFile;
        owner = "root";
        mode = "0400";
      };
    };

    # OMP, Hermes and n8n all trace through this one proxy.
    services.aiIngress.autoStart = cfg.autoStart;

    services.aiIngress.langfuse = {
      enable = true;
      publicKeyFile = config.sops.secrets."langfuse/project_public_key".path;
      secretKeyFile = config.sops.secrets."langfuse/project_secret_key".path;
    };

    # Hermes runs as its own service identity inside a container and reaches
    # the Org tree only through this inherited ACL.
    systemd.tmpfiles.rules = [
      "A+ /home/${username}/org - - - - u:hermes:rwX,d:u:hermes:rwx"
    ];

    services.localN8n = {
      enable = true;
      encryptionKeyFile = config.sops.secrets."n8n/encryption_key".path;
      orgOwner = username;
      orgDirectory = "/home/${username}/org";
    };

    services.hermes-agent = {
      enable = true;
      addToSystemPackages = true;
      workingDirectory = "/var/lib/hermes/workspace";
      # Preferences are seeded after upstream activation; policy lives in a separate managed scope.
      settings = { };
      documents = {
        "AGENTS.md" = ../hermes/workspace/AGENTS.md;
      };
      hermesHomeFiles = {
        "SOUL.md" = ../hermes/workspace/SOUL.md;
      };
      environment = hermes.runtimeEnv;
      # Each host defines this template itself; the contents genuinely differ.
      environmentFiles = [ config.sops.templates."hermes.env".path ];
      container = {
        enable = true;
        backend = "docker";
        image = hermes.image;
        hostUsers = [ username ];
        extraVolumes = [ "/home/${username}/org:/org:rw" ];
        extraOptions = hermes.containerOptions;
      };
    };

    system.activationScripts.hermes-state-capture = {
      deps = [ "users" ];
      text = ''
        ${stateTool} capture ${hermesHome} /run/hermes-state-activation
      '';
    };
    system.activationScripts.hermes-agent-setup.deps = [ "hermes-state-capture" ];
    system.activationScripts.hermes-state-restore = {
      deps = [ "hermes-agent-setup" ];
      text = ''
        install -d -o root -g ${config.services.hermes-agent.group} -m 0750 ${policyDirectory}
        ln -sfn ${policy} ${policyDirectory}/config.yaml
        ${stateTool} restore ${hermesHome} /run/hermes-state-activation \
          --defaults ${defaults} --policy ${policyDirectory}
      '';
    };

    services.hermesDashboard.enable = true;
    systemd.services.hermes-dashboard.restartTriggers = [ policy ];
    systemd.services.hermes-agent.restartTriggers = [
      policy
      defaults
      (pkgs.writeText "hermes-runtime-env.json" (
        builtins.toJSON config.services.hermes-agent.environment
      ))
    ];

    # Upstream wants multi-user.target; this stack is gated behind
    # ai-stack.target and must not start before the ingress it talks to.
    systemd.services.hermes-agent = {
      wantedBy = lib.mkForce [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      after = [ "local-llama-logger.service" ];
      requires = [ "local-llama-logger.service" ];
    };

    services.containerUpdates.units = [
      "docker-n8n.service"
    ];
  };
}
