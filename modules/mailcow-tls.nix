{
  config,
  lib,
  pkgs,
  ...
}:

# Give mailcow's Dovecot/Postfix the host's Let's Encrypt certificate.
#
# WHY THIS EXISTS: mailcow ships its own ACME client, but it can only complete
# an HTTP-01 challenge if it owns port 80. On this host nginx owns 80/443 and
# reverse-proxies mailcow, so mailcow's ACME never succeeds and Dovecot keeps
# serving the self-signed certificate it generated at install time. IMAP
# clients that verify certificates — including Paperless' mail fetcher — then
# fail with CERTIFICATE_VERIFY_FAILED, while the same hostname over HTTPS
# serves a perfectly valid certificate from nginx.
#
# The fix is to stop mailcow issuing certificates and hand it the one nginx
# already has.
#
# BOUNDARY NOTE: mailcow lives in /opt/mailcow-dockerized and is deliberately
# NOT Nix-managed (see docs/ALUCARD_SECURITY.md). This module reaches across
# that boundary to write two files and restart three containers. It is the
# narrowest crossing that solves the problem; everything else about mailcow
# stays outside Nix.

let
  cfg = config.services.mailcowTls;
  sslDir = "${cfg.mailcowDir}/data/assets/ssl";
  acmeDir = "/var/lib/acme/${cfg.domain}";

  deploy = pkgs.writeShellApplication {
    name = "mailcow-tls-deploy";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.docker
      pkgs.gnugrep
    ];
    text = ''
      acme=${lib.escapeShellArg acmeDir}
      ssl=${lib.escapeShellArg sslDir}
      conf=${lib.escapeShellArg "${cfg.mailcowDir}/mailcow.conf"}

      if [ ! -d "$ssl" ]; then
        echo "mailcow ssl directory $ssl not found — is mailcow installed?" >&2
        exit 1
      fi
      if [ ! -r "$acme/fullchain.pem" ]; then
        echo "no ACME certificate at $acme — has nginx obtained one yet?" >&2
        exit 1
      fi

      # mailcow's own ACME client would overwrite these files on its next run.
      # It cannot succeed here anyway (nginx owns :80), so it must be off.
      if ! grep -qE '^SKIP_LETS_ENCRYPT=y' "$conf" 2>/dev/null; then
        echo "WARNING: SKIP_LETS_ENCRYPT is not set to 'y' in $conf." >&2
        echo "         mailcow may overwrite the certificate deployed here." >&2
      fi

      # Idempotent: only touch mailcow when the certificate actually changed,
      # so a rebuild does not bounce the mail server for nothing.
      if cmp -s "$acme/fullchain.pem" "$ssl/cert.pem"; then
        echo "mailcow already has the current certificate"
        exit 0
      fi

      echo "deploying ${cfg.domain} certificate into mailcow"
      install -m 0644 -o root -g root "$acme/fullchain.pem" "$ssl/cert.pem"
      install -m 0600 -o root -g root "$acme/key.pem" "$ssl/key.pem"

      cd ${lib.escapeShellArg cfg.mailcowDir}
      # Compose *service* names, which are stable across mailcow releases —
      # unlike container names, which carry the project prefix.
      docker compose restart ${lib.concatStringsSep " " cfg.reloadServices}
      echo "mailcow certificate updated"
    '';
  };
in
{
  options.services.mailcowTls = {
    enable = lib.mkEnableOption "handing the host's ACME certificate to mailcow";

    domain = lib.mkOption {
      type = lib.types.str;
      example = "mail.example.com";
      description = "ACME certificate to deploy. Must match mailcow's hostname.";
    };

    mailcowDir = lib.mkOption {
      type = lib.types.path;
      default = "/opt/mailcow-dockerized";
    };

    reloadServices = lib.mkOption {
      type = with lib.types; listOf str;
      default = [
        "dovecot-mailcow"
        "postfix-mailcow"
        "nginx-mailcow"
      ];
      description = "Compose services to restart after the certificate changes.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.mailcow-tls = {
      description = "Deploy the host ACME certificate into mailcow";
      wantedBy = [ "multi-user.target" ];
      after = [
        "docker.service"
        "acme-${cfg.domain}.service"
      ];
      requires = [ "docker.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe deploy;
      };
    };

    # postRun runs as root, and only when the certificate was actually renewed.
    security.acme.certs.${cfg.domain}.postRun = ''
      systemctl --no-block restart mailcow-tls.service
    '';

    environment.systemPackages = [ deploy ];
  };
}
