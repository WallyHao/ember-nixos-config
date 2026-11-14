{
  config,
  ...
}:
{
  zramSwap.enable = true;
  zramSwap.memoryPercent = 25;
  zramSwap.priority = 100;
  zramSwap.algorithm = "zstd";

  # No disk swap or hibernation target is selected in phase 1.
  swapDevices = [ ];

  # Bound parallel builds on a 20-thread battery-powered laptop.
  nix.settings.max-jobs = 2;
  nix.settings.cores = 4;

  assertions = [
    {
      assertion = config.swapDevices == [ ];
      message = "Phase 1 must not configure disk swap devices.";
    }
  ];
}
