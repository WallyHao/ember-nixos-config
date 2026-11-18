{
  inputs,
  pkgs,
  inventory,
}:
let
  extraTestScript = ''
    machine.wait_for_unit("multi-user.target")

    with subtest("real tmpfs root and persistent virtual disks"):
        machine.succeed("findmnt / --types tmpfs")
        machine.succeed("findmnt /persist --types btrfs")
        machine.succeed("findmnt /nix --types btrfs")
        machine.succeed("mountpoint /persist")

    machine_id = machine.succeed("cat /etc/machine-id").strip()
    t.assertNotEqual(machine_id, "")

    with subtest("prepare ephemeral, preserved, network, and journal state"):
        machine.succeed("touch /unpreserved-ember-marker")
        machine.succeed("mkdir -p /tmp/ember-tmp-marker")
        machine.succeed("echo workspace-marker > /home/wallyhao/Workspace/marker")
        machine.succeed("install -d -o wallyhao -g users -m 0700 /home/wallyhao/.local/state/file-drop")
        machine.succeed("echo file-drop-marker > /home/wallyhao/.local/state/file-drop/marker")
        machine.succeed("echo nixos-state-marker > /var/lib/nixos/ember-marker")
        machine.succeed("printf '[connection]\\nid=ember-test\\nuuid=4f0b8d6a-1b2c-4d3e-8f90-a1b2c3d4e5f6\\ntype=dummy\\ninterface-name=ember-test0\\n' > /etc/NetworkManager/system-connections/ember-test.nmconnection")
        machine.succeed("chmod 600 /etc/NetworkManager/system-connections/ember-test.nmconnection")
        machine.succeed("logger -t ember-persist ember-persistence-marker")
        machine.succeed("journalctl --sync")

    with subtest("preserved paths have the intended ownership and modes before reboot"):
        t.assertEqual(machine.succeed("stat -c '%U %G %a' /home/wallyhao/Workspace").strip(), "wallyhao users 755")
        t.assertEqual(machine.succeed("stat -c '%U %G %a' /home/wallyhao/.local/state/nix").strip(), "wallyhao users 755")
        t.assertEqual(machine.succeed("stat -c '%U %G %a' /var/lib/nixos").strip(), "root root 755")
        t.assertEqual(machine.succeed("stat -c '%U %G %a' /var/lib/userborn").strip(), "root root 755")
        t.assertEqual(machine.succeed("stat -c '%U %G %a' /etc/NetworkManager/system-connections").strip(), "root root 700")
        t.assertEqual(machine.succeed("stat -c '%a' /etc/NetworkManager/system-connections/ember-test.nmconnection").strip(), "600")

    machine.reboot()
    machine.wait_for_unit("multi-user.target")
    assert_no_ordering_cycles()

    with subtest("machine identity is stable across reboot"):
        t.assertEqual(machine.succeed("cat /etc/machine-id").strip(), machine_id)

    with subtest("unpreserved data disappears from the tmpfs root"):
        machine.fail("test -e /unpreserved-ember-marker")
        machine.fail("test -e /tmp/ember-tmp-marker")

    with subtest("preserved system and user data survives reboot"):
        t.assertEqual(machine.succeed("cat /home/wallyhao/Workspace/marker").strip(), "workspace-marker")
        t.assertEqual(machine.succeed("cat /home/wallyhao/.local/state/file-drop/marker").strip(), "file-drop-marker")
        t.assertEqual(machine.succeed("cat /var/lib/nixos/ember-marker").strip(), "nixos-state-marker")
        machine.succeed("grep -q 'id=ember-test' /etc/NetworkManager/system-connections/ember-test.nmconnection")
        t.assertEqual(machine.succeed("stat -c '%a' /etc/NetworkManager/system-connections/ember-test.nmconnection").strip(), "600")
        machine.succeed("journalctl -t ember-persist --no-pager | grep -q ember-persistence-marker")

    machine.shutdown()
  '';
in
import ./common.nix {
  inherit
    inputs
    pkgs
    inventory
    ;
  name = "ember-vm-persistence";
  inherit extraTestScript;
}
