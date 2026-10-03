# A restricted UID reaches local services and the public internet, but not another
# machine's private or tailnet address, nor SMTP; root is unaffected.
{ pkgs, ... }:
{
  name = "ai-stack-egress";

  nodes = {
    host = {
      imports = [ ../nixos/egress.nix ];
      users.users.agent = {
        isSystemUser = true;
        uid = 985;
        group = "agent";
      };
      users.groups.agent = { };
      services.aiStack.egress.uids = [ 985 ];
      networking.interfaces.eth1.ipv4.addresses = [
        {
          address = "100.64.0.1";
          prefixLength = 10;
        }
        {
          address = "203.0.113.1";
          prefixLength = 24;
        }
      ];
      networking.firewall.allowedTCPPorts = [ 8001 ];
      environment.systemPackages = [ pkgs.curl ];
    };

    peer = {
      networking.interfaces.eth1.ipv4.addresses = [
        {
          address = "100.64.0.2";
          prefixLength = 10;
        }
        {
          address = "203.0.113.2";
          prefixLength = 24;
        }
      ];
      networking.firewall.enable = false;
    };
  };

  testScript = ''
    start_all()
    peer.wait_for_unit("multi-user.target")
    peer.succeed("${pkgs.python3}/bin/python3 -m http.server 80 >/dev/null 2>&1 &")
    peer.succeed("${pkgs.python3}/bin/python3 -m http.server 25 >/dev/null 2>&1 &")
    peer.wait_for_open_port(80)
    peer.wait_for_open_port(25)

    host.wait_for_unit("firewall.service")
    host.succeed("${pkgs.python3}/bin/python3 -m http.server --bind 127.0.0.1 8000 >/dev/null 2>&1 &")
    host.succeed("${pkgs.python3}/bin/python3 -m http.server 8001 >/dev/null 2>&1 &")
    host.wait_for_open_port(8000)
    host.wait_for_open_port(8001)

    def agent(url):
        return f"runuser -u agent -- curl -sf --max-time 5 -o /dev/null {url}"

    with subtest("local destinations stay reachable"):
        host.succeed(agent("http://127.0.0.1:8000"))
        host.succeed(agent("http://192.168.1.1:8001"))

    with subtest("public destinations stay reachable, except SMTP"):
        host.succeed(agent("http://203.0.113.2"))
        host.fail(agent("http://203.0.113.2:25"))

    with subtest("other machines' private and tailnet addresses are blocked"):
        host.fail(agent("http://192.168.1.2"))
        host.fail(agent("http://100.64.0.2"))

    with subtest("other users are unaffected"):
        host.succeed("curl -sf --max-time 5 -o /dev/null http://100.64.0.2")
        host.succeed("curl -sf --max-time 5 -o /dev/null http://203.0.113.2:25")

    with subtest("rules survive a firewall reload without duplicating"):
        host.succeed("systemctl reload firewall")
        host.succeed("test $(iptables -S OUTPUT | grep -c ai-stack-egress) -eq 1")
        host.fail(agent("http://100.64.0.2"))
  '';
}
