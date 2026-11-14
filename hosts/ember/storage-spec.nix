{
  # User authorized the whole internal 512 GB NVMe for Hearth; retain no data.
  targetDisk = "/dev/disk/by-id/nvme-eui.5cdfb804515050ab";
  layoutModule = ./storage.nix;
  layoutConfirmed = true;
}
