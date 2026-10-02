{
  config,
  lib,
  pkgs,
  ...
}:

# One skill set for every harness and host. ~/.agents/skills is read by OMP, Pi and Codex, so
# a skill linked there reaches all three on AC-0137, dracula and alucard identically.
#
# Sources, all version-controlled here rather than installed per machine:
#   skills/shared  authored and vendored skills; edited in place, no rebuild needed.
#   skills/managed skills OMP's manage_skill tool maintains; linked into OMP's managed-skills
#                  directory so the tool still writes, and Pi reads the same directory.
#   lathe          embedded in the pinned lathe binary (packages/lathe.nix).
#
# Third-party skills in skills/shared (grill-me, grill-with-docs, handoff: mattpocock/skills;
# find-skills: vercel-labs/skills; linear-cli: schpet/linear-cli; zotero-cli: the zotero-mcp-server
# package) are vendored copies listed in skills/sources.json. `agent-update` refreshes them; do not
# use `npx skills update`, which would now write through these links.
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
  # One command to refresh everything declared in this repo that has an upstream: vendored skills,
  # OMP plugins, and the Pi / OMP / extension pins. See scripts/agent-update.sh and docs/PI.md.
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
      openssh
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
