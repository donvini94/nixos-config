# One-time PostgreSQL 14 -> 17 upgrade. The upgrade runs before postgresql.service while
# the new data directory does not exist; statistics are rebuilt once the new server runs.
# Remove this file, and /var/lib/postgresql/14, once the upgraded cluster is accepted.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  oldPackage = pkgs.postgresql_14;
  newPackage = pkgs.postgresql_17;
  oldData = "/var/lib/postgresql/${oldPackage.psqlSchema}";
  newData = config.services.postgresql.dataDir;
  upgrade = pkgs.writeShellApplication {
    name = "postgresql-major-upgrade";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = builtins.readFile ./postgresql-upgrade.sh;
  };
in
{
  services.postgresql.package = newPackage;

  systemd.services.postgresql-major-upgrade = {
    description = "Upgrade the PostgreSQL cluster to ${newPackage.psqlSchema}";
    before = [ "postgresql.service" ];
    requiredBy = [ "postgresql.service" ];
    unitConfig.ConditionPathExists = [
      "${oldData}/PG_VERSION"
      "!${newData}/PG_VERSION"
    ];
    environment = {
      OLD_BIN = "${oldPackage}/bin";
      NEW_BIN = "${config.services.postgresql.finalPackage}/bin";
      OLD_DATA = oldData;
      NEW_DATA = newData;
      DUMP_DIR = "/var/backup/postgresql-upgrade";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = lib.getExe upgrade;
      TimeoutStartSec = "1h";
    };
  };

  systemd.services.postgresql-upgrade-analyze = {
    description = "Rebuild planner statistics after the PostgreSQL upgrade";
    after = [ "postgresql-setup.service" ];
    requires = [ "postgresql-setup.service" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "${newData}/.analyze-pending";
    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
    };
    script = ''
      ${config.services.postgresql.finalPackage}/bin/vacuumdb --all --analyze-in-stages
      rm "${newData}/.analyze-pending"
    '';
  };
}
