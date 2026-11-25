{
  lib,
  ...
}:
{
  options.ember.isaac.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Install the Isaac Sim / Isaac Lab user environment on this host. The
      packages are added by modules/isaac through Home Manager; the build
      itself requires an NVIDIA GPU with a working Vulkan/CUDA driver.
    '';
  };
}
