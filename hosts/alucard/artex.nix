# ARTEX (AI pentest platform) for threat-analysis study only: tailnet-only, no LLM key
# configured, so it cannot act on anything until one is added in the UI.
# Upstream builds the image from source, so this drives its compose file from a pinned checkout.
{
  config,
  lib,
  pkgs,
  site,
  ...
}:
let
  src = pkgs.fetchFromGitHub {
    owner = "BaaRai";
    repo = "ARTEX";
    rev = "a13c68cb7078d43b66fb398db3d610e513b6d77a"; # v0.6.0
    hash = "sha256-ZO4vGy8UBdowN60zxblr1T//gR38MJGGnwFDCfmmtRk=";
  };
  dir = "/var/lib/artex";
  serve = pkgs.writeShellScript "artex-private-https" ''
    ${lib.getExe config.services.tailscale.package} serve --yes --bg --https=28787 http://127.0.0.1:8787
  '';
in
{
  assertions = [
    {
      assertion =
        !(builtins.elem 8787 config.networking.firewall.allowedTCPPorts)
        && !(builtins.elem 8788 config.networking.firewall.allowedTCPPorts);
      message = "ARTEX must remain loopback/tailnet-only";
    }
  ];

  systemd.services.artex = {
    description = "ARTEX (study instance)";
    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    path = [
      pkgs.docker
      pkgs.docker-compose
      pkgs.openssl
    ];
    restartTriggers = [ src ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "artex";
      TimeoutStartSec = "30min";
    };
    script = ''
      cd ${dir}
      cp -rT --no-preserve=mode,ownership ${src} .
      if [ ! -f .env ]; then
        install -m600 /dev/null .env
        echo "POSTGRES_PASSWORD=$(openssl rand -hex 24)" > .env
      fi
      docker compose up -d --build
    '';
    preStop = "cd ${dir} && docker compose down";
  };

  systemd.services.tailscale-private-services = {
    serviceConfig.ExecStartPost = [ serve ];
    restartTriggers = [ serve ];
  };
}
