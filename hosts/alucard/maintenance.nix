{
  config,
  lib,
  pkgs,
  ...
}:
let
  # One entry per restic job; a job missing here keeps upstream's randomized schedule.
  jobs = [
    {
      name = "paperless";
      backup = "03:30";
      check = "05:00";
    }
    {
      name = "jellyfin";
      backup = "03:35";
      check = "05:06";
    }
    {
      name = "onyx";
      backup = "03:40";
      check = "05:12";
    }
    {
      name = "n8n";
      backup = "03:45";
      check = "05:18";
    }
    {
      name = "mattermost";
      backup = "03:50";
      check = "05:24";
    }
    {
      name = "hermes";
      backup = "03:55";
      check = "05:30";
    }
    {
      name = "keycloak";
      backup = "04:00";
      check = "05:36";
    }
    {
      name = "twenty";
      backup = "04:05";
      check = "05:42";
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
    ++ map (job: "restic-backups-${job.name}") jobs
    ++ map (job: "restic-check-${job.name}") jobs;
  nightly = calendar: {
    timerConfig = {
      # Reset vendor calendars as well as Nix definitions (notably fstrim).
      OnCalendar = lib.mkForce ([ "" ] ++ map (slot: "${slot} Europe/Berlin") (lib.toList calendar));
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
            "*-*-* ${job.backup}:00 Europe/Berlin"
          ];
          AccuracySec = "1s";
          RandomizedDelaySec = lib.mkForce 0;
        };
      }) jobs
    )
    // builtins.listToAttrs (
      map (job: {
        name = "restic-check-${job.name}";
        value = nightly "Sun *-*-* ${job.check}:00";
      }) jobs
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
