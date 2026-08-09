{
  config,
  lib,
  pkgs,
  ...
}:

let
  crowdsecAdmin = pkgs.writeShellApplication {
    name = "crowdsec-admin";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      if (( EUID != 0 )); then
        exec ${config.security.wrapperDir}/sudo "$0" "$@"
      fi

      exec systemd-run --quiet --wait --pipe --collect \
        --property=User=${lib.escapeShellArg config.services.crowdsec.user} \
        --property=Group=${lib.escapeShellArg config.services.crowdsec.group} \
        --property=DynamicUser=yes \
        --property=StateDirectory=crowdsec \
        --property=NoNewPrivileges=yes \
        --property=PrivateTmp=yes \
        --property=PrivateUsers=yes \
        --property=ProtectHome=yes \
        --property=ProtectSystem=strict \
        --property=UMask=0077 \
        ${lib.getExe' config.services.crowdsec.package "cscli"} \
        -c=/etc/crowdsec/config.yaml "$@"
    '';
  };
in
{
  environment.systemPackages = [
    crowdsecAdmin
    pkgs.ipset
  ];

  services.crowdsec = {
    enable = true;
    autoUpdateService = true;
    openFirewall = false;
    hub.collections = [
      "crowdsecurity/linux"
      "crowdsecurity/nginx"
    ];
    settings = {
      lapi.credentialsFile = "/var/lib/crowdsec/state/local_api_credentials.yaml";
      general.api.server = {
        enable = true;
        # Port 8080 belongs permanently to the AI ingress.
        listen_uri = "127.0.0.1:18082";
        # Do not send security events off-host unless CAPI enrollment is an
        # explicit operator decision.
        online_client = {
          sharing = false;
          pull = {
            community = false;
            blocklists = false;
          };
        };
      };
    };
    localConfig = {
      acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
          labels.type = "syslog";
        }
        {
          source = "file";
          filenames = [ "/var/log/nginx/access.log" ];
          labels.type = "nginx";
        }
      ];
      parsers.s02Enrich = [
        {
          name = "alucard/private-network-whitelist";
          description = "Never ban loopback, LAN, container, or tailnet source ranges";
          whitelist = {
            reason = "private administration network";
            cidr = [
              "127.0.0.0/8"
              "10.0.0.0/8"
              "100.64.0.0/10"
              "172.16.0.0/12"
              "192.168.0.0/16"
              "::1/128"
              "fd7a:115c:a1e0::/48"
            ];
          };
        }
      ];
    };
  };

  # The module registers and stores its bouncer key outside the Nix store.
  services.crowdsec-firewall-bouncer = {
    enable = true;
    settings = {
      mode = "iptables";
      iptables_chains = [
        "INPUT"
        "DOCKER-USER"
      ];
    };
  };

  # The upstream module requires the registration unit but does not order the
  # bouncer after it. Without this edge the first activation races the key file.
  systemd.services.crowdsec-firewall-bouncer.after = [
    "crowdsec-firewall-bouncer-register.service"
    "docker.service"
  ];
  systemd.services.crowdsec-firewall-bouncer.wants = [ "docker.service" ];

  users.users.crowdsec.extraGroups = lib.mkAfter [ "nginx" ];

  # The firewall-bouncer module invokes upstream cscli, which expects this
  # conventional path. CrowdSec itself uses the identical generated config
  # directly from the Nix store.
  environment.etc."crowdsec/config.yaml".source =
    (pkgs.formats.yaml { }).generate "crowdsec.yaml"
      config.services.crowdsec.settings.general;

  services.localObservability.extraScrapeTargets.crowdsec = 6060;
}
