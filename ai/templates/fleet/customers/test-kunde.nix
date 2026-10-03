# A disposable customer for testing provisioning, egress and restores.
{
  services.aiStack = {
    tier = "basic";
    secretsFile = ../secrets/test-kunde.yaml;
    public.domain = "agent.test-kunde.example.de";
    backup.repository = "sftp:u000000-sub1@u000000.your-storagebox.de:restic";
    host.ipv6Address = "2a01:4f8:c0c:0000::1/64";
  };
}
