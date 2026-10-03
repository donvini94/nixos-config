# Alucard's additions to the ai-stack edge: Jellyfin detection and its whitelist.
{ ... }:
{
  services.crowdsec = {
    hub.collections = [ "LePresidente/jellyfin" ];
    localConfig = {
      acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=jellyfin.service" ];
          labels.type = "jellyfin";
        }
      ];
      parsers.s02Enrich = [
        # Stale client sessions POST to /Sessions/ and get 403, which reads as
        # credential stuffing to LePresidente/http-generic-403-bf. Scoped to that path
        # so 403s elsewhere still count.
        {
          name = "alucard/jellyfin-session-403-whitelist";
          description = "Stale Jellyfin client sessions are not a 403 brute force";
          whitelist = {
            reason = "Jellyfin client session reporting returns 403 when the session expired";
            expression = [
              "evt.Meta.http_verb == 'POST' && evt.Meta.http_status == '403' && evt.Parsed.request startsWith '/Sessions/'"
            ];
          };
        }
      ];
    };
  };

  services.observability.server.localTargets.crowdsec = 6060;
}
