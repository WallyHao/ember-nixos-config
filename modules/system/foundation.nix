{
  config,
  lib,
  pkgs,
  ...
}:
{
  time.timeZone = "Asia/Shanghai";

  # English is the system and terminal default. Chinese text display and the
  # Fcitx5/Rime input method remain available through the installed fonts and
  # the zh_CN.UTF-8 locale below.
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "zh_CN.UTF-8/UTF-8"
  ];

  services.journald.settings.Journal = {
    Storage = "persistent";
    SystemMaxUse = "128M";
    MaxRetentionSec = "14day";
  };

  # Weekly periodic TRIM, never on the boot critical path.
  services.fstrim.enable = true;
  services.fstrim.interval = "weekly";
  systemd.timers.fstrim.timerConfig.Persistent = false;

  # The repository's bootstrap recipe must work before the user profile
  # (which also contains just) has been installed.
  # Graphviz stays system-level because skill tooling renders ```dot blocks to
  # SVG (render-graphs.js) and must work for any user or harness without a
  # profile install.
  environment.systemPackages = [
    pkgs.just
    pkgs.graphviz
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    use-xdg-base-directories = true;
    connect-timeout = 10;
    auto-optimise-store = false;

    # Large NVIDIA/kernel builds must not fill the tmpfs root.
    build-dir = "/nix/var/nix/builds";
  };

  nix.gc.automatic = false;
  nix.optimise.automatic = false;
  system.autoUpgrade.enable = false;

  systemd.tmpfiles.rules = [
    "d /nix/var/nix/builds 0755 root root -"
  ];

  # Share the system-generation retention and lock with nixos refresh.
  systemd.services.ember-nix-gc = {
    description = "Trim Ember system generations and collect unreachable store paths";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe (
        import ../maintenance/gc.nix {
          inherit pkgs;
          nix = config.nix.package;
          esp = config.boot.loader.efi.efiSysMountPoint;
        }
      );
    };
  };

  systemd.timers.ember-nix-gc = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Trim shortly after boot, then every three days. Retention is still
      # count-based (+5), so this only bounds how many generations can
      # accumulate between checks.
      OnBootSec = "30min";
      OnUnitActiveSec = "3d";
      # Do not replay a missed run during boot.
      Persistent = false;
      RandomizedDelaySec = "1h";
    };
  };

  nixpkgs.config = import ../../software/policy.nix {
    inherit lib;
  };
}
