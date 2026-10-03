# Keeps the listed service UIDs on this machine and the public internet: they reach every
# local address and local container, but not other machines' private networks, the
# tailnet, link-local/metadata addresses or SMTP port 25.
{ config, lib, ... }:

let
  cfg = config.services.aiStack.egress;
  chain = "ai-stack-egress";
  blocked = {
    iptables = [
      "10.0.0.0/8"
      "172.16.0.0/12"
      "192.168.0.0/16"
      "100.64.0.0/10"
      "169.254.0.0/16"
    ];
    # fc00::/7 covers the tailnet's fd7a:115c:a1e0::/48.
    ip6tables = [
      "fc00::/7"
      "fe80::/10"
    ];
  };
  rules = tool: ''
    ${tool} -w -N ${chain} 2>/dev/null || ${tool} -w -F ${chain}
    ${tool} -w -A ${chain} -m addrtype --dst-type LOCAL -j RETURN
    ${tool} -w -A ${chain} -o docker0 -j RETURN
    ${tool} -w -A ${chain} -o br-+ -j RETURN
    ${lib.concatMapStrings (net: "${tool} -w -A ${chain} -d ${net} -j REJECT\n") blocked.${tool}}
    ${tool} -w -A ${chain} -p tcp --dport 25 -j REJECT
    ${lib.concatMapStrings (uid: ''
      ${tool} -w -C OUTPUT -m owner --uid-owner ${toString uid} -j ${chain} 2>/dev/null \
        || ${tool} -w -A OUTPUT -m owner --uid-owner ${toString uid} -j ${chain}
    '') cfg.uids}
  '';
  removeRules = tool: ''
    ${lib.concatMapStrings (uid: ''
      ${tool} -w -D OUTPUT -m owner --uid-owner ${toString uid} -j ${chain} 2>/dev/null || true
    '') cfg.uids}
    ${tool} -w -F ${chain} 2>/dev/null || true
    ${tool} -w -X ${chain} 2>/dev/null || true
  '';
in
{
  options.services.aiStack.egress = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Restrict the UIDs in `uids` to local and public destinations.";
    };

    uids = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      default = [ ];
      description = "Service UIDs whose outbound traffic is restricted.";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.uids != [ ]) {
    assertions = [
      {
        assertion = !config.networking.nftables.enable;
        message = "services.aiStack.egress uses iptables rules; port it before enabling nftables";
      }
    ];
    networking.firewall.extraCommands = rules "iptables" + rules "ip6tables";
    networking.firewall.extraStopCommands = removeRules "iptables" + removeRules "ip6tables";
  };
}
