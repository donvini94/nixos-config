{ config, lib, pkgs, ... }:

{
  fonts.packages = with pkgs; [
    source-code-pro
    source-sans
    dejavu_fonts
    cantarell-fonts
    nerdfonts
    font-awesome_5
    oxygenfonts
    iosevka
    noto-fonts-cjk
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    kochi-substitute

  ];

}
