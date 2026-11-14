{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.ember.desktop.enable {
    systemd.user.services.ember-wallpaper = {
      Unit = {
        Description = "Emberlight solid background";
        PartOf = [ "graphical-session.target" ];
        After = [
          "graphical-session.target"
          "niri.service"
        ];
      };
      Service = {
        ExecStart = "${pkgs.swaybg}/bin/swaybg -c ${config.ember.appearance.colors.base00}";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
