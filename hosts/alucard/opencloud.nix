# OpenCloud at cloud.istbereit.de, signing in through Keycloak; the nginx vhost lives in
# services/reverse-proxy.nix. Keycloak's `Abschleppdienst` realm holds the public PKCE
# clients `web`, `OpenCloudDesktop`, `OpenCloudAndroid` and `OpenCloudIOS`, and an
# `opencloud-roles` client scope that puts realm roles into a top-level `roles` claim.
# Users are provisioned on first login into OpenCloud's built-in LDAP; only those with
# an opencloudAdmin/SpaceAdmin/User/Guest realm role get in.
{
  config,
  pkgs,
  site,
  ...
}:
let
  cfg = config.services.opencloud;
  idp = "https://auth.${site.domains.primary}";
  realm = "${idp}/realms/Abschleppdienst";
  # Merged into OpenCloud's default policy; the web client talks to Keycloak directly.
  csp = pkgs.writeText "opencloud-csp.yaml" (
    builtins.toJSON {
      directives = {
        connect-src = [ "${idp}/" ];
        frame-src = [ "${idp}/" ];
        script-src = [ "${idp}/" ];
      };
    }
  );
  snapshot = "/var/lib/offsite-backup/opencloud-snapshot";
in
{
  services.opencloud = {
    enable = true;
    # Rolling release; OpenCloud cannot downgrade, so never switch this to opencloud-production.
    package = pkgs.opencloud;
    url = "https://cloud.${site.domains.secondary}";
    environment = {
      # nginx terminates TLS; certificates of everything OpenCloud connects to are verified.
      PROXY_TLS = "false";
      OC_INSECURE = "false";
      OC_OIDC_ISSUER = realm;
      OC_EXCLUDE_RUN_SERVICES = "idp";
      PROXY_OIDC_REWRITE_WELLKNOWN = "true";
      PROXY_CSP_CONFIG_FILE_LOCATION = "${csp}";
      PROXY_AUTOPROVISION_ACCOUNTS = "true";
      # Keycloak's `sub` is stable across username changes.
      PROXY_USER_OIDC_CLAIM = "sub";
      PROXY_AUTOPROVISION_CLAIM_USERNAME = "sub";
      PROXY_USER_CS3_CLAIM = "username";
      GRAPH_USERNAME_MATCH = "none";
      PROXY_ROLE_ASSIGNMENT_DRIVER = "oidc";
      GRAPH_ASSIGN_DEFAULT_USER_ROLE = "false";
      SETTINGS_SETUP_DEFAULT_ASSIGNMENTS = "false";
      # No local admin: administrators are Keycloak users with the opencloudAdmin role.
      OC_ADMIN_USER_ID = "";
      WEB_OPTION_ACCOUNT_EDIT_LINK_HREF = "${realm}/account";
    };
  };

  # OpenCloud must be stopped for a consistent copy. A read-only snapshot of the root
  # subvolume keeps that to seconds; restores come from <snapshot>/var/lib/opencloud
  # and <snapshot>/etc/opencloud (the generated service secrets).
  services.aiStack.backup.jobs.opencloud = {
    runtimeInputs = [
      pkgs.btrfs-progs
      config.systemd.package
    ];
    prepare = ''
      if [ -e ${snapshot} ]; then btrfs subvolume delete ${snapshot}; fi
      systemctl stop opencloud.service
      trap 'systemctl start opencloud.service' EXIT
      btrfs subvolume snapshot -r / ${snapshot}
    '';
    paths = [
      "${snapshot}${cfg.stateDir}"
      "${snapshot}/etc/opencloud"
    ];
  };
  services.restic.backups.opencloud.backupCleanupCommand = ''
    if [ -e ${snapshot} ]; then ${pkgs.btrfs-progs}/bin/btrfs subvolume delete ${snapshot}; fi
  '';
}
