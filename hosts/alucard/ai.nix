{
  config,
  inputs,
  pkgs,
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

  # One-time move of n8n's SQLite database into PostgreSQL. Runs before n8n while the
  # SQLite file exists, then archives it; n8n stays down if the import fails. Remove once
  # Alucard has run on PostgreSQL and the archive is no longer needed.
  systemd.services.n8n-sqlite-migration =
    let
      n8n = config.services.localN8n;
      state = n8n.stateDirectory;
    in
    {
      description = "Move n8n from SQLite to PostgreSQL";
      after = [
        "docker.service"
        "n8n-database-password.service"
      ];
      requires = [
        "docker.service"
        "n8n-database-password.service"
      ];
      before = [ "docker-n8n.service" ];
      requiredBy = [ "docker-n8n.service" ];
      unitConfig.ConditionPathExists = "${state}/database.sqlite";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [
        config.virtualisation.docker.package
        config.services.postgresql.package
        pkgs.util-linux
      ];
      script = ''
        n8n() {
          docker run --rm --network=host --user node \
            -v ${state}:/home/node/.n8n \
            -v ${n8n.encryptionKeyFile}:/run/secrets/n8n_encryption_key:ro \
            -v ${n8n.databasePasswordFile}:/run/secrets/n8n_db_password:ro \
            -e N8N_ENCRYPTION_KEY_FILE=/run/secrets/n8n_encryption_key \
            "$@"
        }
        rm -rf ${state}/sqlite-export
        install -d -o 1000 -g 1000 -m 0700 ${state}/sqlite-export
        n8n -e DB_TYPE=sqlite ${n8n.image} \
          export:entities --outputDir=/home/node/.n8n/sqlite-export --includeExecutionHistoryDataTables=true
        n8n -e DB_TYPE=postgresdb -e DB_POSTGRESDB_HOST=127.0.0.1 -e DB_POSTGRESDB_DATABASE=n8n \
          -e DB_POSTGRESDB_USER=n8n -e DB_POSTGRESDB_PASSWORD_FILE=/run/secrets/n8n_db_password \
          ${n8n.image} import:entities --inputDir=/home/node/.n8n/sqlite-export --truncateTables=true
        echo "PostgreSQL now holds: $(runuser -u postgres -- psql -d n8n -tAc "select
          (select count(*) from workflow_entity) || ' workflows, ' ||
          (select count(*) from workflow_entity where active) || ' active, ' ||
          (select count(*) from credentials_entity) || ' credentials, ' ||
          (select count(*) from \"user\") || ' users, ' ||
          (select count(*) from execution_entity) || ' executions, ' ||
          (select count(*) from project) || ' projects'")"
        install -d -o 1000 -g 1000 -m 0700 ${state}/sqlite-archive
        mv ${state}/database.sqlite* ${state}/sqlite-archive/
      '';
    };

  # Keep the identity existing files and the Org ACL already use.
  services.hermesAgent = {
    uid = 985;
    gid = 981;
  };
}
