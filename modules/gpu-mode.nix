# One GPU, several workloads that each want most of it. `gpu-mode` is the switch:
# it stops whatever holds the card before starting what you asked for, and
# `gpu-mode gaming` (alias: `gaming-mode`) hands the card back to games.
#
# The modes are declared per host because only hosts with competing GPU workloads
# need them; each mode reuses that workload's own start/stop commands, which
# already block until the GPU memory is actually taken or released.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.gpuMode;
  modeNames = lib.attrNames cfg.modes;

  perMode = body: lib.concatMapStringsSep "\n    " (name: "${name}) ${body name} ;;") modeNames;
in
{
  options.services.gpuMode.modes = lib.mkOption {
    default = { };
    description = "Mutually exclusive GPU workloads that `gpu-mode` switches between.";
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            unit = lib.mkOption {
              type = lib.types.str;
              description = "Unit whose state says whether ${name} currently holds the GPU.";
            };
            start = lib.mkOption {
              type = lib.types.str;
              description = "Command that starts ${name} and returns once it is ready.";
            };
            stop = lib.mkOption {
              type = lib.types.str;
              description = "Command that stops ${name} and returns once its GPU memory is free.";
            };
          };
        }
      )
    );
  };

  config = lib.mkIf (cfg.modes != { }) {
    environment.systemPackages = [
      (pkgs.writeShellApplication {
        name = "gpu-mode";
        runtimeInputs = [ pkgs.systemd ];
        text = ''
          modes=(${lib.concatStringsSep " " modeNames})

          mode_running() {
            case "$1" in
              ${perMode (name: "systemctl is-active --quiet ${lib.escapeShellArg cfg.modes.${name}.unit}")}
            esac
          }

          stop_mode() {
            case "$1" in
              ${perMode (name: cfg.modes.${name}.stop)}
            esac
          }

          start_mode() {
            case "$1" in
              ${perMode (name: cfg.modes.${name}.start)}
            esac
          }

          report_memory() {
            if command -v nvidia-smi > /dev/null; then
              echo "GPU memory: $(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader)"
            fi
          }

          case "''${1:-status}" in
            status)
              for mode in "''${modes[@]}"; do
                if mode_running "$mode"; then echo "$mode: running"; else echo "$mode: stopped"; fi
              done
              report_memory
              ;;
            gaming)
              for mode in "''${modes[@]}"; do
                if mode_running "$mode"; then
                  echo "stopping $mode"
                  stop_mode "$mode"
                fi
              done
              echo "GPU free for gaming"
              report_memory
              ;;
            ${lib.concatStringsSep "|" modeNames})
              wanted="$1"
              for mode in "''${modes[@]}"; do
                if [ "$mode" != "$wanted" ] && mode_running "$mode"; then
                  echo "stopping $mode"
                  stop_mode "$mode"
                fi
              done
              if mode_running "$wanted"; then
                echo "$wanted already running"
              else
                start_mode "$wanted"
                echo "$wanted ready"
              fi
              report_memory
              ;;
            *)
              echo "usage: gpu-mode {${lib.concatStringsSep "|" modeNames}|gaming|status}" >&2
              exit 2
              ;;
          esac
        '';
      })
      (pkgs.writeShellScriptBin "gaming-mode" ''
        exec gpu-mode gaming "$@"
      '')
    ];
  };
}
