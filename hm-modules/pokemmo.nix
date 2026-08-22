{
  config,
  pkgs,
  ...
}:

let
  pokemmo = pkgs.callPackage ../packages/pokemmo.nix { };

  # The launcher owns this tree: it downloads the client on first run and
  # replaces it on every game update, icons included. Nothing here is managed
  # declaratively, which is also why the desktop entry points at a runtime path.
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
    # Reported by the client's SDL3 window; lets the compositor tie the window
    # back to this entry instead of showing an unmatched "PokeMMO" surface.
    startupNotify = false;
    settings.StartupWMClass = "com.pokemmo.PokeMMO";
  };
}
