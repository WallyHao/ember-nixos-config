{
  config,
  pkgs,
  ...
}:
{
  # The repository's bootstrap recipe must work before the user profile
  # (which also contains just) has been installed.
  environment.systemPackages = [ pkgs.just ];

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

  # Native system-profile trimming first, then collect only unreachable
  # objects. No global --delete-older-than scan of user profiles.
  systemd.services.ember-nix-gc = {
    description = "Trim Ember system generations and collect unreachable store paths";
    serviceConfig.Type = "oneshot";
    path = [ config.nix.package ];
    script = ''
      if [ -e /nix/var/nix/profiles/system ]; then
        nix-env -p /nix/var/nix/profiles/system --delete-generations +5
      fi
      nix-collect-garbage
    '';
  };

  systemd.timers.ember-nix-gc = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      # Do not replay a missed weekly run during boot.
      Persistent = false;
      RandomizedDelaySec = "1h";
    };
  };
}
