# The Requesty credential a host's interactive clients and services use. Each host holds
# its own key so spend and access are attributed and revocable per machine.
{ lib, ... }:
{
  options.services.requesty.apiKeyFile = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "File holding this host's Requesty API key, readable by the users of its clients.";
  };
}
