{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.localOpenBao;
  bao = lib.getExe config.services.openbao.package;
in
{
  options.services.localOpenBao = {
    enable = lib.mkEnableOption "single-node OpenBao with integrated Raft storage";

    address = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:8200";
      description = ''
        API listener. Loopback only: reachability is granted by the tailnet
        serve rules, never by a public listener or a firewall hole.
      '';
    };

    clusterAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:8201";
      description = "Raft cluster listener. Unused by a single node, still required.";
    };

    nodeId = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      defaultText = lib.literalExpression "config.networking.hostName";
      description = "Raft node identity.";
    };

    snapshotBackup = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Take a nightly `bao operator raft snapshot` and hand it to
          services.offsiteBackup.

          Off until the operator has run `bao operator init` and stored a
          snapshot token under `tokenSecret`: a snapshot is an authenticated
          API call, so this cannot be provisioned before the cluster exists.
          Enabling it without the secret makes the backup unit fail loudly,
          which is the intended behaviour — a silent skip would look like a
          working backup.
        '';
      };

      tokenSecret = lib.mkOption {
        type = lib.types.str;
        default = "openbao/snapshot_token";
        description = ''
          sops key holding a token whose policy allows
          `/sys/storage/raft/snapshot` and nothing else.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.openbao = {
      enable = true;
      settings = {
        ui = true;

        # The hardened upstream unit clears every capability, so the process
        # cannot mlock its memory. Refusing to start would be the alternative.
        disable_mlock = true;

        listener.tcp = {
          type = "tcp";
          address = cfg.address;
          # nginx and Tailscale terminate TLS; nothing reaches this socket from
          # off-host without passing one of them first.
          tls_disable = true;
        };

        storage.raft = {
          path = "/var/lib/openbao";
          node_id = cfg.nodeId;
        };

        api_addr = "http://${cfg.address}";
        cluster_addr = "http://${cfg.clusterAddress}";
      };
    };

    # Sealed is the correct state after a reboot. With a Shamir seal and no
    # cloud KMS to auto-unseal against, the unseal shares live off the machine
    # and an operator supplies them; a key stored beside the ciphertext it
    # protects would make the seal decorative.
    systemd.services.openbao.unitConfig.Description =
      lib.mkForce "OpenBao (Shamir-sealed; unseal after boot)";

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "bao-status" ''
        export BAO_ADDR="http://${cfg.address}"
        exec ${bao} status "$@"
      '')
    ];

    services.offsiteBackup = lib.mkIf cfg.snapshotBackup.enable {
      enable = true;
      jobs.openbao = {
        after = [ "openbao.service" ];
        requires = [ "openbao.service" ];
        prepare = ''
          install -d -m 0700 "$stage"
          BAO_ADDR="http://${cfg.address}"
          export BAO_ADDR
          BAO_TOKEN="$(cat "$CREDENTIALS_DIRECTORY/bao-token")"
          export BAO_TOKEN
          ${bao} operator raft snapshot save "$stage/raft.snap"
          test -s "$stage/raft.snap"
        '';
        verifyPaths = [ "/var/lib/offsite-backup/openbao/raft.snap" ];
      };
    };

    # The snapshot token is a second credential on the backup unit, alongside
    # the restic password the generic module already loads.
    sops.secrets = lib.mkIf cfg.snapshotBackup.enable {
      ${cfg.snapshotBackup.tokenSecret} = {
        owner = "root";
        mode = "0400";
      };
    };

    systemd.services.offsite-backup-openbao = lib.mkIf cfg.snapshotBackup.enable {
      serviceConfig.LoadCredential = [
        "bao-token:${config.sops.secrets.${cfg.snapshotBackup.tokenSecret}.path}"
      ];
    };
  };
}
