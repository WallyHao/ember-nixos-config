{
  lib,
  ...
}:
{
  imports = [
    ../../suites/nixos/workstation.nix
    ./power.nix
  ];

  # The system disk is an external USB SSD; do not add or reorder firmware
  # boot variables on the internal Windows disk. Select the USB entry from
  # the firmware menu instead.
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  boot.loader.timeout = lib.mkForce 3;

  # Steam/Proton stack on the RTX 3090. The current monitor is on the AMD
  # iGPU output, so games use the same PRIME render-offload path as the
  # laptop; hosts/forge/hardware.nix owns the bus IDs.
  ember.gaming = {
    enable = true;
    nvidiaOffload = true;
  };

  # Primary Isaac Sim / Isaac Lab machine (RTX 3090).
  ember.isaac.enable = true;
}
