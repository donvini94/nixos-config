{ pkgs, ... }:

{
  # GTK3 apps (pavucontrol, etc.) on a wlroots/Hyprland session do not resolve
  # their theme NAME from gsettings/dconf the way GNOME apps do: there is no
  # XSettings daemon, and the xdg-desktop-portal Settings interface only carries
  # the `color-scheme` (dark/light) preference — not the theme name. With no
  # ~/.config/gtk-3.0/settings.ini, GTK3 falls back to built-in Adwaita (light)
  # regardless of the dark dconf values caelestia writes. We pin the dark
  # adw-gtk3 variant here so GTK3 renders dark; caelestia keeps layering its
  # wallpaper-dynamic accent colours on top via the gtk.css @define-color
  # overrides it writes separately (home-manager only manages gtk.css when
  # extraCss is set, which we leave empty — so the two do not collide).
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
    # adw-gtk3 is GTK3-only; leave GTK4 to libadwaita defaults (adopts the
    # post-26.05 default of `null` instead of inheriting `theme.name`).
    # GTK4 apps still render dark via the portal color-scheme preference.
    gtk4.theme = null;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
  };
}
