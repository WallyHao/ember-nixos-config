{
  inputs,
  pkgs,
  inventory,
}:
import ./common.nix {
  inherit inputs pkgs inventory;
  name = "ember-vm-file-drop";
  extraSystemConfig = {
    environment.systemPackages = [
      pkgs.curl
      pkgs.nftables
    ];
  };
  extraTestScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("file-drop.service")
    machine.wait_for_open_port(7373)

    with subtest("unauthenticated access is refused"):
        code = machine.succeed(
            "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:7373/"
        ).strip()
        t.assertEqual(code, "401")

    with subtest("first start generates a private credential file"):
        creds = machine.succeed(
            "cat /home/wallyhao/.local/state/file-drop/auth"
        ).strip()
        t.assertTrue(creds.startswith("wallyhao:"), creds)
        t.assertTrue(len(creds) > 20, creds)
        t.assertEqual(
            machine.succeed(
                "stat -c '%U %a' /home/wallyhao/.local/state/file-drop/auth"
            ).strip(),
            "wallyhao 600",
        )

    with subtest("upload lands in the shared directory"):
        machine.succeed("printf 'probe\\n' > /tmp/probe.txt")
        machine.succeed(
            f"curl -sf -u {creds} -F 'file=@/tmp/probe.txt;filename=probe.txt' "
            "'http://127.0.0.1:7373/upload?path=/'"
        )
        t.assertEqual(
            machine.succeed("cat /home/wallyhao/Downloads/Share/probe.txt").strip(),
            "probe",
        )
        t.assertEqual(
            machine.succeed(
                "stat -c '%U' /home/wallyhao/Downloads/Share/probe.txt"
            ).strip(),
            "wallyhao",
        )

    with subtest("authenticated download returns the same bytes"):
        t.assertEqual(
            machine.succeed(
                f"curl -sf -u {creds} http://127.0.0.1:7373/probe.txt"
            ).strip(),
            "probe",
        )

    with subtest("duplicate name is rejected without overwriting"):
        code = machine.succeed(
            f"curl -s -o /dev/null -w '%{{http_code}}' -u {creds} "
            "-F 'file=@/tmp/probe.txt;filename=probe.txt' "
            "'http://127.0.0.1:7373/upload?path=/'"
        ).strip()
        t.assertEqual(code, "409")

    with subtest("firewall admits the service port"):
        t.assertIn("7373", machine.succeed("nft list ruleset"))

    with subtest("service restarts after a crash"):
        old = machine.succeed(
            "systemctl show -p MainPID --value file-drop.service"
        ).strip()
        machine.succeed("systemctl kill -s KILL file-drop.service")
        machine.wait_until_succeeds(
            f'test "$(systemctl show -p MainPID --value file-drop.service)" != "{old}"',
            timeout=60,
        )

    with subtest("empty credential file is regenerated"):
        machine.succeed(": > /home/wallyhao/.local/state/file-drop/auth")
        machine.succeed("systemctl restart file-drop.service")
        machine.wait_for_unit("file-drop.service")
        renewed = machine.succeed(
            "cat /home/wallyhao/.local/state/file-drop/auth"
        ).strip()
        t.assertTrue(renewed.startswith("wallyhao:"), renewed)
        t.assertTrue(len(renewed) > 20, renewed)
  '';
}
