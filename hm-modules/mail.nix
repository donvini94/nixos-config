{
  config,
  lib,
  pkgs,
  ...
}:

let
  name = "Vincenzo Pace";
  maildir = "~/.mail";
  email = "vincenzo.pace94@icloud.com";
  kit = "uneqy@student.kit.edu";
  notmuchrc = "/home/vincenzo/.config/notmuch/notmuchrc";
in
{
  accounts.email = {
    maildirBasePath = "${maildir}";
    accounts = {
      icloud = {
        primary = true;
        address = "${email}";
        realName = "${name}";
        userName = "vincenzo.pace94";
        passwordCommand = "pass mbsync/icloud";
        imap = {
          host = "imap.mail.me.com";
          port = 993;
          tls.enable = true;
        };
        smtp = {
          host = "smtp.mail.me.com";
          port = 587;
          tls.enable = true;
        };
        mbsync = {
          enable = true;
          create = "both";
          expunge = "both";
          patterns = [ "*" ];
        };
      };
      kit = {
        primary = false;
        address = "${kit}";
        realName = "${name}";
        userName = "${kit}";
        passwordCommand = "pass Email/uneqy@student.kit.edu";
        imap = {
          host = "imap.kit.edu";
          tls.enable = true;
          port = 993;
        };
        smtp = {
          host = "smtp.kit.edu";
          port = 587;
          tls.useStartTls = true;
        };
        mbsync = {
          enable = true;
          create = "both";
          expunge = "both";
          patterns = [ "*" ];
          extraConfig.account = {
            AuthMechs = "Login";
            PipelineDepth = 1;
          };
        };
      };
    };
  };
  programs = {
    msmtp.enable = true;
    mbsync.enable = true;
    #    notmuch = {
    #      enable = true;
    #      new = {
    #        ignore = [
    #          "trash"
    #          "*.json"
    #        ];
    #        tags = [ "new" ];
    #      };
    #      search.excludeTags = [
    #        "trash"
    #        "deleted"
    #        "spam"
    #      ];
    #      maildir.synchronizeFlags = true;
    #    };

  };
  services = {
    mbsync = {
      enable = true;
      frequency = "*:0/15";
      preExec = "${pkgs.isync}/bin/mbsync -Ha";
      postExec = "${pkgs.mu}/bin/mu index -m ${maildir}";
    };
  };
}
