"""Focused regression checks for the maintenance backend."""
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
from unittest.mock import patch

source = sys.argv[1]
sys.path.insert(0, source)

import garbage
import network


def check_storage():
    with TemporaryDirectory() as temporary:
        root = Path(temporary)
        profile = root / "system"
        booted = root / "booted"
        active = root / "active"
        for n in range(1, 9):
            target = root / f"closure-{n}"
            target.mkdir()
            (root / f"system-{n}-link").symlink_to(target)
        profile.symlink_to("system-8-link")
        booted.symlink_to(root / "closure-1")
        active.symlink_to(root / "closure-2")

        with (
            patch.object(garbage, "PROFILE", profile),
            patch.object(garbage, "SYSTEMS", {"boot": booted, "active": active}),
            patch.object(garbage, "LOCK", root / "gc.lock"),
            patch.object(garbage, "boot_entries", return_value="fixture"),
            patch.object(garbage.shutil, "disk_usage") as disk,
            patch.object(garbage.subprocess, "run") as run,
        ):
            disk.return_value.free = 0
            keep, remove, _, token = garbage.plan()
            assert keep == {1, 2, 6, 7, 8}
            assert remove == [3, 4, 5]
            active.unlink()
            active.symlink_to(root / "closure-3")
            assert not garbage.collect("/fake-nix", root, token)[0]
            run.assert_not_called()

            token = garbage.plan()[3]
            run.side_effect = [
                subprocess.CompletedProcess([], 0),
                subprocess.CompletedProcess([], 0, stdout="1048576 bytes freed"),
            ]
            ok, message, details = garbage.collect("/fake-nix", root, token)
            assert ok and "1.00 MiB" in message and "2, 4, 5" in details[1]
            assert run.call_args_list[0].args[0][-4:] == ["--delete-generations", "2", "4", "5"]
            assert run.call_args_list[1].args[0] == ["/fake-nix/bin/nix-store", "--gc"]


def check_network():
    url = "https://fixture.invalid/generate_204"

    def control(path, **_):
        if path == "/proxies/SELECT":
            return {"now": "AUTO"}
        if path.startswith(("/group/NODES/", "/proxies/NODES/")):
            return {"delay": 120}
        return {}

    with (
        TemporaryDirectory() as temporary,
        patch.object(network, "uplink", return_value=(True, "", [])),
        patch.object(network, "command", return_value=subprocess.CompletedProcess([], 0)),
        patch.object(network, "controller", side_effect=control) as controller,
        patch.object(network, "verify_egress") as verify,
    ):
        socket = Path(temporary) / "controller.sock"
        socket.touch()
        disabled = Path(temporary) / "disabled"
        with patch.object(network, "CONTROLLER", str(socket)), patch.object(network, "DISABLED", disabled):
            verify.return_value = True, ["fixture-node", "NODES", "AUTO", "SELECT"]
            ok, message, _, recover = network.maintain("nmcli", "systemctl", "uplink", url, True, "network")
            assert ok and "fallback node" in message and not recover
            assert any(call.args[0].startswith("/group/NODES/delay?") for call in controller.call_args_list)
            controller.reset_mock()
            verify.return_value = True, ["DIRECT", "AUTO", "SELECT"]
            result = network.maintain("nmcli", "systemctl", "uplink", url, True, "inspect")
            assert not result[0] and "direct connection" in result[1]
            controller.assert_called_once_with("/proxies/SELECT")

            disabled.touch()
            controller.reset_mock()
            result = network.maintain("nmcli", "systemctl", "uplink", url, True, "network")
            assert not result[0] and result[3] and disabled.exists()
            controller.assert_not_called()


check_storage()
check_network()
print("PASS: retention, stale-plan refusal, proxy fallback and manual override")
