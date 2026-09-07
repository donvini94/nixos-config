{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.remoteOpenAI;
  ingress = config.services.aiIngress;
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
      --output "$response" ${lib.escapeShellArg "${ingress.backendUrl}${ingress.backendHealthPath}"}
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
    models = lib.mkOption {
      type = lib.types.attrsOf modelType;
      default = { };
      description = "Client-visible model registry; also read by clients on hosts that only select this ingress.";
    };
    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = ingress.upstreamBearerCredentialFile != null;
        message = "services.aiIngress.upstreamBearerCredentialFile must be set for the Requesty upstream";
      }
      {
        assertion = cfg.models != { } && builtins.hasAttr cfg.defaultModel cfg.models;
        message = "services.remoteOpenAI.defaultModel must name a registered model";
      }
    ];

    # Ingress, logging, metrics and operator tooling are shared with the local llama
    # backend; this module supplies only the Requesty upstream and its catalog check.
    services.aiIngress = {
      enable = true;
      allowedModels = builtins.attrNames cfg.models;
      priceMap = lib.mapAttrs (_: model: model.cost) cfg.models;
      extraPreStart = [ validateUpstream ];
      extraAfter = [ "network-online.target" ];
    };

    systemd.services.local-llama-logger.wants = [ "network-online.target" ];
  };
}
