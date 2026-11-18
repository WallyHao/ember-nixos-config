"""Privileged maintenance operations. The terminal UI stays unprivileged."""
from concurrent.futures import ThreadPoolExecutor
import http.client
import json
import os
from pathlib import Path
import subprocess
import sys

import garbage
import network


def run_network(config, action):
    try:
        return network.maintain(
            config["nmcli"], config["systemctl"], config["uplink"],
            config["healthUrl"], config["proxyEnabled"], action,
        )
    except (OSError, ValueError, TypeError, KeyError, http.client.HTTPException, subprocess.SubprocessError):
        return False, "Network maintenance failed. Check NetworkManager and the proxy service.", [], False


def run_storage(config, token):
    esp = Path(config["esp"])
    try:
        if token == "inspect":
            return True, "Cleanup plan is shown above.", [garbage.boot_entries(esp)]
        return garbage.collect(config["nix"], esp, token)
    except (OSError, ValueError, RuntimeError):
        return False, "Could not complete the storage check or cleanup.", []


def main():
    config_path, action, *args = sys.argv[1:]
    if os.geteuid() != 0:
        return 2
    with open(config_path) as source:
        config = json.load(source)
    jobs = {}
    with ThreadPoolExecutor(max_workers=2) as workers:
        if action in {"full", "network", "inspect", "restore"}:
            jobs["Network"] = workers.submit(run_network, config, action)
        if action in {"full", "storage", "inspect"}:
            jobs["Storage"] = workers.submit(run_storage, config, args[0] if args else "inspect")
        print(json.dumps({name: job.result() for name, job in jobs.items()}))
    return 0 if jobs else 2


if __name__ == "__main__":
    sys.exit(main())
