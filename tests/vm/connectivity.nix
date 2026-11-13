{
  inputs,
  pkgs,
  inventory,
}:
let
  httpServer = pkgs.writeText "ember-test-http.py" ''
    from http.server import BaseHTTPRequestHandler, HTTPServer
    class Handler(BaseHTTPRequestHandler):
        def do_HEAD(self):
            self.send_response(204)
            self.end_headers()
        def do_GET(self):
            self.send_response(200)
            self.end_headers()
            self.wfile.write(self.client_address[0].encode())
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
  '';
in
import ./common.nix {
  inherit inputs pkgs inventory;
  name = "ember-vm-connectivity";
  networkMode = "none";
  extraSystemConfig = {
    ember.proxy.healthCheckUrl = "http://192.0.2.2:8080/health";
    environment.systemPackages = [
      pkgs.curl
      pkgs.jq
      pkgs.iproute2
      pkgs.microsocks
      pkgs.python3
      pkgs.dnsutils
    ];
  };
  extraTestScript = ''
    with subtest("network tools and provider-free direct boot"):
        machine.succeed("command -v nmcli; command -v nmtui")
        machine.succeed("systemctl is-active NetworkManager systemd-resolved")
        machine.fail("systemctl is-active ember-proxy.service")
        machine.fail("ip link show ember-tun")
        machine.fail("systemctl is-active NetworkManager-wait-online.service")
        machine.succeed("nmcli connection add type ethernet ifname test-unused con-name ember-persistence autoconnect no ipv4.method manual ipv4.addresses 198.51.100.20/24")

    with subtest("isolated guest uplink and runtime-only provider"):
        machine.succeed("ip netns add uplink; ip link add veth-guest type veth peer name veth-uplink")
        machine.succeed("ip link set veth-uplink netns uplink; ip addr add 192.0.2.1/24 dev veth-guest; ip link set veth-guest up")
        machine.succeed("ip netns exec uplink ip addr add 192.0.2.2/24 dev veth-uplink; ip netns exec uplink ip link set veth-uplink up; ip netns exec uplink ip link set lo up")
        machine.succeed("ip netns exec uplink ip addr add 198.51.100.10/32 dev lo")
        machine.succeed("ip route add default via 192.0.2.2")
        machine.succeed("systemd-run --unit=test-http ip netns exec uplink ${pkgs.python3}/bin/python3 ${httpServer}")
        machine.succeed("systemd-run --unit=test-socks ip netns exec uplink ${pkgs.microsocks}/bin/microsocks -i 192.0.2.2 -p 1080")
        machine.wait_until_succeeds("curl --fail --max-time 5 http://192.0.2.2:8080")
        machine.succeed("printf 'proxies:\\n  - name: guest-socks\\n    type: socks5\\n    server: 192.0.2.2\\n    port: 1080\\n' > /run/test-provider.yaml")
        machine.succeed("ember-proxy import /run/test-provider.yaml")
        machine.wait_for_unit("ember-proxy.service")
        machine.wait_until_succeeds("ip link show ember-tun")
        machine.wait_until_succeeds("test -S /run/ember-proxy/controller.sock")
        machine.succeed("ember-proxy check")
        t.assertEqual(machine.succeed("stat -c '%a' /var/lib/hearth-proxy/sources.yaml").strip(), "600")

    with subtest("real SOCKS outbound and loopback-only mixed listener"):
        machine.wait_until_succeeds("test \"$(curl -fsS --max-time 10 --proxy http://127.0.0.1:7890 http://192.0.2.2:8080)\" = 192.0.2.2")
        machine.succeed("ss -lnt | grep '127.0.0.1:7890'")
        machine.fail("ss -lnt | grep -E '(0.0.0.0|\\*|\\[::\\]):7890'")

    with subtest("transparent TUN traffic reaches the SOCKS outbound without application proxy settings"):
        machine.wait_until_succeeds("test \"$(curl -fsS --max-time 10 http://198.51.100.10:8080)\" = 198.51.100.10")

    with subtest("DNS listener and TUN DNS interception return a fake IP without an upstream DNS server"):
        machine.succeed("dig +short +time=3 +tries=1 @127.0.0.1 -p 1053 www.example.org A | grep -E '^198\\.18\\.'")
        machine.succeed("dig +short +time=3 +tries=1 @198.51.100.10 www.example.org A | grep -E '^198\\.18\\.'")

    with subtest("unreachable nodes fall back to direct and recover after the next health probe"):
        machine.succeed("systemctl stop test-socks.service")
        machine.wait_until_succeeds("test \"$(curl -fsS --max-time 5 --proxy http://127.0.0.1:7890 http://192.0.2.2:8080)\" = 192.0.2.1", timeout=150)
        machine.succeed("systemd-run --unit=test-socks ip netns exec uplink ${pkgs.microsocks}/bin/microsocks -i 192.0.2.2 -p 1080")
        machine.wait_until_succeeds("test \"$(curl -fsS --max-time 5 --proxy http://127.0.0.1:7890 http://192.0.2.2:8080)\" = 192.0.2.2", timeout=150)

    with subtest("invalid import retains the working provider"):
        before = machine.succeed("sha256sum /var/lib/hearth-proxy/sources.yaml").split()[0]
        machine.succeed("printf 'proxies: []\\n' > /run/invalid-provider.yaml")
        machine.fail("ember-proxy import /run/invalid-provider.yaml")
        t.assertEqual(machine.succeed("sha256sum /var/lib/hearth-proxy/sources.yaml").split()[0], before)
        machine.succeed("systemctl is-active ember-proxy.service")

    with subtest("stopping the proxy removes TUN and restores direct connectivity"):
        machine.succeed("ember-proxy off")
        machine.wait_until_fails("ip link show ember-tun")
        machine.wait_until_succeeds("test \"$(curl -fsS --max-time 5 http://192.0.2.2:8080)\" = 192.0.2.1")
        machine.succeed("test -f /var/lib/hearth-proxy/disabled")
        machine.reboot()
        machine.wait_for_unit("multi-user.target")
        machine.succeed("test -s /var/lib/hearth-proxy/sources.yaml; test -f /var/lib/hearth-proxy/disabled")
        machine.fail("systemctl is-active ember-proxy.service")
        machine.succeed("nmcli connection show ember-persistence")

    machine.shutdown()
  '';
}
