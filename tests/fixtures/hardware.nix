{
  config,
  lib,
  ...
}:
{
  # The VM has no battery, ACPI platform profile, or NVIDIA device. Disable
  # physical-only policy here and record why: this fixture is test-only and
  # does not prove the TLP or GPU power policy works on hardware.
  services.tlp.enable = lib.mkForce false;
  hardware.cpu.intel.updateMicrocode = lib.mkForce false;
  hardware.enableRedistributableFirmware = lib.mkForce false;
  hardware.enableAllFirmware = lib.mkForce false;
  hardware.bluetooth.enable = lib.mkForce false;

  services.xserver.videoDrivers = lib.mkForce [ "modesetting" ];
  hardware.graphics.enable = true;

  boot.kernelModules = lib.mkForce [ ];
  boot.initrd.availableKernelModules = lib.mkForce [
    "virtio_pci"
    "virtio_blk"
    "virtio_net"
    "virtio_console"
    "9p"
    "9pnet_virtio"
    "ext4"
    "vfat"
    "btrfs"
    "overlay"
    "crc32c"
    "xhci_pci"
    "usbhid"
    "sd_mod"
  ];

  assertions = [
    {
      assertion = !config.hardware.nvidia.enabled;
      message = "VM fixture must not load the NVIDIA driver.";
    }
  ];
}
