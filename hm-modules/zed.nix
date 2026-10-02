# Preserve JSONC comments and trailing commas instead of round-tripping through Nix JSON.
{ ... }:

{
  xdg.configFile = {
    "zed/settings.json".source = ./zed/settings.json;
    "zed/keymap.json".source = ./zed/keymap.json;
  };
}
