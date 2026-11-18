{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.ember.desktop.enable {
    # Mount filesystems as soon as udisks2 reports them and clean up their
    # mountpoints when the device disappears. Removable drives (USB, SD) mount
    # without a prompt under /run/media/wallyhao/<label>; the fstab-managed
    # system subvolumes are already mounted and are left alone.
    services.udiskie = {
      enable = true;
      automount = true;
      notify = true;
      tray = "never";
    };
  };
}
