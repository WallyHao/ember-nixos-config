{
  config,
  lib,
  ...
}:
{
  # Activate nixos-facter once a report exists. Generate it on the host with:
  #   sudo nixos-facter --hardware cpu,memory,pci,bios -o hosts/ember/facter.json
  # The restricted probe set keeps serial numbers, MAC addresses and block
  # device paths out of the repository.
  hardware.facter.reportPath = lib.mkIf (builtins.pathExists ./facter.json) ./facter.json;

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;
  hardware.graphics.enable = true;

  # nvidia-drm's fbdev helper keeps the dGPU from entering runtime suspend and
  # is redundant here: the internal panel and console are driven by i915.
  boot.kernelParams = [
    "nvidia_drm.fbdev=0"
    # Permit deeper NVMe APST power states (55 ms max exit latency).
    "nvme_core.default_ps_max_latency_us=55000"
  ];

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

  # After S3 resume the NVIDIA HDMI audio function (01:00.1) can hold a
  # runtime PM reference on the dGPU, keeping it in D0. The extra power/heat
  # makes the EC ramp the fan even in low-power mode. Cycle the HDA function
  # once per resume so the GPU can enter D3 again.
  powerManagement.resumeCommands = ''
    if [ -e /sys/bus/pci/devices/0000:01:00.1 ]; then
      echo 0000:01:00.1 > /sys/bus/pci/drivers/snd_hda_intel/unbind 2>/dev/null || true
      sleep 1
      echo 0000:01:00.1 > /sys/bus/pci/drivers/snd_hda_intel/bind 2>/dev/null || true
    fi
  '';

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
