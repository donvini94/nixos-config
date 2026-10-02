{ config, pkgs, ... }:

# Only the hub runs IMAP/tagging and writes mail-derived Org files; replicas use muchsync.

let
  mailDir = ../mail;
  scripts = "${mailDir}/bin";
  configs = "${mailDir}/config";
in
{
  home.packages = with pkgs; [
    notmuch
    isync # provides `mbsync`
    muchsync # server side of the replicas' sync, invoked over SSH
    jq # used by notmuch-compute-state + notmuch-emit-followups
  ];

  home.file.".local/bin/mail-sync" = {
    source = "${scripts}/mail-sync";
    executable = true;
  };
  home.file.".local/bin/notmuch-compute-state" = {
    source = "${scripts}/notmuch-compute-state";
    executable = true;
  };
  home.file.".local/bin/notmuch-emit-followups" = {
    source = "${scripts}/notmuch-emit-followups";
    executable = true;
  };
  home.file.".local/bin/notmuch-snapshot-counts" = {
    source = "${scripts}/notmuch-snapshot-counts";
    executable = true;
  };

  home.file.".mbsyncrc".source = "${configs}/mbsyncrc";

  # Same file as the replicas, except that only the hub maps tags to maildir flags:
  # mbsync carries those flags to IMAP, and replicas get the tags via muchsync.
  home.file.".notmuch-config".text =
    builtins.replaceStrings
      [ "/Users/vincenzopace/Maildir" "synchronize_flags=false" ]
      [ "${config.home.homeDirectory}/Maildir" "synchronize_flags=true" ]
      (builtins.readFile "${configs}/notmuch-config");

  systemd.user.services.mail-sync = {
    Unit.Description = "notmuch mail hub: mbsync + indexing + tagging + dashboard";
    Service = {
      Type = "oneshot";
      ExecStart = "%h/.local/bin/mail-sync";
      Nice = 10;
      IOSchedulingClass = "idle";
    };
  };

  systemd.user.timers.mail-sync = {
    Unit.Description = "Run the notmuch mail hub every 5 minutes";
    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
      Unit = "mail-sync.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.notmuch-daily = {
    Unit.Description = "Daily notmuch tag dump + counts snapshot";
    Service = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "notmuch-daily" ''
        set -euo pipefail
        ${pkgs.notmuch}/bin/notmuch dump --output="$HOME/org/notmuch-tags.dump"
        "$HOME/.local/bin/notmuch-snapshot-counts"
      '';
    };
  };

  systemd.user.timers.notmuch-daily = {
    Unit.Description = "Daily notmuch maintenance at 03:00";
    Timer = {
      OnCalendar = "*-*-* 03:00:00";
      Persistent = true;
      Unit = "notmuch-daily.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
