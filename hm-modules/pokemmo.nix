{
  config,
  pkgs,
  ...
}:

let
  pokemmo = pkgs.callPackage ../packages/pokemmo.nix { };

  # The launcher owns this tree: it downloads the client on first run and replaces it on
  # every game update, icons included, so the desktop entry points at a runtime path.
  gameDir = "${config.home.homeDirectory}/.local/share/pokemmo";
in
{
  home.packages = [ pokemmo ];

  xdg.desktopEntries.pokemmo = {
    name = "PokeMMO";
    genericName = "Pokémon MMO";
    comment = "Multiplayer client for the Gen 3/4 Pokémon games";
    exec = "pokemmo";
    icon = "${gameDir}/data/icons/128x128.png";
    terminal = false;
    categories = [
      "Game"
      "RolePlaying"
    ];
    startupNotify = false;
    # What the client's SDL3 window reports; ties the window back to this entry instead of
    # an unmatched "PokeMMO" surface.
    settings.StartupWMClass = "com.pokemmo.PokeMMO";
  };
}
