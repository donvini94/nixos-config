# The customer's public hostname: n8n's production webhooks, forms and hosted chat, and
# nothing else. Everything n8n serves outside these paths (editor, REST API, test
# webhooks, metrics) answers 404 here and stays on the tailnet. Browsers are kept from
# contacting third parties: CDN assets are served locally, fonts fall back to the system.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.aiStack.public;
  n8n = "http://127.0.0.1:5678";
  chatAssets = pkgs.callPackage ../packages/n8n-chat.nix { };
  csp = lib.concatStringsSep "; " [
    "default-src 'self'"
    "script-src 'self' 'unsafe-inline'"
    "style-src 'self' 'unsafe-inline'"
    "img-src 'self' data:"
    "font-src 'self'"
    "connect-src 'self'"
    "form-action 'self'"
    "frame-ancestors 'self'"
    "base-uri 'self'"
  ];
  location =
    { zone, burst }:
    {
      proxyPass = n8n;
      extraConfig = ''
        limit_req zone=${zone} burst=${toString burst} nodelay;
        limit_req_status 429;
        client_max_body_size 16m;
        # Chat replies stream; the page rewrite below needs an uncompressed body.
        proxy_buffering off;
        proxy_set_header Accept-Encoding "";
        sub_filter_once off;
        sub_filter 'https://cdn.jsdelivr.net/npm/' '/_cdn/';
      '';
    };
  webhook = location {
    zone = "ai_stack_webhook";
    burst = 200;
  };
  form = location {
    zone = "ai_stack_form";
    burst = 20;
  };
in
{
  options.services.aiStack.public = {
    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "agent.example.de";
      description = "Public hostname for n8n webhooks, forms and hosted chat; null keeps n8n private.";
    };

    acmeEmail = lib.mkOption {
      type = lib.types.str;
      description = "Contact address for the domain's Let's Encrypt account.";
    };
  };

  config = lib.mkIf (cfg.domain != null) {
    services.localN8n.publicUrl = "https://${cfg.domain}/";

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    security.acme = {
      acceptTerms = true;
      certs.${cfg.domain}.email = cfg.acmeEmail;
    };

    services.nginx = {
      enable = true;
      recommendedProxySettings = lib.mkDefault true;
      recommendedTlsSettings = lib.mkDefault true;
      # Messaging platforms deliver webhooks from few addresses in bursts; forms come
      # from people.
      appendHttpConfig = ''
        limit_req_zone $binary_remote_addr zone=ai_stack_webhook:10m rate=20r/s;
        limit_req_zone $binary_remote_addr zone=ai_stack_form:10m rate=2r/s;
      '';
      virtualHosts.${cfg.domain} = {
        enableACME = true;
        forceSSL = true;
        extraConfig = ''
          add_header Content-Security-Policy "${csp}" always;
          add_header Strict-Transport-Security "max-age=31536000" always;
          add_header X-Content-Type-Options "nosniff" always;
          add_header Referrer-Policy "strict-origin-when-cross-origin" always;
          add_header Permissions-Policy "camera=(), geolocation=(), microphone=()" always;
        '';
        locations = {
          "/".return = "404";
          "/webhook/" = webhook;
          "/webhook-waiting/" = webhook;
          "/form/" = form;
          "/form-waiting/" = form;
          # Images the form pages reference.
          "/static/" = {
            proxyPass = n8n;
            extraConfig = "limit_except GET { deny all; }";
          };
          "/_cdn/".alias = "${chatAssets}/";
        };
      };
    };
  };
}
