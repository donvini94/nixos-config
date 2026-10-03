# Prometheus alert rules as a Nix attrset; default.nix renders them to YAML.
let
  # Only real, writable mounts. /nix and /nix/store are bind mounts of / and would
  # alert three times for one full disk.
  watchedMounts = ''mountpoint=~"/|/home|/boot|/mnt/.*"'';
  ratioFree = "node_filesystem_avail_bytes{${watchedMounts}} / node_filesystem_size_bytes{${watchedMounts}}";
in
{
  groups = [
    {
      name = "storage";
      rules = [
        {
          alert = "FilesystemFillingUp";
          expr = "${ratioFree} < 0.10";
          for = "30m";
          labels.severity = "warning";
          annotations.summary = "{{ $labels.host }}: {{ $labels.mountpoint }} is below 10% free ({{ $value | humanizePercentage }})";
        }
        {
          alert = "FilesystemAlmostFull";
          expr = "${ratioFree} < 0.03";
          for = "10m";
          labels.severity = "critical";
          annotations.summary = "{{ $labels.host }}: {{ $labels.mountpoint }} is below 3% free ({{ $value | humanizePercentage }}); backups to it will start failing";
        }
      ];
    }
    {
      name = "backups";
      rules = [
        {
          # Nightly timer with 15 minutes of jitter; 36h means a run failed or never
          # started. Quiet until a job has succeeded once.
          alert = "BackupStale";
          expr = "time() - restic_backup_last_success_timestamp_seconds > 36 * 3600";
          for = "30m";
          labels.severity = "critical";
          annotations.summary = "{{ $labels.host }}: backup {{ $labels.backup }} last succeeded {{ $value | humanizeDuration }} ago";
        }
      ];
    }
    {
      name = "security-scans";
      rules = [
        {
          # A scan that cannot read an image reports nothing for it, which looks
          # identical to a clean image on the dashboard.
          alert = "ContainerScanIncomplete";
          expr = "security_container_scan_failures > 0";
          for = "15m";
          labels.severity = "warning";
          annotations.summary = "{{ $labels.host }}: {{ $value }} running image(s) could not be scanned; the vulnerability counts are incomplete";
        }
        {
          # Daily timer with up to 2h of jitter, so a legitimate gap never exceeds
          # ~26h. 36h means two runs were missed or the unit is failing outright.
          alert = "ContainerScanStale";
          expr = "time() - security_container_scan_timestamp_seconds > 36 * 3600";
          for = "30m";
          labels.severity = "warning";
          annotations.summary = "{{ $labels.host }}: No container scan completed for {{ $value | humanizeDuration }}";
        }
        {
          # Weekly timer. Both staleness rules compare a published value rather than
          # using absent(), so they stay quiet until a scanner has run at least once.
          alert = "HostScanStale";
          expr = "time() - security_host_scan_timestamp_seconds > 9 * 24 * 3600";
          for = "30m";
          labels.severity = "warning";
          annotations.summary = "{{ $labels.host }}: No host closure scan completed for {{ $value | humanizeDuration }}";
        }
      ];
    }
  ];
}
