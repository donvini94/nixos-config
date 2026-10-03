{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.home.aiModelCatalog;
  python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
  helpers = pkgs.writeTextDir "catalog.py" (builtins.readFile ../ai-ingress/catalog.py);
  configuration = pkgs.writeText "ai-model-clients.json" (
    builtins.toJSON {
      inherit (cfg) endpoint clients;
      provider = "alucard-requesty";
      stateDirectory = "${config.home.homeDirectory}/.local/state/ai-models";
    }
  );
  sync = pkgs.writeShellApplication {
    name = "sync-ai-models";
    runtimeEnv.PYTHONPATH = helpers;
    text = ''
      exec ${python}/bin/python3 ${../scripts/sync-ai-models.py} ${configuration} "$@"
    '';
  };
in
{
  options.home.aiModelCatalog = {
    enable = lib.mkEnableOption "private runtime model discovery for enabled clients";
    endpoint = lib.mkOption { type = lib.types.str; };
    clients = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            path = lib.mkOption { type = lib.types.str; };
            defaults = lib.mkOption { type = lib.types.attrs; };
            modelDefaults = lib.mkOption {
              type = lib.types.attrs;
              default = { };
            };
          };
        }
      );
      default = { };
    };
  };
  config = lib.mkIf cfg.enable {
    home.packages = [ sync ];
    home.activation.captureAiModels = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      if [ -z "''${DRY_RUN:-}" ]; then ${lib.getExe sync} --capture; fi
    '';
    home.activation.refreshAiModels =
      lib.hm.dag.entryAfter
        ([ "writeBoundary" ] ++ lib.optional (config.programs.piClient.enable or false) "piAgentBootstrap")
        ''
          if [ -z "''${DRY_RUN:-}" ]; then ${lib.getExe sync}; fi
        '';
    systemd.user.services.ai-model-catalog = {
      Unit.Description = "Refresh client models from the private AI ingress";
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe sync;
      };
    };
    systemd.user.timers.ai-model-catalog = {
      Unit.Description = "Refresh private model metadata";
      Timer = {
        OnStartupSec = "30s";
        OnUnitActiveSec = "15min";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
