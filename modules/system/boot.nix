{
  lib,
  ...
}:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.timeout = 0;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
  boot.loader.grub.enable = false;

  # The locked NixOS release has no scripted initrd; systemd initrd is the
  # only mode and carries the early preservation mounts.
  systemd.defaultUnit = lib.mkDefault "multi-user.target";
  services.getty.autologinUser = lib.mkForce null;

  # Local login must not wait for network-online.
  systemd.services.NetworkManager-wait-online.enable = false;
  systemd.network.wait-online.enable = false;

  # Do not hide diagnostics with quiet/loglevel tuning.
  boot.kernelParams = [ ];

  # Recovery is documented, not hidden: timeout=0 only removes the automatic
  # wait, not the Space-triggered systemd-boot menu.
}
