{
  config,
  lib,
  pkgs,
  ...
}:

{
  fonts.packages = with pkgs; [
    source-code-pro
    source-sans
    dejavu_fonts
    cantarell-fonts
    nerdfonts
    font-awesome
    oxygenfonts
    iosevka
    noto-fonts
    fira-code
    fira-code-symbols
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-emoji
    kochi-substitute
  ];
}
