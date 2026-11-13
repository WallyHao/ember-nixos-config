# Same layout as the laptop, on a virtual disk only. A smaller ESP leaves
# space on the test driver's small disposable disk.
import ../../hosts/laptop/storage-layout.nix {
  device = "/dev/vda";
  espSize = "512M";
}
