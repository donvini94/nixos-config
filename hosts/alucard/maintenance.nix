{
  config,
  lib,
  pkgs,
  ...
}:
let
  backups = [
    {
      name = "paperless";
      time = "03:30";
    }
    {
      name = "jellyfin";
      time = "03:35";
    }
    {
      name = "onyx";
      time = "03:40";
    }
    {
      name = "n8n";
      time = "03:45";
    }
    {
      name = "mattermost";
      time = "03:50";
    }
    {
      name = "hermes";
      time = "03:55";
    }
    {
      name = "keycloak";
      time = "04:00";
    }
  ];
  checks = [
    {
      name = "paperless";
      time = "05:00";
    }
    {
      name = "jellyfin";
      time = "05:06";
    }
    {
      name = "onyx";
      time = "05:12";
    }
    {
      name = "n8n";
      time = "05:18";
    }
    {
      name = "mattermost";
      time = "05:24";
    }
    {
      name = "hermes";
      time = "05:30";
    }
    {
      name = "keycloak";
      time = "05:36";
    }
  ];
  timers = {
    nix-gc = "*-*-* 01:00:00";
    container-vulnerability-scan = "*-*-* 01:15:00";
    yt-pipeline-purge = "*-*-* 01:25:00";
    host-vulnerability-scan = "Sun *-*-* 01:35:00";
    crowdsec-update-hub = "*-*-* 01:45:00";
    fstrim = "Mon *-*-* 01:50:00";
    paperless-exporter = "*-*-* 03:20:00";
    yt-pipeline-schedule = config.services.yt-pipeline.schedule;
  };
  batchUnits =
    builtins.attrNames timers
    ++ map (job: "restic-backups-${job.name}") backups
    ++ map (job: "restic-check-${job.name}") checks;
  nightly = calendar: {
    timerConfig = {
      # Reset vendor calendars as well as Nix definitions (notably fstrim).
      OnCalendar = lib.mkForce (
        [ "" ] ++ map (slot: "${slot} Europe/Berlin") (lib.toList calendar)
      );
      AccuracySec = "1s";
      RandomizedDelaySec = lib.mkForce 0;
      # Catch-up must not start optional heavy work during daytime activation.
      Persistent = lib.mkForce false;
    };
  };
in
{
  nix.gc.dates = "*-*-* 01:00:00 Europe/Berlin";

  systemd.timers =
    lib.mapAttrs (_: nightly) timers
    // builtins.listToAttrs (
      map (job: {
        name = "restic-backups-${job.name}";
        # Preserve backup catch-up after downtime, unlike optional maintenance.
        value.timerConfig = {
          OnCalendar = lib.mkForce [
            ""
            "*-*-* ${job.time}:00 Europe/Berlin"
          ];
          AccuracySec = "1s";
          RandomizedDelaySec = lib.mkForce 0;
        };
      }) backups
    )
    // builtins.listToAttrs (
      map (job: {
        name = "restic-check-${job.name}";
        value = nightly "Sun *-*-* ${job.time}:00";
      }) checks
    );

  systemd.slices.maintenance.sliceConfig = {
    CPUWeight = 20;
    IOWeight = 20;
  };
  systemd.services =
    lib.genAttrs batchUnits (_: {
      serviceConfig = {
        Slice = "maintenance.slice";
        Nice = lib.mkDefault 10;
        IOSchedulingClass = lib.mkDefault "idle";
      };
    })
    // {
      jellyfin-maintenance = {
        description = "Configure overnight Jellyfin scheduled tasks";
        wantedBy = [ "multi-user.target" ];
        after = [ "jellyfin.service" ];
        requires = [ "jellyfin.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStartSec = "3min";
          StateDirectory = "jellyfin-maintenance";
          StateDirectoryMode = "0700";
          ExecStart = "${pkgs.python3}/bin/python3 ${./scripts/jellyfin-maintenance.py} --state-directory /var/lib/jellyfin-maintenance";
        };
      };
    };
}
