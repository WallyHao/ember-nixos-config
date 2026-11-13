{
  inputs,
  pkgs,
  inventory,
}:
let
  extraTestScript = ''
    import time

    machine.wait_for_unit("greetd.service", timeout=180)

    with subtest("the graphical guest has no NIC"):
        machine.fail("test -e /sys/class/net/eth0")
        machine.succeed("test -e /sys/class/net/lo")

    # Password login through the real greeter, same path as vm-desktop.
    machine.wait_for_text("(?i)(username|pass[wuv]+ord)", timeout=180)
    machine.send_key("esc")
    machine.wait_for_text(r"(?is)\A(?!.*pass[wuv]+ord).*username", timeout=60)
    machine.send_chars("wallyhao\n")
    machine.wait_for_text("(?i)pass[wuv]+ord", timeout=120)
    machine.send_chars("kl;'\n")
    machine.wait_until_succeeds("pgrep -u wallyhao -x niri", timeout=180)
    machine.wait_until_succeeds("pgrep -u wallyhao -x waybar", timeout=180)
    # No plugin manager or online wallpaper source is installed.
    machine.screenshot("offline-desktop")

    with subtest("independent desktop performs no git work without a NIC"):
        machine.fail("pgrep -af 'git clone'")
        machine.fail("pgrep -af 'git.*ember'")
        logs = machine.succeed("journalctl -b --no-pager")
        t.assertNotIn("git clone", logs)
        t.assertNotIn("browse fetch", logs)
        t.assertNotIn("cannot prepare source cache", logs)

    with subtest("the offline desktop still creates its bar and wallpaper layers"):
        machine.succeed("pgrep -u wallyhao -x waybar")
        machine.succeed(
            "runuser -u wallyhao -- env XDG_RUNTIME_DIR=/run/user/1000 "
            "systemctl --user is-active graphical-session.target"
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
  name = "ember-vm-offline-desktop";
  networkMode = "none";
  enableOCR = true;
  inherit extraTestScript;
}
