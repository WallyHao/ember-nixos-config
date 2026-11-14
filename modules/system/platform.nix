{
  security.polkit.enable = true;
  services.dbus.enable = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;

  # No unneeded network, printing, container, firmware-update, or desktop
  # session services in phase 1.
  services.openssh.enable = false;
  services.avahi.enable = false;
  services.printing.enable = false;
  services.fwupd.enable = false;
  virtualisation.docker.enable = false;
  virtualisation.podman.enable = false;
  virtualisation.libvirtd.enable = false;
}
