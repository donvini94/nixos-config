{ config, lib, pkgs, ... }:

{
   programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      aws.disabled = true;
      gcloud.disabled = true;
      line_break.disabled = true;
      nix_shell.disabled = false;
    };
  };

  # programs.carapace.enable = true;
  # programs.carapace.enableNushellIntegration = true;

 
}










