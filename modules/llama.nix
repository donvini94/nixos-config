{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.localLlama;
  stateDirectory = "/var/lib/llama";
  modelRoot = "${stateDirectory}/models";
  bindAddress = "127.0.0.1";
  backendPort = 18080;

  modelFileType = lib.types.submodule {
    options = {
      path = lib.mkOption {
        type = lib.types.str;
        description = "Repository-relative model file path.";
      };
      sourceUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Pinned source URL when the file does not come from the model repository.";
      };
      sha256 = lib.mkOption {
        type = lib.types.strMatching "[0-9a-f]{64}";
        description = "SHA-256 of the model file.";
      };
    };
  };

  modelType = lib.types.submodule (
    { name, ... }:
    {
      options = {
        repo = lib.mkOption {
          type = lib.types.str;
          description = "Hugging Face repository for ${name}.";
        };
        revision = lib.mkOption {
          type = lib.types.str;
          description = "Pinned Hugging Face revision for ${name}.";
        };
        files = lib.mkOption {
          type = lib.types.nonEmptyListOf modelFileType;
          description = "All files required to load ${name}, each pinned by SHA-256.";
        };
        modelFile = lib.mkOption {
          type = lib.types.str;
          description = "Relative path, from among ${name}'s files, of the GGUF file to load.";
        };
        displayName = lib.mkOption {
          type = lib.types.str;
          default = name;
        };
        description = lib.mkOption {
          type = lib.types.str;
          default = "";
        };
        contextSize = lib.mkOption {
          type = lib.types.ints.positive;
          default = 65536;
          description = "Total context llama-server loads ${name} with, across every parallel slot.";
        };
        output = lib.mkOption {
          type = lib.types.ints.positive;
          default = 8192;
          description = "Maximum response tokens advertised to client configuration.";
        };
        reasoning = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether clients should treat ${name} as a reasoning model.";
        };
        cost = lib.mkOption {
          type = lib.types.submodule {
            options = {
              input = lib.mkOption { type = lib.types.number; };
              output = lib.mkOption { type = lib.types.number; };
            };
          };
          default = {
            input = 0;
            output = 0;
          };
          description = "USD per million input and output tokens; 0 for locally served models.";
        };
        parallelSlots = lib.mkOption {
          type = lib.types.ints.positive;
          default = 1;
          description = "Maximum concurrent generation jobs llama-server serves for ${name}.";
        };
        serverArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra llama-server CLI flags (cache quantization, flash attention, GPU offload, MoE placement, tokenizer overrides, ...).";
        };
      };
    }
  );

  modelDirectory = name: "${modelRoot}/${name}";
  modelFilePaths = model: map (file: file.path) model.files;
  hasUniqueFiles =
    model:
    builtins.length (modelFilePaths model) == builtins.length (lib.unique (modelFilePaths model));
  modelFileUrl =
    model: file:
    if file.sourceUrl == null then
      "https://huggingface.co/${model.repo}/resolve/${model.revision}/${file.path}"
    else
      file.sourceUrl;
  model = cfg.models.${cfg.defaultModel};

  modelManifest =
    name: model:
    pkgs.writeText "${name}-sha256-manifest" (
      lib.concatMapStringsSep "\n" (file: "${file.sha256}  ${file.path}") model.files + "\n"
    );

  downloadModel =
    name: model:
    pkgs.writeShellScript "download-local-model-${name}" ''
      set -euo pipefail
      model_dir=${lib.escapeShellArg (modelDirectory name)}
      marker="$model_dir/.verified-sha256"
      manifest=${lib.escapeShellArg (modelManifest name model)}

      if [ -f "$marker" ] && ${pkgs.diffutils}/bin/cmp --silent "$marker" "$manifest"; then
        exit 0
      fi

      download_file() {
        relative_path="$1"
        expected_sha256="$2"
        source_url="$3"
        destination="$model_dir/$relative_path"
        partial="$destination.partial"

        ${pkgs.coreutils}/bin/mkdir -p "$(dirname "$destination")"
        if [ -f "$destination" ] && ${pkgs.coreutils}/bin/printf '%s  %s\n' "$expected_sha256" "$destination" \
          | ${pkgs.coreutils}/bin/sha256sum --check --status; then
          return
        fi

        ${pkgs.curl}/bin/curl --fail --location --retry 5 --continue-at - \
          --output "$partial" "$source_url"
        ${pkgs.coreutils}/bin/printf '%s  %s\n' "$expected_sha256" "$partial" \
          | ${pkgs.coreutils}/bin/sha256sum --check
        ${pkgs.coreutils}/bin/mv "$partial" "$destination"
      }

      ${lib.concatMapStringsSep "\n" (
        file:
        "download_file ${lib.escapeShellArg file.path} ${lib.escapeShellArg file.sha256} ${lib.escapeShellArg (modelFileUrl model file)}"
      ) model.files}
      ${pkgs.coreutils}/bin/cp "$manifest" "$marker"
    '';

  waitForBackend = pkgs.writeShellScript "wait-for-local-llama-backend" ''
    set -eu
    for attempt in $(${pkgs.coreutils}/bin/seq 1 7200); do
      if ${pkgs.curl}/bin/curl --fail --silent --show-error "http://${bindAddress}:${toString backendPort}/health" > /dev/null; then
        exit 0
      fi
      ${pkgs.coreutils}/bin/sleep 1
    done
    echo "Local inference backend did not become healthy within two hours" >&2
    exit 1
  '';

  llamaCppArgv =
    m:
    [
      "${cfg.package}/bin/llama-server"
      "--host"
      bindAddress
      "--port"
      (toString backendPort)
      "-m"
      "${modelDirectory cfg.defaultModel}/${m.modelFile}"
      "-c"
      (toString m.contextSize)
      "--parallel"
      (toString m.parallelSlots)
    ]
    ++ m.serverArgs;
