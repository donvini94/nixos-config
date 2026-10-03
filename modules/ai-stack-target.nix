# `ai-stack.target`: one switch for the workloads that share Dracula's GPU, plus the
# operator tooling to drive it without root. Backends and applications attach themselves
# with wantedBy/partOf.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.aiStackTarget;

  # The target's Wants list is the authoritative membership; tooling never hardcodes units.
  readStackUnits = ''
    read -r -a stack_units <<< "$(${pkgs.systemd}/bin/systemctl show --property=Wants --value ai-stack.target)"
  '';
  healthCmd =
    if cfg.healthUrl == null then
      "true"
    else
      "${pkgs.curl}/bin/curl --fail --silent --max-time 1 ${cfg.healthUrl} >/dev/null";
in
{
  options.services.aiStackTarget = {
    enable = lib.mkEnableOption "ai-stack.target and its operator tooling";

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether ai-stack.target starts automatically at boot.";
    };

    operators = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users allowed to drive the target without root.";
    };

    lifecycleUnits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "ai-stack.target" ];
      description = "Units the operator group may start and stop without root.";
    };

    healthUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional URL that must answer before the stack counts as healthy.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.operators != [ ];
        message = "services.aiStackTarget.operators must contain at least one user";
      }
    ];

    systemd.targets.ai-stack = {
      description = "AI application stack";
      wantedBy = lib.optional cfg.autoStart "multi-user.target";
    };

    users.groups.ai-operators = { };
    users.users = lib.genAttrs cfg.operators (_: {
      extraGroups = [ "ai-operators" ];
    });

    # Inert unless polkit itself runs; servers do not enable it by default, which
    # leaves ai-stack-{start,stop} root-only.
    security.polkit.enable = true;
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        const units = ${builtins.toJSON cfg.lifecycleUnits};
        const verbs = ["start", "stop", "restart", "kill"];
        if (action.id === "org.freedesktop.systemd1.manage-units"
            && subject.isInGroup("ai-operators")
            && units.indexOf(action.lookup("unit")) !== -1
            && verbs.indexOf(action.lookup("verb")) !== -1) {
          return polkit.Result.YES;
        }
      });
    '';

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "ai-stack-start" ''
        set -euo pipefail
        ${pkgs.systemd}/bin/systemctl start ai-stack.target
        ${readStackUnits}
        for _ in $(${pkgs.coreutils}/bin/seq 1 200); do
          if ${pkgs.systemd}/bin/systemctl is-active --quiet ai-stack.target "''${stack_units[@]}" \
            && ${healthCmd}; then
            exit 0
          fi
          ${pkgs.coreutils}/bin/sleep 1
        done
        echo "AI stack did not become healthy within 200 seconds" >&2
        exit 1
      '')
      (pkgs.writeShellScriptBin "ai-stack-stop" ''
        set -euo pipefail
        ${readStackUnits}
        ${pkgs.systemd}/bin/systemctl stop ai-stack.target
        for _ in $(${pkgs.coreutils}/bin/seq 1 150); do
          all_stopped=true
          for unit in "''${stack_units[@]}"; do
            state="$(${pkgs.systemd}/bin/systemctl is-active "$unit" || true)"
            if [ "$state" != inactive ] && [ "$state" != failed ]; then
              all_stopped=false
              break
            fi
          done
          if [ "$all_stopped" = true ]; then
            exit 0
          fi
          ${pkgs.coreutils}/bin/sleep 0.2
        done
        echo "AI services did not stop within 30 seconds" >&2
        exit 1
      '')
      (pkgs.writeShellScriptBin "ai-stack-health" ''
        set -euo pipefail
        ${readStackUnits}
        ${pkgs.systemd}/bin/systemctl is-active --quiet ai-stack.target "''${stack_units[@]}"
        ${healthCmd}
      '')
    ];
  };
}
