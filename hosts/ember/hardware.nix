{
  config,
  lib,
  ...
}:
{
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;
  hardware.graphics.enable = true;

  # AX203 does not participate in mounting the local NVMe. Load both Intel
  # Wi-Fi components after the full firmware tree is available. The initrd
  # firmware picker sees only the module's advertised API 100, while this
  # card actually needs the bundled fallback API 89 firmware.
  boot.kernelModules = [
    "iwlwifi"
    "iwlmvm"
  ];

  # Intel iGPU is the default display path; NVIDIA is available through
  # PRIME render offload. No Xorg/display manager is enabled in phase 1.
  services.xserver.videoDrivers = [
    "modesetting"
    "nvidia"
  ];

  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    prime = {
      offload.enable = true;
      nvidiaBusId = "PCI:1:0:0";
      intelBusId = "PCI:0:2:0";
    };
    powerManagement.finegrained = true;
    # The open 595+ driver uses the kernel suspend notifier by default.
    # Do not enable the older systemd suspend services as well.
  };

  assertions = [
    {
      assertion = !config.hardware.nvidia.prime.sync.enable;
      message = "Phase 1 uses PRIME offload, not PRIME sync.";
    }
    {
      assertion = !config.hardware.nvidia.prime.reverseSync.enable;
      message = "Phase 1 does not enable PRIME reverse sync.";
    }
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "usbhid"
    "usb_storage"
    "uas"
    "sd_mod"
    "nvme"
    "btrfs"
    "crc32c"
    "i915"
    "r8169"
    "snd_hda_intel"
  ];
}
