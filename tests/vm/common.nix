{
  inputs,
  pkgs,
  inventory,
  name,
  extraTestScript,
  extraSystemConfig ? { },
  extraInstallerConfig ? { },
  networkMode ? "default",
  enableOCR ? false,
  testTimeout ? 600,
  qemuPackage ? pkgs.qemu_test,
  qemuExtraOptions ? [ ],
  memorySize ? 1024,
}:
let
  nixpkgs = toString inputs.nixpkgs;
  diskoSrc = toString inputs.disko;

  hostResult = (import ../../lib/mk-host.nix) {
    inherit inputs inventory;
    hostName = "ember";
    hardwareModules = [ ../fixtures/hardware.nix ];
    storageModule = null;
  };

  makeDiskoTest =
    (import ./disko-test-lib.nix {
      lib = pkgs.lib;
      makeTest = import "${nixpkgs}/nixos/tests/make-test-python.nix";
      eval-config = import "${nixpkgs}/nixos/lib/eval-config.nix";
      qemu-common-lib =
        pkgs':
        (import "${nixpkgs}/nixos/lib/qemu-common.nix") {
          lib = pkgs'.lib;
          inherit (pkgs') stdenv;
        };
      inherit diskoSrc;
    }).makeDiskoTest;
in
makeDiskoTest {
  inherit pkgs name;

  # Common boot assertions: a successful login target is not enough if
  # systemd had to delete mount stop jobs to break an ordering cycle.
  extraTestScript = ''
    def assert_no_ordering_cycles(shutdown=False):
        # The serial log spans guest reboots and includes shutdown, which a
        # journalctl -b check after reboot omits. After poweroff only the
        # driver's console log remains available.
        evidence = machine.get_console_log()
        if not shutdown:
            evidence += machine.succeed("journalctl --no-pager")
        bad_markers = (
            "Found ordering cycle",
            "deleted to break ordering cycle",
            "Failed to mount",
        )
        cycles = [line for line in evidence.splitlines()
                  if any(marker in line for marker in bad_markers)]
        t.assertEqual(cycles, [], "systemd ordering/mount failures: " + "\n".join(cycles))

    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("home-manager-wallyhao.service", timeout=180)
    assert_no_ordering_cycles()
  ''
  + extraTestScript
  + ''
    assert_no_ordering_cycles(shutdown=True)
  '';

  disko-config = ../fixtures/storage.nix;
  testMode = "module";
  inherit
    networkMode
    enableOCR
    extraInstallerConfig
    testTimeout
    qemuPackage
    qemuExtraOptions
    memorySize
    ;

  extraSystemConfig = {
    imports = hostResult.modules ++ [ extraSystemConfig ];
    _module.args = { inherit inputs; };
    nix.settings.auto-optimise-store = pkgs.lib.mkForce false;

    # The VM has no real GPU. Keep Steam and the 32-bit graphics stack out of
    # every VM closure: they would dominate build time and prove nothing on
    # virtio-gpu. Production keeps ember.gaming.enable at its default.
    ember.gaming.enable = pkgs.lib.mkForce false;

    # Test-only tooling for real PAM/TTY login checks. It is not part of the
    # target system package set.
    environment.systemPackages = [ pkgs.expect ];

    # The test instrumentation normally gives root an empty password file for
    # its backdoor. Keep the target's locked root entry; the backdoor uses
    # agetty autologin on the serial console and does not need a root password.
    users.users.root.hashedPasswordFile = pkgs.lib.mkForce null;

    # VM login uses a fixed test credential, never the local account hash.
    users.users.wallyhao.initialHashedPassword = pkgs.lib.mkForce null;
    users.users.wallyhao.initialPassword = "kl;'";
  };
}
