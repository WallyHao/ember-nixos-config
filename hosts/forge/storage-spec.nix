{
  # The desktop disk has not been inspected from this repository. Keep the
  # deployment gate closed until the operator records the stable by-id path,
  # a reviewed layout module and explicit confirmation:
  #
  #   targetDisk = "/dev/disk/by-id/...";
  #   layoutModule = ./storage.nix;   # a reviewed layout, not the laptop's disk
  #   layoutConfirmed = true;
  #
  # `hosts/ember/storage-layout.nix` is a layout implementation, but its labels
  # and subvolumes describe the laptop installation. Do not copy the laptop's
  # identifiers to this machine.
  targetDisk = null;
  layoutModule = null;
  layoutConfirmed = false;
}
