{
  config,
  inputs,
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
