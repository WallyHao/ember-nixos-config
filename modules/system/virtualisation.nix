{
  pkgs,
  ...
}:
{
  # QEMU/KVM guests managed through libvirt, with virt-manager as the desktop
  # front end. The libvirt module already requires Polkit, which platform.nix
  # enables; the account reaches the system connection through the "libvirtd"
  # group declared in inventory.
  virtualisation.libvirtd = {
    enable = true;

    # pkg.qemu only emulates the host architecture, which is all a local
    # desktop VM needs. Switch back to pkgs.qemu if cross-architecture
    # emulation is ever required.
    qemu.package = pkgs.qemu_kvm;
  };

  programs.virt-manager.enable = true;

  # The CPU-specific KVM module is host policy; see modules/system/hardware.nix
  # and the matching ember.hardware.kvmModule setting in hosts/<name>/.
}
