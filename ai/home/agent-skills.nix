{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:

# Shared skills are writable repo links; sources.json records vendored origins.
# update-skills refreshes only vendored sources; native client package managers own plugins.
# Pi opts out of this tree in its own settings.
let
  repo = "${config.home.homeDirectory}/nixos-config/ai/skills";
  # Out-of-store links keep every authored file writable and editable without a rebuild.
  link = config.lib.file.mkOutOfStoreSymlink;
  lathe = pkgs.callPackage ../packages/lathe.nix { };

  sharedNames = [
    "aisec"
    "isc-rules"
    "python"
    "rust"
    "debt-ledger"
    "delete-list"
    "grill-me"
    "grill-with-docs"
    "handoff"
    "find-skills"
    "linear-cli"
    "zotero-cli"
  ];
  updateSkills = pkgs.writeShellApplication {
    name = "update-skills";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      diffutils
      git
      jq
      inputs.determinate.inputs.nix.packages.${pkgs.stdenv.hostPlatform.system}.default
      rsync
      unzip
    ];
    text = builtins.readFile ../scripts/update-skills.sh;
  };
in
{
  home.packages = [
    updateSkills
    lathe
  ];

  home.file =
    lib.listToAttrs (
      map (name: {
        name = ".agents/skills/${name}";
        value.source = link "${repo}/shared/${name}";
      }) sharedNames
    )
    // lib.listToAttrs (
      map (name: {
        name = ".agents/skills/${name}";
        value.source = "${lathe}/share/lathe/skills/${name}";
      }) lathe.skillNames
    );
}
