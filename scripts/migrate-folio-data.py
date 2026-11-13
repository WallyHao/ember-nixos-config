#!/usr/bin/env python3
"""Copy authorized Folio connection/node/subscription DATA, never its policy."""
import argparse
import configparser
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

import yaml


def private_copy(source, destination):
    destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = destination.with_name(destination.name + ".incoming")
    if temporary.exists() or temporary.is_symlink():
        raise ValueError("unexpected staging file")
    with open(source, "rb") as incoming, open(temporary, "xb") as outgoing:
        os.fchmod(outgoing.fileno(), 0o600)
        shutil.copyfileobj(incoming, outgoing)
    os.replace(temporary, destination)


def connection(path):
    value = configparser.ConfigParser(interpolation=None, strict=False)
    value.read(path)
    return value.get("connection", "uuid", fallback="")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target-root", required=True)
    parser.add_argument("--normalizer", required=True)
    args = parser.parse_args()
    if os.geteuid() != 0 or Path("/proc/sys/kernel/hostname").read_text().strip() != "folio":
        raise ValueError("Run through just migrate-folio-data on Folio with local sudo")
    root = Path(args.target_root).resolve()
    if root != Path("/mnt"):
        raise ValueError("only the reviewed /mnt target is accepted")
    for mount, label in [(root / "persist", "HEARTH_SYSTEM"), (root / "boot", "HEARTH_EFI")]:
        found = subprocess.run(["findmnt", "--mountpoint", str(mount), "-n", "-o", "LABEL"], capture_output=True, text=True, check=True).stdout.strip()
        if found != label:
            raise ValueError("reviewed internal target is not mounted")
    spec = importlib.util.spec_from_file_location("proxy_data", args.normalizer)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    work = Path("/var/lib/folio-mihomo")
    private = Path("/var/lib/folio-mihomo-private")
    nodes, subscriptions, visited = {}, {}, set()

    def collect(path):
        path = path.resolve()
        if path in visited:
            return
        if not (path.is_relative_to(work) or path.is_relative_to(private) or path.is_relative_to(Path("/run/credentials/folio-mihomo.service"))):
            raise ValueError("provider path outside authorized Folio directories")
        visited.add(path)
        data = module.read(path)
        for node in data.get("proxies", []):
            name = node.get("name") if isinstance(node, dict) else None
            if not name or (name in nodes and nodes[name] != node):
                raise ValueError("invalid or ambiguous node identity")
            nodes[name] = node
        for name, provider in data.get("proxy-providers", {}).items():
            if provider.get("type") == "http":
                if name in subscriptions and subscriptions[name] != provider:
                    raise ValueError("ambiguous subscription identity")
                subscriptions[name] = provider
                cache = Path(provider.get("path", ""))
                if not cache.is_absolute():
                    cache = path.parent / cache
                # Cached nodes allow first boot without subscription access.
                if cache.is_file():
                    collect(cache)
            elif provider.get("type") == "file":
                source = Path(provider["path"])
                if str(source) == "/run/credentials/folio-mihomo.service/provider.yaml":
                    source = private / "provider.yaml"
                elif not source.is_absolute():
                    source = path.parent / source
                collect(source)
    collect(work / "config.json")
    if (private / "provider.yaml").is_file():
        collect(private / "provider.yaml")
    data = module.normalize({"proxies": list(nodes.values()), "proxy-providers": subscriptions})
    state = root / "persist/var/lib/hearth-proxy"
    state.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(state, 0o700)
    backup = state / ("migration-backup-" + str(time.time_ns()))
    backup.mkdir(mode=0o700)
    target = state / "sources.yaml"
    if target.is_file():
        private_copy(target, backup / "sources.yaml")
    # These contents include no foreign DNS, rules, groups, listeners or routes.
    module.write_private(target, data)
    network = root / "persist/etc/NetworkManager/system-connections"
    network.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(network, 0o700)
    count = 0
    agent_only = 0
    for source in sorted(Path("/etc/NetworkManager/system-connections").iterdir()):
        if not source.is_file() or source.is_symlink():
            continue
        parsed = configparser.ConfigParser(interpolation=None, strict=False)
        parsed.read(source)
        if parsed.has_section("wifi-security"):
            security = "wifi-security"
        else:
            security = "802-11-wireless-security"
        if parsed.get(security, "key-mgmt", fallback="") in ("wpa-psk", "sae") and not parsed.get(security, "psk", fallback=""):
            agent_only += 1
        uuid = connection(source)
        if not uuid or any(char not in "0123456789abcdefABCDEF-" for char in uuid):
            raise ValueError("invalid connection identity")
        destination = network / (uuid + ".nmconnection")
        if destination.is_symlink() or (destination.exists() and connection(destination) != uuid):
            raise ValueError("connection destination conflicts with another identity")
        matches = [path for path in network.iterdir() if path.is_file() and connection(path) == uuid]
        for index, old in enumerate(matches):
            private_copy(old, backup / f"network-{count}-{index}.nmconnection")
        private_copy(source, destination)
        for old in matches:
            if old != destination:
                old.unlink()
        count += 1
    # Preserve disabled if present. Import does not start either host's service.
    print(json.dumps({"copied_nodes": len(nodes), "copied_subscriptions": len(subscriptions), "copied_connections": count, "connections_needing_agent_secret": agent_only, "private_backup_created": True}))
    print("No Folio service was changed. No node, subscription, SSID or password contents were printed.")


if __name__ == "__main__":
    os.umask(0o077)
    try:
        main()
    except Exception:
        sys.exit("Private-data migration did not complete. Source data was not changed; check local permissions/mounts/format. No private content was printed.")
