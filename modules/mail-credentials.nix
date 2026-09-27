{ username, ... }:

# Bereit Mailcow mailbox credential for unattended consumers on NixOS hosts: alucard's
# mbsync (mail hub) and, on the desktops, msmtp and Emacs' org-caldav. The file is in
# authinfo format so auth-source reads it directly; the shell consumers pull the password
# field out of the `machine mail.istbereit.de login …` line. The Mac keeps the same two
# lines in ~/.authinfo.gpg instead (no sops-nix on darwin here).
{
  sops.secrets."mail/bereit_authinfo" = {
    sopsFile = ../secrets/mail.yaml;
    key = "bereit_authinfo";
    owner = username;
    mode = "0400";
  };
}
