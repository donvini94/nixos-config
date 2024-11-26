{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:

{
  environment.shells = with pkgs; [
    bash
    nushell
  ];
  environment.variables.EDITOR = "nvim";
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
      fcitx5-configtool
      fcitx5-anthy
      libsForQt5.fcitx5-qt
    ];
  };

  nixpkgs.config.allowUnfree = true;
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };
}
