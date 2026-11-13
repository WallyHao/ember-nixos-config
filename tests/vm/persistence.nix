{
  inputs,
  pkgs,
  inventory,
}:
let
  profilePath = "/home/wallyhao/.local/state/nix/profiles/profile";
  privateStore = "/persist/profile-store";
  privateStoreUri = "local?store=${privateStore}/nix/store&state=${privateStore}/nix/var/nix&log=${privateStore}/nix/var/log/nix";

  extraTestScript = ''
    import re

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
        machine.succeed("echo nixos-state-marker > /var/lib/nixos/ember-marker")
        machine.succeed("printf '[connection]\\nid=ember-test\\nuuid=4f0b8d6a-1b2c-4d3e-8f90-a1b2c3d4e5f6\\ntype=dummy\\ninterface-name=ember-test0\\n' > /etc/NetworkManager/system-connections/ember-test.nmconnection")
        machine.succeed("chmod 600 /etc/NetworkManager/system-connections/ember-test.nmconnection")
        machine.succeed("logger -t ember-persist ember-persistence-marker")
        machine.succeed("journalctl --sync")

    with subtest("create an isolated store and native profile generations"):
        machine.succeed("mkdir -p /persist/profile-src/one/bin /persist/profile-src/two/bin /persist/profile-src/garbage/bin")
        for name in ("one", "two", "garbage"):
            machine.succeed(
                f"echo '#!/bin/sh' > /persist/profile-src/{name}/bin/ember-profile-{name}; "
                f"echo 'echo ember-profile-{name}' >> /persist/profile-src/{name}/bin/ember-profile-{name}; "
                f"chmod +x /persist/profile-src/{name}/bin/ember-profile-{name}"
            )

        one = machine.succeed(
            "${pkgs.nix}/bin/nix-store --store \"${privateStoreUri}\" --add /persist/profile-src/one"
        ).strip()
        two = machine.succeed(
            "${pkgs.nix}/bin/nix-store --store \"${privateStoreUri}\" --add /persist/profile-src/two"
        ).strip()
        garbage = machine.succeed(
            "${pkgs.nix}/bin/nix-store --store \"${privateStoreUri}\" --add /persist/profile-src/garbage"
        ).strip()

        machine.succeed("chown -R wallyhao:users ${privateStore}")
        machine.succeed("mkdir -p /home/wallyhao/.local/state/nix/profiles")
        machine.succeed("chown -R wallyhao:users /home/wallyhao/.local/state/nix")

        machine.succeed(
            "${pkgs.nix}/bin/nix profile install --store \"${privateStoreUri}\" "
            "--profile ${profilePath} " + one
        )
        machine.succeed(
            "${pkgs.nix}/bin/nix profile install --store \"${privateStoreUri}\" "
            "--profile ${profilePath} " + two
        )
        machine.succeed("chown -R wallyhao:users /home/wallyhao/.local/state/nix")

        history = re.sub(
            r"\x1b\[[0-9;]*m",
            "",
            machine.succeed(
                "${pkgs.nix}/bin/nix profile history --store \"${privateStoreUri}\" --profile ${profilePath}"
            ),
        )
        t.assertIn("Version 1", history)
        t.assertIn("Version 2", history)
        t.assertEqual(machine.succeed("stat -c '%U' ${profilePath}").strip(), "wallyhao")

        t.assertEqual(
            machine.succeed("runuser -u wallyhao -- ${profilePath}/bin/ember-profile-one").strip(),
            "ember-profile-one",
        )
        t.assertEqual(
            machine.succeed("runuser -u wallyhao -- ${profilePath}/bin/ember-profile-two").strip(),
            "ember-profile-two",
        )

        roots = machine.succeed(
            "${pkgs.nix}/bin/nix-store --store \"${privateStoreUri}\" --gc --print-roots"
        )
        t.assertIn("${profilePath}", roots)
        machine.succeed("${pkgs.nix}/bin/nix-store --store \"${privateStoreUri}\" --gc")
        machine.succeed("test -e " + one)
        machine.succeed("test -e " + two)
        machine.succeed("test ! -e " + garbage)

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
        t.assertEqual(machine.succeed("cat /var/lib/nixos/ember-marker").strip(), "nixos-state-marker")
        machine.succeed("grep -q 'id=ember-test' /etc/NetworkManager/system-connections/ember-test.nmconnection")
        t.assertEqual(machine.succeed("stat -c '%a' /etc/NetworkManager/system-connections/ember-test.nmconnection").strip(), "600")
        machine.succeed("journalctl -t ember-persist --no-pager | grep -q ember-persistence-marker")

    with subtest("native profile generations survive reboot"):
        history = re.sub(
            r"\x1b\[[0-9;]*m",
            "",
            machine.succeed(
                "${pkgs.nix}/bin/nix profile history --store \"${privateStoreUri}\" --profile ${profilePath}"
            ),
        )
        t.assertIn("Version 1", history)
        t.assertIn("Version 2", history)
        t.assertEqual(
            machine.succeed("runuser -u wallyhao -- ${profilePath}/bin/ember-profile-one").strip(),
            "ember-profile-one",
        )
        t.assertEqual(
            machine.succeed("runuser -u wallyhao -- ${profilePath}/bin/ember-profile-two").strip(),
            "ember-profile-two",
        )

    with subtest("native GC keeps both generations until one is removed"):
        roots = machine.succeed(
            "${pkgs.nix}/bin/nix-store --store \"${privateStoreUri}\" --gc --print-roots"
        )
        t.assertIn("${profilePath}", roots)
        machine.succeed("${pkgs.nix}/bin/nix-store --store \"${privateStoreUri}\" --gc")
        machine.succeed("test -e " + one)
        machine.succeed("test -e " + two)

        machine.succeed(
            "${pkgs.nix}/bin/nix profile remove --store \"${privateStoreUri}\" "
            "--profile ${profilePath} one"
        )
        machine.fail("test -e ${profilePath}/bin/ember-profile-one")
        machine.succeed(
            "runuser -u wallyhao -- ${profilePath}/bin/ember-profile-two"
        )

        machine.succeed(
            "${pkgs.nix}/bin/nix profile wipe-history --store \"${privateStoreUri}\" --profile ${profilePath}"
        )
        history = re.sub(
            r"\x1b\[[0-9;]*m",
            "",
            machine.succeed(
                "${pkgs.nix}/bin/nix profile history --store \"${privateStoreUri}\" --profile ${profilePath}"
            ),
        )
        t.assertNotIn("Version 1", history)
        t.assertNotIn("Version 2", history)
        t.assertIn("Version 3", history)

        machine.succeed("${pkgs.nix}/bin/nix-store --store \"${privateStoreUri}\" --gc")
        machine.succeed("test ! -e " + one)
        machine.succeed("test -e " + two)
        t.assertEqual(
            machine.succeed("runuser -u wallyhao -- ${profilePath}/bin/ember-profile-two").strip(),
            "ember-profile-two",
        )

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
