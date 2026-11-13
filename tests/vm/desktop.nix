{
  inputs,
  pkgs,
  inventory,
}:
let
  software = (import ../../software/packages.nix { inherit pkgs; }).workstation;
  profileHelper = pkgs.runCommand "ember-desktop-profile-fixture" { } ''
    mkdir -p $out/scripts
    cp ${../../scripts/ember} $out/scripts/ember
    cp ${../../justfile} $out/justfile
    cp -r ${../../software} $out/software
  '';
  image = pkgs.runCommand "ember-clipboard-fixture.png" { } ''
    printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jS1sAAAAASUVORK5CYII=' | base64 -d > $out
  '';
  extraTestScript = ''
    import time

    def login():
        machine.wait_for_unit("greetd.service", timeout=180)
        machine.wait_for_text("(?i)(username|pass[wuv]+ord)", timeout=180)
        machine.send_key("esc")
        machine.wait_for_text(r"(?is)\A(?!.*pass[wuv]+ord).*username", timeout=60)
        machine.send_chars("wallyhao\n")
        machine.wait_for_text("(?i)pass[wuv]+ord", timeout=120)
        machine.send_chars("kl;'\n")
        machine.wait_until_succeeds("pgrep -u wallyhao -x niri", timeout=180)

    machine.wait_for_unit("greetd.service", timeout=180)
    machine.wait_for_text("(?i)emberlight", timeout=180)
    machine.screenshot("emberlight-greeter")
    machine.send_key("esc")
    machine.wait_for_text(r"(?is)\A(?!.*pass[wuv]+ord).*username", timeout=60)
    machine.send_chars("wallyhao\n")
    machine.wait_for_text("(?i)pass[wuv]+ord", timeout=120)
    machine.send_chars("wrong-password\n")
    machine.wait_for_text("(?i)authentication fail", timeout=120)
    machine.fail("pgrep -u wallyhao -x niri")
    machine.succeed("systemctl restart greetd.service")
    login()
    base_user = "runuser -u wallyhao -- env HOME=/home/wallyhao PATH=/run/wrappers/bin:/run/current-system/sw/bin:/etc/profiles/per-user/wallyhao/bin XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus "
    for service in ["waybar", "mako", "ember-wallpaper", "ember-polkit", "ember-clipboard-watch"]:
        try:
            machine.wait_until_succeeds(base_user + "systemctl --user is-active " + service + ".service", timeout=30)
        except Exception:
            print(machine.execute(base_user + "journalctl --user -b --no-pager -n 100")[1])
            raise
    machine.fail("pgrep -u wallyhao -x noctalia")
    display = machine.succeed(base_user + "find /run/user/1000 -maxdepth 1 -type s -name 'wayland-*' -printf '%f\\n'").splitlines()[0]
    socket = machine.succeed(base_user + "sh -c \"find /run/user/1000 -maxdepth 1 -type s -name 'niri.*.sock' | head -n1\"").strip()
    user = base_user + f"WAYLAND_DISPLAY={display} NIRI_SOCKET={socket} "

    def as_user(command):
        return machine.succeed(user + "sh -c " + shlex.quote(command))

    def wait_user(command, timeout=60):
        machine.wait_until_succeeds(user + "sh -c " + shlex.quote(command), timeout=timeout)

    def popup(key):
        machine.send_key(key)
        machine.wait_until_succeeds("pgrep -u wallyhao -x fuzzel", timeout=60)
        time.sleep(1)

    def dismiss():
        machine.send_key("esc")
        machine.wait_until_fails("pgrep -u wallyhao -x fuzzel", timeout=60)

    with subtest("native profile install is offline and idempotent"):
        as_user("cd ${profileHelper}; just profile install")
        generation = as_user("readlink /home/wallyhao/.local/state/nix/profiles/profile")
        as_user("cd ${profileHelper}; just profile install")
        t.assertEqual(generation, as_user("readlink /home/wallyhao/.local/state/nix/profiles/profile"))
        as_user("/home/wallyhao/.local/state/nix/profiles/profile/bin/omp --version")

    with subtest("Foot input, launcher and notification delivery"):
        machine.send_key("meta_l-ret")
        wait_user("niri msg --json windows | jq -e 'any(.[]; .app_id == \"foot\")'")
        time.sleep(1)
        machine.send_chars("printf ember-terminal > /home/wallyhao/Documents/ember-terminal-test\n")
        machine.wait_until_succeeds("test \"$(cat /home/wallyhao/Documents/ember-terminal-test)\" = ember-terminal", timeout=60)
        machine.screenshot("ember-desktop")
        popup("meta_l-d")
        dismiss()
        as_user("notify-send -t 30000 'Ember notification test' 'Mako receives notifications'")
        wait_user("makoctl list | grep -q 'Ember notification test'", timeout=10)
        machine.screenshot("ember-notification")
        as_user("makoctl dismiss --all")

    db = "/run/user/1000/ember-clipboard/history.db"
    with subtest("clipboard text restore, cancel and image round trip"):
        as_user("printf ember-clipboard-test | wl-copy")
        wait_user(f"cliphist -db-path {db} list | grep -q ember-clipboard-test")
        popup("meta_l-v")
        dismiss()
        t.assertEqual(as_user("wl-paste --no-newline").strip(), "ember-clipboard-test")
        as_user("printf replacement | wl-copy")
        wait_user(f"cliphist -db-path {db} list | grep -q replacement")
        popup("meta_l-v")
        machine.send_chars("ember-clipboard-test")
        time.sleep(1)
        machine.send_key("ret")
        wait_user("test \"$(wl-paste --no-newline)\" = ember-clipboard-test")
        as_user(f"cliphist -db-path {db} wipe")
        as_user("wl-copy --type image/png < ${image}")
        wait_user(f"test \"$(cliphist -db-path {db} list | wc -l)\" = 1")
        popup("meta_l-v")
        machine.send_key("ret")
        wait_user("wl-paste --type image/png | cmp - ${image}")

    with subtest("Polkit agent displays a real challenge and accepts cancellation"):
        machine.send_chars("pkcheck --action-id org.ember.test --process $$ --allow-user-interaction > /home/wallyhao/Documents/polkit-result 2>/home/wallyhao/Documents/polkit-error; echo $? > /home/wallyhao/Documents/polkit-status\n")
        try:
            machine.wait_for_text("(?i)(authentication|required|authenticate)", timeout=25)
        except Exception:
            print(machine.execute("cat /home/wallyhao/Documents/polkit-error /home/wallyhao/Documents/polkit-status")[1])
            raise
        machine.screenshot("ember-polkit")
        machine.send_key("esc")
        wait_user("test -s /home/wallyhao/Documents/polkit-status")
        t.assertNotEqual(as_user("cat /home/wallyhao/Documents/polkit-status").strip(), "0")
        t.assertEqual(as_user("cat /home/wallyhao/Documents/polkit-result").strip(), "")

    with subtest("reboot confirmation can be cancelled"):
        boot = machine.succeed("cat /proc/sys/kernel/random/boot_id")
        popup("meta_l-shift-r")
        dismiss()
        t.assertEqual(boot, machine.succeed("cat /proc/sys/kernel/random/boot_id"))

    with subtest("locking clears history and authentication unlocks"):
        as_user("systemctl --user start ember-lock.service")
        machine.wait_until_succeeds("pgrep -u wallyhao -x swaylock", timeout=60)
        machine.fail("test -e " + db)
        machine.send_chars("wrong-password\n")
        time.sleep(3)
        machine.succeed("pgrep -u wallyhao -x swaylock")
        machine.screenshot("ember-locked")
        machine.send_chars("kl;'\n")
        machine.wait_until_fails("pgrep -u wallyhao -x swaylock", timeout=60)
        wait_user("systemctl --user is-active ember-clipboard-watch.service")
        machine.fail("test -e " + db)

    machine.shutdown()
  '';

