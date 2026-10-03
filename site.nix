# Deployment-specific identity: people, domains and the private network. Everything else
# in the repository takes these through the `site` module argument, so a second
# deployment starts here.
{
  owner = {
    username = "vincenzo";
    macUsername = "vincenzopace";
    fullName = "Vincenzo Pace";
    mail = "vincenzo.pace94@icloud.com";
  };

  # Second admin account on the server; Linux-only, no managed client configuration.
  partner = "kyrill";

  # Public domains served by the server's reverse proxy.
  domains = {
    primary = "dumusstbereitsein.de";
    secondary = "istbereit.de";
  };

  # Hostname of the always-on server and the tailnet its services are published on.
  server = "alucard";
  tailnet = "tailf117a1.ts.net";
}
