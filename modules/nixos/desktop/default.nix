{
  config,
  lib,
  ...
}:
let
  cfg = config.ember.desktop;
in
{
  options.ember.desktop.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable the Ember graphical user session and Home Manager desktop.";
  };

  imports = [
    ./session.nix
    ./security.nix
    ./audio.nix
    ./portals.nix
    ./input-method.nix
  ];

}
