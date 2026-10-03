# Alucard's additions to the ai-stack edge: Jellyfin detection and the whitelists its
# applications need.
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
        # Next.js router prefetch (?_rsc=) trips crowdsecurity/http-crawl-non_statics.
        # Statuses are constrained so a scanner cannot append ?_rsc= to hide 404/403
        # probing. Both field names are matched because the parser file name carries a
        # store hash, so this node may run before http-logs (query in .request) or
        # after it (.http_args).
        {
          name = "alucard/nextjs-rsc-prefetch-whitelist";
          description = "Next.js router prefetch is not an aggressive crawl";
          whitelist = {
            reason = "Next.js RSC prefetch (?_rsc=) from the Onyx admin UI";
            expression = [
              "(evt.Parsed.request contains '_rsc=' || evt.Parsed.http_args contains '_rsc=') && evt.Meta.http_status in ['200', '204', '304']"
            ];
          };
        }
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
