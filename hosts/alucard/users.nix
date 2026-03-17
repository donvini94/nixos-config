{ ... }:
{
  users.users = {
    vincenzo = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "docker"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDj2dxqVTVKEzFUBw4Ol8G2XBwTHEwxFquzYNIelKBOzDQLE2WNvjfBko1iQkUNHrVfr3GiAuxdsE+O3hltDvo4UsQqsEqCSu/HEWRfyXDJrcLSm7ogkOAGBZtrmIr73YfGhpzRqcfnoAqSJOkX6PFmaFJ+YgoOuJLH6KbQo3xv0r5RqFkZhfnOiD5gwMtEExP4uawycb9mrsqxOWoMANR870qYq6JERxcGZU4m0UcvnpB01EbvTuWMIACL11cCylkcCPoDnv9KD94k0nhqGOE5/UB6mxRPBBJdQk3Dd3KXe2u2s++Enpu2WKdqOFywxxvXZ2PHBh4Oy8eJpytzMWxSUcLNcNk54JgAgaUCYYN0s3CmKh2r+z6pGSo5xUuJxyl13TfsSzCTsx3dkUOAaRpQAIHDseIDKX983zDS831GZA1d4xiOOtC7ct8F8z3qMokHU+N8OB0ys2T7cS29Q9BKSgaPSBlM0YTWQwD0R2Tf+D74VQnSYPgNNGFByZwV8bc= vincenzo@nixos"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCPlhh/4miDPy8MD7ckimo0ZlEyRIIQymAeNrpvbURg+H0G+kztFgr2x0muzAVwy5noz7511zQBkG9q+lJfWHzjGvVibew5HhcdlECkzpStrkRkupM0l7Ql1ILlQb/lME1v4TM+JM1nCbOgIqkjKJ/dzE3WqHz8CfJ6ilf5QedKHnAFbMu6miOGHMJxDje+0t/51QPul513d2oyIjtUBjtW0Yo77PgSuopFbhEI//cn0P7QVJArbmv7YZqGNifVzMyzQBlvXQtJC0CR/bGTJwspCCU2xIangzHrkKxRqkZJrk1zC5JyMbW1oRUZ3ah7MbUq/ivAUfjvzvkrZS5DbigMmSIbGmoK9d/k6pQjj4gyL1Q5KZRq4g2JKkV6Uhaqr2yfG2F0T6FGKnhGO6P5PK2bkAobfCfLL5IGkceK/WB0InMKfdbii971CeUY0qk+1ad7Fn9txuR5omttkEtM9Hh9Afz1kGxa4ia9+d71OV4KoXVykqr/bD284rhOooX4/mU= vincenzo@dracula"
      ];
    };
    nix = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "docker"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDj2dxqVTVKEzFUBw4Ol8G2XBwTHEwxFquzYNIelKBOzDQLE2WNvjfBko1iQkUNHrVfr3GiAuxdsE+O3hltDvo4UsQqsEqCSu/HEWRfyXDJrcLSm7ogkOAGBZtrmIr73YfGhpzRqcfnoAqSJOkX6PFmaFJ+YgoOuJLH6KbQo3xv0r5RqFkZhfnOiD5gwMtEExP4uawycb9mrsqxOWoMANR870qYq6JERxcGZU4m0UcvnpB01EbvTuWMIACL11cCylkcCPoDnv9KD94k0nhqGOE5/UB6mxRPBBJdQk3Dd3KXe2u2s++Enpu2WKdqOFywxxvXZ2PHBh4Oy8eJpytzMWxSUcLNcNk54JgAgaUCYYN0s3CmKh2r+z6pGSo5xUuJxyl13TfsSzCTsx3dkUOAaRpQAIHDseIDKX983zDS831GZA1d4xiOOtC7ct8F8z3qMokHU+N8OB0ys2T7cS29Q9BKSgaPSBlM0YTWQwD0R2Tf+D74VQnSYPgNNGFByZwV8bc= vincenzo@nixos"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCPlhh/4miDPy8MD7ckimo0ZlEyRIIQymAeNrpvbURg+H0G+kztFgr2x0muzAVwy5noz7511zQBkG9q+lJfWHzjGvVibew5HhcdlECkzpStrkRkupM0l7Ql1ILlQb/lME1v4TM+JM1nCbOgIqkjKJ/dzE3WqHz8CfJ6ilf5QedKHnAFbMu6miOGHMJxDje+0t/51QPul513d2oyIjtUBjtW0Yo77PgSuopFbhEI//cn0P7QVJArbmv7YZqGNifVzMyzQBlvXQtJC0CR/bGTJwspCCU2xIangzHrkKxRqkZJrk1zC5JyMbW1oRUZ3ah7MbUq/ivAUfjvzvkrZS5DbigMmSIbGmoK9d/k6pQjj4gyL1Q5KZRq4g2JKkV6Uhaqr2yfG2F0T6FGKnhGO6P5PK2bkAobfCfLL5IGkceK/WB0InMKfdbii971CeUY0qk+1ad7Fn9txuR5omttkEtM9Hh9Afz1kGxa4ia9+d71OV4KoXVykqr/bD284rhOooX4/mU= vincenzo@dracula"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDg8T7GRlyOP6jme62lF6xTfLEK137MFP766m3C2G+0K3vckxxutE1dW3GPT/kqsDgGHIysRAFWeUm60X2tfdEWVaSNi9g1kb8uss+9EA8zrUuI596/HDeJnsHFo3K/hf7PhjEDhxblo8JzDMz7IF6y58Annh7fTQCdHk564k429YI65mMY16D1GiE0aL0hkiEvAk25gp5mLjEYyAHDHE2ma8csGWJCap5OaAqJ9h0mkf9mcrhczo7MlEF6iL6EWTDToDw0NWPpEVPFRvJUJM+2gNSSxIVIFZkt8eczX/TY0lFkSkSPy5FXqtedHTOazU4mxGU5Lwy3A4gmg3/3ibZ1 Marius"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJtziDwyaqKfBPL1dDEM6kMdA+KTL+d0810PzAbOsWHn kyrill@kyrill-ThinkPad-T495"
      ];
    };
    marius = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDg8T7GRlyOP6jme62lF6xTfLEK137MFP766m3C2G+0K3vckxxutE1dW3GPT/kqsDgGHIysRAFWeUm60X2tfdEWVaSNi9g1kb8uss+9EA8zrUuI596/HDeJnsHFo3K/hf7PhjEDhxblo8JzDMz7IF6y58Annh7fTQCdHk564k429YI65mMY16D1GiE0aL0hkiEvAk25gp5mLjEYyAHDHE2ma8csGWJCap5OaAqJ9h0mkf9mcrhczo7MlEF6iL6EWTDToDw0NWPpEVPFRvJUJM+2gNSSxIVIFZkt8eczX/TY0lFkSkSPy5FXqtedHTOazU4mxGU5Lwy3A4gmg3/3ibZ1 Marius"
      ];
    };
    kyrill = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJtziDwyaqKfBPL1dDEM6kMdA+KTL+d0810PzAbOsWHn kyrill@kyrill-ThinkPad-T495"
      ];
    };
    jellyfin = {
      extraGroups = [
        "wheel"
        "docker"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDj2dxqVTVKEzFUBw4Ol8G2XBwTHEwxFquzYNIelKBOzDQLE2WNvjfBko1iQkUNHrVfr3GiAuxdsE+O3hltDvo4UsQqsEqCSu/HEWRfyXDJrcLSm7ogkOAGBZtrmIr73YfGhpzRqcfnoAqSJOkX6PFmaFJ+YgoOuJLH6KbQo3xv0r5RqFkZhfnOiD5gwMtEExP4uawycb9mrsqxOWoMANR870qYq6JERxcGZU4m0UcvnpB01EbvTuWMIACL11cCylkcCPoDnv9KD94k0nhqGOE5/UB6mxRPBBJdQk3Dd3KXe2u2s++Enpu2WKdqOFywxxvXZ2PHBh4Oy8eJpytzMWxSUcLNcNk54JgAgaUCYYN0s3CmKh2r+z6pGSo5xUuJxyl13TfsSzCTsx3dkUOAaRpQAIHDseIDKX983zDS831GZA1d4xiOOtC7ct8F8z3qMokHU+N8OB0ys2T7cS29Q9BKSgaPSBlM0YTWQwD0R2Tf+D74VQnSYPgNNGFByZwV8bc= vincenzo@nixos"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCPlhh/4miDPy8MD7ckimo0ZlEyRIIQymAeNrpvbURg+H0G+kztFgr2x0muzAVwy5noz7511zQBkG9q+lJfWHzjGvVibew5HhcdlECkzpStrkRkupM0l7Ql1ILlQb/lME1v4TM+JM1nCbOgIqkjKJ/dzE3WqHz8CfJ6ilf5QedKHnAFbMu6miOGHMJxDje+0t/51QPul513d2oyIjtUBjtW0Yo77PgSuopFbhEI//cn0P7QVJArbmv7YZqGNifVzMyzQBlvXQtJC0CR/bGTJwspCCU2xIangzHrkKxRqkZJrk1zC5JyMbW1oRUZ3ah7MbUq/ivAUfjvzvkrZS5DbigMmSIbGmoK9d/k6pQjj4gyL1Q5KZRq4g2JKkV6Uhaqr2yfG2F0T6FGKnhGO6P5PK2bkAobfCfLL5IGkceK/WB0InMKfdbii971CeUY0qk+1ad7Fn9txuR5omttkEtM9Hh9Afz1kGxa4ia9+d71OV4KoXVykqr/bD284rhOooX4/mU= vincenzo@dracula"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJtziDwyaqKfBPL1dDEM6kMdA+KTL+d0810PzAbOsWHn kyrill@kyrill-ThinkPad-T495"
      ];
    };
  };
}
