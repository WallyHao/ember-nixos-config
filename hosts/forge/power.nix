{
  # Desktop power policy: AMD P-State/EPP on mains only. There is no battery,
  # ACPI platform profile or Lenovo EC on this machine, so battery and
  # platform-profile keys from the laptop policy are deliberately absent.
  services.tlp.settings = {
    CPU_SCALING_GOVERNOR_ON_AC = "powersave";
    CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
    PCIE_ASPM_ON_AC = "default";
    RUNTIME_PM_ON_AC = "auto";
  };
}
