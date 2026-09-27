{ config, pkgs, ... }:

# notmuch replica role for NixOS desktops (dracula). The Mac runs the same role from
# the stateful files under ../mail/ (see mail/README.md).
#
# A replica never talks IMAP. Every 5 minutes mail-replica-sync runs `muchsync alucard`,
# which makes this Maildir + notmuch database identical to the hub's (mail, tags,
# directory placement) and pushes local tag changes and Fcc'd sent mail back. The hub
# (hm-modules/mail-hub.nix) owns IMAP, tagging, and every mail-derived file in ~/org, so
# nothing here writes into Syncthing-shared folders.
#
# Sending is local: msmtp reads the mailbox password from the sops-nix secret in
# modules/mail-credentials.nix, so no GPG prompt is involved.

let
  mailDir = ../mail;
  scripts = "${mailDir}/bin";
  configs = "${mailDir}/config";
  authinfo = "/run/secrets/mail/bereit_authinfo";
in
{
  home.packages = with pkgs; [
    notmuch
    muchsync
    msmtp
  ];

  home.file.".local/bin/mail-replica-sync" = {
    source = "${scripts}/mail-replica-sync";
    executable = true;
  };

  # The repo file ships the Mac's CA bundle, log path and GPG-backed passwordeval.
  # The /nix/store result is mode 444, which msmtp accepts because the password comes
  # from passwordeval, not from this file.
  home.file.".msmtprc".text = builtins.replaceStrings
    [
      "/etc/ssl/cert.pem"
      "~/Library/Logs/msmtp.log"
      "gpg --quiet --no-tty --decrypt ~/.authinfo.gpg | awk"
      "{print $6; exit}'\""
    ]
    [
      "/etc/ssl/certs/ca-bundle.crt"
      "~/.local/state/msmtp.log"
      "awk"
      "{print $6; exit}' ${authinfo}\""
    ]
    (builtins.readFile "${configs}/msmtprc");

  # notmuch refuses $HOME expansion in its config, so the path has to be absolute; the
  # repo file ships the macOS one.
  home.file.".notmuch-config".text = builtins.replaceStrings
    [ "/Users/vincenzopace/Maildir" ]
    [ "${config.home.homeDirectory}/Maildir" ]
    (builtins.readFile "${configs}/notmuch-config");

  systemd.user.services.mail-replica-sync = {
    Unit.Description = "muchsync this notmuch replica with the alucard mail hub";
    Service = {
      Type = "oneshot";
      ExecStart = "%h/.local/bin/mail-replica-sync";
      Nice = 10;
      IOSchedulingClass = "idle";
    };
  };

  systemd.user.timers.mail-replica-sync = {
    Unit.Description = "Sync the notmuch replica every 5 minutes";
    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
      Unit = "mail-replica-sync.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
