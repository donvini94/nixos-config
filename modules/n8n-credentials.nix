# Declarative provisioning of n8n's shared Header Auth credentials.
#
# n8n stores credentials encrypted in its own SQLite database, so they cannot
# be a Nix file or an env var — they must be imported through n8n's own CLI,
# which encrypts them with the instance encryption key. This unit is the only
# supported way to keep those two credentials in SOPS instead of in someone's
# browser session, and it is also the rotation path: change the secret, switch,
# and the credential is re-imported under the same fixed ID.
#
# Secrets never touch Nix, argv, workflow JSON, logs, or the repository. They
# arrive via systemd LoadCredential, are rendered into a root-only runtime
# directory, bind-mounted read-only into a throwaway container, and deleted
# when the unit exits.
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

  # The container runs as uid/gid 1000 (`node`). The rendered JSON is chowned to
  # that id so the import can read it while the runtime directory itself stays
  # root-only; bind-mounting the file needs no traversal by the container.
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

    # A throwaway container: same image, same state volume, same encryption key,
    # no network. The image's entrypoint already is `n8n`, so only the
    # subcommand is passed. `import:credentials` upserts by id: idempotent.
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
      # n8n must be down: importing into a live SQLite database races the
      # running instance's own writes.
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

    # Pull the sync into n8n's dependency graph so a restart of n8n orders
    # itself after a fresh import, and a rotation transaction stops n8n first.
    systemd.services.docker-n8n = {
      after = [ "n8n-credentials-sync.service" ];
      requires = [ "n8n-credentials-sync.service" ];
    };
  };
}
