{
  config,
  inputs,
  site,
  username,
  ...
}:

let
  secretFile = ../../secrets/alucard-ai.yaml;
in
{
  imports = [
    inputs.ai-stack.nixosModules.default
    inputs.ai-stack.nixosModules.monitoringServer
    ../../coding-agents/nixos/requesty.nix
  ];

  # nixos-rebuild evaluates as root, which fetches the private ai-stack with a read-only
  # deploy key; users keep their own GitHub keys.
  sops.secrets."github/ai_stack_deploy_key".mode = "0400";
  programs.ssh = {
    knownHosts.github = {
      hostNames = [ "github.com" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    };
    extraConfig = ''
      Match localuser root host github.com
        IdentityFile ${config.sops.secrets."github/ai_stack_deploy_key".path}
    '';
  };

  # This host's interactive clients (Pi, OMP) use their own key, not the stack's.
  sops.secrets."requesty/operator_api_key" = {
    sopsFile = secretFile;
    owner = username;
    mode = "0400";
  };
  services.requesty.apiKeyFile = config.sops.secrets."requesty/operator_api_key".path;

  services.aiStack = {
    enable = true;
    secretsFile = secretFile;
    public = {
      domain = "agent.${site.domains.secondary}";
      acmeEmail = site.owner.mail;
    };
    features.onyx = {
      enable = true;
      domain = "chat.${site.domains.primary}";
    };
    hermes = {
      dashboardUser = "demo";
      telegram = true;
    };
    sharedDirectory = {
      path = "/home/${username}/org";
      mountPoint = "/org";
      owner = username;
    };
  };

  # Alucard is the central monitoring server and the canary customer host.
  services.observability = {
    exporters.enable = true;
    server = {
      enable = true;
      secretsFile = secretFile;
      localTargets.n8n = 5678;
    };
  };

  # Keep the identity existing files and the Org ACL already use.
  services.hermesAgent = {
    uid = 985;
    gid = 981;
  };
}
