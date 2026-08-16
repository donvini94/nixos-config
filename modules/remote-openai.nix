{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.remoteOpenAI;
  expectedModels = pkgs.writeText "remote-openai-models" (
    lib.concatStringsSep "\n" (builtins.attrNames cfg.models) + "\n"
  );
  validateUpstream = pkgs.writeShellScript "validate-remote-openai" ''
    set -euo pipefail
    credential="$CREDENTIALS_DIRECTORY/upstream-bearer-token"
    if ${pkgs.gnugrep}/bin/grep --quiet '^REPLACE_' "$credential"; then
      echo "Replace the encrypted Requesty API-key placeholder before enabling Alucard AI" >&2
      exit 1
    fi

    response="$(${pkgs.coreutils}/bin/mktemp)"
    actual="$(${pkgs.coreutils}/bin/mktemp)"
    missing="$(${pkgs.coreutils}/bin/mktemp)"
    trap '${pkgs.coreutils}/bin/rm -f "$response" "$actual" "$missing"' EXIT
    {
      ${pkgs.coreutils}/bin/printf 'header = "Authorization: Bearer '
      ${pkgs.coreutils}/bin/tr -d '\r\n' < "$credential"
      ${pkgs.coreutils}/bin/printf '"\n'
    } | ${pkgs.curl}/bin/curl --config - --fail --silent --show-error \
      --output "$response" ${lib.escapeShellArg "${cfg.backendUrl}${cfg.backendHealthPath}"}
    ${pkgs.jq}/bin/jq --exit-status --raw-output '.data[].id' "$response" \
      | ${pkgs.coreutils}/bin/sort --unique > "$actual"
    ${pkgs.coreutils}/bin/comm -23 ${expectedModels} "$actual" > "$missing"
    if [ -s "$missing" ]; then
      echo "Configured models missing from the authenticated Requesty catalog:" >&2
      ${pkgs.coreutils}/bin/cat "$missing" >&2
      exit 1
    fi
  '';

  modelType = lib.types.submodule (
    { name, ... }:
    {
      options = {
        name = lib.mkOption {
          type = lib.types.str;
          default = name;
        };
        context = lib.mkOption {
          type = lib.types.ints.positive;
        };
        output = lib.mkOption {
          type = lib.types.ints.positive;
        };
        reasoning = lib.mkOption {
          type = lib.types.bool;
          default = true;
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
          description = "USD per million input and output tokens.";
        };
      };
    }
  );
in
{
  options.services.remoteOpenAI = {
    enable = lib.mkEnableOption "authenticated remote OpenAI-compatible ingress";
    backendUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://router.requesty.ai";
      description = "Upstream origin without the /v1 request path.";
    };
    backendHealthPath = lib.mkOption {
      type = lib.types.str;
      default = "/v1/models";
      description = "Authenticated upstream path used by the local /health probe.";
    };
    upstreamBearerCredentialFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Root-only upstream API key injected by the ingress.";
    };
    models = lib.mkOption {
      type = lib.types.attrsOf modelType;
      default = { };
      description = "Explicit client-visible model or Requesty policy registry.";
    };
    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };
    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/llama";
    };
    requestLog = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.stateDirectory}/logs/requests.jsonl";
    };
    operators = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    logRetention = lib.mkOption {
      type = lib.types.ints.positive;
      default = 14;
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.upstreamBearerCredentialFile != null;
        message = "services.remoteOpenAI.upstreamBearerCredentialFile must be configured";
      }
      {
        assertion = cfg.models != { } && builtins.hasAttr cfg.defaultModel cfg.models;
        message = "services.remoteOpenAI.defaultModel must name a registered model";
      }
      {
        assertion = cfg.operators != [ ];
        message = "services.remoteOpenAI.operators must contain at least one user";
      }
      {
        assertion = lib.hasPrefix "/var/lib/" cfg.stateDirectory;
        message = "services.remoteOpenAI.stateDirectory must be below /var/lib";
      }
    ];

    # The ingress, its logging, metrics, and operator tooling are shared with
    # the local llama backend; this module only supplies the Requesty one and
    # the catalog check that refuses to start on a drifted model registry.
    services.aiIngress = {
      enable = true;
      inherit (cfg)
        backendUrl
        backendHealthPath
        bindAddress
        port
        stateDirectory
        requestLog
        logRetention
        operators
        upstreamBearerCredentialFile
        ;
      environmentLabel = config.networking.hostName;
      allowedModels = builtins.attrNames cfg.models;
      priceMap = lib.mapAttrs (_: model: model.cost) cfg.models;
      extraPreStart = [ validateUpstream ];
      extraAfter = [ "network-online.target" ];
    };

    systemd.services.local-llama-logger.wants = [ "network-online.target" ];
  };
}
