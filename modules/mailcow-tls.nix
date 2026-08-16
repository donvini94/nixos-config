{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.mailcowTls;
  sslDir = "${cfg.mailcowDir}/data/assets/ssl";
  acmeDir = "/var/lib/acme/${cfg.domain}";
  configureBindings = pkgs.writeShellApplication {
    name = "mailcow-network-policy";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.docker
      pkgs.gnugrep
      pkgs.gnused
    ];
    text = ''
      set -euo pipefail

      conf=${lib.escapeShellArg "${cfg.mailcowDir}/mailcow.conf"}
      changed=0

      ensure_setting() {
        key=$1
        value=$2

        if grep -Fxq "$key=$value" "$conf"; then
          return
        fi
        if grep -q "^$key=" "$conf"; then
          sed -i "\\|^$key=|c\\$key=$value" "$conf"
        else
          printf '\n%s=%s\n' "$key" "$value" >> "$conf"
        fi
        changed=1
      }

      test -f "$conf"
      ensure_setting HTTP_BIND 127.0.0.1
      ensure_setting HTTPS_BIND 127.0.0.1
      ensure_setting SKIP_LETS_ENCRYPT y

      if [ "$changed" -eq 1 ]; then
        echo "applying Mailcow reverse-proxy network policy"
        cd ${lib.escapeShellArg cfg.mailcowDir}
        docker compose up -d
      fi
    '';
  };
  deploy = pkgs.writeShellApplication {
    name = "mailcow-tls-deploy";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.docker
    ];
    text = ''
      set -euo pipefail
      ssl=${lib.escapeShellArg sslDir}
      acme=${lib.escapeShellArg acmeDir}
      conf=${lib.escapeShellArg "${cfg.mailcowDir}/mailcow.conf"}

      if [ ! -d "$ssl" ]; then
        echo "mailcow ssl directory $ssl not found — is mailcow installed?" >&2
        exit 1
      fi
      if [ ! -r "$acme/fullchain.pem" ]; then
        echo "ACME certificate $acme/fullchain.pem is unavailable" >&2
        exit 1
      fi

      # Mailcow's own ACME client would overwrite these files on its next run.
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
    systemd.services.mailcow-network-policy = {
      description = "Keep Mailcow web listeners behind host nginx";
      wantedBy = [ "multi-user.target" ];
      before = [ "mailcow-tls.service" ];
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe configureBindings;
      };
    };

    systemd.services.mailcow-tls = {
      description = "Deploy the host ACME certificate into mailcow";
      wantedBy = [ "multi-user.target" ];
      after = [
        "docker.service"
        "mailcow-network-policy.service"
        "acme-${cfg.domain}.service"
      ];
      requires = [
        "docker.service"
        "mailcow-network-policy.service"
      ];
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

    environment.systemPackages = [
      configureBindings
      deploy
    ];
  };
}
