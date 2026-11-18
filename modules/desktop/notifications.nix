# Folio's Mako behaviour, with colours derived exclusively from Stylix.
{ config, lib, ... }: {
  config = lib.mkIf config.ember.desktop.enable {
    systemd.user.services.mako = {
      Unit = {
        Description = "Ember notification daemon";
        After = [
          "graphical-session.target"
          "niri.service"
        ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "dbus";
        BusName = "org.freedesktop.Notifications";
        ExecStart = lib.getExe config.services.mako.package;
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
    services.mako = {
      enable = true;
      settings = {
        font = "${config.ember.desktop.fontFamily} ${toString config.ember.desktop.fontSize}";
        background-color = config.ember.appearance.colors.base00;
        text-color = config.ember.appearance.colors.base05;
        border-color = config.ember.appearance.colors.base04;
        border-radius = 0;
        border-size = 1;
        max-history = 0;
        default-timeout = 5000;
        anchor = "top-right";
        actions = true;
      };
    };
  };
}
