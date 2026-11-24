# Host-scoped hardware facts consumed by otherwise generic modules.
# Set these in hosts/<name>/hardware.nix; evaluation never probes hardware.
{
  config,
  lib,
  ...
}:
{
  options.ember.hardware = {
    ignoreDrmDevice = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        DRM device path Niri should ignore. Host policy: a laptop may hide its
        discrete GPU so runtime suspend works, while a desktop must not.
      '';
    };

    kvmModule = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "kvm-intel"
          "kvm-amd"
        ]
      );
      default = null;
      description = ''
        CPU-specific KVM module to load explicitly. Left unset by the shared
        hardware closure because the module depends on the physical machine.
      '';
    };
  };

  config = {
    boot.kernelModules = lib.optional (config.ember.hardware.kvmModule != null) (
      config.ember.hardware.kvmModule
    );
  };
}
