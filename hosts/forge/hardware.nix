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

  # No PRIME wiring: PCI matching selects amdgpu and nvidia, and the display
  # runs on the RTX 3090. Niri keeps every DRM device visible.
  ember.hardware.kvmModule = "kvm-amd";
}
