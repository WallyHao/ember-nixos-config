{
  # First-pass values for the observed Intel HWP/EPP and ACPI platform
  # profile support. These are configuration, not measured optima.
  #
  # PLATFORM_PROFILE_* is the only fan-speed lever this machine exposes
  # (Fn+Q / Lenovo power modes: low-power, balanced, balanced-performance,
  # performance, custom). There is no hwmon fan/pwm node on 83JJ, and this
  # kernel does not build legion_laptop, so the EC fan curve itself cannot be
  # adjusted from Linux.
  #
  # AC therefore uses low-power (the EC "Quiet" mode) too: the fan stays off
  # the high curve while plugged in. Cost: lower sustained PL1/PL2. To get the
  # performance curve back, set PLATFORM_PROFILE_ON_AC = "balanced" and
  # `nixos apply` (no reboot needed; the tlp unit is restarted).
  services.tlp.settings = {
    CPU_SCALING_GOVERNOR_ON_AC = "powersave";
    CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
    CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
    CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
    PLATFORM_PROFILE_ON_AC = "low-power";
    PLATFORM_PROFILE_ON_BAT = "low-power";
    PCIE_ASPM_ON_AC = "default";
    PCIE_ASPM_ON_BAT = "powersupersave";
    RUNTIME_PM_ON_AC = "auto";
    RUNTIME_PM_ON_BAT = "auto";
  };
}