in
{
  options.services.localLlama = {
    enable = lib.mkEnableOption "local OpenAI-compatible inference (llama.cpp/GGUF)";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llama-cpp;
      defaultText = lib.literalExpression "pkgs.llama-cpp";
      description = ''
        llama.cpp build providing `llama-server`. Override with a CUDA-enabled
        build without touching the host's ambient `pkgs.llama-cpp`.
      '';
    };
    defaultModel = lib.mkOption {
      type = lib.types.str;
      description = "Primary local model ID, loaded by its backend at service start.";
    };
    models = lib.mkOption {
      type = lib.types.attrsOf modelType;
      default = { };
      description = "Pinned local model registry (EXL3 via TabbyAPI or GGUF via llama.cpp) keyed by the OpenAI request model ID.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.models != { } && builtins.hasAttr cfg.defaultModel cfg.models;
        message = "services.localLlama.defaultModel must name a registered model";
      }
      {
        assertion = lib.all hasUniqueFiles (lib.attrValues cfg.models);
        message = "services.localLlama model file paths must be unique within each model";
      }
      {
        assertion = builtins.elem model.modelFile (modelFilePaths model);
        message = "services.localLlama.defaultModel's modelFile must name one of its files";
      }
    ];

    systemd.services.local-llama-backend = {
      description = "llama.cpp local GGUF inference server";
      wantedBy = [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      serviceConfig = {
        Type = "simple";
        User = "llama";
        Group = "llama";
        StateDirectory = "llama";
        StateDirectoryMode = "0750";
        WorkingDirectory = stateDirectory;
        ExecStartPre = downloadModel cfg.defaultModel model;
        ExecStart = lib.escapeShellArgs (llamaCppArgv model);
        ExecStartPost = waitForBackend;
        Restart = "on-failure";
        RestartSec = "5s";
        TimeoutStartSec = "infinity";
        TimeoutStopSec = "10s";
        KillMode = "control-group";
        KillSignal = "SIGTERM";
      };
    };

    systemd.services.ai-stack-resume = {
      description = "Recover an active local AI stack after suspend";
      wantedBy = [ "suspend.target" ];
      after = [ "suspend.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "restart-active-ai-stack-after-suspend" ''
          if ${pkgs.systemd}/bin/systemctl is-active --quiet ai-stack.target; then
            ${pkgs.systemd}/bin/systemctl restart ai-stack.target
          fi
        '';
      };
    };

    services.logind.settings.Login.IdleAction = "ignore";

    # The ingress, its logging, metrics, and operator tooling are shared with
    # the Requesty backend; this module only supplies the local one.
    services.aiIngress = {
      enable = true;
      backendUrl = "http://${bindAddress}:${toString backendPort}";
      priceMap = lib.mapAttrs (_: localModel: localModel.cost) cfg.models;
      lifecycleUnits = [
        "ai-stack.target"
        "local-llama-backend.service"
        "local-llama-logger.service"
      ];
      extraAfter = [ "local-llama-backend.service" ];
    };
  };
}
