{ config, lib, ... }:
let
  cfg = config.services.remoteOpenAI;
in
{
  options.services.remoteOpenAI = {
    enable = lib.mkEnableOption "authenticated remote OpenAI-compatible ingress";
    defaultModel = lib.mkOption {
      type = lib.types.str;
      description = "Initial model preference; catalog metadata is discovered at runtime.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.aiIngress.upstreamBearerCredentialFile != null;
        message = "The remote AI ingress requires an upstream credential";
      }
    ];
    services.aiIngress = {
      enable = true;
      discoverModels = true;
      extraAfter = [ "network-online.target" ];
    };
    systemd.services.local-llama-logger.wants = [ "network-online.target" ];
  };
}
