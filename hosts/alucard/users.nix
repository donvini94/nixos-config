{
  pkgs,
  site,
  username,
  ...
}:
let
  vincenzoDracula = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOzARAhbqDrpWUQKC18u5yy4Q+aqumo06DJvimHkDwRB vincenzo@dracula-2026-11";
  vincenzoMac = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEbNjs+cT/dtyAYjYkrMcLeqBdCDbDTSPTafnSO3APKr vincenzopace@AC-0137-2026-11";
  marius = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDg8T7GRlyOP6jme62lF6xTfLEK137MFP766m3C2G+0K3vckxxutE1dW3GPT/kqsDgGHIysRAFWeUm60X2tfdEWVaSNi9g1kb8uss+9EA8zrUuI596/HDeJnsHFo3K/hf7PhjEDhxblo8JzDMz7IF6y58Annh7fTQCdHk564k429YI65mMY16D1GiE0aL0hkiEvAk25gp5mLjEYyAHDHE2ma8csGWJCap5OaAqJ9h0mkf9mcrhczo7MlEF6iL6EWTDToDw0NWPpEVPFRvJUJM+2gNSSxIVIFZkt8eczX/TY0lFkSkSPy5FXqtedHTOazU4mxGU5Lwy3A4gmg3/3ibZ1 Marius";
  kyrill = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGiaATjOxsO6XwxO2NPn5eR1PHP4wRG6O8OFcjs4jJ+f k_blue01@uni-muenster.de";
  jannis = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLqIJOuTjXhRtk1R1GpIiEt/vFprbOxcFdwI/y4eY3+abMxjhh+xN9mzbYZxDll96bPVA7S7+/JZvMoR53q7wdo= bereitbookpro5@secretive.AC-0156.local";

  vincenzoKeys = [
    vincenzoDracula
    vincenzoMac
  ];
in
{
  users.users = {
    ${username} = {
      isNormalUser = true;
      # Pinned, not allocated: /run/user/1000 is referenced at evaluation time
      # by the vulnerability scanner's sandbox.
      uid = 1000;
      shell = pkgs.fish;
      extraGroups = [
        "wheel"
        "docker"
      ];
      openssh.authorizedKeys.keys = vincenzoKeys;
    };
    nix = {
      isNormalUser = true;
      # Existing rootless Docker data and Enshrouded require these exact IDs.
      uid = 1005;
      subUidRanges = [ { startUid = 100000; count = 65536; } ];
      subGidRanges = [ { startGid = 100000; count = 65536; } ];
      linger = true;
      openssh.authorizedKeys.keys = vincenzoKeys;
    };
    marius = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ marius ];
    };
    ${site.partner} = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ kyrill ];
    };
    jannis = {
      isNormalUser = true;
      openssh.authorizedKeys.keys = [ jannis ];
    };
  };
}
