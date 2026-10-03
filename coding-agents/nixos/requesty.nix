# The Requesty credential a host's interactive clients and services use. Each host holds
# its own key so spend and access are attributed and revocable per machine.
{ lib, ... }:
{
  # Deployment preferences only; Requesty supplies the organization-approved model catalog.
  options.services.requesty.endpoint = lib.mkOption {
    type = lib.types.str;
    default = "https://router.requesty.ai/v1";
    description = "OpenAI-compatible Requesty endpoint.";
  };

  options.services.requesty.defaultModel = lib.mkOption {
    type = lib.types.str;
    default = "deepinfra/deepseek-v4.1-flash";
    description = "Model clients use for cheap background roles.";
  };

  options.services.requesty.apiKeyFile = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "File holding this host's Requesty API key, readable by the users of its clients.";
  };
}
