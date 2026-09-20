{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.localTranscription;
  stateDirectory = "/var/lib/local-transcription";
  bindAddress = "127.0.0.1";
  port = 8272;

  image = "qwenllm/qwen3-asr@sha256:fb75b775f089e06e5a1aaebffd421e37505cc630d50c86d889d95ffa45a7e16a";
  sourceRevision = "80c22e6140bcb9166fb9906798894fc8b18c8309";
  modelRevision = "185ce639118ad1362d049ca0d8ed04b6ec5cd6c9";
  serverScript = ../local-transcription/server.py;

  upstreamSource = pkgs.fetchFromGitHub {
    owner = "netease-youdao";
    repo = "Confucius4-R2T2";
    rev = sourceRevision;
    hash = "sha256-J965AYB3eh+FD4c790QiyDnaFT3TccW0bYXHGO7AeH4=";
  };

  modelFiles = [
    {
      path = "added_tokens.json";
      sha256 = "de40784677cbd1843cabe5fbee078c7e042cd0b62155f0810af5a13842e5722a";
    }
    {
      path = "chat_template.json";
      sha256 = "75a8cfca24f00de72d796fbfed6858fc9614ef3dabd8696684cc3bc03a9c58ff";
    }
    {
      path = "config.json";
      sha256 = "829b3b9cea085a46459353609774b08e4898924253ae6d623c2b4cd855386b23";
    }
    {
      path = "generation_config.json";
      sha256 = "1da527824d81e07118facff437e03f2e24a23311e3bdeb2368973fe77e5f275c";
    }
    {
      path = "merges.txt";
      sha256 = "8831e4f1a044471340f7c0a83d7bd71306a5b867e95fd870f74d0c5308a904d5";
    }
    {
      path = "model.safetensors";
      sha256 = "cc4d5324d386c80f98a8a7b09fbcdcc813ad08a6503fe3a586ebb144ec4610dc";
    }
    {
      path = "preprocessor_config.json";
      sha256 = "45e120a4eda2c20c5d7f2ea9354e63536bf35e27aa573fb7cdf78017b378770d";
    }
    {
      path = "special_tokens_map.json";
      sha256 = "7b376c510ccf9d88bb9bbee41dfc5052122e16e0dec1124a8d8983c59259a9f3";
    }
    {
      path = "tokenizer.json";
      sha256 = "0499602714160467f2d68b910651d6216020689f1e016be87a2d0019ee3baeab";
    }
    {
      path = "tokenizer_config.json";
      sha256 = "4942d005604266809309cabc9f4e9cb89ce855d59b14681fdc0e1cc62ea26c4c";
    }
    {
      path = "vocab.json";
      sha256 = "ca10d7e9fb3ed18575dd1e277a2579c16d108e32f27439684afa0e10b1440910";
    }
  ];

  modelManifest = pkgs.writeText "confucius4-r2t2-sha256" (
    lib.concatMapStringsSep "\n" (file: "${file.sha256}  ${file.path}") modelFiles + "\n"
  );

  prepare = pkgs.writeShellScript "prepare-local-transcription" ''
    set -euo pipefail

    model_dir=${lib.escapeShellArg "${stateDirectory}/model"}
    cache_dir=${lib.escapeShellArg "${stateDirectory}/cache"}

    ${pkgs.coreutils}/bin/mkdir -p "$model_dir" "$cache_dir"


    download_file() {
      destination="$1"
      expected_sha256="$2"
      source_url="$3"
      partial="$destination.partial"

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

    if [ ! -f "$model_dir/.verified-sha256" ] \
      || ! ${pkgs.diffutils}/bin/cmp --silent "$model_dir/.verified-sha256" ${modelManifest}; then
      ${lib.concatMapStringsSep "\n" (file: ''
        download_file "$model_dir/${file.path}" ${lib.escapeShellArg file.sha256} \
          ${lib.escapeShellArg "https://huggingface.co/netease-youdao/Confucius4-R2T2/resolve/${modelRevision}/${file.path}"}
      '') modelFiles}
      ${pkgs.coreutils}/bin/cp ${modelManifest} "$model_dir/.verified-sha256"
      ${pkgs.coreutils}/bin/cp ${upstreamSource}/MODEL_LICENSE "$model_dir/MODEL_LICENSE"
    fi


    if ! ${pkgs.docker}/bin/docker image inspect ${lib.escapeShellArg image} >/dev/null 2>&1; then
      ${pkgs.docker}/bin/docker pull ${lib.escapeShellArg image}
    fi

    ${pkgs.docker}/bin/docker rm --force confucius4-r2t2 >/dev/null 2>&1 || true
  '';

  serviceUrl = "http://${bindAddress}:${toString port}/health";
in
{
  options.services.localTranscription = {
    enable = lib.mkEnableOption "local Confucius4-R2T2 speech transcription";

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether the transcription model starts automatically at boot.";
    };

    operators = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users allowed to start and stop the transcription service without sudo.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.docker.enable;
        message = "services.localTranscription requires virtualisation.docker.enable";
      }
      {
        assertion = cfg.operators != [ ];
        message = "services.localTranscription.operators must contain at least one user";
      }
    ];

    systemd.services.local-transcription = {
      description = "Confucius4-R2T2 local streaming transcription";
      wantedBy = lib.optional cfg.autoStart "multi-user.target";
      after = [
        "docker.service"
        "network-online.target"
      ];
      wants = [ "network-online.target" ];
      requires = [ "docker.service" ];
      conflicts = [ "ai-stack.target" ];
      before = [ "ai-stack.target" ];

      serviceConfig = {
        Type = "simple";
        StateDirectory = "local-transcription";
        StateDirectoryMode = "0750";
        ExecStartPre = prepare;
        ExecStart = lib.escapeShellArgs [
          "${pkgs.docker}/bin/docker"
          "run"
          "--rm"
          "--name"
          "confucius4-r2t2"
          "--device"
          "nvidia.com/gpu=all"
          "--network"
          "host"
          "--shm-size"
          "4g"
          "--cap-drop"
          "ALL"
          "--security-opt"
          "no-new-privileges"
          "--mount"
          "type=bind,source=${upstreamSource},target=/app,readonly"
          "--mount"
          "type=bind,source=${serverScript},target=/service/server.py,readonly"
          "--mount"
          "type=bind,source=${stateDirectory}/model,target=/model,readonly"
          "--mount"
          "type=bind,source=${stateDirectory}/cache,target=/root/.cache"
          "--env"
          "PYTHONPATH=/app"
          "--entrypoint"
          "python"
          image
          "-u"
          "/service/server.py"
          "--model"
          "/model"
          "--host"
          bindAddress
          "--port"
          (toString port)
          "--gpu-memory-utilization"
          "0.4"
        ];
        ExecStop = "${pkgs.docker}/bin/docker stop --timeout 30 confucius4-r2t2";
        Restart = "on-failure";
        RestartSec = "5s";
        TimeoutStartSec = "infinity";
        TimeoutStopSec = "45s";
        KillMode = "process";
      };
    };

    security.polkit = {
      enable = true;
      # Matched on the user list rather than a group (as modules/ai-ingress.nix does):
      # a fresh group only reaches a running session after a re-login, which would
      # leave `transcription-stop` asking for a password on the day it is installed.
      extraConfig = ''
        polkit.addRule(function(action, subject) {
          const operators = ${builtins.toJSON cfg.operators};
          const verbs = ["start", "stop", "restart", "kill"];
          if (action.id === "org.freedesktop.systemd1.manage-units"
              && operators.indexOf(subject.user) !== -1
              && action.lookup("unit") === "local-transcription.service"
              && verbs.indexOf(action.lookup("verb")) !== -1) {
            return polkit.Result.YES;
          }
        });
      '';
    };

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "transcription-start" ''
        set -euo pipefail
        ${pkgs.systemd}/bin/systemctl start local-transcription.service
        for _ in $(${pkgs.coreutils}/bin/seq 1 3600); do
          if ${pkgs.systemd}/bin/systemctl is-active --quiet local-transcription.service \
            && ${pkgs.curl}/bin/curl --fail --silent --max-time 1 --output /dev/null ${serviceUrl}; then
            exit 0
          fi
          ${pkgs.coreutils}/bin/sleep 1
        done
        echo "Transcription service did not become ready within one hour" >&2
        exit 1
      '')
      (pkgs.writeShellScriptBin "transcription-stop" ''
        exec ${pkgs.systemd}/bin/systemctl stop local-transcription.service
      '')
      (pkgs.writeShellScriptBin "transcription-health" ''
        set -euo pipefail
        ${pkgs.systemd}/bin/systemctl is-active --quiet local-transcription.service
        ${pkgs.curl}/bin/curl --fail --silent --show-error --max-time 2 --output /dev/null ${serviceUrl}
        echo ready
      '')
    ];
  };
}
