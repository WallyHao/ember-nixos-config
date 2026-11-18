{ lib, ... }:
{
  options.ember.desktop.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable the Ember graphical user session and Home Manager desktop.";
  };

  imports = import ../../lib/module-dir.nix ./.;
}
