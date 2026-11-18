"""Bounded control operations for Ember's private Mihomo controller."""
import json
import os
from pathlib import Path
import subprocess
import sys


ENDPOINT = "http://localhost/proxies/SELECT"
SOCKET = "/run/ember-proxy/controller.sock"
UNIT = "ember-proxy.service"


class ControlError(Exception):
    pass


def service_state(systemctl):
    result = subprocess.run(
        [systemctl, "is-active", UNIT], capture_output=True, text=True, timeout=5
    )
    state = result.stdout.strip()
    return state if state in {"active", "activating", "deactivating", "inactive", "failed"} else "unknown"


def controller(curl, payload=None):
    command = [curl, "-q", "-fsS", "--noproxy", "*", "--max-time", "5", "--unix-socket", SOCKET]
    if payload is not None:
        command.extend(["-X", "PUT", "-H", "Content-Type: application/json", "--data-binary", "@-"])
    result = subprocess.run(
        [*command, ENDPOINT], input=payload, capture_output=True, text=True, timeout=6
    )
    if result.returncode:
        raise ControlError("The proxy controller could not complete the request.")
    if payload is None:
        snapshot = json.loads(result.stdout)
        return snapshot["now"], [
            name for name in snapshot["all"] if isinstance(name, str) and "\0" not in name
        ]


def main(curl, systemctl, directory, action, *args):
    if os.geteuid() != 0:
        raise ControlError("Administrator authorization is required.")
    state = Path(directory)
    if action == "select" and len(args) == 1:
        node = args[0]
        _, nodes = controller(curl)
        if node not in nodes:
            raise ControlError("The selected node is no longer available. Reload the node list.")
        controller(curl, json.dumps({"name": node}, ensure_ascii=True))
        current, _ = controller(curl)
        if current != node:
            raise ControlError("The controller did not confirm the requested node.")
        print(f"selected: {current}")
        return
    if args or action not in {"on", "off", "nodes", "panel-nodes"}:
        raise ControlError("Unsupported proxy operation.")
    if action in {"nodes", "panel-nodes"}:
        current, nodes = controller(curl)
        if action == "panel-nodes":
            if current not in nodes:
                current = ""
            sys.stdout.buffer.write("\0".join([current, *nodes]).encode("utf-8"))
        else:
            print("current: " + current, *nodes, sep="\n")
        return
    if action == "on":
        if not any(path.is_file() and path.stat().st_size for path in (
            state / "sources.yaml", state / "providers.yaml"
        )):
            raise ControlError("Import a proxy provider before enabling the proxy.")
        (state / "disabled").unlink(missing_ok=True)
        operation = "restart"
    else:
        (state / "disabled").touch(mode=0o600)
        operation = "stop"
    result = subprocess.run(
        [systemctl, operation, UNIT], capture_output=True, timeout=90
    )
    if result.returncode:
        raise ControlError("The proxy service could not complete the operation.")


if __name__ == "__main__":
    try:
        curl, systemctl, directory, *args = sys.argv[1:]
        if args == ["status"]:
            print(service_state(systemctl))
        else:
            main(curl, systemctl, directory, *args)
    except ControlError as error:
        sys.exit(str(error))
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
        sys.exit("Could not query or update the proxy.")
