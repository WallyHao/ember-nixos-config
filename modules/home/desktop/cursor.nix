{
  config,
  lib,
  pkgs,
  ...
}:
let
  cursorTheme = pkgs.callPackage ../../../packages/nordzy-cursors-emberlight.nix { };
in
{
  config = lib.mkIf config.ember.desktop.enable {
    home.pointerCursor = {
      enable = true;
      package = cursorTheme;
      name = "Nordzy-Emberlight";
      size = 24;
      gtk.enable = true;
      x11.enable = true;
    };
  };
}
