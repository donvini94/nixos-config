{
  config,
  lib,
  pkgs,
  ...
}:

let
  sources = {
    prompt-snippets = "https://github.com/donvini94/omp-prompt-snippets.git";
  };
  sync = pkgs.writeShellApplication {
    name = "sync-agent-content";
    runtimeInputs = [
      pkgs.git
      pkgs.bun
      pkgs.coreutils
    ];
    text = builtins.readFile ../scripts/sync-agent-content.sh;
  };
in
{
  options.home.agentContent.enable = lib.mkEnableOption "shared prompt source packages";

  config = lib.mkIf config.home.agentContent.enable {
    home.activation.agentContentRepos = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -z "''${DRY_RUN:-}" ]; then
        ${lib.getExe sync} ${lib.escapeShellArg "${config.home.homeDirectory}/.local/share/agent-content"} \
          ${lib.escapeShellArgs (lib.mapAttrsToList (name: url: "${name}=${url}") sources)}
      fi
    '';
  };
}
