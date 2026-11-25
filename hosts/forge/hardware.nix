# Machine-specific facts and overrides for the AMD desktop recorded in Folio:
# MSI MAG B650M MORTAR WIFI, Ryzen 7 9700X, AMD integrated graphics and an
# RTX 3090. The shared hosts/hardware/portable.nix closure owns firmware,
# microcode, i915/amdgpu, the 32-bit graphics stack, video drivers and the
# NVIDIA open module.
{ lib, ... }:
{
  # Activate nixos-facter once a report exists. Generate it on the host with:
  #   sudo nixos-facter --hardware cpu,memory,pci,bios -o hosts/forge/facter.json
  hardware.facter.reportPath = lib.mkIf (builtins.pathExists ./facter.json) ./facter.json;

  # RZ616/MT7922 Wi-Fi and the RTL8125 Ethernet controller autoload from PCI
  # matching. Keep the boot path independent of the network.
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "usbhid"
    "usb_storage"
    "uas"
    "sd_mod"
    "nvme"
    "btrfs"
    "crc32c"
    "r8169"
    "snd_hda_intel"
  ];

  # Current desk wiring: the monitor is connected to the motherboard DP
  # output, so the AMD iGPU drives the display and the RTX 3090 is the
  # render/offload and compute device. Bus IDs are decimal:
  # 0000:10:00.0 -> PCI:16:0:0, 0000:01:00.0 -> PCI:1:0:0.
  # If the monitor is later moved to the RTX 3090, remove this block and set
  # ember.gaming.nvidiaOffload = false in hosts/forge/default.nix.
  hardware.nvidia.prime = {
    offload.enable = true;
    offload.enableOffloadCmd = true;
    amdgpuBusId = "PCI:16:0:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  ember.hardware.kvmModule = "kvm-amd";
}
