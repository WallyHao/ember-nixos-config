{
  config,
  lib,
  ...
}:
let
  persistRoot = "/persist";
  home = config.ember.userHome;

  earlyDirectories = [
    "${persistRoot}/etc"
    "${persistRoot}/etc/NetworkManager"
    "${persistRoot}/etc/NetworkManager/system-connections"
    "${persistRoot}/var"
    "${persistRoot}/var/lib"
    "${persistRoot}/var/lib/nixos"
    "${persistRoot}/var/lib/userborn"
    "${persistRoot}/var/lib/bluetooth"
    "${persistRoot}/var/lib/tlp"
    "${persistRoot}/var/lib/systemd"
    "${persistRoot}/var/lib/systemd/timers"
    "${persistRoot}/var/log"
    "${persistRoot}/var/log/journal"
    "${persistRoot}${home}"
    "${persistRoot}${home}/.local"
    "${persistRoot}${home}/.local/state"
    "${persistRoot}${home}/.local/state/nix"
    "${persistRoot}${home}/Workspace"
    "${persistRoot}${home}/Documents"
    "${persistRoot}${home}/Downloads"
    "${persistRoot}${home}/Pictures"
  ];

  sysrootPaths = map (path: "/sysroot${path}") earlyDirectories;
in
{
  preservation.enable = true;

  preservation.preserveAt.${persistRoot} = {
    directories = [
      {
        directory = "/var/lib/nixos";
        inInitrd = true;
        mode = "0755";
      }
      {
        directory = "/var/lib/userborn";
        inInitrd = true;
        mode = "0755";
      }
      {
        directory = "/var/lib/bluetooth";
        mode = "0700";
      }
      {
        directory = "/var/lib/tlp";
        mode = "0755";
      }
      {
        directory = "/var/lib/systemd/timers";
        mode = "0755";
      }
      {
        directory = "/var/log/journal";
        group = "systemd-journal";
        mode = "2755";
      }
      {
        directory = "/etc/NetworkManager/system-connections";
        mode = "0700";
        configureParent = true;
      }
    ];

    files = [
      {
        file = "/etc/machine-id";
        inInitrd = true;
      }
      {
        file = "/var/lib/systemd/random-seed";
        how = "symlink";
        inInitrd = true;
        configureParent = true;
      }
    ];
  };

  # systemd-machine-id-commit.service cannot commit a bind-mounted
  # machine-id; the file already lives on persistent storage.
  systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];

  # The regular preservation mount units start before tmpfiles, so the
  # persistent source directories must already exist in initrd.
  boot.initrd.systemd.tmpfiles.settings.ember-persist = lib.genAttrs sysrootPaths (_path: {
    d = {
      user = "root";
      group = "root";
      mode = "0755";
    };
  });

  # The initrd mounts survive switch-root, but their generated stage-2 units
  # otherwise regain After=local-fs-pre.target. userborn must precede early
  # tmpfiles (and thus local-fs-pre), so explicitly retain early-mount
  # semantics in stage 2 as well. Keep shutdown ordering and unmount conflicts.
  systemd.mounts =
    map
      (directory: {
        what = "${persistRoot}${directory}";
        where = directory;
        options = "bind";
        unitConfig.DefaultDependencies = false;
        before = [
          "userborn.service"
          "umount.target"
        ];
        conflicts = [ "umount.target" ];
      })
      [
        "/var/lib/nixos"
        "/var/lib/userborn"
      ];

  # The backing filesystem participates in the same early dependency chain.
  # A drop-in keeps its device/type/options in the eventual storage module;
  # it does not select a disk or duplicate the fixture's filesystem layout.
  systemd.units."persist.mount" = {
    overrideStrategy = "asDropin";
    text = ''
      [Unit]
      DefaultDependencies=no
      Before=umount.target
      Conflicts=umount.target
    '';
  };

  # Only require the account mounts, rather than the whole preservation target.
  systemd.services.userborn.unitConfig.RequiresMountsFor = [
    "/var/lib/nixos"
    "/var/lib/userborn"
  ];

  # journald only needs its own persistent directory. The target-wide
  # ordering was another source of shutdown ordering cycles.
  systemd.services.systemd-journald.unitConfig.RequiresMountsFor = [
    "/var/log/journal"
  ];
}
