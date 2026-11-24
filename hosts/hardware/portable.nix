# Machine-independent driver closure for the supported Ember machines:
# the Intel i7-13650HX / RTX 4060 laptop and the AMD Ryzen 7 9700X /
# RTX 3090 desktop. Kernel PCI matching selects the driver; no fixed PCI
# addresses, PRIME wiring, DRM card numbers or render-device overrides live
# here. Machine-specific facts and overrides belong in hosts/<name>/hardware.nix.
{ config, ... }:
{
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;
  hardware.cpu.amd.updateMicrocode = true;

  # Early KMS for both integrated GPUs; the unused module is inert.
  boot.initrd.kernelModules = [
    "i915"
    "amdgpu"
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [
    "nvidia"
    "amdgpu"
    "modesetting"
  ];

  # The open module covers both RTX cards. finegrained power management is
  # host policy: it requires PRIME offload, which some machines do not use.
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
  };
}
