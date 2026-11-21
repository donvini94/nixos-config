{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Bump rev to roll out upstream changes; activation never moves past it.
  sources = {
    prompt-snippets = {
      url = "https://github.com/donvini94/omp-prompt-snippets.git";
      rev = "d90b608a84fbd96030cad517a832749e1a701100";
    };
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
          ${lib.escapeShellArgs (lib.mapAttrsToList (name: s: "${name}=${s.rev}=${s.url}") sources)}
      fi
    '';
  };
}
