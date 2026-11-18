{
  config,
  ...
}:
{
  services.tlp.enable = true;
  services.tlp.pd.enable = false;
  services.upower.enable = true;

  services.power-profiles-daemon.enable = false;
  services.auto-cpufreq.enable = false;
  services.tuned.enable = false;

  # TLP is the only power-policy executor. Its kernel-module side effects
  # (msr, udev rules) are kept; no other governor/profile service is enabled.
  assertions = [
    {
      assertion = !(config.services.tlp.enable && config.services.power-profiles-daemon.enable);
      message = "TLP and power-profiles-daemon must not both be enabled.";
    }
    {
      assertion = !(config.services.tlp.enable && config.services.auto-cpufreq.enable);
      message = "TLP and auto-cpufreq must not both be enabled.";
    }
    {
      assertion = !(config.services.tlp.enable && config.services.tuned.enable);
      message = "TLP and tuned must not both be enabled.";
    }
  ];
}
