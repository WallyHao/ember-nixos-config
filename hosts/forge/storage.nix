import ./storage-layout.nix {
  device = (import ./storage-spec.nix).targetDisk;
}
