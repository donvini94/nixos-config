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
    runtimeEnv.MAILCOW_DIR = cfg.mailcowDir;
    text = builtins.readFile ../scripts/mailcow-configure-bindings.sh;
  };
  deploy = pkgs.writeShellApplication {
    name = "mailcow-tls-deploy";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.docker
      pkgs.gnugrep
    ];
    runtimeEnv = {
      MAILCOW_DIR = cfg.mailcowDir;
      MAILCOW_SSL_DIR = sslDir;
      MAILCOW_ACME_DIR = acmeDir;
      MAILCOW_DOMAIN = cfg.domain;
      MAILCOW_RELOAD_SERVICES = lib.concatStringsSep " " cfg.reloadServices;
    };
    text = builtins.readFile ../scripts/mailcow-deploy-cert.sh;
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
