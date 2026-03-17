{
  config,
  lib,
  pkgs,
  ...
}:

{
  fonts.packages =
    with pkgs;
    [
      source-code-pro
      source-sans
      dejavu_fonts
      cantarell-fonts
      font-awesome
      oxygenfonts
      iosevka
      noto-fonts
      fira-code
      fira-code-symbols
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      kochi-substitute
      symbola
    ]
    ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts);
}
