# Ember layout for the desktop's external 1 TB USB SSD.
# Declaring this layout does not partition anything; disko only runs it when
# explicitly invoked from an installer. The internal NVMe is not touched.
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
            label = "ember-esp";
            size = espSize;
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              extraArgs = [
                "-F"
                "32"
                "-n"
                "EMBER_EFI"
              ];
              mountpoint = "/boot";
              mountOptions = [
                "umask=0077"
                "noatime"
              ];
            };
          };
          system = {
            label = "ember-system";
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [
                "-L"
                "EMBER_SYSTEM"
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
