# Settings shared by every customer server: the operator's identity and access.
{
  services.aiStack = {
    host.operatorSshKeys = [ "ssh-ed25519 AAAA... operator" ];
    tailnet.domain = "tailXXXX.ts.net";
    public.acmeEmail = "ops@example.de";
  };
  system.stateVersion = "26.05";
}
