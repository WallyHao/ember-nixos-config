{
  # Desktop target: the external ZHITAI 1 TB USB SSD that currently boots the
  # Folio system. The internal 2 TB NVMe holds unrelated Windows/data
  # partitions and is deliberately excluded. The by-id path includes the
  # drive serial, not the USB port.
  targetDisk = "/dev/disk/by-id/usb-ZHITAI_SPIRIT_PREMIUM_ZTE51T0AL262824228-0:0";
  layoutModule = ./storage.nix;
  layoutConfirmed = true;
}
