{ username, ... }:

# Bereit Mailcow mailbox credential for unattended consumers on NixOS hosts: alucard's
# mbsync (mail hub) and, on the desktops, msmtp. Both pull the password field out of the
# authinfo-format `machine mail.istbereit.de login …` line. The Mac keeps the same line
# in ~/.authinfo.gpg instead (no sops-nix on darwin here).
{
  sops.secrets."mail/bereit_authinfo" = {
    sopsFile = ../../secrets/mail.yaml;
    key = "bereit_authinfo";
    owner = username;
    mode = "0400";
  };
}
