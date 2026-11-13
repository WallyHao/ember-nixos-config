{
  inputs,
  pkgs,
  inventory,
}:
let
  extraTestScript = ''
    import re

    with subtest("the booted guest has no NIC at all"):
        machine.fail("test -e /sys/class/net/eth0")
        machine.succeed("test -e /sys/class/net/lo")

    machine.wait_for_unit("multi-user.target", timeout=180)
    machine.wait_for_unit("greetd.service", timeout=180)

    with subtest("the local login target is reached without network-online"):
        machine.succeed("systemctl is-active multi-user.target")
        machine.succeed("systemctl is-active greetd.service")
        machine.succeed("systemctl is-active getty@tty2.service")
        machine.fail("systemctl is-active NetworkManager-wait-online.service")
        machine.fail("systemctl is-active systemd-networkd-wait-online.service")
        machine.fail("systemctl is-active nixos-upgrade.service")

    with subtest("no network wait or update timer is in the boot critical chain"):
        chain = machine.succeed("systemd-analyze critical-chain multi-user.target")
        t.assertNotIn("NetworkManager-wait-online", chain)
        t.assertNotIn("nixos-upgrade", chain)

    with subtest("record boot timing and virtualization mode"):
        virt = machine.succeed("systemd-detect-virt || true").strip()
        print("virtualization:", virt)
        t.assertIn(virt, ["kvm", "qemu"], virt)
        timing = machine.succeed("systemd-analyze time")
        print(timing)
        userspace = re.search(r"([0-9.]+)s \(userspace\)", timing)
        assert userspace is not None, timing
        # Investigation threshold, not a user-facing promise.
        t.assertLess(float(userspace.group(1)), 60.0, timing)

    machine.shutdown()
  '';
in
import ./common.nix {
  inherit
    inputs
    pkgs
    inventory
    ;
  name = "ember-vm-offline-boot";
  networkMode = "none";
  inherit extraTestScript;
}
