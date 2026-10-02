# Import runtime credentials through n8n's CLI; plaintext must not enter the Nix store.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.n8nCredentials;
  n8nCfg = config.services.localN8n;
  stateDirectory = "/var/lib/n8n-container";

  syncScript = pkgs.writeShellApplication {
    name = "n8n-credentials-sync";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
      pkgs.docker
    ];
    runtimeEnv = {
      N8N_STATE_DIRECTORY = stateDirectory;
      N8N_ENCRYPTION_KEY_FILE = n8nCfg.encryptionKeyFile;
      N8N_IMAGE = n8nCfg.image;
    };
    text = builtins.readFile ../scripts/n8n-credentials-sync.sh;
  };
in
{
  options.services.n8nCredentials = {
    enable = lib.mkEnableOption "SOPS-managed n8n Header Auth credentials";

    hermesApiKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "File containing the Hermes API bearer key.";
    };

    webhookTokenFile = lib.mkOption {
      type = lib.types.path;
      description = "File containing the shared X-Startup-Token webhook secret.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = n8nCfg.enable && n8nCfg.encryptionKeyFile != null;
        message = "services.n8nCredentials requires services.localN8n with an encryption key";
      }
    ];

    systemd.services.n8n-credentials-sync = {
      description = "Import SOPS-managed n8n credentials";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      # n8n must be down: importing into a live SQLite database races its own writes.
      before = [ "docker-n8n.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "n8n-credentials-sync";
        RuntimeDirectoryMode = "0700";
        LoadCredential = [
          "hermes_api_key:${cfg.hermesApiKeyFile}"
          "n8n_webhook_token:${cfg.webhookTokenFile}"
        ];
        ExecStart = lib.getExe syncScript;
      };
    };

    # Pull the sync into n8n's graph: n8n stops for a rotation and starts after the import.
    systemd.services.docker-n8n = {
      after = [ "n8n-credentials-sync.service" ];
      requires = [ "n8n-credentials-sync.service" ];
    };
  };
}
