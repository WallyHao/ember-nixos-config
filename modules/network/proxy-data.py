#!/usr/bin/env python3
"""Private proxy source data only. Never import a foreign routing/DNS policy."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
from urllib.parse import urlsplit

import yaml


def read(path):
    with open(path, encoding="utf-8") as handle:
        value = yaml.safe_load(handle)
    if not isinstance(value, dict):
        raise ValueError("expected a source mapping")
    return value


def normalize(data):
    nodes = data.get("proxies", [])
    if not isinstance(nodes, list):
        raise ValueError("expected a node list")
    names = set()
    for node in nodes:
        if not isinstance(node, dict) or not all(isinstance(node.get(key), str) and node[key] for key in ("name", "type", "server")):
            raise ValueError("invalid node fields")
        if type(node.get("port")) is not int or not 0 < node["port"] < 65536:
            raise ValueError("invalid node port")
        if node["name"] in names or node["name"] in ("DIRECT", "REJECT", "HK-AUTO", "NODES", "AUTO", "SELECT"):
            raise ValueError("duplicate or reserved node name")
        names.add(node["name"])
    providers = data.get("proxy-providers", {})
    if not isinstance(providers, dict):
        raise ValueError("expected a provider mapping")
    subscriptions = {}
    for name, source in providers.items():
        if not isinstance(name, str) or not isinstance(source, dict) or source.get("type") != "http":
            raise ValueError("only HTTP sources or already exported static nodes are accepted")
        url = source.get("url", "")
        if not isinstance(url, str) or urlsplit(url).scheme not in ("http", "https") or not urlsplit(url).hostname:
            raise ValueError("invalid subscription URL")
        interval = source.get("interval", 3600)
        if type(interval) is not int or interval < 60:
            raise ValueError("invalid update interval")
        header = source.get("header", {})
        if not isinstance(header, dict) or not all(isinstance(key, str) and (isinstance(value, str) or (isinstance(value, list) and all(isinstance(item, str) for item in value))) for key, value in header.items()):
            raise ValueError("invalid subscription headers")
        subscriptions[name] = {"type": "http", "url": url, "interval": interval, "header": header}
    if not nodes and not subscriptions:
        raise ValueError("no nodes or subscriptions found")
    # Group/rule/DNS/listener/exec fields are deliberately never retained.
    return {"proxies": nodes, "proxy-providers": subscriptions}


def write_private(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    descriptor, temporary = tempfile.mkstemp(prefix=".proxy-", dir=path.parent)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            yaml.safe_dump(value, handle, allow_unicode=True, sort_keys=False)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def assemble(base, source, output, state):
    data = normalize(read(source))
    config = read(base)
    providers = {}
    health_check = config["proxy-providers"]["local"]["health-check"]
    if data["proxies"]:
        write_private(Path(state) / "nodes.yaml", {"proxies": data["proxies"]})
        providers["local"] = {
            "type": "file",
            "path": str(Path(state) / "nodes.yaml"),
            "health-check": health_check,
        }
    cache = Path(state) / "subscriptions"
    cache.mkdir(mode=0o700, exist_ok=True)
    for name, subscription in data["proxy-providers"].items():
        identity = "source-" + hashlib.sha256(name.encode()).hexdigest()[:16]
        providers[identity] = subscription | {
            "path": str(cache / (identity + ".yaml")),
            "health-check": health_check,
        }
    config["proxy-providers"] = providers
    # Only Ember's own groups are populated, never a group from the source.
    provider_names = list(providers)
    for group in config["proxy-groups"]:
        uses = group.get("use")
        if uses:
            group["use"] = [name for use in uses for name in (provider_names if use == "local" else [use])]
    write_private(output, config)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    command = commands.add_parser("normalize")
    command.add_argument("source")
    command.add_argument("output")
    command = commands.add_parser("assemble")
    command.add_argument("base")
    command.add_argument("source")
    command.add_argument("output")
    command.add_argument("state")
    args = parser.parse_args()
    try:
        if args.command == "normalize":
            write_private(args.output, normalize(read(args.source)))
        else:
            assemble(args.base, args.source, args.output, args.state)
    except Exception:
        # Do not leak tokens, node URLs, authentication fields or YAML snippets.
        sys.exit("Proxy data rejected; source must contain valid static nodes and/or HTTP subscriptions. No private values were printed.")


if __name__ == "__main__":
    main()
