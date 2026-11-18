"""Check Ember's physical uplink and verify an HTTPS request through Mihomo."""
import http.client
import json
import os
from pathlib import Path
import socket
import ssl
import subprocess
import time
from urllib.parse import quote, urlencode, urlsplit


CONTROLLER = "/run/ember-proxy/controller.sock"
DISABLED = Path("/var/lib/hearth-proxy/disabled")
UNIT = "ember-proxy.service"


class UnixHTTP(http.client.HTTPConnection):
    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(self.timeout)
        self.sock.connect(CONTROLLER)


def controller(path, method="GET", body=None, timeout=3):
    conn = UnixHTTP("localhost", timeout=timeout)
    try:
        payload = json.dumps(body) if body is not None else None
        conn.request(method, path, payload, {"Content-Type": "application/json"})
        with conn.getresponse() as response:
            if "/delay?" in path and response.status in {503, 504}:
                return {}
            if response.status == 204:
                return {}
            if response.status != 200:
                raise ValueError("controller request failed")
            return json.load(response)
    finally:
        conn.close()


def command(args, timeout=10):
    return subprocess.run(args, capture_output=True, text=True, timeout=timeout,
                          env=dict(os.environ, LC_ALL="C"))


def uplink(nmcli, check, repair):
    status = command([nmcli, "-t", "-f", "TYPE,STATE", "device", "status"])
    if status.returncode:
        return False, "Could not read the NetworkManager device status.", []
    devices = status.stdout.splitlines()
    connected = {line.split(":")[0] for line in devices if line.endswith(":connected")}
    details = ["Wi-Fi is connected." if "wifi" in connected else "Wi-Fi is disconnected."]
    if "ethernet" in connected:
        details.append("Ethernet is connected.")
    if not connected & {"wifi", "ethernet"}:
        return False, "No Wi-Fi or Ethernet connection is available.", details
    if command([check], timeout=30).returncode == 0:
        return True, "", details + ["Direct Internet probe passed."]
    args = [nmcli, "--wait", "5", "networking", "connectivity"]
    state = command(args + (["check"] if repair else [])).stdout.strip()
    if state == "portal":
        return False, "The network requires captive portal sign-in.", details + ["Sign in through the captive portal and run maintenance again."]
    return False, "Direct Internet probe failed.", details


def speed_test(url):
    query = urlencode({"url": url, "timeout": 4000, "expected": 204})
    delays = controller(f"/group/HK-AUTO/delay?{query}", timeout=6)
    # Refresh health of the actual group member that AUTO consults.
    hk_healthy = controller(f"/proxies/HK-AUTO/delay?{query}", timeout=6)
    if not hk_healthy:
        controller(f"/group/NODES/delay?{query}", timeout=6)
        controller(f"/proxies/NODES/delay?{query}", timeout=6)
        controller(f"/proxies/DIRECT/delay?{query}", timeout=6)
    return delays


def verify_egress(url):
    target = urlsplit(url)
    if target.scheme != "https" or not target.hostname:
        raise ValueError("expected HTTPS health URL")
    context = ssl.create_default_context(cafile="/etc/ssl/certs/ca-bundle.crt")
    probe = http.client.HTTPSConnection("127.0.0.1", 7890, timeout=6, context=context)
    probe.set_tunnel(target.hostname, target.port or 443)
    try:
        probe.connect()
        port = str(probe.sock.getsockname()[1])
        snapshot = controller("/connections")
        chain = next(
            (item["chains"] for item in snapshot.get("connections") or []
             if str(item["metadata"]["sourcePort"]) == port and
             item["metadata"]["sourceIP"] == "127.0.0.1"),
            [],
        )
        probe.request("GET", (target.path or "/") + (f"?{target.query}" if target.query else ""),
                      headers={"Host": target.netloc, "Connection": "close"})
        with probe.getresponse() as response:
            if response.status != 204:
                return False, []
        return True, chain
    finally:
        probe.close()


def maintain(nmcli, systemctl, check, url, enabled, action):
    repair = action != "inspect"
    ok, summary, details = uplink(nmcli, check, repair)
    if not ok:
        return False, summary, details, False
    if not enabled:
        return False, "The Ember proxy is disabled in the system configuration.", details, False
    if DISABLED.exists() and action != "restore":
        return False, "The proxy was manually disabled.", details, repair
    active = command([systemctl, "is-active", "--quiet", UNIT]).returncode == 0
    if repair and (DISABLED.exists() or not active):
        if action == "restore":
            DISABLED.unlink(missing_ok=True)
        if command([systemctl, "start", "--no-block", UNIT]).returncode:
            return False, "Could not start the proxy service.", details, False
        for _ in range(30):
            if Path(CONTROLLER).exists():
                break
            time.sleep(0.5)
    if not Path(CONTROLLER).exists():
        return False, "The proxy controller is unavailable. Check the service and node configuration.", details, False
    details.append("The proxy controller is ready.")
    if action == "restore":
        controller("/proxies/SELECT", "PUT", {"name": "AUTO"})
    selection = controller("/proxies/SELECT")["now"]
    auto = selection == "AUTO"
    if not auto:
        details.append("The manual node selection is still in effect.")
    delays = speed_test(url) if repair and auto else {}
    reachable, chain = verify_egress(url)
    if not reachable:
        return False, "The HTTPS probe through the local proxy port failed.", details, repair and not auto
    if not chain:
        return False, "The HTTPS probe passed, but its route could not be verified.", details, repair and not auto
    # Mihomo records the leaf node first, followed by the groups it traversed.
    node = chain[0]
    if node in {"DIRECT", "COMPATIBLE"}:
        return False, "The probe used a direct connection.", details, repair and not auto
    if node.startswith("REJECT"):
        return False, "The probe found no usable proxy exit.", details, repair and not auto

    label = "".join(char for char in node if char.isprintable())[:120]
    details.append(f"Proxy exit: {label}" + (f" ({delays[node]} ms)" if node in delays else ""))
    if auto and "HK-AUTO" in chain[1:]:
        return True, "Verified traffic through a Hong Kong node.", details, False
    if auto and "AUTO" in chain[1:]:
        return True, "Verified traffic through a fallback node outside the Hong Kong group.", details, False
    if auto:
        return True, "Verified proxy traffic through a different route.", details, False
    return True, "Verified traffic through the manually selected node.", details, repair
