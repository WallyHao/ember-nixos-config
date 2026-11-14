# One implementation for the laptop and isolated virtual disks.
# Declaring a layout does not partition any device.
{
  device,
  espSize ? "2G",
}:
let
  btrfsOptions = [
    "noatime"
    "compress=zstd:1"
    "nodiscard"
  ];
in
{
  disko.devices = {
    disk.main = {
      inherit device;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            label = "hearth-esp";
            size = espSize;
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              extraArgs = [
                "-F"
                "32"
                "-n"
                "HEARTH_EFI"
              ];
              mountpoint = "/boot";
              mountOptions = [
                "umask=0077"
                "noatime"
              ];
            };
          };
          system = {
            label = "hearth-system";
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [
                "-L"
                "HEARTH_SYSTEM"
              ];
              subvolumes = {
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = btrfsOptions;
                };
                "@persist" = {
                  mountpoint = "/persist";
                  mountOptions = btrfsOptions;
                };
              };
            };
          };
        };
      };
    };
    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [
        "size=2G"
        "mode=755"
      ];
    };
  };
  fileSystems."/nix".neededForBoot = true;
  fileSystems."/persist".neededForBoot = true;
}
