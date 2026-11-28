# Forgejo: the canonical Git host for nixos-config and the Bereit repositories. Tailnet
# only: HTTP and the built-in SSH server bind loopback and Tailscale Serve publishes them.
{
  config,
  pkgs,
  site,
  ...
}:
let
  cfg = config.services.forgejo;
  domain = "${config.networking.hostName}.${site.tailnet}";
  httpsPort = 23300;
  sshPort = 2222;
in
{
  services.forgejo = {
    enable = true;
    settings = {
      server = {
        DOMAIN = domain;
        ROOT_URL = "https://${domain}:${toString httpsPort}/";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 13300;
        START_SSH_SERVER = true;
        SSH_LISTEN_HOST = "127.0.0.1";
        SSH_LISTEN_PORT = 12222;
        SSH_DOMAIN = domain;
        SSH_PORT = sshPort;
      };
      service.DISABLE_REGISTRATION = true;
      session.COOKIE_SECURE = true;
      repository.DEFAULT_BRANCH = "main";
      # Workflows keep their GitHub `uses:` references and pinned commit SHAs.
      actions = {
        ENABLED = true;
        DEFAULT_ACTIONS_URL = "https://github.com";
      };
    };
  };

  services.aiStack.tailnet = {
    https.forgejo = {
      listen = httpsPort;
      target = cfg.settings.server.HTTP_PORT;
    };
    tcp.forgejo-ssh = {
      listen = sshPort;
      target = cfg.settings.server.SSH_LISTEN_PORT;
    };
  };

  # The database as a consistent copy; repositories, attachments, LFS and the generated
  # secrets (custom/conf) that decrypt stored credentials, in place.
  services.aiStack.backup.jobs.forgejo = {
    runtimeInputs = [ pkgs.sqlite ];
    prepare = ''
      sqlite3 ${cfg.database.path} ".backup '$stage/forgejo.db'"
      test -s "$stage/forgejo.db"
    '';
    paths = [
      cfg.repositoryRoot
      "${cfg.stateDir}/data"
      cfg.customDir
    ];
  };
}
