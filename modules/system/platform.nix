{
  config,
  pkgs,
  lib,
  ...
}:
{
  # uv installs python-build-standalone CPython builds that expect the generic
  # Linux ELF interpreter. nix-ld provides it; glibc is appended because that
  # build links against the stock loader rather than a Nix-patched one.
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = lib.mkAfter [ pkgs.glibc ];

  security.polkit.enable = true;
  services.dbus.enable = true;

  # Privileged backend for automatic removable-media mounting. udiskie in the
  # user session drives it; see modules/desktop/disks.nix.
  services.udisks2.enable = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # The IdeaPad platform keeps its own Bluetooth rfkill switch in the EC with a
  # persisted "off" state. Registering that switch drags the kernel's global
  # Bluetooth rfkill state to blocked, hci0 inherits it, and BlueZ can then
  # neither list nor power the controller (PowerState=off-blocked). Clear every
  # Bluetooth switch as soon as one appears and again before bluetoothd starts;
  # BlueZ AutoEnable (powerOnBoot) then powers the adapter on.
  services.udev.extraRules = lib.mkIf config.hardware.bluetooth.enable ''
    ACTION=="add", SUBSYSTEM=="rfkill", ATTR{type}=="bluetooth", RUN+="${pkgs.util-linux}/bin/rfkill unblock bluetooth"
  '';

  systemd.services.bluetooth = lib.mkIf config.hardware.bluetooth.enable {
    serviceConfig.ExecStartPre = [ "-${pkgs.util-linux}/bin/rfkill unblock bluetooth" ];
  };

  # No unneeded network, printing, container, firmware-update, or desktop
  # session services in phase 1. QEMU/KVM guests live in virtualisation.nix.
  services.openssh.enable = false;
  services.avahi.enable = false;
  services.printing.enable = false;
  services.fwupd.enable = false;
  virtualisation.docker.enable = false;
  virtualisation.podman.enable = false;
}
