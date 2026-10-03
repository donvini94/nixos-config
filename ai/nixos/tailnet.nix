# Administration over the tailnet only: backends bind loopback and Tailscale Serve
# publishes the listed ports on the host's tailnet address. This module owns the host's
# whole Serve configuration; hosts add their own endpoints to `tcp`. No tailnet interface
# is trusted by the firewall, and Funnel is never used.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.aiStack.tailnet;
  tailscale = lib.getExe config.services.tailscale.package;
  host = "${config.networking.hostName}.${cfg.domain}";
  hermesPort = 29119;
  ready = pkgs.writeShellScript "tailscale-serve-ready" ''
    state="$(${tailscale} status --json --peers=false | ${lib.getExe pkgs.jq} -r .BackendState)"
    test "$state" = Running
  '';
  configure = pkgs.writeShellScript "tailscale-serve" ''
    set -euo pipefail
    ${tailscale} serve reset
    ${lib.concatStrings (
      lib.mapAttrsToList (_: service: ''
        ${tailscale} serve --yes --bg --tcp=${toString service.listen} tcp://127.0.0.1:${toString service.target}
      '') cfg.tcp
    )}
    ${lib.optionalString config.services.hermesAgent.enable ''
      ${tailscale} serve --yes --bg --https=${toString hermesPort} http://127.0.0.1:19119
    ''}
  '';
in
{
  options.services.aiStack.tailnet = {
    domain = lib.mkOption {
      type = lib.types.str;
      example = "tail1234.ts.net";
      description = "The tailnet's MagicDNS suffix; the Hermes dashboard checks origins against it.";
    };

    tcp = lib.mkOption {
      default = { };
      description = "Loopback ports published on the tailnet as plain TCP, keyed by name.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            listen = lib.mkOption {
              type = lib.types.port;
              description = "Port on the host's tailnet address.";
            };
            target = lib.mkOption {
              type = lib.types.port;
              description = "Loopback port behind it.";
            };
          };
        }
      );
    };
  };

  config = lib.mkIf config.services.aiStack.enable {
    services.tailscale = {
      enable = true;
      disableTaildrop = true;
      openFirewall = false;
      useRoutingFeatures = "none";
    };

    services.aiStack.tailnet.tcp.n8n = {
      listen = 25678;
      target = 5678;
    };

    # Hermes accepts only its bound loopback Host and Origin, so nginx admits the exact
    # tailnet origin and rewrites both before proxying.
    services.nginx = lib.mkIf config.services.hermesAgent.enable {
      enable = true;
      appendHttpConfig = lib.mkAfter ''
        map $http_origin $hermes_tailnet_origin {
          default invalid;
          "" "";
          "https://${host}:${toString hermesPort}" "http://127.0.0.1:9119";
        }
      '';
      virtualHosts.hermes-tailnet-proxy = {
        serverName = host;
        listen = [
          {
            addr = "127.0.0.1";
            port = 19119;
          }
        ];
        extraConfig = lib.optionalString config.services.aiStack.edge.enable "modsecurity off;";
        locations."/" = {
          proxyPass = "http://127.0.0.1:9119";
          proxyWebsockets = true;
          recommendedProxySettings = false;
          extraConfig = ''
            if ($hermes_tailnet_origin = invalid) { return 403; }
            proxy_set_header Host 127.0.0.1:9119;
            proxy_set_header Origin $hermes_tailnet_origin;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Host $http_host;
            proxy_set_header X-Forwarded-Proto https;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
          '';
        };
      };
    };

    systemd.services.tailscale-private-services = {
      description = "Publish the host's administration ports inside the tailnet";
      after = [
        "nginx.service"
        "tailscaled.service"
      ];
      wants = [
        "nginx.service"
        "tailscaled.service"
      ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ configure ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecCondition = ready;
        ExecStart = configure;
      };
    };
  };
}
