{ config, pkgs, ... }:
{
  virtualisation.docker = {
    enable = true;
    storageDriver = "btrfs";
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };

  # Required directories for media automation
  systemd.tmpfiles.rules = [
    "d /var/lib/media-stack 0755 root root"
    "d /var/lib/media-stack/jellyseerr 0755 jellyfin jellyfin"
    "d /var/lib/media-stack/sonarr 0755 jellyfin jellyfin"
    "d /var/lib/media-stack/radarr 0755 jellyfin jellyfin"
    "d /var/lib/media-stack/prowlarr 0755 jellyfin jellyfin"
    "d /var/lib/media-stack/qbittorrent 0755 jellyfin jellyfin"
    "d /var/lib/media-stack/gluetun 0755 jellyfin jellyfin"
    "d /var/lib/media-stack/sabnzbd 0755 jellyfin jellyfin"
    "d /mnt/hetzner/downloads 0755 jellyfin jellyfin"
    "d /mnt/hetzner/downloads/usenet 0755 jellyfin jellyfin"
    "d /mnt/hetzner/downloads/usenet/complete 0755 jellyfin jellyfin"
    "d /mnt/hetzner/downloads/usenet/incomplete 0755 jellyfin jellyfin"
    "d /mnt/hetzner/shows 0755 jellyfin jellyfin"
    "d /mnt/hetzner/movies 0755 jellyfin jellyfin"
  ];

  # Media automation Docker Compose stack
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
      WorkingDirectory = "/var/lib/media-stack";
      EnvironmentFile = config.sops.templates."mullvad.env".path;
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p /var/lib/media-stack"
        "${pkgs.coreutils}/bin/cp ${./media-stack/docker-compose.yml} /var/lib/media-stack/docker-compose.yml"
      ];
      ExecStart = "${pkgs.docker-compose}/bin/docker-compose up -d";
      ExecStop = "${pkgs.docker-compose}/bin/docker-compose down";
      User = "root";
      Group = "root";
    };
  };

  # Mining detection watchdog
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
