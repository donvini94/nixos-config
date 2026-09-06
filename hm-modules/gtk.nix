{ pkgs, ... }:

{
  # GTK3 apps on a wlroots session cannot resolve a theme NAME: there is no XSettings
  # daemon and the xdg-desktop-portal Settings interface carries only `color-scheme`, so
  # without ~/.config/gtk-3.0/settings.ini GTK3 falls back to built-in Adwaita light,
  # whatever dark dconf values caelestia writes. Pinning the dark variant here leaves
  # caelestia's wallpaper accents to gtk.css; keep extraCss empty, or home-manager takes
  # over gtk.css and the two collide.
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    # adw-gtk3 is GTK3-only; GTK4 apps stay on libadwaita and render dark via the portal
    # color-scheme preference.
    gtk4.theme = null;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
  };
}
