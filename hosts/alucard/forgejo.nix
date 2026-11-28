# Forgejo: the canonical Git host for nixos-config and the Bereit repositories. Tailnet
# only: HTTP and the built-in SSH server bind loopback and Tailscale Serve publishes them.
{
  config,
  lib,
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

  # First start only: the operator's admin account. The CLI takes no password file, so the
  # password is in argv for that one call.
  sops.secrets."forgejo/admin_password".owner = cfg.user;
  systemd.services.forgejo.preStart = lib.mkAfter ''
    if ! ${lib.getExe cfg.package} admin user list --admin | grep -qw ${site.owner.username}; then
      ${lib.getExe cfg.package} admin user create --admin --must-change-password=false \
        --username ${site.owner.username} --email ${site.owner.mail} \
        --password "$(cat ${config.sops.secrets."forgejo/admin_password".path})"
    fi
  '';

  # nixos-rebuild evaluates as root, which fetches the private flake inputs over Forgejo's
  # SSH with a read-only deploy key; users keep their own keys.
  sops.secrets."forgejo/deploy_key".mode = "0400";
  programs.ssh = {
    knownHosts.forgejo = {
      hostNames = [ "[${domain}]:${toString sshPort}" ];
      publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDENOH/PrkZHsVqcCmKkx0OztDuvxmQ0SIpvgWymjde6NMdWMk7pYODhdCXyDaacCI0823/AZZfjbIXCMLt+gFYmPylm9y+6ixjKcr3rL16Jv1qPIi/FGv3FzSsoJ76jzlm81AzRhmJG28IsQvcahqmIKl/Kk7aM9g3vfjA0XIj/BI7cezzTrtWVBfyceRzEQoQOOJYjkA6PKvjVieC/g+gulRvUMmuHqOfOnnXKZsIRDaGLHrcY6rfk8sHXWY8Y/GuKdF4VpNZkDGdMlLAPbG4czYkcmWNoobcrrvHUZs0/vbdUw+C4c/6efCTRQmwy6WB+3d27LCQSGiqRPKud2R/NS29S7ePai8sKPI743bg/DqjdaHsVmHpATS5OT6/Qqj/sB1cprL+s1WHpFKMPgdZDnEYimngtfDmL9tYrLuvlHRaF7B0JTIten/bpu7tCwNJIZI+Z6qQRdzOzjpgmuZXqueX3PnPdbkeEZx0hgn/+Oudj1lzbNQENf+rXwWVtn9jZ5AQyQDIZh46dux0lkWc4jCwPD+wXBPiRxtbbQiB0IQunAXK4haYj97xeKlXKADjLudUYRSHKLon6l7ARwjp83CfbnraY1uJxzTEsjUg36fdfErqblvCNRTzk/HFR3OQ3tlJe1trmLSaY+44Ueo78dYGZTMPL2T3DGOZSkVhaQ==";
    };
    extraConfig = ''
      Match localuser root host ${domain}
        IdentityFile ${config.sops.secrets."forgejo/deploy_key".path}
        IdentitiesOnly yes
    '';
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
