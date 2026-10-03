# The public hostname exposes only n8n's production webhook, form and chat paths, serves
# the chat's CDN assets locally and limits form traffic. A stub stands in for n8n.
{ lib, pkgs, ... }:
let
  stub = pkgs.writeText "n8n-stub.py" ''
    from http.server import BaseHTTPRequestHandler, HTTPServer

    class Handler(BaseHTTPRequestHandler):
        def respond(self):
            if self.path.endswith("/chat"):
                body = b'<link href="https://cdn.jsdelivr.net/npm/@n8n/chat/dist/style.css">'
                kind = "text/html"
            else:
                body = ("upstream " + self.path).encode()
                kind = "text/plain"
            self.send_response(200)
            self.send_header("Content-Type", kind)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        do_GET = do_POST = respond

    HTTPServer(("127.0.0.1", 5678), Handler).serve_forever()
  '';
in
{
  name = "ai-stack-public";

  nodes = {
    server = {
      imports = [
        ../nixos/n8n.nix
        ../nixos/public.nix
      ];
      services.aiStack.public = {
        domain = "agent.test";
        acmeEmail = "ops@example.test";
      };
      # No ACME server in the test network; TLS is not what this test covers.
      security.acme.certs = lib.mkForce { };
      services.nginx.virtualHosts."agent.test" = {
        enableACME = lib.mkForce false;
        forceSSL = lib.mkForce false;
      };
      systemd.services.n8n-stub = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 ${stub}";
      };
    };
    client.environment.systemPackages = [ pkgs.curl ];
  };

  testScript = ''
    start_all()
    server.wait_for_unit("nginx.service")
    server.wait_for_open_port(5678)
    server.wait_for_open_port(80)

    def status(path, method="GET"):
        return client.succeed(
            f"curl -s -o /dev/null -w '%{{http_code}}' -X {method} -H 'Host: agent.test' http://server{path}"
        ).strip()

    with subtest("production webhook, form and asset paths reach n8n"):
        for path in ["/webhook/abc", "/webhook-waiting/1", "/form/x", "/form-waiting/1", "/static/n8n-logo.png"]:
            assert status(path) == "200", path
        assert "upstream /webhook/abc" in client.succeed("curl -s -H 'Host: agent.test' http://server/webhook/abc")

    with subtest("everything else is not found"):
        for path in ["/", "/signin", "/rest/login", "/webhook-test/abc", "/form-test/x",
                     "/metrics", "/healthz", "/assets/index.js", "/api/v1/workflows", "/mcp-server/http"]:
            assert status(path) == "404", path
        assert status("/static/x", "POST") == "403"

    with subtest("chat pages load their assets from this host"):
        page = client.succeed("curl -s -H 'Host: agent.test' http://server/webhook/id/chat")
        assert "cdn.jsdelivr.net" not in page, page
        assert "/_cdn/@n8n/chat/dist/style.css" in page, page
        for asset in ["/_cdn/@n8n/chat/dist/style.css", "/_cdn/@n8n/chat/dist/chat.bundle.es.js",
                      "/_cdn/normalize.css@8.0.1/normalize.min.css"]:
            assert status(asset) == "200", asset

    with subtest("browsers are told not to load third-party content"):
        headers = client.succeed("curl -sI -H 'Host: agent.test' http://server/webhook/abc")
        assert "font-src 'self'" in headers, headers
        assert "Strict-Transport-Security" in headers, headers

    with subtest("forms are rate limited per client"):
        codes = client.succeed(
            "for i in $(seq 60); do curl -s -o /dev/null -w '%{http_code}\\n' -H 'Host: agent.test' http://server/form/x; done"
        ).split()
        assert "429" in codes, codes
  '';
}
