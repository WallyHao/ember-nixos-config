{
  services.journald.settings.Journal = {
    Storage = "persistent";
    SystemMaxUse = "128M";
    MaxRetentionSec = "14day";
  };

  # Weekly periodic TRIM, never on the boot critical path.
  services.fstrim.enable = true;
  services.fstrim.interval = "weekly";
  systemd.timers.fstrim.timerConfig.Persistent = false;
}
