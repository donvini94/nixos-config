{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.localTeleport;
  tailscale = lib.getExe config.services.tailscale.package;
  certDir = "/var/lib/teleport-tls";
  certFile = "${certDir}/${cfg.publicHost}.crt";
  keyFile = "${certDir}/${cfg.publicHost}.key";

  # Teleport terminates TLS itself, so Tailscale passes the connection through
  # untouched. The certificate is a real Let's Encrypt one issued for the tailnet
  # name, which is what lets `tsh` and a browser verify the proxy without any
  # public DNS record or public listener.
  issueCert = pkgs.writeShellApplication {
    name = "teleport-tailnet-cert";
    runtimeInputs = [
      config.services.tailscale.package
      pkgs.coreutils
    ];
    text = ''
      install -d -m 0700 ${lib.escapeShellArg certDir}
      tailscale cert \
        --cert-file ${lib.escapeShellArg certFile} \
        --key-file ${lib.escapeShellArg keyFile} \
        ${lib.escapeShellArg cfg.publicHost}
      chmod 0600 ${lib.escapeShellArg certFile} ${lib.escapeShellArg keyFile}
    '';
  };
in
{
  options.services.localTeleport = {
    enable = lib.mkEnableOption "Teleport access plane reachable only over the tailnet";

    clusterName = lib.mkOption {
      type = lib.types.str;
      default = "bereit";
      description = ''
        Cluster identity. Baked into the cluster CA on first start and
        immutable afterwards: changing it orphans every issued certificate.
      '';
    };

    publicHost = lib.mkOption {
      type = lib.types.str;
      description = "Tailnet DNS name clients dial and the proxy certificate is issued for.";
    };

    proxyPort = lib.mkOption {
      type = lib.types.port;
      default = 33080;
      description = "Tailnet port published for the multiplexed proxy.";
    };

    webListenAddr = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:3080";
      description = "Loopback address the proxy binds. Never published directly.";
    };

    authListenAddr = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:3025";
      description = "Loopback address the auth service binds.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.tailscale.enable;
        message = "services.localTeleport requires Tailscale: it is the only transport that reaches the proxy";
      }
    ];

    systemd.services.teleport-tailnet-cert = {
      description = "Issue the Teleport proxy certificate for ${cfg.publicHost}";
      after = [ "tailscaled.service" ];
      requires = [ "tailscaled.service" ];
      before = [ "teleport.service" ];
      wantedBy = [ "teleport.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe issueCert;
        # Teleport loads the keypair at start, so a reissue is invisible until
        # the process re-reads it. try-reload skips the no-op first boot, where
        # teleport.service has not started yet.
        ExecStartPost = "${pkgs.systemd}/bin/systemctl try-reload-or-restart teleport.service";
      };
    };

    # Let's Encrypt certificates last 90 days; renew well inside that window.
    systemd.timers.teleport-tailnet-cert = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Mon *-*-* 04:15:00";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };

    systemd.services.teleport = {
      after = [ "teleport-tailnet-cert.service" ];
      requires = [ "teleport-tailnet-cert.service" ];
    };

    services.teleport = {
      enable = true;
      settings = {
        version = "v3";

        teleport = {
          nodename = config.networking.hostName;
          data_dir = "/var/lib/teleport";
          log = {
            output = "stderr";
            severity = "INFO";
          };
        };

        auth_service = {
          enabled = "yes";
          cluster_name = cfg.clusterName;
          listen_addr = cfg.authListenAddr;
          # One port for web, SSH and tunnels, so a single tailnet passthrough
          # covers the whole access plane.
          proxy_listener_mode = "multiplex";
          authentication = {
            # Local users are the bootstrap and the break-glass path. The GitHub
            # connector is a dynamic resource created with `tctl create`, since
            # it carries an OAuth client secret that cannot live in this repo.
            type = "local";
            second_factor = "webauthn";
            webauthn.rp_id = cfg.publicHost;
          };
        };

        proxy_service = {
          enabled = "yes";
          web_listen_addr = cfg.webListenAddr;
          public_addr = [ "${cfg.publicHost}:${toString cfg.proxyPort}" ];
          https_keypairs = [
            {
              key_file = keyFile;
              cert_file = certFile;
            }
          ];
        };

        ssh_service = {
          enabled = "yes";
          labels = {
            host = config.networking.hostName;
            role = "startup-infrastructure";
          };
        };
      };
    };
  };
}
