{ config, pkgs, ... }:

# The notmuch mail hub, imported by hosts/alucard/home.nix only. This is the one host
# that talks IMAP (mbsync), runs the tagging pipeline, and writes mail-derived files
# into the Syncthing-shared ~/org (mail-followups.org, notmuch-tags.dump,
# notmuch-counts/). The Mac and dracula are muchsync replicas of this host's Maildir
# and notmuch database (hm-modules/email.nix, mail/bin/mail-replica-sync).
#
# The user timers run without a login session because alucard lingers vincenzo.
#
# CEILING: if alucard is down, no host receives new mail in notmuch (Mailcow still
# holds it, and replicas can still send). Upgrade path is promoting a replica to hub,
# which means copying this module's role there, not running two hubs at once.

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

  home.file.".local/bin/mail-sync" = { source = "${scripts}/mail-sync"; executable = true; };
  home.file.".local/bin/notmuch-compute-state" = { source = "${scripts}/notmuch-compute-state"; executable = true; };
  home.file.".local/bin/notmuch-emit-followups" = { source = "${scripts}/notmuch-emit-followups"; executable = true; };
  home.file.".local/bin/notmuch-snapshot-counts" = { source = "${scripts}/notmuch-snapshot-counts"; executable = true; };

  home.file.".mbsyncrc".source = "${configs}/mbsyncrc";

  # Same file as the replicas, except that only the hub maps tags to maildir flags:
  # mbsync carries those flags to IMAP, and replicas get the tags via muchsync.
  home.file.".notmuch-config".text = builtins.replaceStrings
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
