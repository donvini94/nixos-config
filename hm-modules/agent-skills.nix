{
  config,
  lib,
  pkgs,
  ...
}:

# Shared skills are writable repo links; sources.json records vendored origins.
# Use agent-update, not npx skills update (which would write through the links).
# Pi opts out of this tree in its own settings.
let
  repo = "${config.home.homeDirectory}/nixos-config/skills";
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
  agentUpdate = pkgs.writeShellApplication {
    name = "agent-update";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      diffutils
      git
      gnugrep
      gnused
      jq
      nodejs
      rsync
      unzip
    ];
    text = builtins.readFile ../scripts/agent-update.sh;
  };

  managedNames = [
    "calendar-to-org-agenda"
    "meeting-minutes"
  ];
in
{
  home.packages = [ agentUpdate ];

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
    )
    // lib.listToAttrs (
      map (name: {
        name = ".omp/agent/managed-skills/${name}";
        value.source = link "${repo}/managed/${name}";
      }) managedNames
    );
}
