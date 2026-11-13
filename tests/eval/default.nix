{
  inputs,
  inventory,
  deployment,
}:
let
  lib = inputs.nixpkgs.lib;
  schema = import ../../inventory/schema.nix;
  mkHost = import ../../lib/mk-host.nix;

  preview = mkHost {
    inherit inputs inventory;
    hostName = "ember";
    hardwareModule = inventory.hosts.ember.physicalHardwareModule;
    storageModule = ../fixtures/storage.nix;
  };

  cfg = preview.system.config;
  user = cfg.users.users.wallyhao;
  preservation = cfg.preservation.preserveAt."/persist";
  unboundDeployment = import ../../lib/deployment.nix {
    inventory = lib.recursiveUpdate inventory {
      hosts.ember.storage = {
        targetDisk = null;
        layoutModule = null;
        layoutConfirmed = false;
      };
    };
  };

  hasPreservedDirectory =
    path:
    builtins.any (entry: entry.directory == path) preservation.directories
    || builtins.any (userEntry: builtins.any (entry: entry.directory == path) userEntry.directories) (
      builtins.attrValues preservation.users
    );

  checks = {
    identity-host = cfg.networking.hostName == "ember";
    identity-system = cfg.system.stateVersion == "26.11";
    identity-user = user.isNormalUser && user.uid == 1000 && user.home == "/home/wallyhao";
    identity-shell = lib.getName user.shell == "zsh";
    storage-bound = deployment.storageBound && deployment.installable;
    storage-reason = builtins.match ".*bound and confirmed.*" deployment.reason != null;
    boot-loader =
      cfg.boot.loader.systemd-boot.enable
      && cfg.boot.loader.timeout == 0
      && cfg.boot.loader.systemd-boot.configurationLimit == 5
      && !cfg.boot.loader.grub.enable;
    boot-default-target =
      cfg.systemd.defaultUnit == "graphical.target"
      && cfg.services.getty.autologinUser == null
      && cfg.systemd.services."getty@tty2".enable;
    boot-initrd = cfg.boot.initrd.enable && cfg.boot.initrd.systemd ? tmpfiles;
    hardware-cpu = cfg.hardware.cpu.intel.updateMicrocode && !cfg.hardware.cpu.amd.updateMicrocode;
    hardware-nvidia =
      cfg.hardware.nvidia.enabled
      && cfg.hardware.nvidia.open
      && cfg.hardware.nvidia.prime.offload.enable
      && !cfg.hardware.nvidia.prime.sync.enable
      && !cfg.hardware.nvidia.prime.reverseSync.enable
      && cfg.hardware.nvidia.prime.nvidiaBusId == "PCI:1:0:0"
      && cfg.hardware.nvidia.prime.intelBusId == "PCI:0:2:0"
      && cfg.hardware.nvidia.powerManagement.finegrained
      && !cfg.hardware.nvidia.powerManagement.enable;
    hardware-video-drivers =
      builtins.elem "nvidia" cfg.services.xserver.videoDrivers
      && !(builtins.elem "amdgpu" cfg.services.xserver.videoDrivers);
    power-tlp = cfg.services.tlp.enable && !cfg.services.tlp.pd.enable;
    power-exclusive =
      !cfg.services.power-profiles-daemon.enable
      && !cfg.services.auto-cpufreq.enable
      && !cfg.services.tuned.enable
      && cfg.powerManagement.cpuFreqGovernor == null;
    power-tlp-params =
      cfg.services.tlp.settings.CPU_SCALING_GOVERNOR_ON_AC == "powersave"
      && cfg.services.tlp.settings.CPU_SCALING_GOVERNOR_ON_BAT == "powersave"
      && cfg.services.tlp.settings.CPU_ENERGY_PERF_POLICY_ON_AC == "balance_performance"
      && cfg.services.tlp.settings.CPU_ENERGY_PERF_POLICY_ON_BAT == "balance_power"
      && cfg.services.tlp.settings.PLATFORM_PROFILE_ON_AC == "balanced"
      && cfg.services.tlp.settings.PLATFORM_PROFILE_ON_BAT == "low-power"
      && cfg.services.tlp.settings.RUNTIME_PM_ON_AC == "auto"
      && cfg.services.tlp.settings.RUNTIME_PM_ON_BAT == "auto";
    accounts-userborn =
      cfg.services.userborn.enable
      && cfg.services.userborn.passwordFilesLocation == "/var/lib/nixos"
      && !cfg.services.userborn.importLegacyState
      && cfg.users.mutableUsers
      && cfg.security.sudo.wheelNeedsPassword;
    accounts-password =
      user.initialHashedPassword == inventory.users.wallyhao.initialHashedPassword
      && user.hashedPassword == null
      && user.hashedPasswordFile == null
      && user.password == null
      && cfg.users.users.root.hashedPassword == null
      && cfg.users.users.root.hashedPasswordFile == null;
    accounts-groups =
      builtins.elem "wheel" user.extraGroups && builtins.elem "networkmanager" user.extraGroups;
    network =
      cfg.networking.networkmanager.enable
      && cfg.networking.networkmanager.dns == "systemd-resolved"
      && cfg.services.resolved.enable
      && cfg.networking.firewall.enable
      && cfg.networking.firewall.allowedTCPPorts == [ ]
      && cfg.networking.firewall.allowedUDPPorts == [ ]
      && !cfg.networking.useNetworkd
      && !cfg.systemd.services.NetworkManager-wait-online.enable
      && !cfg.systemd.network.wait-online.enable
      && cfg.services.timesyncd.enable;
    memory =
      cfg.zramSwap.enable
      && cfg.zramSwap.memoryPercent == 25
      && cfg.zramSwap.priority == 100
      && cfg.zramSwap.algorithm == "zstd"
      && cfg.swapDevices == [ ]
      && cfg.boot.resumeDevice == ""
      && cfg.nix.settings.max-jobs == 2
      && cfg.nix.settings.cores == 4;
    maintenance =
      cfg.services.journald.settings.Journal.Storage == "persistent"
      && cfg.services.journald.settings.Journal.SystemMaxUse == "128M"
      && cfg.services.journald.settings.Journal.MaxRetentionSec == "14day"
      && cfg.services.fstrim.enable
      && !cfg.systemd.timers.fstrim.timerConfig.Persistent
      && !cfg.nix.gc.automatic
      && !cfg.nix.optimise.automatic
      && !cfg.system.autoUpgrade.enable
      && cfg.nix.settings.build-dir == "/nix/var/nix/builds";
    platform =
      cfg.security.polkit.enable
      && cfg.services.dbus.enable
      && cfg.hardware.bluetooth.enable
      && !cfg.hardware.bluetooth.powerOnBoot
      && !cfg.services.openssh.enable
      && !cfg.services.avahi.enable
      && !cfg.services.printing.enable
      && !cfg.services.fwupd.enable
      && !cfg.virtualisation.docker.enable
      && !cfg.virtualisation.podman.enable
      && !cfg.virtualisation.libvirtd.enable;
    preservation-enabled =
      cfg.preservation.enable
      && hasPreservedDirectory "/var/lib/nixos"
      && hasPreservedDirectory "/var/lib/userborn"
      && hasPreservedDirectory "/var/log/journal"
      && hasPreservedDirectory "/etc/NetworkManager/system-connections"
      && hasPreservedDirectory "/home/wallyhao/Workspace"
      && hasPreservedDirectory "/home/wallyhao/.local/state/nix";
    preservation-early =
      builtins.any (entry: entry.directory == "/var/lib/nixos" && entry.inInitrd) preservation.directories
      && builtins.any (
        entry: entry.directory == "/var/lib/userborn" && entry.inInitrd
      ) preservation.directories
      && builtins.any (entry: entry.file == "/etc/machine-id" && entry.inInitrd) preservation.files
      && cfg.boot.initrd.systemd.tmpfiles.settings ? ember-persist;
    preservation-ordering =
      builtins.elem "/var/lib/nixos" (cfg.systemd.services.userborn.unitConfig.RequiresMountsFor or [ ])
      && builtins.elem "/var/lib/userborn" (
        cfg.systemd.services.userborn.unitConfig.RequiresMountsFor or [ ]
      )
      && builtins.elem "/var/log/journal" (
        cfg.systemd.services.systemd-journald.unitConfig.RequiresMountsFor or [ ]
      )
      && !(builtins.elem "preservation.target" (cfg.systemd.services.userborn.after or [ ]))
      && !(builtins.elem "preservation.target" (cfg.systemd.services.systemd-journald.after or [ ]));
    locale =
      cfg.time.timeZone == "Asia/Shanghai"
      && cfg.i18n.defaultLocale == "en_US.UTF-8"
      && builtins.elem "en_US.UTF-8/UTF-8" cfg.i18n.supportedLocales
      && builtins.elem "zh_CN.UTF-8/UTF-8" cfg.i18n.supportedLocales
      && cfg.environment.sessionVariables.LANG == "en_US.UTF-8"
      && !(cfg.environment.sessionVariables ? LC_ALL)
      && cfg.i18n.extraLocaleSettings == { };
    filesystems =
      (cfg.boot.supportedFilesystems.ntfs or false) && (cfg.boot.supportedFilesystems.exfat or false);
    preview-storage =
      builtins.elem "/nix" (builtins.attrNames cfg.fileSystems)
      && builtins.elem "/persist" (builtins.attrNames cfg.fileSystems)
      && builtins.elem "/boot" (builtins.attrNames cfg.fileSystems);
    unbound-target-gate = !unboundDeployment.storageBound && !unboundDeployment.installable;
    preview-virtual-disk = cfg.disko.devices.disk.main.device == "/dev/vda";
  };

  failed = builtins.filter (name: checks.${name} != true) (builtins.attrNames checks);

  mustFail =
    name: value:
    let
      result = builtins.tryEval value;
    in
    if result.success then throw "negative eval contract did not fail: ${name}" else name;

  baseUser = inventory.users.wallyhao;
  duplicateUidInventory = inventory // {
    users = inventory.users // {
      wallyhao2 = baseUser // {
        name = "wallyhao2";
      };
    };
    hosts = inventory.hosts // {
      ember = inventory.hosts.ember // {
        users = [
          "wallyhao"
          "wallyhao2"
        ];
      };
    };
  };
  missingUserInventory = inventory // {
    hosts = inventory.hosts // {
      ember = inventory.hosts.ember // {
        users = [ "missing" ];
      };
    };
  };
  partialStorageInventory = inventory // {
    hosts = inventory.hosts // {
      ember = inventory.hosts.ember // {
        storage = {
          targetDisk = "/dev/vda";
          layoutModule = null;
          layoutConfirmed = false;
        };
      };
    };
  };

  negative = [
    (mustFail "duplicate-uid" (schema {
      inherit lib;
      inventory = duplicateUidInventory;
    }))
    (mustFail "missing-user" (schema {
      inherit lib;
      inventory = missingUserInventory;
    }))
    (mustFail "partial-storage" (schema {
      inherit lib;
      inventory = partialStorageInventory;
    }))
    (mustFail "tlp-with-ppd" (
      (lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = preview.modules ++ [
          {
            services.tlp.enable = true;
            services.power-profiles-daemon.enable = true;
          }
        ];
      }).config.system.build.toplevel.drvPath
    ))
  ];

  negativeNames = map (x: x) negative;
in
if failed != [ ] then
  throw "ember eval contracts failed: ${builtins.concatStringsSep ", " failed}"
else
  checks
  // {
    inherit (deployment) storageBound installable;
    negative = negativeNames;
  }
