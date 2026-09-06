{
  config,
  lib,
  pkgs,
  ...
}:
let
  mediaDir = path: "d ${path} 0755 jellyfin jellyfin";
in
{
  virtualisation.docker = {
    enable = true;
    storageDriver = "btrfs";
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };

  # Rootless dockerd inherits the systemd user manager's 8MB RLIMIT_MEMLOCK,
  # too low for the Onyx OpenSearch container's `ulimits.memlock: -1`.
  # Merge into the drop-in nixpkgs already emits for this template unit;
  # defining systemd.units."user@.service" conflicts with it.
  systemd.services."user@".serviceConfig.LimitMEMLOCK = "infinity";

  systemd.tmpfiles.rules = [
    "d /var/lib/media-stack 0755 root root"
  ]
  ++ map (app: mediaDir "/var/lib/media-stack/${app}") [
    "jellyseerr"
    "sonarr"
    "radarr"
    "prowlarr"
    "qbittorrent"
    "gluetun"
    "sabnzbd"
    "kapowarr"
    "komga"
  ]
  ++ map mediaDir [
    "/mnt/hetzner/downloads"
    "/mnt/hetzner/downloads/usenet"
    "/mnt/hetzner/downloads/usenet/complete"
    "/mnt/hetzner/downloads/usenet/incomplete"
    "/mnt/hetzner/shows"
    "/mnt/hetzner/movies"
    "/mnt/hetzner/comics"
  ];

  systemd.services.media-stack = {
    description = "Media automation stack with VPN-isolated torrenting";
    after = [
      "docker.service"
      "mnt-hetzner.mount"
    ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "30min";
      WorkingDirectory = "/var/lib/media-stack";
      EnvironmentFile = config.sops.templates."mullvad.env".path;
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p /var/lib/media-stack"
        "${pkgs.coreutils}/bin/cp ${./media-stack/docker-compose.yml} /var/lib/media-stack/docker-compose.yml"
        "${pkgs.docker-compose}/bin/docker-compose pull"
      ];
      ExecStart = "${pkgs.docker-compose}/bin/docker-compose up -d";
      ExecStop = "${pkgs.docker-compose}/bin/docker-compose down";
      User = "root";
      Group = "root";
    };
  };

  systemd.services.mining-watchdog = {
    description = "Detect and stop mining containers";
    after = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      User = "vincenzo";
      Group = "users";
      Environment = [
        "DOCKER_HOST=unix:///run/user/1000/docker.sock"
        "XDG_RUNTIME_DIR=/run/user/1000"
        "PATH=${pkgs.docker}/bin:/run/current-system/sw/bin"
      ];
      ExecStart = pkgs.writeShellScript "mining-watchdog.sh" ''
        export DOCKER_HOST=unix:///run/user/1000/docker.sock
        export XDG_RUNTIME_DIR=/run/user/1000
        while true; do
          ${pkgs.docker}/bin/docker ps -q 2>/dev/null | while read c; do
            if ${pkgs.docker}/bin/docker exec "$c" sh -c "ss -tn 2>/dev/null | grep -E ':(3333|4444|5555|7777|8333)'" 2>/dev/null; then
              ${pkgs.docker}/bin/docker stop "$c" && \
                logger "Mining-watchdog: Stopped container $c for mining activity"
            fi
          done
          sleep 60
        done
      '';
      Restart = "always";
    };
  };
}
