{ config, lib, pkgs, ... }:

{
  fonts.packages = with pkgs; [
    source-code-pro
    source-sans
    dejavu_fonts
    cantarell-fonts
    nerdfonts
    font-awesome_5
    iosevka
    oxygenfonts];

 
}










