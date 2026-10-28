{
  inputs,
  pkgs,
  username,
  ...
}:

{
  imports = [
    ./hm-modules/base.nix
    ./hm-modules/ssh.nix
    ./hm-modules/hyprland.nix
    ./hm-modules/kitty.nix
    ./hm-modules/gtk.nix
    ./hm-modules/mpv.nix
    ./hm-modules/pokemmo.nix
    ./hm-modules/packages.nix
    ./hm-modules/zed.nix
    ./hm-modules/starship.nix
    ./hm-modules/zathura.nix
    ./hm-modules/doom.nix
    ./hm-modules/zellij
    ./hm-modules/caelestia.nix
    ./hm-modules/services.nix
    ./transcription/home.nix
    ./transcription/meeting.nix
    ./mail/home/email.nix
    ./coding-agents/home/claude.nix
    ./hm-modules/zotero-cli.nix
    inputs.caelestia-shell.homeManagerModules.default
  ];

  nixpkgs.config = {
    allowUnfree = true;
    # Zotero 10 still embeds Firefox ESR 140, which went EOL on 2026-10-13. Zotero opens
    # only its own UI and connector traffic; revisit when Zotero moves to ESR 153.
    permittedInsecurePackages = [ "firefox-esr-140-bin-unwrapped-140.17.0esr" ];
  };

  home = {
    username = "${username}";
    homeDirectory = "/home/${username}";
    stateVersion = "23.05";
    pointerCursor = {
      enable = true;
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 24;
      gtk.enable = true;
    };
  };

  fonts.fontconfig.enable = true;

  xdg.mimeApps.defaultApplications = {
    "application/pdf" = [ "zathura.desktop" ];
    "image/*" = [ "viewnior.desktop" ];
    "video/*" = [ "mpv.desktop" ];
  };

  systemd.user.startServices = "sd-switch";
}
