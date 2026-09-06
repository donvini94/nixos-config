# n8n keeps credentials encrypted in its own SQLite database, so they can only be
# installed through n8n's CLI under the instance encryption key — never as a Nix
# file or env var. Re-importing under the same fixed ID is also the rotation path.
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

  # The container runs as uid/gid 1000 (`node`); the rendered JSON is chowned to it
  # so the import can read the bind-mounted file while the runtime dir stays root-only.
  containerUid = 1000;

  syncScript = pkgs.writeShellScript "n8n-credentials-sync" ''
    set -euo pipefail

    creds="$RUNTIME_DIRECTORY/credentials.json"
    umask 077

    ${pkgs.jq}/bin/jq -n \
      --rawfile hermes_key "$CREDENTIALS_DIRECTORY/hermes_api_key" \
      --rawfile webhook_token "$CREDENTIALS_DIRECTORY/n8n_webhook_token" \
      '[
        {
          id: "startupHermesApi",
          name: "Startup Hermes API",
          type: "httpHeaderAuth",
          data: { name: "Authorization", value: ("Bearer " + ($hermes_key | rtrimstr("\n"))) }
        },
        {
          id: "startupWebhookAuth",
          name: "Startup webhook token",
          type: "httpHeaderAuth",
          data: { name: "X-Startup-Token", value: ($webhook_token | rtrimstr("\n")) }
        }
      ]' > "$creds"
    ${pkgs.coreutils}/bin/chown ${toString containerUid} "$creds"
    ${pkgs.coreutils}/bin/chmod 0400 "$creds"

    # The image's entrypoint already is `n8n`, so only the subcommand is passed.
    # `import:credentials` upserts by id: idempotent.
    ${pkgs.docker}/bin/docker run --rm \
      --name n8n-credentials-sync \
      --network none \
      --user ${toString containerUid}:${toString containerUid} \
      --volume ${stateDirectory}:/home/node/.n8n \
      --volume ${n8nCfg.encryptionKeyFile}:/run/secrets/n8n_encryption_key:ro \
      --volume "$creds":/tmp/credentials.json:ro \
      ${n8nCfg.image} \
      import:credentials --input=/tmp/credentials.json
  '';
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
        ExecStart = syncScript;
      };
    };

    # Pull the sync into n8n's graph: n8n stops for a rotation and starts after the import.
    systemd.services.docker-n8n = {
      after = [ "n8n-credentials-sync.service" ];
      requires = [ "n8n-credentials-sync.service" ];
    };
  };
}