in
import ./common.nix {
  inherit
    inputs
    pkgs
    inventory
    extraTestScript
    ;
  name = "ember-vm-desktop";
  networkMode = "none";
  enableOCR = true;
  testTimeout = 900;
  memorySize = 2048;
  qemuExtraOptions = [
    "-vga"
    "none"
    "-device"
    "virtio-gpu-pci,xres=1280,yres=1024"
  ];
  extraSystemConfig =
    {
      lib,
      pkgs,
      ...
    }:
    {
      # Test-only: this virtual GPU has no hardware EGL renderer.
      # Production still uses the locked Niri package without this patch.
      nixpkgs.overlays = [
        (_final: prev: {
          niri = prev.niri.overrideAttrs (old: {
            postPatch = (old.postPatch or "") + ''
              substituteInPlace src/backend/tty.rs --replace-fail "!egl_device.is_software()," "true,"
              # llvmpipe registers its GBM renderer on the primary card, not
              # the virtual device's unused render node. Match the lookup key.
              substituteInPlace src/backend/tty.rs --replace-fail \
                $'let primary_render_node = primary_node\n                    .node_with_type(NodeType::Render)' \
                $'let primary_render_node = primary_node\n                    .node_with_type(NodeType::Primary)'
            '';
          });
        })
      ];
      boot.kernelModules = lib.mkForce [ "virtio_gpu" ];
      system.extraDependencies = [
        software
        profileHelper
        image
      ];
      environment.sessionVariables.LIBGL_ALWAYS_SOFTWARE = "1";
      # A real agent challenge without enabling the optional setuid pkexec wrapper.
      environment.systemPackages = [
        (pkgs.writeTextDir "share/polkit-1/actions/org.ember.test.policy" ''
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN" "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
          <policyconfig>
            <action id="org.ember.test">
              <description>Ember VM authentication test</description>
              <message>Authentication required for Ember VM test</message>
              <defaults>
                <allow_any>auth_self</allow_any>
                <allow_inactive>auth_self</allow_inactive>
                <allow_active>auth_self</allow_active>
              </defaults>
            </action>
          </policyconfig>
        '')
        pkgs.libnotify
        pkgs.cliphist
        pkgs.polkit
        pkgs.glib
        pkgs.jq
      ];
    };
}
