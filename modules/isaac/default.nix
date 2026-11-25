# Isaac Sim / Isaac Lab user environment, adapted from the Folio module.
# The FHS wrapper supplies the Python, CUDA/Vulkan and build toolchain that the
# upstream Isaac Lab instructions expect; installs themselves stay in $HOME.
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  packages = import ./src/package.nix { inherit pkgs lib; };
in
{
  options.ember.isaac.enable = lib.mkOption {
    type = lib.types.bool;
    default = osConfig.ember.isaac.enable or false;
    description = "Install the Isaac Sim / Isaac Lab environment and launchers.";
  };

  config = lib.mkIf config.ember.isaac.enable {
    home.packages = builtins.attrValues packages;
    xdg.configFile."isaac/profile.json".source = ./src/versions.json;
  };
}
