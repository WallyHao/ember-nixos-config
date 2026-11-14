{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.ember.desktop.enable {
    security.pam.services.swaylock = { };
    programs.dconf.enable = true;
    environment.systemPackages = [ pkgs.brightnessctl ];
  };
}
